import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../providers/providers.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';
import '../../enums/transaction_type.dart';
import '../../enums/bill_source.dart';

class TransactionDetailPage extends ConsumerStatefulWidget {
  final String transactionId;

  const TransactionDetailPage({
    super.key,
    required this.transactionId,
  });

  @override
  ConsumerState<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends ConsumerState<TransactionDetailPage> {
  Transaction? _transaction;
  Category? _category;
  Category? _subCategory;
  Account? _account;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final transactionRepo = ref.read(transactionRepositoryProvider);
      final transaction = await transactionRepo.getById(widget.transactionId);

      if (transaction == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('交易记录不存在')),
          );
          context.pop();
        }
        return;
      }

      Category? category;
      Category? subCategory;
      Account? account;

      if (transaction.categoryId != null) {
        final categoryRepo = ref.read(categoryRepositoryProvider);
        category = await categoryRepo.getById(transaction.categoryId!);
        if (transaction.subCategoryId != null) {
          subCategory = await categoryRepo.getById(transaction.subCategoryId!);
        }
      }

      if (transaction.accountId.isNotEmpty) {
        final accountRepo = ref.read(accountRepositoryProvider);
        account = await accountRepo.getById(transaction.accountId);
      }

      if (mounted) {
        setState(() {
          _transaction = transaction;
          _category = category;
          _subCategory = subCategory;
          _account = account;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条交易记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(transactionsProvider.notifier).delete(widget.transactionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('交易记录已删除')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('交易详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('交易详情')),
        body: const Center(child: Text('交易记录不存在')),
      );
    }

    final transaction = _transaction!;
    final type = TransactionTypeExtension.fromString(transaction.type);
    final isExpense = type == TransactionType.expense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易详情'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () async {
              final result = await context.push<bool>(
                '/transactions/edit/${transaction.id}',
              );
              if (result == true) {
                _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: _isDeleting ? null : _deleteTransaction,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAmountCard(transaction, isExpense),
          const SizedBox(height: 16),
          _buildInfoCard(transaction),
          const SizedBox(height: 16),
          _buildMetaCard(transaction),
        ],
      ),
    );
  }

  Widget _buildAmountCard(Transaction transaction, bool isExpense) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isExpense ? Icons.arrow_upward : Icons.arrow_downward,
              size: 48,
              color: isExpense ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              isExpense ? '支出' : '收入',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              MoneyUtils.format(transaction.amount),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isExpense ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Transaction transaction) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '交易信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              '商户名称',
              transaction.merchantName ?? '未知',
              Icons.store_outlined,
            ),
            if (_category != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                '分类',
                _subCategory != null
                    ? '${_category!.name} · ${_subCategory!.name}'
                    : _category!.name,
                Icons.category_outlined,
              ),
            ],
            if (_account != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                '账户',
                _account!.name,
                Icons.account_balance_wallet_outlined,
              ),
            ],
            if (transaction.description != null &&
                transaction.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                '备注',
                transaction.description!,
                Icons.note_outlined,
              ),
            ],
            if (transaction.location != null &&
                transaction.location!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                '地点',
                transaction.location!,
                Icons.location_on_outlined,
              ),
            ],
            if (transaction.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTagsRow(transaction.tags),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaCard(Transaction transaction) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '其他信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              '交易时间',
              AppDateUtils.formatDateTime(transaction.transactionDate),
              Icons.access_time,
            ),
            if (transaction.source != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                '数据来源',
                BillSourceExtension.fromString(transaction.source!).label,
                Icons.source_outlined,
              ),
            ],
            const SizedBox(height: 16),
            _buildInfoRow(
              '创建时间',
              AppDateUtils.formatDateTime(transaction.createdAt),
              Icons.add_circle_outline,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              '更新时间',
              AppDateUtils.formatDateTime(transaction.updatedAt),
              Icons.update,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow(List<String> tags) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.label_outline, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '标签',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
