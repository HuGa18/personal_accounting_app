import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/transaction.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../dto/statistics_result_dto.dart';
import '../../dto/daily_statistics_dto.dart';
import '../../providers/providers.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';
import '../../enums/transaction_type.dart';

/// 首页看板页面
/// 展示本月收支概况、预算执行进度、近7天支出趋势、最近交易记录
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsAsync = ref.watch(thisMonthStatisticsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: '导入账单',
            onPressed: () async {
              await context.push('/import');
              ref.invalidate(thisMonthStatisticsProvider);
              ref.invalidate(transactionsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(thisMonthStatisticsProvider);
              ref.invalidate(transactionsProvider);
              ref.invalidate(budgetsProvider);
            },
          ),
        ],
      ),
      body: statisticsAsync.when(
        data: (statistics) => _buildBody(
          context,
          ref,
          statistics,
          transactionsAsync,
          budgetsAsync,
          categoriesAsync,
        ),
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
                onPressed: () {
                  ref.invalidate(thisMonthStatisticsProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/transactions/add');
          ref.invalidate(thisMonthStatisticsProvider);
          ref.invalidate(transactionsProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    StatisticsResultDTO statistics,
    AsyncValue<List<Transaction>> transactionsAsync,
    AsyncValue<List<Budget>> budgetsAsync,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(thisMonthStatisticsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(budgetsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 本月收支概况
            _buildSummaryCard(context, statistics),
            const SizedBox(height: 16),

            // 预算执行进度
            budgetsAsync.when(
              data: (budgets) => categoriesAsync.when(
                data: (categories) => _buildBudgetProgress(
                  context,
                  budgets,
                  categories,
                  statistics,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // 近7天支出趋势
            _buildTrendCard(context, statistics.dailyStatistics),
            const SizedBox(height: 16),

            // 最近交易记录
            _buildRecentTransactions(context, ref, transactionsAsync),
          ],
        ),
      ),
    );
  }

  /// 构建本月收支概况卡片
  Widget _buildSummaryCard(
    BuildContext context,
    StatisticsResultDTO statistics,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '本月收支概况',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateUtils.formatMonth(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  '支出',
                  statistics.totalExpense,
                  Colors.red,
                  Icons.arrow_upward,
                ),
                _buildSummaryItem(
                  '收入',
                  statistics.totalIncome,
                  Colors.green,
                  Icons.arrow_downward,
                ),
                _buildSummaryItem(
                  '结余',
                  statistics.balance,
                  statistics.balance >= 0 ? Colors.blue : Colors.orange,
                  Icons.account_balance_wallet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建收支概况单项
  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          MoneyUtils.format(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 构建预算执行进度
  Widget _buildBudgetProgress(
    BuildContext context,
    List<Budget> budgets,
    List<Category> categories,
    StatisticsResultDTO statistics,
  ) {
    if (budgets.isEmpty) {
      return const SizedBox.shrink();
    }

    // 构建分类ID到分类名称的映射
    final categoryMap = <String, Category>{};
    for (var category in categories) {
      categoryMap[category.id] = category;
    }

    // 构建分类ID到支出的映射
    final categoryExpenseMap = <String, double>{};
    for (var cs in statistics.categoryStatistics) {
      categoryExpenseMap[cs.categoryId] = cs.amount;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '预算执行进度',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...budgets.take(3).map((budget) {
              final category = categoryMap[budget.categoryId];
              final spent = categoryExpenseMap[budget.categoryId] ?? 0;
              final percentage = budget.amount > 0 ? spent / budget.amount : 0;
              final isOverBudget = percentage > 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category?.name ?? '未知分类',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${MoneyUtils.format(spent)} / ${MoneyUtils.format(budget.amount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverBudget ? Colors.red : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage > 1 ? 1 : percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverBudget ? Colors.red : Colors.blue,
                      ),
                    ),
                    if (isOverBudget)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '已超支 ${MoneyUtils.format(spent - budget.amount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 构建近7天支出趋势卡片
  Widget _buildTrendCard(
    BuildContext context,
    List<DailyStatisticsDTO> dailyStatistics,
  ) {
    // 获取最近7天的数据
    final last7Days = _getLast7DaysStatistics(dailyStatistics);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '近7天支出趋势',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (last7Days.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无数据'),
                ),
              )
            else
              SizedBox(
                height: 150,
                child: _buildSimpleBarChart(last7Days),
              ),
          ],
        ),
      ),
    );
  }

  /// 获取最近7天的统计数据
  List<DailyStatisticsDTO> _getLast7DaysStatistics(
    List<DailyStatisticsDTO> dailyStatistics,
  ) {
    final now = DateTime.now();
    final result = <DailyStatisticsDTO>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateUtils.formatDate(date);

      final stat = dailyStatistics.firstWhere(
        (s) => DateUtils.formatDate(s.date) == dateStr,
        orElse: () => DailyStatisticsDTO(
          date: date,
          expense: 0,
          income: 0,
        ),
      );
      result.add(stat);
    }

    return result;
  }

  /// 构建简单的柱状图
  Widget _buildSimpleBarChart(List<DailyStatisticsDTO> data) {
    final maxExpense = data.fold<double>(
      0,
      (max, item) => item.expense > max ? item.expense : max,
    );

    if (maxExpense == 0) {
      return const Center(child: Text('暂无支出数据'));
    }

    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final height = maxExpense > 0 ? (item.expense / maxExpense) * 100 : 0.0;
        final weekday = item.date.weekday;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (item.expense > 0)
              Text(
                MoneyUtils.formatWithoutSymbol(item.expense),
                style: const TextStyle(fontSize: 10),
              ),
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: height.clamp(4, 100),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              weekDays[weekday - 1],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// 构建最近交易记录
  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近交易',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to main shell with transaction list tab
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请点击底部导航栏"明细"查看全部交易')),
                    );
                  },
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('暂无交易记录'),
                    ),
                  );
                }

                // 按日期排序，取最近5条
                final sortedTransactions = transactions.toList()
                  ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
                final recentTransactions = sortedTransactions.take(5).toList();

                return Column(
                  children: recentTransactions
                      .map((tx) => _buildTransactionItem(context, tx))
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('加载失败: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建交易记录项
  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense ? Colors.red : Colors.green;
    final amountPrefix = isExpense ? '-' : '+';

    return ListTile(
      contentPadding: EdgeInsets.zero,
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
      subtitle: Text(
        DateUtils.getRelativeTime(transaction.transactionDate),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
      },
    );
  }
}