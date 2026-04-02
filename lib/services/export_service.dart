import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../utils/date_utils.dart';
import '../utils/money_utils.dart';
import '../utils/constants.dart';

/// 导出格式枚举
enum ExportFormat {
  csv,
  excel,
  pdf,
}

/// 导出结果
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int recordCount;

  ExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.recordCount = 0,
  });
}

/// 数据导出服务
/// 
/// 功能：
/// - 支持导出CSV、Excel、PDF格式
/// - 支持选择时间范围
/// - 集成系统分享功能
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final TransactionRepository _transactionRepository = TransactionRepository();
  final AccountRepository _accountRepository = AccountRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();

  /// 导出交易记录
  /// 
  /// [format] 导出格式
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// [accountId] 账户ID（可选）
  Future<ExportResult> exportTransactions({
    required ExportFormat format,
    required DateTime startDate,
    required DateTime endDate,
    String? accountId,
  }) async {
    try {
      // 获取交易记录
      final transactions = await _transactionRepository.getAll(
        startDate: startDate,
        endDate: endDate,
        accountId: accountId,
      );

      if (transactions.isEmpty) {
        return ExportResult(
          success: false,
          error: '所选时间范围内没有交易记录',
        );
      }

      // 获取账户和分类信息用于显示名称
      final accounts = await _accountRepository.getAll();
      final categories = await _categoryRepository.getAll();
      
      final accountMap = {for (var a in accounts) a.id: a};
      final categoryMap = {for (var c in categories) c.id: c};

      // 根据格式导出
      String filePath;
      switch (format) {
        case ExportFormat.csv:
          filePath = await _exportToCsv(transactions, accountMap, categoryMap);
          break;
        case ExportFormat.excel:
          filePath = await _exportToExcel(transactions, accountMap, categoryMap);
          break;
        case ExportFormat.pdf:
          filePath = await _exportToPdf(transactions, accountMap, categoryMap);
          break;
      }

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: transactions.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: '导出失败: $e',
      );
    }
  }

  /// 导出为CSV格式
  Future<String> _exportToCsv(
    List<Transaction> transactions,
    Map<String, Account> accountMap,
    Map<String, Category> categoryMap,
  ) async {
    final List<List<dynamic>> rows = [];

    // 表头
    rows.add([
      '日期',
      '类型',
      '金额',
      '账户',
      '分类',
      '子分类',
      '商户名称',
      '备注',
      '来源',
      '标签',
    ]);

    // 数据行
    for (var tx in transactions) {
      final account = accountMap[tx.accountId];
      final category = tx.categoryId != null ? categoryMap[tx.categoryId] : null;
      final subCategory = tx.subCategoryId != null 
          ? categoryMap[tx.subCategoryId] 
          : null;

      rows.add([
        AppDateUtils.formatDateTime(tx.transactionDate),
        _getTypeLabel(tx.type),
        MoneyUtils.formatWithoutSymbol(tx.amount),
        account?.name ?? '',
        category?.name ?? '',
        subCategory?.name ?? '',
        tx.merchantName ?? '',
        tx.description ?? '',
        tx.source ?? '',
        tx.tags.join(';'),
      ]);
    }

    // 生成CSV内容
    final csvContent = const ListToCsvConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
    ).convert(rows);

    // 保存文件
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '交易记录_${AppDateUtils.formatDate(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString('\uFEFF$csvContent', encoding: utf8); // 添加BOM以支持Excel打开

    return file.path;
  }

  /// 导出为Excel格式
  Future<String> _exportToExcel(
    List<Transaction> transactions,
    Map<String, Account> accountMap,
    Map<String, Category> categoryMap,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['交易记录'];

    // 设置表头
    final headers = ['日期', '类型', '金额', '账户', '分类', '子分类', '商户名称', '备注', '来源', '标签'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByString(_getExcelColumn(i, 1))).value = TextCellValue(headers[i]);
      // 设置表头样式
      sheet.cell(CellIndex.indexByString(_getExcelColumn(i, 1))).cellStyle = CellStyle(
        bold: true,
        backgroundColor: ExcelColor.fromHexString('#4472C4'),
        fontColor: ExcelColor.white,
      );
    }

    // 填充数据
    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final account = accountMap[tx.accountId];
      final category = tx.categoryId != null ? categoryMap[tx.categoryId] : null;
      final subCategory = tx.subCategoryId != null 
          ? categoryMap[tx.subCategoryId] 
          : null;

      final row = i + 2; // 从第2行开始（第1行是表头）
      
      sheet.cell(CellIndex.indexByString(_getExcelColumn(0, row))).value = 
          TextCellValue(AppDateUtils.formatDateTime(tx.transactionDate));
      sheet.cell(CellIndex.indexByString(_getExcelColumn(1, row))).value = 
          TextCellValue(_getTypeLabel(tx.type));
      sheet.cell(CellIndex.indexByString(_getExcelColumn(2, row))).value = 
          DoubleCellValue(tx.amount);
      sheet.cell(CellIndex.indexByString(_getExcelColumn(3, row))).value = 
          TextCellValue(account?.name ?? '');
      sheet.cell(CellIndex.indexByString(_getExcelColumn(4, row))).value = 
          TextCellValue(category?.name ?? '');
      sheet.cell(CellIndex.indexByString(_getExcelColumn(5, row))).value = 
          TextCellValue(subCategory?.name ?? '');
      sheet.cell(CellIndex.indexByString(_getExcelColumn(6, row))).value = 
          TextCellValue(tx.merchantName ?? '');
      sheet.cell(CellIndex.indexByString(_getExcelColumn(7, row))).value = 
          TextCellValue(tx.description ?? '');
      sheet.cell(CellIndex.indexByString(_getExcelColumn(8, row))).value = 
          TextCellValue(tx.source ?? '');
      sheet.cell(CellIndex.indexByString(_getExcelColumn(9, row))).value = 
          TextCellValue(tx.tags.join(';'));
    }

    // 设置列宽
    sheet.setColumnWidth(ExcelColumn.fromChar('A'), 20); // 日期
    sheet.setColumnWidth(ExcelColumn.fromChar('B'), 10); // 类型
    sheet.setColumnWidth(ExcelColumn.fromChar('C'), 12); // 金额
    sheet.setColumnWidth(ExcelColumn.fromChar('D'), 15); // 账户
    sheet.setColumnWidth(ExcelColumn.fromChar('E'), 15); // 分类
    sheet.setColumnWidth(ExcelColumn.fromChar('F'), 15); // 子分类
    sheet.setColumnWidth(ExcelColumn.fromChar('G'), 20); // 商户名称
    sheet.setColumnWidth(ExcelColumn.fromChar('H'), 30); // 备注
    sheet.setColumnWidth(ExcelColumn.fromChar('I'), 12); // 来源
    sheet.setColumnWidth(ExcelColumn.fromChar('J'), 20); // 标签

    // 删除默认创建的Sheet
    excel.delete('Sheet1');

    // 保存文件
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '交易记录_${AppDateUtils.formatDate(DateTime.now())}.xlsx';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);

    return file.path;
  }

  /// 导出为PDF格式
  Future<String> _exportToPdf(
    List<Transaction> transactions,
    Map<String, Account> accountMap,
    Map<String, Category> categoryMap,
  ) async {
    // 创建PDF文档
    final pdf = PdfDocument();
    
    // 添加页面
    final page = pdf.pages.add();
    
    // 设置字体（支持中文）
    final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16);
    
    // 绘制标题
    final title = '交易记录导出';
    page.graphics.drawString(
      title,
      titleFont,
      bounds: const Rect.fromLTWH(0, 0, 500, 30),
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
    );

    // 绘制导出信息
    final exportInfo = '导出时间: ${AppDateUtils.formatDateTime(DateTime.now())}  记录数: ${transactions.length}';
    page.graphics.drawString(
      exportInfo,
      font,
      bounds: const Rect.fromLTWH(0, 35, 500, 20),
    );

    // 创建表格
    final table = PdfGrid();
    table.columns.addCount(6);
    
    // 设置表头
    table.headers.add(1);
    table.headers[0].cells[0].value = '日期';
    table.headers[0].cells[1].value = '类型';
    table.headers[0].cells[2].value = '金额';
    table.headers[0].cells[3].value = '账户';
    table.headers[0].cells[4].value = '分类';
    table.headers[0].cells[5].value = '商户';
    
    // 设置表头样式
    for (var cell in table.headers[0].cells) {
      cell.style.backgroundBrush = PdfSolidBrush(PdfColor(68, 114, 196));
      cell.style.textBrush = PdfSolidBrush(PdfColor(255, 255, 255));
      cell.style.font = font;
    }

    // 添加数据行
    for (var tx in transactions) {
      final account = accountMap[tx.accountId];
      final category = tx.categoryId != null ? categoryMap[tx.categoryId] : null;

      final row = table.rows.add();
      row.cells[0].value = AppDateUtils.formatDate(tx.transactionDate);
      row.cells[1].value = _getTypeLabel(tx.type);
      row.cells[2].value = MoneyUtils.formatWithoutSymbol(tx.amount);
      row.cells[3].value = account?.name ?? '';
      row.cells[4].value = category?.name ?? '';
      row.cells[5].value = tx.merchantName ?? '';
      
      // 设置行样式
      for (var cell in row.cells) {
        cell.style.font = font;
        cell.style.borders.all = PdfPen(PdfColor(200, 200, 200));
      }
    }

    // 设置列宽
    table.columns[0].width = 80;
    table.columns[1].width = 50;
    table.columns[2].width = 60;
    table.columns[3].width = 80;
    table.columns[4].width = 80;
    table.columns[5].width = 100;

    // 绘制表格
    table.draw(
      page: page,
      bounds: const Rect.fromLTWH(0, 60, 0, 0),
    );

    // 保存PDF
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '交易记录_${AppDateUtils.formatDate(DateTime.now())}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    // 释放资源
    pdf.dispose();

    return file.path;
  }

  /// 通过系统分享功能分享导出的文件
  Future<void> shareFile(String filePath, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: subject ?? '交易记录导出',
    );
  }

  /// 获取交易类型标签
  String _getTypeLabel(String type) {
    switch (type) {
      case 'expense':
        return '支出';
      case 'income':
        return '收入';
      case 'transfer':
        return '转账';
      default:
        return type;
    }
  }

  /// 获取Excel列名（0=A, 1=B, ...）
  String _getExcelColumn(int index, int row) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index < 26) {
      return '${letters[index]}$row';
    } else {
      final firstLetter = letters[(index ~/ 26) - 1];
      final secondLetter = letters[index % 26];
      return '$firstLetter$secondLetter$row';
    }
  }

  /// 导出全部数据（无时间限制）
  Future<ExportResult> exportAllTransactions({
    required ExportFormat format,
  }) async {
    try {
      // 获取所有交易记录
      final transactions = await _transactionRepository.getAll();

      if (transactions.isEmpty) {
        return ExportResult(
          success: false,
          error: '没有交易记录',
        );
      }

      // 获取账户和分类信息
      final accounts = await _accountRepository.getAll();
      final categories = await _categoryRepository.getAll();
      
      final accountMap = {for (var a in accounts) a.id: a};
      final categoryMap = {for (var c in categories) c.id: c};

      // 根据格式导出
      String filePath;
      switch (format) {
        case ExportFormat.csv:
          filePath = await _exportToCsv(transactions, accountMap, categoryMap);
          break;
        case ExportFormat.excel:
          filePath = await _exportToExcel(transactions, accountMap, categoryMap);
          break;
        case ExportFormat.pdf:
          filePath = await _exportToPdf(transactions, accountMap, categoryMap);
          break;
      }

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: transactions.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: '导出失败: $e',
      );
    }
  }

  /// 导出账户列表
  Future<ExportResult> exportAccounts({required ExportFormat format}) async {
    try {
      final accounts = await _accountRepository.getAll();

      if (accounts.isEmpty) {
        return ExportResult(
          success: false,
          error: '没有账户数据',
        );
      }

      String filePath;
      switch (format) {
        case ExportFormat.csv:
          filePath = await _exportAccountsToCsv(accounts);
          break;
        case ExportFormat.excel:
          filePath = await _exportAccountsToExcel(accounts);
          break;
        case ExportFormat.pdf:
          filePath = await _exportAccountsToPdf(accounts);
          break;
      }

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: accounts.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: '导出失败: $e',
      );
    }
  }

  /// 导出账户为CSV
  Future<String> _exportAccountsToCsv(List<Account> accounts) async {
    final List<List<dynamic>> rows = [];

    rows.add(['账户名称', '账户类型', '余额', '货币', '创建时间']);

    for (var account in accounts) {
      rows.add([
        account.name,
        _getAccountTypeLabel(account.type),
        MoneyUtils.formatWithoutSymbol(account.balance),
        account.currency,
        AppDateUtils.formatDateTime(account.createdAt),
      ]);
    }

    final csvContent = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '账户列表_${AppDateUtils.formatDate(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString('\uFEFF$csvContent', encoding: utf8);

    return file.path;
  }

  /// 导出账户为Excel
  Future<String> _exportAccountsToExcel(List<Account> accounts) async {
    final excel = Excel.createExcel();
    final sheet = excel['账户列表'];

    final headers = ['账户名称', '账户类型', '余额', '货币', '创建时间'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByString(_getExcelColumn(i, 1))).value = TextCellValue(headers[i]);
    }

    for (var i = 0; i < accounts.length; i++) {
      final account = accounts[i];
      final row = i + 2;

      sheet.cell(CellIndex.indexByString(_getExcelColumn(0, row))).value = TextCellValue(account.name);
      sheet.cell(CellIndex.indexByString(_getExcelColumn(1, row))).value = TextCellValue(_getAccountTypeLabel(account.type));
      sheet.cell(CellIndex.indexByString(_getExcelColumn(2, row))).value = DoubleCellValue(account.balance);
      sheet.cell(CellIndex.indexByString(_getExcelColumn(3, row))).value = TextCellValue(account.currency);
      sheet.cell(CellIndex.indexByString(_getExcelColumn(4, row))).value = TextCellValue(AppDateUtils.formatDateTime(account.createdAt));
    }

    excel.delete('Sheet1');

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '账户列表_${AppDateUtils.formatDate(DateTime.now())}.xlsx';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);

    return file.path;
  }

  /// 导出账户为PDF
  Future<String> _exportAccountsToPdf(List<Account> accounts) async {
    final pdf = PdfDocument();
    final page = pdf.pages.add();
    
    final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16);

    page.graphics.drawString(
      '账户列表导出',
      titleFont,
      bounds: const Rect.fromLTWH(0, 0, 500, 30),
    );

    final table = PdfGrid();
    table.columns.addCount(5);
    
    table.headers.add(1);
    table.headers[0].cells[0].value = '账户名称';
    table.headers[0].cells[1].value = '账户类型';
    table.headers[0].cells[2].value = '余额';
    table.headers[0].cells[3].value = '货币';
    table.headers[0].cells[4].value = '创建时间';

    for (var cell in table.headers[0].cells) {
      cell.style.backgroundBrush = PdfSolidBrush(PdfColor(68, 114, 196));
      cell.style.textBrush = PdfSolidBrush(PdfColor(255, 255, 255));
      cell.style.font = font;
    }

    for (var account in accounts) {
      final row = table.rows.add();
      row.cells[0].value = account.name;
      row.cells[1].value = _getAccountTypeLabel(account.type);
      row.cells[2].value = MoneyUtils.formatWithoutSymbol(account.balance);
      row.cells[3].value = account.currency;
      row.cells[4].value = AppDateUtils.formatDate(account.createdAt);
      
      for (var cell in row.cells) {
        cell.style.font = font;
      }
    }

    table.draw(page: page, bounds: const Rect.fromLTWH(0, 60, 0, 0));

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '账户列表_${AppDateUtils.formatDate(DateTime.now())}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    pdf.dispose();

    return file.path;
  }

  /// 获取账户类型标签
  String _getAccountTypeLabel(String type) {
    const typeLabels = {
      'alipay': '支付宝',
      'wechat': '微信',
      'bankCard': '银行卡',
      'cloudFlash': '云闪付',
      'jdBaitiao': '京东白条',
      'digitalRmb': '数字人民币',
      'cash': '现金',
      'other': '其他',
    };
    return typeLabels[type] ?? type;
  }
}
