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

/// 微信支付账单解析器
/// 
/// 支持解析微信支付导出的账单文件（CSV、Excel、PDF格式）
/// 
/// CSV格式示例：
/// ```
/// 交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
/// 2024-01-15 12:30:00,商户消费,美团外卖,外卖订单,支出,35.00,零钱,支付成功,4200001234567890123,123456789,午餐
/// ```
class WechatParser extends BillParser {
  @override
  BillSource get source => BillSource.wechat;

  @override
  List<String> get supportedExtensions => ['csv', 'xlsx', 'xls', 'pdf'];

  @override
  Future<List<Transaction>> parseCsv(Uint8List fileBytes, String accountId) async {
    try {
      // 尝试多种编码解析
      String content;
      try {
        content = utf8.decode(fileBytes);
      } catch (e) {
        content = _decodeGbk(fileBytes);
      }

      // 跳过头部信息行，找到实际数据开始位置
      final lines = content.split('\n');
      int dataStartIndex = 0;
      
      for (int i = 0; i < lines.length; i++) {
        // 微信CSV数据行以日期开头
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
          print('微信CSV第${i + 1}行解析失败: $e');
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('微信CSV解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseCsvRow(List<dynamic> row, String accountId, int rowIndex) {
    // 微信CSV列顺序：
    // 交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
    if (row.length < 6) return null;

    final dateStr = row[0].toString().trim();
    final transactionTypeStr = row.length > 1 ? row[1].toString().trim() : '';
    final counterparty = row.length > 2 ? row[2].toString().trim() : '';
    final product = row.length > 3 ? row[3].toString().trim() : '';
    final typeStr = row.length > 4 ? row[4].toString().trim() : '';
    final amountStr = row.length > 5 ? row[5].toString().trim() : '';
    final paymentMethod = row.length > 6 ? row[6].toString().trim() : '';
    final status = row.length > 7 ? row[7].toString().trim() : '';
    final remark = row.length > 10 ? row[10].toString().trim() : '';

    // 跳过非成功交易
    if (status.isNotEmpty && !status.contains('成功') && !status.contains('完成')) {
      return null;
    }

    final transactionDate = parseDateTime(dateStr);
    if (transactionDate == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null || amount == 0) return null;

    // 根据收/支字段确定金额正负
    double finalAmount = amount.abs();
    if (typeStr.contains('支出')) {
      finalAmount = -finalAmount;
    }

    final transactionType = determineTransactionType(finalAmount);
    // 优先使用交易对方，其次商品名称
    final merchantName = counterparty.isNotEmpty ? counterparty : 
                         product.isNotEmpty ? product : 
                         transactionTypeStr;

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: finalAmount.abs(),
      merchantName: merchantName,
      description: remark.isNotEmpty ? remark : product,
      transactionDate: transactionDate,
      source: source.name,
      tags: [transactionTypeStr, paymentMethod].where((t) => t.isNotEmpty).toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Transaction>> parseExcel(Uint8List fileBytes, String accountId) async {
    try {
      final excel = Excel.decodeBytes(fileBytes);

      final transactions = <Transaction>[];

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        // 查找表头行
        int headerRowIndex = -1;
        for (int i = 0; i < sheet.maxRows && i < 10; i++) {
          final row = sheet.rows[i];
          final rowText = row.map((cell) => cell?.value?.toString() ?? '').join(',');
          if (rowText.contains('交易时间') || rowText.contains('时间')) {
            headerRowIndex = i;
            break;
          }
        }

        if (headerRowIndex == -1) continue;

        // 解析数据行
        for (int i = headerRowIndex + 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          try {
            final transaction = _parseExcelRow(row, accountId, i);
            if (transaction != null) {
              transactions.add(transaction);
            }
          } catch (e) {
            print('微信Excel第${i + 1}行解析失败: $e');
          }
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('微信Excel解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseExcelRow(List<Data?> row, String accountId, int rowIndex) {
    if (row.isEmpty) return null;

    final dateStr = _getCellValue(row, 0);
    final transactionTypeStr = _getCellValue(row, 1);
    final counterparty = _getCellValue(row, 2);
    final product = _getCellValue(row, 3);
    final typeStr = _getCellValue(row, 4);
    final amountStr = _getCellValue(row, 5);
    final paymentMethod = _getCellValue(row, 6);
    final status = _getCellValue(row, 7);
    final remark = _getCellValue(row, 10);

    // 跳过非成功交易
    if (status.isNotEmpty && !status.contains('成功') && !status.contains('完成')) {
      return null;
    }

    final transactionDate = parseDateTime(dateStr);
    if (transactionDate == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null || amount == 0) return null;

    double finalAmount = amount.abs();
    if (typeStr.contains('支出')) {
      finalAmount = -finalAmount;
    }

    final transactionType = determineTransactionType(finalAmount);
    final merchantName = counterparty.isNotEmpty ? counterparty : 
                         product.isNotEmpty ? product : 
                         transactionTypeStr;

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: finalAmount.abs(),
      merchantName: merchantName,
      description: remark.isNotEmpty ? remark : product,
      transactionDate: transactionDate,
      source: source.name,
      tags: [transactionTypeStr, paymentMethod].where((t) => t.isNotEmpty).toList(),
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
      throw ImportException('微信PDF解析失败: ${e.toString()}');
    }
  }

  List<Transaction> _parsePdfText(String text, String accountId) {
    final transactions = <Transaction>[];
    final lines = text.split('\n');
    
    for (final line in lines) {
      final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})').firstMatch(line);
      if (dateMatch == null) continue;

      final transactionDate = parseDateTime(dateMatch.group(1));
      if (transactionDate == null) continue;

      final amountMatch = RegExp(r'[-+]?\d+\.?\d*').firstMatch(line.substring(dateMatch.end));
      if (amountMatch == null) continue;

      final amount = parseAmount(amountMatch.group(0));
      if (amount == null || amount == 0) continue;

      final amountStr = amountMatch.group(0)!;
      final merchantPart = line.substring(dateMatch.end, line.indexOf(amountStr, dateMatch.end)).trim();
      
      final transactionType = determineTransactionType(amount);
      final merchantName = merchantPart.isNotEmpty ? merchantPart : '微信支付';

      transactions.add(Transaction(
        id: IdUtils.generate(),
        accountId: accountId,
        type: transactionType,
        amount: amount.abs(),
        merchantName: merchantName,
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