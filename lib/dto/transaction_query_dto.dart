import '../enums/transaction_type.dart';

/// 交易查询条件
class TransactionQueryDTO {
  final int page;
  final int pageSize;
  final String? accountId;
  final String? categoryId;
  final String? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? keyword;

  const TransactionQueryDTO({
    this.page = 1,
    this.pageSize = 20,
    this.accountId,
    this.categoryId,
    this.type,
    this.startDate,
    this.endDate,
    this.keyword,
  });

  factory TransactionQueryDTO.fromJson(Map<String, dynamic> json) {
    return TransactionQueryDTO(
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      accountId: json['accountId'] as String?,
      categoryId: json['categoryId'] as String?,
      type: json['type'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      keyword: json['keyword'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'pageSize': pageSize,
      'accountId': accountId,
      'categoryId': categoryId,
      'type': type,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'keyword': keyword,
    };
  }

  TransactionQueryDTO copyWith({
    int? page,
    int? pageSize,
    String? accountId,
    String? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? keyword,
  }) {
    return TransactionQueryDTO(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      keyword: keyword ?? this.keyword,
    );
  }

  @override
  String toString() {
    return 'TransactionQueryDTO(page: $page, pageSize: $pageSize, accountId: $accountId, categoryId: $categoryId, type: $type, keyword: $keyword)';
  }
}
