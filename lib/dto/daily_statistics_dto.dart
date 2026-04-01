/// 每日统计
class DailyStatisticsDTO {
  final DateTime date;
  final double expense;
  final double income;

  const DailyStatisticsDTO({
    required this.date,
    required this.expense,
    required this.income,
  });

  factory DailyStatisticsDTO.fromJson(Map<String, dynamic> json) {
    return DailyStatisticsDTO(
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'expense': expense,
      'income': income,
    };
  }

  DailyStatisticsDTO copyWith({
    DateTime? date,
    double? expense,
    double? income,
  }) {
    return DailyStatisticsDTO(
      date: date ?? this.date,
      expense: expense ?? this.expense,
      income: income ?? this.income,
    );
  }

  @override
  String toString() {
    return 'DailyStatisticsDTO(date: $date, expense: $expense, income: $income)';
  }
}
