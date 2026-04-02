import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../providers/providers.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';
import '../../utils/id_utils.dart';
import '../../utils/constants.dart';
import '../../enums/transaction_type.dart';
import '../../enums/category_type.dart';

/// 交易表单页面
/// 支持添加/编辑交易记录
class TransactionFormPage extends ConsumerStatefulWidget {
  /// 编辑模式传入的交易ID
  final String? transactionId;

  const TransactionFormPage({
    super.key,
    this.transactionId,
  });

  @override
  ConsumerState<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _subCategoryId;
  String? _accountId;
  DateTime _transactionDate = DateTime.now();
  bool _isLoading = false;
  Transaction? _existingTransaction;

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null) {
      _loadTransaction();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 加载现有交易数据（编辑模式）
  Future<void> _loadTransaction() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(transactionRepositoryProvider);
      final transaction = await repository.getById(widget.transactionId!);
      if (transaction != null && mounted) {
        setState(() {
          _existingTransaction = transaction;
          _type = TransactionTypeExtension.fromString(transaction.type);
          _categoryId = transaction.categoryId;
          _subCategoryId = transaction.subCategoryId;
          _accountId = transaction.accountId;
          _transactionDate = transaction.transactionDate;
          _amountController.text = transaction.amount.toString();
          _merchantController.text = transaction.merchantName ?? '';
          _descriptionController.text = transaction.description ?? '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_existingTransaction != null ? '编辑交易' : '添加交易'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_existingTransaction != null ? '编辑交易' : '添加交易'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 16),
            _buildAmountInput(),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 16),
            _buildAccountSelector(),
            const SizedBox(height: 16),
            _buildMerchantInput(),
            const SizedBox(height: 16),
            _buildDescriptionInput(),
            const SizedBox(height: 16),
            _buildDatePicker(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 构建交易类型选择器
  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '交易类型',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SegmentedButton<TransactionType>(
          segments: const [
            ButtonSegment(
              value: TransactionType.expense,
              label: Text('支出'),
              icon: Icon(Icons.arrow_upward),
            ),
            ButtonSegment(
              value: TransactionType.income,
              label: Text('收入'),
              icon: Icon(Icons.arrow_downward),
            ),
            ButtonSegment(
              value: TransactionType.transfer,
              label: Text('转账'),
              icon: Icon(Icons.swap_horiz),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (Set<TransactionType> selection) {
            setState(() {
              _type = selection.first;
              // 切换类型时清空分类选择
              _categoryId = null;
              _subCategoryId = null;
            });
          },
        ),
      ],
    );
  }

  /// 构建金额输入框
  Widget _buildAmountInput() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: '金额',
        prefixText: '¥',
        border: OutlineInputBorder(),
        hintText: '0.00',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入金额';
        }
        final amount = double.tryParse(value);
        if (amount == null) {
          return '请输入有效金额';
        }
        if (amount <= 0) {
          return '金额必须大于0';
        }
        return null;
      },
    );
  }

  /// 构建分类选择器
  Widget _buildCategorySelector() {
    final categoriesAsync = _type == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        // 过滤出父级分类
        final parentCategories = categories.where((c) => c.parentId == null).toList();
        // 过滤出子分类
        final subCategories = _categoryId != null
            ? categories.where((c) => c.parentId == _categoryId).toList()
            : <Category>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(),
              ),
              items: parentCategories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            if (c.icon != null) ...[
                              Text(c.icon!),
                              const SizedBox(width: 8),
                            ],
                            Text(c.name),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                  _subCategoryId = null;
                });
              },
              validator: (value) {
                if (value == null) {
                  return '请选择分类';
                }
                return null;
              },
            ),
            if (subCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _subCategoryId,
                decoration: const InputDecoration(
                  labelText: '子分类',
                  border: OutlineInputBorder(),
                ),
                items: subCategories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _subCategoryId = value);
                },
              ),
            ],
          ],
        );
      },
      loading: () => const TextFormField(
        decoration: InputDecoration(
          labelText: '分类',
          border: OutlineInputBorder(),
          suffixIcon: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        enabled: false,
      ),
      error: (error, stack) => TextFormField(
        decoration: const InputDecoration(
          labelText: '分类',
          border: OutlineInputBorder(),
          errorText: '加载失败',
        ),
        enabled: false,
      ),
    );
  }

  /// 构建账户选择器
  Widget _buildAccountSelector() {
    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      data: (accounts) => DropdownButtonFormField<String>(
        value: _accountId,
        decoration: const InputDecoration(
          labelText: '账户',
          border: OutlineInputBorder(),
        ),
        items: accounts
            .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Row(
                    children: [
                      Icon(_getAccountIcon(a.type), size: 20),
                      const SizedBox(width: 8),
                      Text(a.name),
                    ],
                  ),
                ))
            .toList(),
        onChanged: (value) => setState(() => _accountId = value),
        validator: (value) {
          if (value == null) {
            return '请选择账户';
          }
          return null;
        },
      ),
      loading: () => const TextFormField(
        decoration: InputDecoration(
          labelText: '账户',
          border: OutlineInputBorder(),
          suffixIcon: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        enabled: false,
      ),
      error: (error, stack) => TextFormField(
        decoration: const InputDecoration(
          labelText: '账户',
          border: OutlineInputBorder(),
          errorText: '加载失败',
        ),
        enabled: false,
      ),
    );
  }

  /// 获取账户图标
  IconData _getAccountIcon(String? type) {
    switch (type) {
      case 'alipay':
        return Icons.account_balance_wallet;
      case 'wechat':
        return Icons.chat;
      case 'bankCard':
        return Icons.credit_card;
      case 'cloudFlash':
        return Icons.flash_on;
      case 'jdBaitiao':
        return Icons.shopping_bag;
      case 'digitalRmb':
        return Icons.currency_yuan;
      case 'cash':
        return Icons.money;
      default:
        return Icons.account_balance;
    }
  }

  /// 构建商户名称输入框
  Widget _buildMerchantInput() {
    return TextFormField(
      controller: _merchantController,
      decoration: const InputDecoration(
        labelText: '商户名称',
        border: OutlineInputBorder(),
        hintText: '例如：美团外卖、滴滴出行',
      ),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入商户名称';
        }
        return null;
      },
    );
  }

  /// 构建备注输入框
  Widget _buildDescriptionInput() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: '备注',
        border: OutlineInputBorder(),
        hintText: '可选',
      ),
      maxLines: 3,
    );
  }

  /// 构建日期时间选择器
  Widget _buildDatePicker() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.grey),
      ),
      title: const Text('交易时间'),
      subtitle: Text(
        AppDateUtils.formatDateTime(_transactionDate),
        style: const TextStyle(fontSize: 16),
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: _selectDateTime,
    );
  }

  /// 选择日期时间
  Future<void> _selectDateTime() async {
    // 选择日期
    final date = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
    );

    if (date == null) return;

    if (!mounted) return;

    // 选择时间
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactionDate),
      locale: const Locale('zh', 'CN'),
    );

    if (time == null) return;

    if (!mounted) return;

    setState(() {
      _transactionDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  /// 提交表单
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final amount = double.parse(_amountController.text);

      final transaction = Transaction(
        id: _existingTransaction?.id ?? IdUtils.generate(),
        accountId: _accountId!,
        type: _type.name,
        amount: amount,
        categoryId: _categoryId,
        subCategoryId: _subCategoryId,
        merchantName: _merchantController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        transactionDate: _transactionDate,
        source: _existingTransaction?.source ?? 'manual',
        tags: _existingTransaction?.tags ?? [],
        createdAt: _existingTransaction?.createdAt ?? now,
        updatedAt: now,
      );

      if (_existingTransaction != null) {
        await ref.read(transactionsProvider.notifier).update(transaction);
      } else {
        await ref.read(transactionsProvider.notifier).add(transaction);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingTransaction != null ? '修改成功' : '添加成功'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
