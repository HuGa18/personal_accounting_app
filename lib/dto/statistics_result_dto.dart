import 'category_statistics_dto.dart';
import 'daily_statistics_dto.dart';

/// 统计数据结果
class StatisticsResultDTO {
  final double totalExpense;
  final double totalIncome;
  final double balance;
  final List<CategoryStatisticsDTO> categoryStatistics;
  final List<DailyStatisticsDTO> dailyStatistics;

  const StatisticsResultDTO({
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    required this.categoryStatistics,
    required this.dailyStatistics,
  });

  factory StatisticsResultDTO.fromJson(Map<String, dynamic> json) {
    return StatisticsResultDTO(
      totalExpense: (json['totalExpense'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      categoryStatistics: (json['categoryStatistics'] as List?)
              ?.map((e) => CategoryStatisticsDTO.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dailyStatistics: (json['dailyStatistics'] as List?)
              ?.map((e) => DailyStatisticsDTO.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalExpense': totalExpense,
      'totalIncome': totalIncome,
      'balance': balance,
      'categoryStatistics': categoryStatistics.map((e) => e.toJson()).toList(),
      'dailyStatistics': dailyStatistics.map((e) => e.toJson()).toList(),
    };
  }

  StatisticsResultDTO copyWith({
    double? totalExpense,
    double? totalIncome,
    double? balance,
    List<CategoryStatisticsDTO>? categoryStatistics,
    List<DailyStatisticsDTO>? dailyStatistics,
  }) {
    return StatisticsResultDTO(
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
      balance: balance ?? this.balance,
      categoryStatistics: categoryStatistics ?? this.categoryStatistics,
      dailyStatistics: dailyStatistics ?? this.dailyStatistics,
    );
  }

  @override
  String toString() {
    return 'StatisticsResultDTO(totalExpense: $totalExpense, totalIncome: $totalIncome, balance: $balance)';
  }
}
