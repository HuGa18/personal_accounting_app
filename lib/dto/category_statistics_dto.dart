/// 分类统计
class CategoryStatisticsDTO {
  final String categoryId;
  final String categoryName;
  final double amount;
  final double percentage;

  const CategoryStatisticsDTO({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });

  factory CategoryStatisticsDTO.fromJson(Map<String, dynamic> json) {
    return CategoryStatisticsDTO(
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'amount': amount,
      'percentage': percentage,
    };
  }

  CategoryStatisticsDTO copyWith({
    String? categoryId,
    String? categoryName,
    double? amount,
    double? percentage,
  }) {
    return CategoryStatisticsDTO(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
    );
  }

  @override
  String toString() {
    return 'CategoryStatisticsDTO(categoryId: $categoryId, categoryName: $categoryName, amount: $amount, percentage: $percentage)';
  }
}
