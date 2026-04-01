class Budget {
  final String id;
  final String categoryId;
  final double amount;
  final String period;
  final int startDay;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    this.startDay = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'period': period,
      'start_day': startDay,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      categoryId: map['category_id'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      period: map['period'],
      startDay: map['start_day'] ?? 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    String? period,
    int? startDay,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDay: startDay ?? this.startDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}