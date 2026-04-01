class Transaction {
  final String id;
  final String accountId;
  final String type;
  final double amount;
  final String? categoryId;
  final String? subCategoryId;
  final String? merchantName;
  final String? description;
  final DateTime transactionDate;
  final String? source;
  final String? location;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Transaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    this.categoryId,
    this.subCategoryId,
    this.merchantName,
    this.description,
    required this.transactionDate,
    this.source,
    this.location,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'merchant_name': merchantName,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'source': source,
      'location': location,
      'tags': tags.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      accountId: map['account_id'],
      type: map['type'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      categoryId: map['category_id'],
      subCategoryId: map['sub_category_id'],
      merchantName: map['merchant_name'],
      description: map['description'],
      transactionDate: DateTime.parse(map['transaction_date']),
      source: map['source'],
      location: map['location'],
      tags: map['tags'] != null && map['tags'].toString().isNotEmpty
          ? map['tags'].toString().split(',')
          : [],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Transaction copyWith({
    String? id,
    String? accountId,
    String? type,
    double? amount,
    String? categoryId,
    String? subCategoryId,
    String? merchantName,
    String? description,
    DateTime? transactionDate,
    String? source,
    String? location,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      merchantName: merchantName ?? this.merchantName,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      source: source ?? this.source,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}