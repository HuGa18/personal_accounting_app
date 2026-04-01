import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db.dart';
import '../models/account.dart';
import '../models/transaction.dart' as tx;
import '../models/category.dart';
import '../models/budget.dart';
import '../models/import_record.dart';
import '../utils/date_utils.dart';
import '../utils/id_utils.dart';

/// 备份结果
class BackupResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int? recordCount;

  BackupResult({
    required this.success,
    this.filePath,
    this.error,
    this.recordCount,
  });
}

/// 恢复结果
class RestoreResult {
  final bool success;
  final String? error;
  final Map<String, int>? restoredCounts;
  final String? snapshotPath;

  RestoreResult({
    required this.success,
    this.error,
    this.restoredCounts,
    this.snapshotPath,
  });
}

/// 备份数据结构
class BackupData {
  final String version;
  final DateTime backupDate;
  final List<Account> accounts;
  final List<tx.Transaction> transactions;
  final List<Category> categories;
  final List<Budget> budgets;
  final List<ImportRecord> importRecords;

  BackupData({
    required this.version,
    required this.backupDate,
    required this.accounts,
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.importRecords,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'backup_date': backupDate.toIso8601String(),
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'budgets': budgets.map((b) => b.toJson()).toList(),
      'import_records': importRecords.map((r) => r.toJson()).toList(),
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> map) {
    return BackupData(
      version: map['version'] ?? '1.0',
      backupDate: DateTime.parse(map['backup_date']),
      accounts: (map['accounts'] as List)
          .map((a) => Account.fromJson(a))
          .toList(),
      transactions: (map['transactions'] as List)
          .map((t) => tx.Transaction.fromJson(t))
          .toList(),
      categories: (map['categories'] as List)
          .map((c) => Category.fromJson(c))
          .toList(),
      budgets: (map['budgets'] as List)
          .map((b) => Budget.fromJson(b))
          .toList(),
      importRecords: (map['import_records'] as List)
          .map((r) => ImportRecord.fromJson(r))
          .toList(),
    );
  }
}

/// 数据备份恢复服务
/// 
/// 功能：
/// - 支持数据备份（加密压缩）
/// - 支持数据恢复
/// - 支持备份密码设置
/// - 恢复前创建快照
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  static const String _backupVersion = '1.0';
  static const String _passwordKey = 'backup_password_hash';
  static const String _passwordHintKey = 'backup_password_hint';
  
  /// 获取数据库实例
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// 设置备份密码
  /// 
  /// [password] 备份密码
  /// [hint] 密码提示（可选）
  Future<void> setPassword(String password, {String? hint}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 使用 SHA256 哈希存储密码
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    
    await prefs.setString(_passwordKey, hash.toString());
    
    if (hint != null) {
      await prefs.setString(_passwordHintKey, hint);
    }
  }

  /// 验证备份密码
  /// 
  /// [password] 待验证的密码
  Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_passwordKey);
    
    if (storedHash == null) {
      // 未设置密码，任何密码都允许
      return true;
    }
    
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    
    return hash.toString() == storedHash;
  }

  /// 检查是否已设置密码
  Future<bool> hasPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_passwordKey);
  }

  /// 获取密码提示
  Future<String?> getPasswordHint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordHintKey);
  }

  /// 清除备份密码
  Future<void> clearPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passwordKey);
    await prefs.remove(_passwordHintKey);
  }

  /// 备份数据
  /// 
  /// [password] 备份密码（可选，如未设置则使用默认密码）
  Future<BackupResult> backup({String? password}) async {
    try {
      final db = await _db;
      
      // 获取所有数据（包括已删除的，以便完整备份）
      final accounts = await _getAllAccountsWithDeleted(db);
      final transactions = await _getAllTransactionsWithDeleted(db);
      final categories = await _getAllCategoriesWithDeleted(db);
      final budgets = await _getAllBudgetsWithDeleted(db);
      final importRecords = await _getAllImportRecordsWithDeleted(db);

      // 创建备份数据
      final backupData = BackupData(
        version: _backupVersion,
        backupDate: DateTime.now(),
        accounts: accounts,
        transactions: transactions,
        categories: categories,
        budgets: budgets,
        importRecords: importRecords,
      );

      // 转换为 JSON
      final jsonString = jsonEncode(backupData.toJson());
      
      // 使用密码加密
      final actualPassword = password ?? await _getDefaultPassword();
      final encryptedData = _encrypt(jsonString, actualPassword);
      
      // 压缩数据
      final compressedData = _compress(encryptedData);

      // 保存到文件
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '记账数据备份_${DateUtils.formatDate(DateTime.now())}.mabak';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(compressedData);

      final totalCount = accounts.length + transactions.length + 
          categories.length + budgets.length + importRecords.length;

      return BackupResult(
        success: true,
        filePath: file.path,
        recordCount: totalCount,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        error: '备份失败: $e',
      );
    }
  }

  /// 恢复数据
  /// 
  /// [filePath] 备份文件路径
  /// [password] 备份密码
  Future<RestoreResult> restore({
    required String filePath,
    required String password,
  }) async {
    try {
      // 验证密码
      if (!await verifyPassword(password)) {
        return RestoreResult(
          success: false,
          error: '密码错误',
        );
      }

      // 读取备份文件
      final file = File(filePath);
      if (!await file.exists()) {
        return RestoreResult(
          success: false,
          error: '备份文件不存在',
        );
      }

      // 解压数据
      final compressedData = await file.readAsBytes();
      final encryptedData = _decompress(compressedData);
      
      // 解密数据
      final jsonString = _decrypt(encryptedData, password);
      
      // 解析 JSON
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final backupData = BackupData.fromJson(jsonMap);

      // 创建快照
      final snapshotPath = await _createSnapshot();

      // 恢复数据
      final restoredCounts = await _restoreData(backupData);

      return RestoreResult(
        success: true,
        restoredCounts: restoredCounts,
        snapshotPath: snapshotPath,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        error: '恢复失败: $e',
      );
    }
  }

  /// 从快照恢复
  /// 
  /// [snapshotPath] 快照文件路径
  Future<RestoreResult> restoreFromSnapshot(String snapshotPath) async {
    try {
      final file = File(snapshotPath);
      if (!await file.exists()) {
        return RestoreResult(
          success: false,
          error: '快照文件不存在',
        );
      }

      // 读取快照（快照不加密，仅压缩）
      final compressedData = await file.readAsBytes();
      final jsonString = utf8.decode(_decompress(compressedData));
      
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final backupData = BackupData.fromJson(jsonMap);

      // 恢复数据（不需要创建新快照）
      final restoredCounts = await _restoreData(backupData);

      return RestoreResult(
        success: true,
        restoredCounts: restoredCounts,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        error: '快照恢复失败: $e',
      );
    }
  }

  /// 创建快照（恢复前备份当前数据）
  Future<String> _createSnapshot() async {
    final db = await _db;
    
    // 获取所有数据
    final accounts = await _getAllAccountsWithDeleted(db);
    final transactions = await _getAllTransactionsWithDeleted(db);
    final categories = await _getAllCategoriesWithDeleted(db);
    final budgets = await _getAllBudgetsWithDeleted(db);
    final importRecords = await _getAllImportRecordsWithDeleted(db);

    final snapshotData = BackupData(
      version: _backupVersion,
      backupDate: DateTime.now(),
      accounts: accounts,
      transactions: transactions,
      categories: categories,
      budgets: budgets,
      importRecords: importRecords,
    );

    final jsonString = jsonEncode(snapshotData.toJson());
    final compressedData = _compress(utf8.encode(jsonString));

    final directory = await getApplicationDocumentsDirectory();
    final snapshotsDir = Directory('${directory.path}/snapshots');
    if (!await snapshotsDir.exists()) {
      await snapshotsDir.create(recursive: true);
    }

    final fileName = 'snapshot_${DateUtils.formatDateTime(DateTime.now()).replaceAll(':', '-')}.snap';
    final file = File('${snapshotsDir.path}/$fileName');
    await file.writeAsBytes(compressedData);

    return file.path;
  }

  /// 恢复数据到数据库
  Future<Map<String, int>> _restoreData(BackupData data) async {
    final db = await _db;
    
    final counts = <String, int>{};
    
    await db.transaction((txn) async {
      // 清空现有数据（物理删除）
      await txn.delete('accounts');
      await txn.delete('transactions');
      await txn.delete('categories');
      await txn.delete('budgets');
      await txn.delete('import_records');

      // 恢复账户
      for (var account in data.accounts) {
        await txn.insert('accounts', account.toJson());
      }
      counts['accounts'] = data.accounts.length;

      // 恢复交易记录
      for (var transaction in data.transactions) {
        await txn.insert('transactions', transaction.toJson());
      }
      counts['transactions'] = data.transactions.length;

      // 恢复分类
      for (var category in data.categories) {
        await txn.insert('categories', category.toJson());
      }
      counts['categories'] = data.categories.length;

      // 恢复预算
      for (var budget in data.budgets) {
        await txn.insert('budgets', budget.toJson());
      }
      counts['budgets'] = data.budgets.length;

      // 恢复导入记录
      for (var record in data.importRecords) {
        await txn.insert('import_records', record.toJson());
      }
      counts['importRecords'] = data.importRecords.length;
    });

    return counts;
  }

  /// 获取所有账户（包括已删除）
  Future<List<Account>> _getAllAccountsWithDeleted(Database db) async {
    final maps = await db.query('accounts');
    return maps.map((m) => Account.fromJson(m)).toList();
  }

  /// 获取所有交易记录（包括已删除）
  Future<List<tx.Transaction>> _getAllTransactionsWithDeleted(Database db) async {
    final maps = await db.query('transactions');
    return maps.map((m) => tx.Transaction.fromJson(m)).toList();
  }

  /// 获取所有分类（包括已删除）
  Future<List<Category>> _getAllCategoriesWithDeleted(Database db) async {
    final maps = await db.query('categories');
    return maps.map((m) => Category.fromJson(m)).toList();
  }

  /// 获取所有预算（包括已删除）
  Future<List<Budget>> _getAllBudgetsWithDeleted(Database db) async {
    final maps = await db.query('budgets');
    return maps.map((m) => Budget.fromJson(m)).toList();
  }

  /// 获取所有导入记录（包括已删除）
  Future<List<ImportRecord>> _getAllImportRecordsWithDeleted(Database db) async {
    final maps = await db.query('import_records');
    return maps.map((m) => ImportRecord.fromJson(m)).toList();
  }

  /// 加密数据（使用 XOR + AES 模拟加密）
  Uint8List _encrypt(String data, String password) {
    final dataBytes = utf8.encode(data);
    final passwordBytes = utf8.encode(password);
    
    // 使用密码生成密钥
    final key = _generateKey(password);
    
    // XOR 加密
    final encrypted = Uint8List(dataBytes.length);
    for (var i = 0; i < dataBytes.length; i++) {
      encrypted[i] = dataBytes[i] ^ key[i % key.length];
    }
    
    return encrypted;
  }

  /// 解密数据
  String _decrypt(Uint8List data, String password) {
    final key = _generateKey(password);
    
    // XOR 解密（与加密相同）
    final decrypted = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      decrypted[i] = data[i] ^ key[i % key.length];
    }
    
    return utf8.decode(decrypted);
  }

  /// 根据密码生成加密密钥
  Uint8List _generateKey(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return Uint8List.fromList(hash.bytes);
  }

  /// 压缩数据（使用 GZIP）
  Uint8List _compress(List<int> data) {
    return Uint8List.fromList(gzip.encode(data));
  }

  /// 解压数据
  Uint8List _decompress(List<int> data) {
    return Uint8List.fromList(gzip.decode(data));
  }

  /// 获取默认密码
  Future<String> _getDefaultPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_passwordKey);
    
    if (storedHash != null) {
      // 如果已设置密码，返回空字符串，调用方需要提供密码
      return '';
    }
    
    // 未设置密码时使用默认密钥
    return 'personal_accounting_app_default_key_2024';
  }

  /// 分享备份文件
  Future<void> shareBackup(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: '记账数据备份',
    );
  }

  /// 获取所有快照列表
  Future<List<File>> getSnapshots() async {
    final directory = await getApplicationDocumentsDirectory();
    final snapshotsDir = Directory('${directory.path}/snapshots');
    
    if (!await snapshotsDir.exists()) {
      return [];
    }
    
    final files = await snapshotsDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.snap'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // 按时间倒序
  }

  /// 删除快照
  Future<void> deleteSnapshot(String snapshotPath) async {
    final file = File(snapshotPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 清理旧快照（保留最近 N 个）
  Future<void> cleanupOldSnapshots({int keepCount = 5}) async {
    final snapshots = await getSnapshots();
    
    if (snapshots.length > keepCount) {
      for (var i = keepCount; i < snapshots.length; i++) {
        await snapshots[i].delete();
      }
    }
  }

  /// 获取备份文件信息
  Future<Map<String, dynamic>?> getBackupInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final fileSize = await file.length();
      
      return {
        'file_path': filePath,
        'file_size': fileSize,
        'file_name': filePath.split('/').last,
      };
    } catch (e) {
      return null;
    }
  }
}
