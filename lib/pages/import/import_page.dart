import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../enums/bill_source.dart';
import '../../services/bill_parser_service.dart';
import '../../providers/providers.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';

/// 账单导入页面
/// 
/// 支持选择账单来源、选择文件、解析预览、分类修正、确认导入
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  // 当前步骤
  int _currentStep = 0;
  
  // 选中的账单来源
  BillSource? _selectedSource;
  
  // 选中的账户ID
  String? _selectedAccountId;
  
  // 选中的文件信息
  String? _selectedFileName;
  String? _selectedFileExtension;
  Uint8List? _selectedFileBytes;
  
  // 解析结果
  List<Transaction> _parsedTransactions = [];
  List<Transaction> _editedTransactions = [];
  ParseResult? _parseResult;
  
  // 解析状态
  bool _isParsing = false;
  double _parseProgress = 0.0;
  String? _parseError;
  
  // 导入状态
  bool _isImporting = false;
  
  // 账单解析服务
  final BillParserService _parserService = BillParserService();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单导入'),
        centerTitle: true,
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        onStepTapped: _onStepTapped,
        controlsBuilder: _buildControls,
        steps: [
          _buildSourceStep(),
          _buildFileStep(),
          _buildPreviewStep(),
          _buildConfirmStep(),
        ],
      ),
    );
  }

  /// 构建步骤控制按钮
  Widget _buildControls(
    BuildContext context, {
    VoidCallback? onStepContinue,
    VoidCallback? onStepCancel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_currentStep < 3)
            ElevatedButton(
              onPressed: onStepContinue,
              child: const Text('继续'),
            ),
          if (_currentStep > 0 && _currentStep < 3)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: onStepCancel,
                child: const Text('返回'),
              ),
            ),
        ],
      ),
    );
  }

  /// 步骤1: 选择账单来源
  Step _buildSourceStep() {
    final accountsAsync = ref.watch(accountsProvider);

    return Step(
      title: const Text('选择来源'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择账单来源',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '请选择账单的来源渠道，不同渠道的账单格式可能不同',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // 账单来源选择
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: BillSource.values
                .where((s) => s.isImportable)
                .map((source) => _buildSourceCard(source))
                .toList(),
          ),
          const SizedBox(height: 24),
          
          // 账户选择
          const Text(
            '选择关联账户',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '导入的交易将关联到此账户',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          accountsAsync.when(
            data: (accounts) => _buildAccountSelector(accounts),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('加载账户失败: $error'),
          ),
        ],
      ),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    );
  }

  /// 构建账单来源卡片
  Widget _buildSourceCard(BillSource source) {
    final isSelected = _selectedSource == source;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSource = source;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? source.color.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? source.color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              source.icon,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              source.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建账户选择器
  Widget _buildAccountSelector(List<Account> accounts) {
    if (accounts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('请先创建账户'),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedAccountId,
      decoration: const InputDecoration(
        labelText: '选择账户',
        border: OutlineInputBorder(),
      ),
      items: accounts.map((account) {
        return DropdownMenuItem(
          value: account.id,
          child: Text(account.name),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedAccountId = value;
        });
      },
    );
  }

  /// 步骤2: 选择文件
  Step _buildFileStep() {
    final supportedExtensions = _selectedSource != null
        ? _parserService.getSupportedExtensions(_selectedSource!)
        : <String>[];

    return Step(
      title: const Text('选择文件'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '支持的文件格式: ${supportedExtensions.join(", ").toUpperCase()}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // 文件选择按钮
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 48,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ?? '点击选择文件',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedFileName != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '文件大小: ${(_selectedFileBytes!.length / 1024).toStringAsFixed(2)} KB',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 解析进度
          if (_isParsing) ...[
            const SizedBox(height: 24),
            LinearProgressIndicator(value: _parseProgress),
            const SizedBox(height: 8),
            Text(
              '正在解析... ${(_parseProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          
          // 解析错误
          if (_parseError != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _parseError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  /// 步骤3: 预览和修正
  Step _buildPreviewStep() {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Step(
      title: const Text('预览修正'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 解析结果统计
          if (_parseResult != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '解析结果',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatItem('总记录', _parseResult!.totalCount),
                        const SizedBox(width: 24),
                        _buildStatItem('有效记录', _parseResult!.uniqueCount),
                        const SizedBox(width: 24),
                        _buildStatItem('重复记录', _parseResult!.duplicateCount),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // 交易列表预览
          const Text(
            '交易记录预览',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击记录可修正分类',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          
          if (_editedTransactions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无有效记录'),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: categoriesAsync.when(
                data: (categories) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: _editedTransactions.length,
                  itemBuilder: (context, index) {
                    return _buildTransactionPreviewItem(
                      _editedTransactions[index],
                      categories,
                      index,
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('加载分类失败: $error'),
              ),
            ),
        ],
      ),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// 构建交易预览项
  Widget _buildTransactionPreviewItem(
    Transaction transaction,
    List<Category> categories,
    int index,
  ) {
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense ? Colors.red : Colors.green;
    
    // 查找分类名称
    String categoryName = '未分类';
    if (transaction.categoryId != null) {
      final category = categories.firstWhere(
        (c) => c.id == transaction.categoryId,
        orElse: () => categories.first,
      );
      categoryName = category.name;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withOpacity(0.1),
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: amountColor,
            size: 20,
          ),
        ),
        title: Text(
          transaction.merchantName ?? '未知商户',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppDateUtils.formatDateTime(transaction.transactionDate),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          MoneyUtils.format(transaction.amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
        onTap: () => _showCategorySelector(transaction, categories, index),
      ),
    );
  }

  /// 显示分类选择器
  void _showCategorySelector(
    Transaction transaction,
    List<Category> categories,
    int index,
  ) {
    final expenseCategories = categories.where((c) => c.type == 'expense').toList();
    final incomeCategories = categories.where((c) => c.type == 'income').toList();
    final isExpense = transaction.type == 'expense';
    final relevantCategories = isExpense ? expenseCategories : incomeCategories;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择分类 - ${transaction.merchantName ?? "未知商户"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: relevantCategories.length,
                itemBuilder: (context, catIndex) {
                  final category = relevantCategories[catIndex];
                  final isSelected = transaction.categoryId == category.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _editedTransactions[index] = transaction.copyWith(
                          categoryId: category.id,
                        );
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue[50]
                            : Colors.grey[100],
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue
                              : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category.icon ?? '📁',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.name,
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 步骤4: 确认导入
  Step _buildConfirmStep() {
    return Step(
      title: const Text('确认导入'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '导入信息',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('账单来源', _selectedSource?.label ?? '-'),
                  _buildInfoRow('文件名称', _selectedFileName ?? '-'),
                  _buildInfoRow('有效记录', '${_editedTransactions.length} 条'),
                  _buildInfoRow(
                    '总金额',
                    MoneyUtils.format(
                      _editedTransactions.fold<double>(
                        0,
                        (sum, tx) => sum + tx.amount,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          if (_isImporting)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在导入...'),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importTransactions,
                icon: const Icon(Icons.check),
                label: const Text('确认导入'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
        ],
      ),
      isActive: _currentStep >= 3,
      state: StepState.indexed,
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// 选择文件
  Future<void> _pickFile() async {
    try {
      final supportedExtensions = _selectedSource != null
          ? _parserService.getSupportedExtensions(_selectedSource!)
          : <String>[];

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileExtension = file.extension;
          _selectedFileBytes = file.bytes;
          _parseError = null;
        });
      }
    } catch (e) {
      setState(() {
        _parseError = '选择文件失败: $e';
      });
    }
  }

  /// 解析文件
  Future<void> _parseFile() async {
    if (_selectedFileBytes == null ||
        _selectedFileExtension == null ||
        _selectedSource == null ||
        _selectedAccountId == null) {
      return;
    }

    setState(() {
      _isParsing = true;
      _parseProgress = 0;
      _parseError = null;
    });

    try {
      // 模拟解析进度
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        setState(() {
          _parseProgress = i / 10;
        });
      }

      // 解析账单
      final result = await _parserService.parseAndImport(
        fileBytes: _selectedFileBytes!,
        extension: _selectedFileExtension!,
        source: _selectedSource!,
        accountId: _selectedAccountId!,
      );

      setState(() {
        _parseResult = result;
        _parsedTransactions = result.transactions;
        _editedTransactions = List.from(result.transactions);
        _isParsing = false;
      });

      // 自动匹配分类
      await _autoMatchCategories();
    } catch (e) {
      setState(() {
        _parseError = '解析失败: $e';
        _isParsing = false;
      });
    }
  }

  /// 自动匹配分类
  Future<void> _autoMatchCategories() async {
    final categoriesAsync = ref.read(categoriesProvider);
    
    categoriesAsync.when(
      data: (categories) async {
        for (int i = 0; i < _editedTransactions.length; i++) {
          final transaction = _editedTransactions[i];
          if (transaction.categoryId == null && transaction.merchantName != null) {
            // 根据商户名称匹配分类
            final matchedCategory = await ref
                .read(categoriesProvider.notifier)
                .matchCategory(transaction.merchantName!);
            
            if (matchedCategory != null) {
              setState(() {
                _editedTransactions[i] = transaction.copyWith(
                  categoryId: matchedCategory.id,
                );
              });
            }
          }
        }
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  /// 导入交易
  Future<void> _importTransactions() async {
    if (_editedTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导入的记录')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      // 批量添加交易
      await ref.read(transactionsProvider.notifier).addBatch(_editedTransactions);

      // 记录导入结果
      await _parserService.recordImport(
        source: _selectedSource!,
        transactions: _editedTransactions,
      );

      setState(() {
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入 ${_editedTransactions.length} 条记录'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 步骤继续
  void _onStepContinue() {
    switch (_currentStep) {
      case 0:
        // 验证来源和账户
        if (_selectedSource == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择账单来源')),
          );
          return;
        }
        if (_selectedAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择关联账户')),
          );
          return;
        }
        setState(() => _currentStep++);
        break;
      case 1:
        // 验证文件并解析
        if (_selectedFileBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择文件')),
          );
          return;
        }
        _parseFile().then((_) {
          if (_parseError == null && _editedTransactions.isNotEmpty) {
            setState(() => _currentStep++);
          }
        });
        break;
      case 2:
        // 进入确认步骤
        setState(() => _currentStep++);
        break;
    }
  }

  /// 步骤返回
  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  /// 步骤点击
  void _onStepTapped(int step) {
    // 只允许点击已完成的步骤
    if (step < _currentStep) {
      setState(() => _currentStep = step);
    }
  }
}