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

/// 支付宝账单解析器
/// 
/// 支持解析支付宝导出的账单文件（CSV、Excel、PDF格式）
/// 
/// CSV格式示例：
/// ```
/// 交易时间,交易分类,交易说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注
/// 2024-01-15 12:30:00,餐饮美食,美团外卖,支出,35.00,余额宝,交易成功,2024011522001401234567890,123456789,午餐
/// ```
class AlipayParser extends BillParser {
  @override
  BillSource get source => BillSource.alipay;

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
        // 尝试GBK编码
        content = _decodeGbk(fileBytes);
      }

      // 跳过头部信息行，找到实际数据开始位置
      final lines = content.split('\n');
      int dataStartIndex = 0;
      
      for (int i = 0; i < lines.length; i++) {
        // 支付宝CSV通常有头部信息，数据行以日期开头
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
          // 记录解析错误但继续处理其他行
          print('支付宝CSV第${i + 1}行解析失败: $e');
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('支付宝CSV解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseCsvRow(List<dynamic> row, String accountId, int rowIndex) {
    // 支付宝CSV列顺序：
    // 交易时间,交易分类,交易说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注
    if (row.length < 5) return null;

    final dateStr = row[0].toString().trim();
    final category = row.length > 1 ? row[1].toString().trim() : '';
    final description = row.length > 2 ? row[2].toString().trim() : '';
    final typeStr = row.length > 3 ? row[3].toString().trim() : '';
    final amountStr = row.length > 4 ? row[4].toString().trim() : '';
    final paymentMethod = row.length > 5 ? row[5].toString().trim() : '';
    final status = row.length > 6 ? row[6].toString().trim() : '';
    final orderNo = row.length > 7 ? row[7].toString().trim() : '';
    final remark = row.length > 9 ? row[9].toString().trim() : '';

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
    final merchantName = description.isNotEmpty ? description : category;

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: finalAmount.abs(),
      merchantName: merchantName,
      description: remark.isNotEmpty ? remark : description,
      transactionDate: transactionDate,
      source: source.name,
      tags: [category, paymentMethod].where((t) => t.isNotEmpty).toList(),
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
            print('支付宝Excel第${i + 1}行解析失败: $e');
          }
        }
      }

      return transactions;
    } catch (e) {
      throw ImportException('支付宝Excel解析失败: ${e.toString()}');
    }
  }

  Transaction? _parseExcelRow(List<Data?> row, String accountId, int rowIndex) {
    if (row.isEmpty) return null;

    final dateStr = _getCellValue(row, 0);
    final category = _getCellValue(row, 1);
    final description = _getCellValue(row, 2);
    final typeStr = _getCellValue(row, 3);
    final amountStr = _getCellValue(row, 4);
    final paymentMethod = _getCellValue(row, 5);
    final status = _getCellValue(row, 6);
    final remark = _getCellValue(row, 9);

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
    final merchantName = description.isNotEmpty ? description : category;

    return Transaction(
      id: IdUtils.generate(),
      accountId: accountId,
      type: transactionType,
      amount: finalAmount.abs(),
      merchantName: merchantName,
      description: remark.isNotEmpty ? remark : description,
      transactionDate: transactionDate,
      source: source.name,
      tags: [category, paymentMethod].where((t) => t.isNotEmpty).toList(),
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
        
        // 解析PDF文本内容
        final pageTransactions = _parsePdfText(text, accountId);
        transactions.addAll(pageTransactions);
      }

      document.dispose();
      return transactions;
    } catch (e) {
      throw ImportException('支付宝PDF解析失败: ${e.toString()}');
    }
  }

  List<Transaction> _parsePdfText(String text, String accountId) {
    final transactions = <Transaction>[];
    
    // 支付宝PDF账单格式解析
    // 通常每行包含：日期 时间 商户 金额 等信息
    final lines = text.split('\n');
    
    for (final line in lines) {
      // 尝试匹配交易记录行
      // 格式示例：2024-01-15 12:30:00 美团外卖 -35.00
      final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})').firstMatch(line);
      if (dateMatch == null) continue;

      final transactionDate = parseDateTime(dateMatch.group(1));
      if (transactionDate == null) continue;

      // 提取金额
      final amountMatch = RegExp(r'[-+]?\d+\.?\d*').firstMatch(line.substring(dateMatch.end));
      if (amountMatch == null) continue;

      final amount = parseAmount(amountMatch.group(0));
      if (amount == null || amount == 0) continue;

      // 提取商户名称（在日期和金额之间）
      final merchantPart = line.substring(dateMatch.end, line.indexOf(amountMatch.group(0), dateMatch.end)).trim();
      
      final transactionType = determineTransactionType(amount);
      final merchantName = merchantPart.isNotEmpty ? merchantPart : '支付宝交易';

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
    // 简单的GBK解码处理
    // 实际项目中应使用专门的GBK解码库
    try {
      return utf8.decode(bytes);
    } catch (e) {
      // 如果UTF-8解码失败，尝试移除BOM后解码
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