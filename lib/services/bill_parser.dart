import 'dart:typed_data';
import '../models/transaction.dart';
import '../enums/bill_source.dart';
import '../exceptions/import_exception.dart';

/// 账单解析器抽象类
/// 
/// 定义所有账单解析器的通用接口
/// 
/// 子类需要实现:
/// - [source]: 账单来源
/// - [parse]: 解析账单数据
/// - [parseCsv]: 解析CSV格式
/// - [parseExcel]: 解析Excel格式
/// - [parsePdf]: 解析PDF格式
abstract class BillParser {
  /// 账单来源
  BillSource get source;

  /// 支持的文件扩展名
  List<String> get supportedExtensions => ['csv', 'xlsx', 'xls', 'pdf'];

  /// 解析账单数据
  /// 
  /// [fileBytes] 文件字节数据
  /// [extension] 文件扩展名（不含点号）
  /// [accountId] 关联的账户ID
  /// 
  /// 返回解析后的交易列表
  Future<List<Transaction>> parse(
    Uint8List fileBytes,
    String extension,
    String accountId,
  ) async {
    final ext = extension.toLowerCase();

    if (!supportedExtensions.contains(ext)) {
      throw ImportException('不支持的文件格式：$ext，支持的格式：${supportedExtensions.join(', ')}');
    }

    switch (ext) {
      case 'csv':
        return parseCsv(fileBytes, accountId);
      case 'xlsx':
      case 'xls':
        return parseExcel(fileBytes, accountId);
      case 'pdf':
        return parsePdf(fileBytes, accountId);
      default:
        throw ImportException('不支持的文件格式：$ext');
    }
  }

  /// 解析CSV格式账单
  Future<List<Transaction>> parseCsv(Uint8List fileBytes, String accountId);

  /// 解析Excel格式账单
  Future<List<Transaction>> parseExcel(Uint8List fileBytes, String accountId);

  /// 解析PDF格式账单
  Future<List<Transaction>> parsePdf(Uint8List fileBytes, String accountId);

  /// 解析金额字符串
  /// 
  /// 处理各种金额格式，如：
  /// - ¥100.00
  /// - 100.00元
  /// - -100.00
  /// - 1,000.00
  double? parseAmount(String? amountStr) {
    if (amountStr == null || amountStr.isEmpty) {
      return null;
    }

    // 移除货币符号、空格、逗号等
    String cleaned = amountStr
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('元', '')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .replaceAll('，', '')
        .trim();

    // 处理括号表示负数的情况，如 (100.00)
    bool isNegative = false;
    if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
      isNegative = true;
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    // 处理前置负号
    if (cleaned.startsWith('-')) {
      isNegative = true;
      cleaned = cleaned.substring(1);
    }

    try {
      final amount = double.parse(cleaned);
      return isNegative ? -amount : amount;
    } catch (e) {
      return null;
    }
  }

  /// 解析日期时间字符串
  /// 
  /// 支持多种日期格式
  DateTime? parseDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return null;
    }

    final trimmed = dateStr.trim();

    // 尝试多种日期格式
    final patterns = [
      // 标准格式
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})$'),
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})$'),
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$'),
      // 斜杠格式
      RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})$'),
      RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{1,2})$'),
      RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$'),
      // 中文格式
      RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{1,2}):(\d{1,2})$'),
      RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{1,2})$'),
      RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null) {
        try {
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          final hour = match.groupCount >= 4 ? int.parse(match.group(4)!) : 0;
          final minute = match.groupCount >= 5 ? int.parse(match.group(5)!) : 0;
          final second = match.groupCount >= 6 ? int.parse(match.group(6)!) : 0;

          return DateTime(year, month, day, hour, minute, second);
        } catch (e) {
          continue;
        }
      }
    }

    // 尝试ISO 8601格式
    try {
      return DateTime.parse(trimmed);
    } catch (e) {
      return null;
    }
  }

  /// 判断交易类型
  /// 
  /// 根据金额正负判断是收入还是支出
  String determineTransactionType(double amount) {
    if (amount > 0) {
      return 'income';
    } else {
      return 'expense';
    }
  }

  /// 生成唯一标识
  /// 
  /// 用于去重判断
  String generateUniqueKey({
    required DateTime transactionDate,
    required double amount,
    required String merchantName,
  }) {
    return '${source.name}_${transactionDate.millisecondsSinceEpoch}_${amount.abs().toStringAsFixed(2)}_$merchantName';
  }
}
