import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../dto/statistics_result_dto.dart';
import '../../dto/category_statistics_dto.dart';
import '../../dto/daily_statistics_dto.dart';
import '../../providers/providers.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';

/// 统计分析页面
/// 展示支出构成图、支出趋势图、分类对比图、Top商户排行、智能洞察
class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  @override
  Widget build(BuildContext context) {
    final statisticsAsync = ref.watch(statisticsProvider);
    final timeRangeState = ref.watch(statisticsTimeRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计分析'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(statisticsProvider);
            },
          ),
        ],
      ),
      body: statisticsAsync.when(
        data: (statistics) => _buildBody(context, ref, statistics, timeRangeState),
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
                  ref.invalidate(statisticsProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    StatisticsResultDTO statistics,
    StatisticsTimeRangeState timeRangeState,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(statisticsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间范围选择器
            _buildTimeRangeSelector(context, ref, timeRangeState),
            const SizedBox(height: 16),

            // 收支概况
            _buildSummaryCard(context, statistics, timeRangeState),
            const SizedBox(height: 16),

            // 支出构成环形图
            _buildExpensePieChart(context, statistics.categoryStatistics),
            const SizedBox(height: 16),

            // 月度支出趋势折线图
            if (statistics.dailyStatistics.isNotEmpty)
              _buildTrendLineChart(context, statistics.dailyStatistics),
            const SizedBox(height: 16),

            // 分类对比柱状图
            _buildCategoryBarChart(context, statistics.categoryStatistics),
            const SizedBox(height: 16),

            // Top商户排行
            _buildTopMerchants(context, statistics.categoryStatistics),
            const SizedBox(height: 16),

            // 智能洞察
            _buildInsights(context, statistics),
          ],
        ),
      ),
    );
  }

  /// 构建时间范围选择器
  Widget _buildTimeRangeSelector(
    BuildContext context,
    WidgetRef ref,
    StatisticsTimeRangeState timeRangeState,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '时间范围',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeRangeChip(
                  context,
                  ref,
                  '本月',
                  StatisticsTimeRange.thisMonth,
                  timeRangeState.range == StatisticsTimeRange.thisMonth,
                ),
                _buildTimeRangeChip(
                  context,
                  ref,
                  '上月',
                  StatisticsTimeRange.lastMonth,
                  timeRangeState.range == StatisticsTimeRange.lastMonth,
                ),
                _buildTimeRangeChip(
                  context,
                  ref,
                  '本季度',
                  StatisticsTimeRange.thisQuarter,
                  timeRangeState.range == StatisticsTimeRange.thisQuarter,
                ),
                _buildTimeRangeChip(
                  context,
                  ref,
                  '今年',
                  StatisticsTimeRange.thisYear,
                  timeRangeState.range == StatisticsTimeRange.thisYear,
                ),
                _buildTimeRangeChip(
                  context,
                  ref,
                  '自定义',
                  StatisticsTimeRange.custom,
                  timeRangeState.range == StatisticsTimeRange.custom,
                ),
              ],
            ),
            if (timeRangeState.range == StatisticsTimeRange.custom)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Text(
                      '${DateUtils.formatDate(timeRangeState.startDate)} 至 ${DateUtils.formatDate(timeRangeState.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _showCustomDateRangePicker(context, ref),
                      child: const Text('修改'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    StatisticsTimeRange range,
    bool isSelected,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (range == StatisticsTimeRange.custom) {
          _showCustomDateRangePicker(context, ref);
        } else {
          ref.read(statisticsTimeRangeProvider.notifier).setRange(range);
          ref.invalidate(statisticsProvider);
        }
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Future<void> _showCustomDateRangePicker(BuildContext context, WidgetRef ref) async {
    final timeRangeState = ref.read(statisticsTimeRangeProvider);
    final startDate = timeRangeState.customStartDate ?? DateTime.now().subtract(const Duration(days: 30));
    final endDate = timeRangeState.customEndDate ?? DateTime.now();

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: startDate,
        end: endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      ref.read(statisticsTimeRangeProvider.notifier).setCustomRange(
        pickedRange.start,
        pickedRange.end,
      );
      ref.invalidate(statisticsProvider);
    }
  }

  /// 构建收支概况卡片
  Widget _buildSummaryCard(
    BuildContext context,
    StatisticsResultDTO statistics,
    StatisticsTimeRangeState timeRangeState,
  ) {
    String periodText;
    switch (timeRangeState.range) {
      case StatisticsTimeRange.thisMonth:
        periodText = DateUtils.formatMonth(DateTime.now());
        break;
      case StatisticsTimeRange.lastMonth:
        final lastMonth = DateTime.now().subtract(const Duration(days: 30));
        periodText = DateUtils.formatMonth(lastMonth);
        break;
      case StatisticsTimeRange.thisQuarter:
        periodText = '本季度';
        break;
      case StatisticsTimeRange.thisYear:
        periodText = '${DateTime.now().year}年';
        break;
      case StatisticsTimeRange.custom:
        periodText = '自定义区间';
        break;
    }

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
                  '收支概况',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  periodText,
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
                  '总支出',
                  statistics.totalExpense,
                  Colors.red,
                  Icons.arrow_upward,
                ),
                _buildSummaryItem(
                  '总收入',
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 构建支出构成环形图
  Widget _buildExpensePieChart(
    BuildContext context,
    List<CategoryStatisticsDTO> categoryStatistics,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支出构成',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (categoryStatistics.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无支出数据'),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildPieChartSections(categoryStatistics),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: categoryStatistics.take(5).map((cs) {
                      return _buildLegendItem(
                        cs.categoryName,
                        cs.percentage,
                        _getCategoryColor(categoryStatistics.indexOf(cs)),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    List<CategoryStatisticsDTO> categoryStatistics,
  ) {
    return categoryStatistics.asMap().entries.map((entry) {
      final index = entry.key;
      final cs = entry.value;
      final color = _getCategoryColor(index);

      return PieChartSectionData(
        color: color,
        value: cs.amount,
        title: cs.percentage >= 5 ? '${cs.percentage.toStringAsFixed(0)}%' : '',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegendItem(String name, double percentage, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$name (${percentage.toStringAsFixed(1)}%)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Color _getCategoryColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }

  /// 构建月度支出趋势折线图
  Widget _buildTrendLineChart(
    BuildContext context,
    List<DailyStatisticsDTO> dailyStatistics,
  ) {
    // 按日期排序
    final sortedData = List<DailyStatisticsDTO>.from(dailyStatistics)
      ..sort((a, b) => a.date.compareTo(b.date));

    // 取最近30天数据
    final displayData = sortedData.length > 30 
        ? sortedData.sublist(sortedData.length - 30) 
        : sortedData;

    final maxExpense = displayData.fold<double>(
      0,
      (max, item) => item.expense > max ? item.expense : max,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支出趋势',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxExpense > 0 ? maxExpense / 4 : 1,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: displayData.length > 10 
                            ? (displayData.length / 5).floorToDouble() 
                            : 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= displayData.length) {
                            return const SizedBox.shrink();
                          }
                          final date = displayData[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            MoneyUtils.formatWithoutSymbol(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (displayData.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxExpense > 0 ? maxExpense * 1.2 : 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: displayData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.expense);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分类对比柱状图
  Widget _buildCategoryBarChart(
    BuildContext context,
    List<CategoryStatisticsDTO> categoryStatistics,
  ) {
    // 取前6个分类
    final topCategories = categoryStatistics.take(6).toList();
    final maxAmount = topCategories.isEmpty 
        ? 0.0 
        : topCategories.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分类对比',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (topCategories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无分类数据'),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxAmount > 0 ? maxAmount * 1.2 : 100,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= topCategories.length) {
                              return const SizedBox.shrink();
                            }
                            final name = topCategories[value.toInt()].categoryName;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                name.length > 4 ? '${name.substring(0, 4)}...' : name,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              MoneyUtils.formatWithoutSymbol(value),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 1,
                    ),
                    barGroups: topCategories.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.amount,
                            color: _getCategoryColor(entry.key),
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建Top商户排行
  Widget _buildTopMerchants(
    BuildContext context,
    List<CategoryStatisticsDTO> categoryStatistics,
  ) {
    // 取前5个分类作为Top排行
    final topCategories = categoryStatistics.take(5).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支出排行',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (topCategories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无数据'),
                ),
              )
            else
              Column(
                children: topCategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cs = entry.value;
                  final totalExpense = categoryStatistics.fold<double>(
                    0,
                    (sum, item) => sum + item.amount,
                  );
                  final percentage = totalExpense > 0 
                      ? (cs.amount / totalExpense * 100) 
                      : 0.0;

                  return _buildRankItem(
                    index + 1,
                    cs.categoryName,
                    cs.amount,
                    percentage,
                    _getCategoryColor(index),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankItem(
    int rank,
    String name,
    double amount,
    double percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 排名
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3 ? color : Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 名称
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          // 百分比
          SizedBox(
            width: 60,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // 金额
          Text(
            MoneyUtils.format(amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建智能洞察
  Widget _buildInsights(
    BuildContext context,
    StatisticsResultDTO statistics,
  ) {
    final insights = _generateInsights(statistics);

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  '智能洞察',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// 生成智能洞察
  List<String> _generateInsights(StatisticsResultDTO statistics) {
    final insights = <String>[];

    // 支出占比分析
    if (statistics.categoryStatistics.isNotEmpty) {
      final topCategory = statistics.categoryStatistics.first;
      insights.add(
        '"${topCategory.categoryName}"是您最大的支出类别，占比${topCategory.percentage.toStringAsFixed(1)}%',
      );
    }

    // 收支平衡分析
    if (statistics.totalExpense > 0 && statistics.totalIncome > 0) {
      final savingsRate = (statistics.balance / statistics.totalIncome * 100);
      if (savingsRate >= 30) {
        insights.add('您的储蓄率为${savingsRate.toStringAsFixed(1)}%，储蓄习惯良好！');
      } else if (savingsRate >= 10) {
        insights.add('您的储蓄率为${savingsRate.toStringAsFixed(1)}%，建议适当控制支出。');
      } else if (savingsRate >= 0) {
        insights.add('您的储蓄率为${savingsRate.toStringAsFixed(1)}%，建议制定预算计划。');
      } else {
        insights.add('本期支出超过收入，请注意控制消费。');
      }
    }

    // 每日平均支出
    if (statistics.dailyStatistics.isNotEmpty && statistics.totalExpense > 0) {
      final avgDaily = statistics.totalExpense / statistics.dailyStatistics.length;
      insights.add('日均支出约${MoneyUtils.format(avgDaily)}。');
    }

    // 多样性分析
    if (statistics.categoryStatistics.length >= 5) {
      insights.add('您的消费类别较为丰富，注意合理分配预算。');
    } else if (statistics.categoryStatistics.length > 0 && statistics.categoryStatistics.length < 3) {
      insights.add('消费类别较少，建议关注其他方面的支出。');
    }

    return insights;
  }
}
