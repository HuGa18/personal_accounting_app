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

/// 京东白条账单解析器
/// 
/// 支持解析京东白条导出的账单文件（CSV、Excel、PDF格式）
/// 
/// CSV格式示例：
/// ```
/// 交易日期,交易时间,商户名称,商品名称,交易金额,交易类型,分期期数,交易状态
/// 2024-01-15,12:30:00,京东商城,iPhone 15,5999.00,消费,12,成功
/// ```
class JdBaitiaoParser extends BillParser {
  @override
  BillSource get source => BillSource.jdBaitiao;

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
        if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(lines[i].trim())) {
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
          print('京东白条CSV第${i + 1}行解析失败: $e');
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('京东白条CSV解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseCsvRow(List<dynamic> row, String accountId, int rowIndex) {
    // 京东白条CSV列顺序：
    // 交易日期,交易时间,商户名称,商品名称,交易金额,交易类型,分期期数,交易状态
    if (row.length < 5) return null;

    final dateStr = row[0].toString().trim();
    final timeStr = row.length > 1 ? row[1].toString().trim() : '';
    final merchantName = row.length > 2 ? row[2].toString().trim() : '';
    final productName = row.length > 3 ? row[3].toString().trim() : '';
    final amountStr = row.length > 4 ? row[4].toString().trim() : '';
    final transactionTypeStr = row.length > 5 ? row[5].toString().trim() : '';
    final installment = row.length > 6 ? row[6].toString().trim() : '';
    final status = row.length > 7 ? row[7].toString().trim() : '';

    // 跳过非成功交易
    if (status.isNotEmpty && !status.contains('成功') && !status.contains('完成')) {
      return null;
    }

    // 合并日期和时间
    final fullDateStr = timeStr.isNotEmpty ? '$dateStr $timeStr' : dateStr;
    final transactionDate = parseDateTime(fullDateStr);
    if (transactionDate == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null || amount == 0) return null;

    // 京东白条交易通常是支出
    final transactionType = determineTransactionType(-amount.abs());
    
    // 商户名称优先，其次商品名称
    final name = merchantName.isNotEmpty ? merchantName : 
                 productName.isNotEmpty ? productName : '京东白条';
    
    // 构建标签
    final tags = <String>[];
    if (transactionTypeStr.isNotEmpty) tags.add(transactionTypeStr);
    if (installment.isNotEmpty && installment != '0') tags.add('${installment}期分期');

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: amount.abs(),
      merchantName: name,
      description: productName.isNotEmpty ? productName : null,
      transactionDate: transactionDate,
      source: source.name,
      tags: tags,
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

        if (headerRowIndex == -1) continue;

        for (int i = headerRowIndex + 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          try {
            final transaction = _parseExcelRow(row, accountId, i);
            if (transaction != null) {
              transactions.add(transaction);
            }
          } catch (e) {
            print('京东白条Excel第${i + 1}行解析失败: $e');
          }
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('京东白条Excel解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseExcelRow(List<Data?> row, String accountId, int rowIndex) {
    if (row.isEmpty) return null;

    final dateStr = _getCellValue(row, 0);
    final timeStr = _getCellValue(row, 1);
    final merchantName = _getCellValue(row, 2);
    final productName = _getCellValue(row, 3);
    final amountStr = _getCellValue(row, 4);
    final transactionTypeStr = _getCellValue(row, 5);
    final installment = _getCellValue(row, 6);
    final status = _getCellValue(row, 7);

    if (status.isNotEmpty && !status.contains('成功') && !status.contains('完成')) {
      return null;
    }

    final fullDateStr = timeStr.isNotEmpty ? '$dateStr $timeStr' : dateStr;
    final transactionDate = parseDateTime(fullDateStr);
    if (transactionDate == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null || amount == 0) return null;

    final transactionType = determineTransactionType(-amount.abs());
    final name = merchantName.isNotEmpty ? merchantName : 
                 productName.isNotEmpty ? productName : '京东白条';
    
    final tags = <String>[];
    if (transactionTypeStr.isNotEmpty) tags.add(transactionTypeStr);
    if (installment.isNotEmpty && installment != '0') tags.add('${installment}期分期');

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: amount.abs(),
      merchantName: name,
      description: productName.isNotEmpty ? productName : null,
      transactionDate: transactionDate,
      source: source.name,
      tags: tags,
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
      throw ImportException('京东白条PDF解析失败: ${e.toString()}');
    }
  }

  List<Transaction> _parsePdfText(String text, String accountId) {
    final transactions = <Transaction>[];
    final lines = text.split('\n');
    
    for (final line in lines) {
      final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(line);
      if (dateMatch == null) continue;

      final transactionDate = parseDateTime(dateMatch.group(1));
      if (transactionDate == null) continue;

      final amountMatch = RegExp(r'\d+\.?\d*').firstMatch(line.substring(dateMatch.end));
      if (amountMatch == null) continue;

      final amount = parseAmount(amountMatch.group(0));
      if (amount == null || amount == 0) continue;

      transactions.add(Transaction(
        id: IdUtils.generate(),
        accountId: accountId,
        type: 'expense',
        amount: amount.abs(),
        merchantName: '京东白条',
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

  String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) {
      return '';
    }
    return row[index]!.value?.toString().trim() ?? '';
  }
}