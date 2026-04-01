import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../dto/statistics_result_dto.dart';
import '../dto/category_statistics_dto.dart';
import '../dto/daily_statistics_dto.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/category_repository.dart';
import 'transactions_provider.dart';
import 'categories_provider.dart';

/// 统计仓库 Provider
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository();
});

/// 统计数据仓库
class StatisticsRepository {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();

  /// 计算统计数据
  Future<StatisticsResultDTO> calculateStatistics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 获取日期范围内的所有交易
    final transactions = await _transactionRepository.getByDateRange(
      startDate: startDate,
      endDate: endDate,
    );

    // 获取所有分类（批量查询，避免N+1问题）
    final categories = await _categoryRepository.getAll();
    final categoryMap = <String, Category>{};
    for (var category in categories) {
      categoryMap[category.id] = category;
    }

    // 计算总支出和总收入
    double totalExpense = 0;
    double totalIncome = 0;
    final categoryAmounts = <String, double>{};
    final dailyExpenses = <String, double>{};
    final dailyIncomes = <String, double>{};

    for (var tx in transactions) {
      final dateKey = _formatDate(tx.transactionDate);
      
      if (tx.type == 'expense') {
        totalExpense += tx.amount;
        
        // 分类统计
        if (tx.categoryId != null) {
          categoryAmounts[tx.categoryId!] = 
              (categoryAmounts[tx.categoryId!] ?? 0) + tx.amount;
        }
        
        // 每日统计
        dailyExpenses[dateKey] = (dailyExpenses[dateKey] ?? 0) + tx.amount;
      } else if (tx.type == 'income') {
        totalIncome += tx.amount;
        dailyIncomes[dateKey] = (dailyIncomes[dateKey] ?? 0) + tx.amount;
      }
    }

    // 构建分类统计列表
    final categoryStatistics = <CategoryStatisticsDTO>[];
    for (var entry in categoryAmounts.entries) {
      final category = categoryMap[entry.key];
      categoryStatistics.add(CategoryStatisticsDTO(
        categoryId: entry.key,
        categoryName: category?.name ?? '未知分类',
        amount: entry.value,
        percentage: totalExpense > 0 ? (entry.value / totalExpense * 100) : 0,
      ));
    }
    
    // 按金额降序排序
    categoryStatistics.sort((a, b) => b.amount.compareTo(a.amount));

    // 构建每日统计列表
    final dailyStatistics = <DailyStatisticsDTO>[];
    final allDates = <String>{...dailyExpenses.keys, ...dailyIncomes.keys};
    final sortedDates = allDates.toList()..sort();
    
    for (var date in sortedDates) {
      dailyStatistics.add(DailyStatisticsDTO(
        date: DateTime.parse(date),
        expense: dailyExpenses[date] ?? 0,
        income: dailyIncomes[date] ?? 0,
      ));
    }

    return StatisticsResultDTO(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      balance: totalIncome - totalExpense,
      categoryStatistics: categoryStatistics,
      dailyStatistics: dailyStatistics,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 统计时间范围
enum StatisticsTimeRange {
  thisMonth,
  lastMonth,
  thisQuarter,
  thisYear,
  custom,
}

/// 统计时间范围状态
class StatisticsTimeRangeState {
  final StatisticsTimeRange range;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const StatisticsTimeRangeState({
    this.range = StatisticsTimeRange.thisMonth,
    this.customStartDate,
    this.customEndDate,
  });

  /// 获取开始日期
  DateTime get startDate {
    final now = DateTime.now();
    switch (range) {
      case StatisticsTimeRange.thisMonth:
        return DateTime(now.year, now.month, 1);
      case StatisticsTimeRange.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1);
        return DateTime(lastMonth.year, lastMonth.month, 1);
      case StatisticsTimeRange.thisQuarter:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterStartMonth, 1);
      case StatisticsTimeRange.thisYear:
        return DateTime(now.year, 1, 1);
      case StatisticsTimeRange.custom:
        return customStartDate ?? DateTime(now.year, now.month, 1);
    }
  }

  /// 获取结束日期
  DateTime get endDate {
    final now = DateTime.now();
    switch (range) {
      case StatisticsTimeRange.thisMonth:
        return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case StatisticsTimeRange.lastMonth:
        return DateTime(now.year, now.month, 0, 23, 59, 59);
      case StatisticsTimeRange.thisQuarter:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterStartMonth + 3, 0, 23, 59, 59);
      case StatisticsTimeRange.thisYear:
        return DateTime(now.year, 12, 31, 23, 59, 59);
      case StatisticsTimeRange.custom:
        return customEndDate ?? now;
    }
  }

  StatisticsTimeRangeState copyWith({
    StatisticsTimeRange? range,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) {
    return StatisticsTimeRangeState(
      range: range ?? this.range,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
    );
  }
}

/// 统计时间范围 Provider
final statisticsTimeRangeProvider = NotifierProvider<StatisticsTimeRangeNotifier, StatisticsTimeRangeState>(() {
  return StatisticsTimeRangeNotifier();
});

/// 统计时间范围 Notifier
class StatisticsTimeRangeNotifier extends Notifier<StatisticsTimeRangeState> {
  @override
  StatisticsTimeRangeState build() {
    return const StatisticsTimeRangeState();
  }

  /// 设置时间范围
  void setRange(StatisticsTimeRange range) {
    state = state.copyWith(range: range);
  }

  /// 设置自定义时间范围
  void setCustomRange(DateTime startDate, DateTime endDate) {
    state = state.copyWith(
      range: StatisticsTimeRange.custom,
      customStartDate: startDate,
      customEndDate: endDate,
    );
  }
}

/// 统计数据 Provider
final statisticsProvider = FutureProvider<StatisticsResultDTO>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final timeRangeState = ref.watch(statisticsTimeRangeProvider);
  
  return repository.calculateStatistics(
    startDate: timeRangeState.startDate,
    endDate: timeRangeState.endDate,
  );
});

/// 本月统计 Provider
final thisMonthStatisticsProvider = FutureProvider<StatisticsResultDTO>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, 1);
  final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  return repository.calculateStatistics(
    startDate: startDate,
    endDate: endDate,
  );
});

/// 近7天统计 Provider
final last7DaysStatisticsProvider = FutureProvider<StatisticsResultDTO>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final now = DateTime.now();
  final startDate = now.subtract(const Duration(days: 7));
  
  return repository.calculateStatistics(
    startDate: startDate,
    endDate: now,
  );
});