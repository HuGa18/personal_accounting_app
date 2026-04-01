import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../providers/providers.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';
import '../../utils/constants.dart';
import '../../enums/transaction_type.dart';

/// 交易列表页面
/// 按时间线展示交易记录，支持筛选、搜索、分页、左滑删除
class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 滚动监听，触发加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// 加载更多数据
  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    final filter = ref.read(transactionFilterProvider);
    setState(() => _isLoadingMore = true);

    try {
      await ref.read(transactionsProvider.notifier).getByPage(
        page: filter.page + 1,
        pageSize: filter.pageSize,
        accountId: filter.accountId,
        categoryId: filter.categoryId,
        type: filter.type,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
      ref.read(transactionFilterProvider.notifier).setPage(filter.page + 1);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// 刷新数据
  Future<void> _refresh() async {
    ref.read(transactionFilterProvider.notifier).setPage(1);
    await ref.read(transactionsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索商户名称或备注',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(transactionFilterProvider.notifier).setKeyword(
                    value.isEmpty ? null : value,
                  );
                },
              )
            : const Text('交易明细'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(transactionFilterProvider.notifier).setKeyword(null);
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) => _buildTransactionList(transactions, filter),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/transactions/add');
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 构建交易列表
  Widget _buildTransactionList(
    List<Transaction> transactions,
    TransactionFilterState filter,
  ) {
    if (transactions.isEmpty) {
      return _buildEmptyState(filter);
    }

    // 按日期分组
    final groupedTransactions = _groupByDate(transactions);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: groupedTransactions.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedTransactions.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final group = groupedTransactions[index];
          return _buildDateGroup(group['date'] as String, group['transactions'] as List<Transaction>);
        },
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(TransactionFilterState filter) {
    String message = '暂无交易记录';
    if (filter.hasFilter) {
      message = '没有符合条件的交易记录';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (filter.hasFilter) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                ref.read(transactionFilterProvider.notifier).reset();
              },
              child: const Text('清除筛选条件'),
            ),
          ],
        ],
      ),
    );
  }

  /// 按日期分组
  List<Map<String, dynamic>> _groupByDate(List<Transaction> transactions) {
    // 按日期排序
    final sortedTransactions = transactions.toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final groups = <String, List<Transaction>>{};
    for (var tx in sortedTransactions) {
      final dateKey = DateUtils.formatDate(tx.transactionDate);
      groups.putIfAbsent(dateKey, () => []);
      groups[dateKey]!.add(tx);
    }

    return groups.entries
        .map((e) => {'date': e.key, 'transactions': e.value})
        .toList();
  }

  /// 构建日期分组
  Widget _buildDateGroup(String date, List<Transaction> transactions) {
    final dateDisplay = _formatDateDisplay(date);
    final dayTotal = _calculateDayTotal(transactions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateDisplay,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '支出: ${MoneyUtils.format(dayTotal['expense']!)}  收入: ${MoneyUtils.format(dayTotal['income']!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // 交易列表
        ...transactions.map((tx) => _buildTransactionItem(tx)),
        const Divider(height: 1),
      ],
    );
  }

  /// 格式化日期显示
  String _formatDateDisplay(String dateStr) {
    final date = DateUtils.parseDate(dateStr);
    if (DateUtils.isToday(date)) {
      return '今天 ${DateUtils.formatDate(date)}';
    } else if (DateUtils.isYesterday(date)) {
      return '昨天 ${DateUtils.formatDate(date)}';
    } else {
      return DateUtils.formatDate(date);
    }
  }

  /// 计算当日收支
  Map<String, double> _calculateDayTotal(List<Transaction> transactions) {
    double expense = 0;
    double income = 0;

    for (var tx in transactions) {
      if (tx.type == 'expense') {
        expense += tx.amount;
      } else if (tx.type == 'income') {
        income += tx.amount;
      }
    }

    return {'expense': expense, 'income': income};
  }

  /// 构建交易项
  Widget _buildTransactionItem(Transaction transaction) {
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense ? Colors.red : Colors.green;
    final amountPrefix = isExpense ? '-' : '+';

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _confirmDelete(transaction);
      },
      onDismissed: (direction) {
        ref.read(transactionsProvider.notifier).delete(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除: ${transaction.merchantName ?? "交易记录"}'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () {
                // TODO: Implement undo
              },
            ),
          ),
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTime(transaction.transactionDate),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (transaction.description != null && transaction.description!.isNotEmpty)
              Text(
                transaction.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          '$amountPrefix${MoneyUtils.format(transaction.amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
        onTap: () {
          // TODO: Navigate to transaction detail page
          _showTransactionDetail(transaction);
        },
      ),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 确认删除
  Future<bool> _confirmDelete(Transaction transaction) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${transaction.merchantName ?? "此交易记录"}" 吗？'),
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
    ) ?? false;
  }

  /// 显示交易详情
  void _showTransactionDetail(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _TransactionDetailSheet(
          transaction: transaction,
          scrollController: scrollController,
        ),
      ),
    );
  }

  /// 显示筛选对话框
  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const TransactionFilterSheet(),
    );
  }
}

/// 交易详情底部弹窗
class _TransactionDetailSheet extends ConsumerWidget {
  final Transaction transaction;
  final ScrollController scrollController;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '交易详情',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 金额
          Center(
            child: Column(
              children: [
                Icon(
                  isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 48,
                  color: amountColor,
                ),
                const SizedBox(height: 8),
                Text(
                  '${isExpense ? "-" : "+"}${MoneyUtils.format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 详情列表
          _buildDetailItem('商户名称', transaction.merchantName ?? '-'),
          _buildDetailItem('交易类型', isExpense ? '支出' : '收入'),
          _buildDetailItem('交易时间', DateUtils.formatDateTime(transaction.transactionDate)),
          _buildDetailItem('备注', transaction.description ?? '-'),
          _buildDetailItem('来源', transaction.source ?? '手动记录'),
          if (transaction.location != null)
            _buildDetailItem('地点', transaction.location!),
          if (transaction.tags.isNotEmpty)
            _buildDetailItem('标签', transaction.tags.join(', ')),
          const SizedBox(height: 24),
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await context.push('/transactions/edit/${transaction.id}');
                    ref.read(transactionsProvider.notifier).refresh();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: const Text('确定要删除此交易记录吗？'),
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

                    if (confirmed == true) {
                      ref.read(transactionsProvider.notifier).delete(transaction.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已删除')),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete),
                  label: const Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// 交易筛选底部弹窗
class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  ConsumerState<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends ConsumerState<TransactionFilterSheet> {
  String? _selectedType;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(transactionFilterProvider);
    _selectedType = filter.type;
    _selectedAccountId = filter.accountId;
    _selectedCategoryId = filter.categoryId;
    _startDate = filter.startDate;
    _endDate = filter.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '筛选条件',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  ref.read(transactionFilterProvider.notifier).reset();
                  Navigator.pop(context);
                },
                child: const Text('重置'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 交易类型
          const Text('交易类型', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeChip('全部', null),
              _buildTypeChip('支出', 'expense'),
              _buildTypeChip('收入', 'income'),
              _buildTypeChip('转账', 'transfer'),
            ],
          ),
          const SizedBox(height: 16),

          // 账户选择
          const Text('账户', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          accountsAsync.when(
            data: (accounts) => Wrap(
              spacing: 8,
              children: [
                _buildAccountChip('全部', null),
                ...accounts.map((a) => _buildAccountChip(a.name, a.id)),
              ],
            ),
            loading: () => const Text('加载中...'),
            error: (_, __) => const Text('加载失败'),
          ),
          const SizedBox(height: 16),

          // 分类选择
          const Text('分类', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          categoriesAsync.when(
            data: (categories) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCategoryChip('全部', null),
                ...categories.take(10).map((c) => _buildCategoryChip(c.name, c.id)),
              ],
            ),
            loading: () => const Text('加载中...'),
            error: (_, __) => const Text('加载失败'),
          ),
          const SizedBox(height: 16),

          // 时间范围
          const Text('时间范围', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectStartDate(),
                  child: Text(
                    _startDate != null
                        ? DateUtils.formatDate(_startDate!)
                        : '开始日期',
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('至'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectEndDate(),
                  child: Text(
                    _endDate != null
                        ? DateUtils.formatDate(_endDate!)
                        : '结束日期',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 应用按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final notifier = ref.read(transactionFilterProvider.notifier);
                notifier.setType(_selectedType);
                notifier.setAccountId(_selectedAccountId);
                notifier.setCategoryId(_selectedCategoryId);
                notifier.setDateRange(_startDate, _endDate);
                Navigator.pop(context);
              },
              child: const Text('应用筛选'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String? type) {
    final isSelected = _selectedType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedType = type);
      },
    );
  }

  Widget _buildAccountChip(String label, String? accountId) {
    final isSelected = _selectedAccountId == accountId;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedAccountId = accountId);
      },
    );
  }

  Widget _buildCategoryChip(String label, String? categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedCategoryId = categoryId);
      },
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: _endDate ?? DateTime.now(),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }
}