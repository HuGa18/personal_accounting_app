class Account {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0.0,
    this.currency = 'CNY',
    this.color,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Account.fromJson(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      balance: (map['balance'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'CNY',
      color: map['color'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    String? currency,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}