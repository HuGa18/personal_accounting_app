import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../bill_parser.dart';
import '../../models/transaction.dart';
import '../../enums/bill_source.dart';
import '../../utils/id_utils.dart';
import '../../exceptions/import_exception.dart';

/// 银行卡账单解析器
/// 
/// 支持解析银行卡账单文件（CSV、Excel、PDF格式）
/// 
/// 由于不同银行的账单格式可能有差异，本解析器采用通用的解析策略：
/// 1. 自动识别日期、金额、商户等关键字段
/// 2. 支持常见的银行卡账单格式
/// 
/// CSV格式示例：
/// ```
/// 交易日期,交易时间,摘要,交易金额,账户余额,交易类型,对方户名,对方账号
/// 2024-01-15,12:30:00,美团外卖,-35.00,1234.56,消费,美团公司,6222001234567890
/// ```
class BankCardParser extends BillParser {
  @override
  BillSource get source => BillSource.bankCard;

  @override
  List<String> get supportedExtensions => ['csv', 'xlsx', 'xls', 'pdf'];

  @override
  Future<List<Transaction>> parseCsv(Uint8List fileBytes, String accountId) async {
    try {
      String content;
      try {
        content = utf8.decode(fileBytes);
      } catch (e) {
        content = _decodeGbk(fileBytes);
      }

      final lines = content.split('\n');
      int dataStartIndex = 0;
      
      for (int i = 0; i < lines.length; i++) {
        if (RegExp(r'^\d{4}[-/]\d{2}[-/]\d{2}').hasMatch(lines[i].trim())) {
          dataStartIndex = i;
          break;
        }
      }

      final dataLines = lines.sublist(dataStartIndex);
      final csvContent = dataLines.join('\n');

      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvContent);

      final transactions = <Transaction>[];

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) {
          continue;
        }

        try {
          final transaction = _parseCsvRow(row, accountId, i);
          if (transaction != null) {
            transactions.add(transaction);
          }
        } catch (e) {
          print('银行卡CSV第${i + 1}行解析失败: $e');
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('银行卡CSV解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseCsvRow(List<dynamic> row, String accountId, int rowIndex) {
    if (row.length < 4) return null;

    // 智能识别字段
    String? dateStr;
    String? amountStr;
    String? summary;
    String? counterparty;
    String? remark;
    String? typeStr;

    for (int i = 0; i < row.length && i < 10; i++) {
      final value = row[i].toString().trim();
      if (value.isEmpty) continue;

      // 识别日期字段
      if (dateStr == null && RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}').hasMatch(value)) {
        dateStr = value;
        // 尝试合并时间字段
        if (i + 1 < row.length && RegExp(r'^\d{1,2}:\d{1,2}').hasMatch(row[i + 1].toString().trim())) {
          dateStr = '$dateStr ${row[i + 1].toString().trim()}';
        }
        continue;
      }

      // 识别金额字段
      if (amountStr == null && RegExp(r'^[-+]?\d+[,.\d]*$').hasMatch(value.replaceAll(' ', ''))) {
        final parsed = parseAmount(value);
        if (parsed != null && parsed != 0) {
          amountStr = value;
          continue;
        }
      }

      // 识别类型字段
      if (typeStr == null && (value.contains('支出') || value.contains('收入') || 
          value.contains('消费') || value.contains('转账') || value.contains('存入'))) {
        typeStr = value;
        continue;
      }

      // 识别摘要/商户字段
      if (summary == null && value.length > 1 && value.length < 50 && 
          !RegExp(r'^\d').hasMatch(value) && !value.contains('余额')) {
        summary = value;
        continue;
      }

      // 识别对方户名
      if (counterparty == null && (value.contains('公司') || value.contains('店') || 
          value.contains('有限') || value.contains('商户'))) {
        counterparty = value;
        continue;
      }

      // 识别备注
      if (remark == null && value.length > 0 && value != dateStr && value != amountStr) {
        remark = value;
      }
    }

    if (dateStr == null || amountStr == null) return null;

    final transactionDate = parseDateTime(dateStr);
    if (transactionDate == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null || amount == 0) return null;

    final transactionType = determineTransactionType(amount);
    final merchantName = counterparty ?? summary ?? '银行卡交易';

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: amount.abs(),
      merchantName: merchantName,
      description: remark ?? summary,
      transactionDate: transactionDate,
      source: source.name,
      tags: [typeStr].where((t) => t != null && t.isNotEmpty).cast<String>().toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Transaction>> parseExcel(Uint8List fileBytes, String accountId) async {
    try {
      final bytes = ByteData.sublistView(fileBytes);
      final excel = Excel.decodeBytes(bytes);

      final transactions = <Transaction>[];

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        int headerRowIndex = -1;
        for (int i = 0; i < sheet.maxRows && i < 10; i++) {
          final row = sheet.rows[i];
          final rowText = row.map((cell) => cell?.value?.toString() ?? '').join(',');
          if (rowText.contains('日期') || rowText.contains('时间')) {
            headerRowIndex = i;
            break;
          }
        }

        if (headerRowIndex == -1) {
          // 如果没有找到表头，尝试从第一行开始解析
          headerRowIndex = 0;
        }

        for (int i = headerRowIndex + 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          try {
            final transaction = _parseExcelRow(row, accountId, i);
            if (transaction != null) {
              transactions.add(transaction);
            }
          } catch (e) {
            print('银行卡Excel第${i + 1}行解析失败: $e');
          }
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('银行卡Excel解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseExcelRow(List<Data?> row, String accountId, int rowIndex) {
    if (row.isEmpty) return null;

    // 收集所有非空单元格
    final values = <String>[];
    for (final cell in row) {
      final value = cell?.value?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        values.add(value);
      }
    }

    if (values.isEmpty) return null;

    // 智能识别字段
    String? dateStr;
    String? amountStr;
    String? summary;

    for (final value in values) {
      if (dateStr == null && RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}').hasMatch(value)) {
        dateStr = value;
        continue;
      }

      if (amountStr == null) {
        final parsed = parseAmount(value);
        if (parsed != null && parsed != 0) {
          amountStr = value;
          continue;
        }
      }

      if (summary == null && value.length > 1 && value.length < 50) {
        summary = value;
      }
    }

    if (dateStr == null || amountStr == null) return null;

    final transactionDate = parseDateTime(dateStr);
    if (transactionDate == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null || amount == 0) return null;

    final transactionType = determineTransactionType(amount);

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: amount.abs(),
      merchantName: summary ?? '银行卡交易',
      transactionDate: transactionDate,
      source: source.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Transaction>> parsePdf(Uint8List fileBytes, String accountId) async {
    try {
      final document = PdfDocument(inputBytes: fileBytes);
      final transactions = <Transaction>[];

      for (int i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        final text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
        
        final pageTransactions = _parsePdfText(text, accountId);
        transactions.addAll(pageTransactions);
      }

      document.dispose();
      return transactions;
    } catch (e) {
      throw ImportException('银行卡PDF解析失败: ${e.toString()}');
    }
  }

  List<Transaction> _parsePdfText(String text, String accountId) {
    final transactions = <Transaction>[];
    final lines = text.split('\n');
    
    for (final line in lines) {
      final dateMatch = RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})').firstMatch(line);
      if (dateMatch == null) continue;

      final transactionDate = parseDateTime(dateMatch.group(1));
      if (transactionDate == null) continue;

      final amountMatch = RegExp(r'[-+]?\d+\.?\d*').firstMatch(line.substring(dateMatch.end));
      if (amountMatch == null) continue;

      final amount = parseAmount(amountMatch.group(0));
      if (amount == null || amount == 0) continue;

      final transactionType = determineTransactionType(amount);

      transactions.add(Transaction(
        id: IdUtils.generate(),
        accountId: accountId,
        type: transactionType,
        amount: amount.abs(),
        merchantName: '银行卡交易',
        transactionDate: transactionDate,
        source: source.name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    return transactions;
  }

  String _decodeGbk(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      if (bytes.length > 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        return utf8.decode(bytes.sublist(3));
      }
      rethrow;
    }
  }
}