import '../models/transaction.dart';

/// 交易表单数据
class TransactionFormDTO {
  final String? id;
  final String accountId;
  final String type;
  final double amount;
  final String categoryId;
  final String? subCategoryId;
  final String merchantName;
  final String? description;
  final DateTime transactionDate;
  final List<String> tags;

  const TransactionFormDTO({
    this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.subCategoryId,
    required this.merchantName,
    this.description,
    required this.transactionDate,
    this.tags = const [],
  });

  factory TransactionFormDTO.fromJson(Map<String, dynamic> json) {
    return TransactionFormDTO(
      id: json['id'] as String?,
      accountId: json['accountId'] as String? ?? '',
      type: json['type'] as String? ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId'] as String? ?? '',
      subCategoryId: json['subCategoryId'] as String?,
      merchantName: json['merchantName'] as String? ?? '',
      description: json['description'] as String?,
      transactionDate: json['transactionDate'] != null
          ? DateTime.parse(json['transactionDate'] as String)
          : DateTime.now(),
      tags: (json['tags'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'subCategoryId': subCategoryId,
      'merchantName': merchantName,
      'description': description,
      'transactionDate': transactionDate.toIso8601String(),
      'tags': tags,
    };
  }

  TransactionFormDTO copyWith({
    String? id,
    String? accountId,
    String? type,
    double? amount,
    String? categoryId,
    String? subCategoryId,
    String? merchantName,
    String? description,
    DateTime? transactionDate,
    List<String>? tags,
  }) {
    return TransactionFormDTO(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      merchantName: merchantName ?? this.merchantName,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      tags: tags ?? this.tags,
    );
  }

  /// 验证表单数据
  String? validate() {
    if (amount <= 0) {
      return '金额必须大于0';
    }
    if (merchantName.isEmpty) {
      return '商户名称不能为空';
    }
    if (accountId.isEmpty) {
      return '请选择账户';
    }
    if (categoryId.isEmpty) {
      return '请选择分类';
    }
    return null;
  }

  /// 转换为 Transaction Model
  Transaction toModel({String? newId}) {
    return Transaction(
      id: newId ?? id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: accountId,
      type: type,
      amount: amount,
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      merchantName: merchantName,
      description: description,
      transactionDate: transactionDate,
      source: 'manual',
      tags: tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 从 Transaction Model 创建
  factory TransactionFormDTO.fromModel(Transaction transaction) {
    return TransactionFormDTO(
      id: transaction.id,
      accountId: transaction.accountId,
      type: transaction.type,
      amount: transaction.amount,
      categoryId: transaction.categoryId ?? '',
      subCategoryId: transaction.subCategoryId,
      merchantName: transaction.merchantName ?? '',
      description: transaction.description,
      transactionDate: transaction.transactionDate,
      tags: transaction.tags,
    );
  }

  @override
  String toString() {
    return 'TransactionFormDTO(id: $id, accountId: $accountId, type: $type, amount: $amount, merchantName: $merchantName)';
  }
}
