import 'dart:typed_data';
import '../models/transaction.dart';
import '../models/import_record.dart';
import '../enums/bill_source.dart';
import '../exceptions/import_exception.dart';
import '../repositories/import_record_repository.dart';
import '../utils/id_utils.dart';
import 'bill_parser.dart';
import 'parsers/alipay_parser.dart';
import 'parsers/wechat_parser.dart';
import 'parsers/bank_card_parser.dart';
import 'parsers/cloud_flash_parser.dart';
import 'parsers/jd_baitiao_parser.dart';
import 'parsers/digital_rmb_parser.dart';

/// 账单解析服务
/// 
/// 统一管理各种账单解析器，提供解析、去重等功能
/// 
/// 使用示例：
/// ```dart
/// final service = BillParserService();
/// 
/// // 解析账单文件
/// final transactions = await service.parseBill(
///   fileBytes: bytes,
///   extension: 'csv',
///   source: BillSource.alipay,
///   accountId: 'account-123',
/// );
/// 
/// // 检查重复记录
/// final isDuplicate = await service.checkDuplicate(
///   source: 'alipay',
///   externalId: 'unique-key',
/// );
/// ```
class BillParserService {
  final ImportRecordRepository _importRecordRepository;

  /// 解析器映射表
  final Map<BillSource, BillParser> _parsers = {};

  BillParserService({
    ImportRecordRepository? importRecordRepository,
  }) : _importRecordRepository = importRecordRepository ?? ImportRecordRepository() {
    _initParsers();
  }

  /// 初始化解析器
  void _initParsers() {
    _parsers[BillSource.alipay] = AlipayParser();
    _parsers[BillSource.wechat] = WechatParser();
    _parsers[BillSource.bankCard] = BankCardParser();
    _parsers[BillSource.cloudFlash] = CloudFlashParser();
    _parsers[BillSource.jdBaitiao] = JdBaitiaoParser();
    _parsers[BillSource.digitalRmb] = DigitalRmbParser();
  }

  /// 获取支持的账单来源列表
  List<BillSource> get supportedSources => _parsers.keys.toList();

  /// 获取指定来源支持的文件格式
  List<String> getSupportedExtensions(BillSource source) {
    final parser = _parsers[source];
    return parser?.supportedExtensions ?? [];
  }

  /// 解析账单文件
  /// 
  /// [fileBytes] 文件字节数据
  /// [extension] 文件扩展名（不含点号）
  /// [source] 账单来源
  /// [accountId] 关联的账户ID
  /// [enableDeduplication] 是否启用去重（默认启用）
  /// 
  /// 返回解析后的交易列表
  Future<List<Transaction>> parseBill({
    required Uint8List fileBytes,
    required String extension,
    required BillSource source,
    required String accountId,
    bool enableDeduplication = true,
  }) async {
    // 获取对应的解析器
    final parser = _parsers[source];
    if (parser == null) {
      throw ImportException('不支持的账单来源：${source.label}');
    }

    // 解析账单
    final transactions = await parser.parse(fileBytes, extension, accountId);

    // 去重处理
    if (enableDeduplication && transactions.isNotEmpty) {
      return await _deduplicate(transactions, source);
    }

    return transactions;
  }

  /// 去重处理
  /// 
  /// 根据交易日期、金额、商户名称生成唯一标识，过滤已导入的记录
  Future<List<Transaction>> _deduplicate(
    List<Transaction> transactions,
    BillSource source,
  ) async {
    final uniqueTransactions = <Transaction>[];

    for (final transaction in transactions) {
      // 生成唯一标识
      final externalId = _generateExternalId(transaction, source);

      // 检查是否已存在
      final exists = await _importRecordRepository.existsBySourceAndExternalId(
        source.name,
        externalId,
      );

      if (!exists) {
        uniqueTransactions.add(transaction);
      }
    }

    return uniqueTransactions;
  }

  /// 生成外部唯一标识
  /// 
  /// 用于去重判断
  String _generateExternalId(Transaction transaction, BillSource source) {
    // 使用日期、金额、商户名称组合生成唯一标识
    final dateStr = transaction.transactionDate.toIso8601String();
    final amountStr = transaction.amount.abs().toStringAsFixed(2);
    final merchantStr = transaction.merchantName ?? '';
    
    return '${source.name}_${dateStr}_${amountStr}_${merchantStr.hashCode}';
  }

  /// 检查记录是否重复
  /// 
  /// [source] 账单来源
  /// [externalId] 外部唯一标识
  Future<bool> checkDuplicate({
    required String source,
    required String externalId,
  }) async {
    return _importRecordRepository.existsBySourceAndExternalId(source, externalId);
  }

  /// 记录导入结果
  /// 
  /// 将成功导入的记录保存到导入记录表，用于后续去重
  /// 
  /// [source] 账单来源
  /// [transactions] 成功导入的交易列表
  Future<void> recordImport({
    required BillSource source,
    required List<Transaction> transactions,
  }) async {
    if (transactions.isEmpty) return;

    final records = transactions.map((transaction) {
      final externalId = _generateExternalId(transaction, source);
      return ImportRecord(
        id: IdUtils.generate(),
        source: source.name,
        externalId: externalId,
        importDate: DateTime.now(),
        recordCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    await _importRecordRepository.insertBatch(records);
  }

  /// 解析并导入账单（一站式方法）
  /// 
  /// 解析账单文件、去重、记录导入结果
  /// 
  /// [fileBytes] 文件字节数据
  /// [extension] 文件扩展名（不含点号）
  /// [source] 账单来源
  /// [accountId] 关联的账户ID
  /// 
  /// 返回解析结果
  Future<ParseResult> parseAndImport({
    required Uint8List fileBytes,
    required String extension,
    required BillSource source,
    required String accountId,
  }) async {
    try {
      // 解析账单
      final allTransactions = await parseBill(
        fileBytes: fileBytes,
        extension: extension,
        source: source,
        accountId: accountId,
        enableDeduplication: false, // 先不过滤，统计总数
      );

      // 去重
      final uniqueTransactions = await _deduplicate(allTransactions, source);

      // 计算重复数量
      final duplicateCount = allTransactions.length - uniqueTransactions.length;

      // 记录导入结果
      if (uniqueTransactions.isNotEmpty) {
        await recordImport(
          source: source,
          transactions: uniqueTransactions,
        );
      }

      return ParseResult(
        success: true,
        totalCount: allTransactions.length,
        uniqueCount: uniqueTransactions.length,
        duplicateCount: duplicateCount,
        transactions: uniqueTransactions,
        errors: [],
      );
    } catch (e) {
      return ParseResult(
        success: false,
        totalCount: 0,
        uniqueCount: 0,
        duplicateCount: 0,
        transactions: [],
        errors: [e.toString()],
      );
    }
  }

  /// 清除导入记录
  /// 
  /// 用于重新导入历史账单
  /// 
  /// [source] 账单来源（可选，不传则清除所有）
  Future<void> clearImportRecords({BillSource? source}) async {
    final records = await _importRecordRepository.getAll();
    
    for (final record in records) {
      if (source == null || record.source == source.name) {
        await _importRecordRepository.delete(record.id);
      }
    }
  }

  /// 获取导入历史
  /// 
  /// [source] 账单来源（可选，不传则返回所有）
  Future<List<ImportRecord>> getImportHistory({BillSource? source}) async {
    final records = await _importRecordRepository.getAll();
    
    if (source == null) {
      return records;
    }
    
    return records.where((r) => r.source == source.name).toList();
  }
}

/// 解析结果
class ParseResult {
  /// 是否成功
  final bool success;

  /// 总记录数
  final int totalCount;

  /// 唯一记录数（去重后）
  final int uniqueCount;

  /// 重复记录数
  final int duplicateCount;

  /// 解析的交易列表
  final List<Transaction> transactions;

  /// 错误信息
  final List<String> errors;

  const ParseResult({
    required this.success,
    required this.totalCount,
    required this.uniqueCount,
    required this.duplicateCount,
    required this.transactions,
    required this.errors,
  });

  /// 成功率
  double get successRate =>
      totalCount > 0 ? uniqueCount / totalCount * 100 : 0.0;

  /// 是否有错误
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    return 'ParseResult(success: $success, total: $totalCount, unique: $uniqueCount, duplicate: $duplicateCount)';
  }
}