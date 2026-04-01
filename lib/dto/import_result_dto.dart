import '../models/transaction.dart';

/// 导入结果
class ImportResultDTO {
  final int totalCount;
  final int successCount;
  final int failedCount;
  final List<String> errors;
  final List<Transaction> transactions;

  const ImportResultDTO({
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.errors,
    required this.transactions,
  });

  factory ImportResultDTO.fromJson(Map<String, dynamic> json) {
    return ImportResultDTO(
      totalCount: json['totalCount'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      failedCount: json['failedCount'] as int? ?? 0,
      errors: (json['errors'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      transactions: (json['transactions'] as List?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCount': totalCount,
      'successCount': successCount,
      'failedCount': failedCount,
      'errors': errors,
      'transactions': transactions.map((e) => e.toJson()).toList(),
    };
  }

  ImportResultDTO copyWith({
    int? totalCount,
    int? successCount,
    int? failedCount,
    List<String>? errors,
    List<Transaction>? transactions,
  }) {
    return ImportResultDTO(
      totalCount: totalCount ?? this.totalCount,
      successCount: successCount ?? this.successCount,
      failedCount: failedCount ?? this.failedCount,
      errors: errors ?? this.errors,
      transactions: transactions ?? this.transactions,
    );
  }

  /// 是否全部成功
  bool get isAllSuccess => failedCount == 0 && totalCount > 0;

  /// 成功率
  double get successRate =>
      totalCount > 0 ? successCount / totalCount * 100 : 0.0;

  @override
  String toString() {
    return 'ImportResultDTO(totalCount: $totalCount, successCount: $successCount, failedCount: $failedCount)';
  }
}
