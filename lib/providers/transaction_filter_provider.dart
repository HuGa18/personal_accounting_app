import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 交易筛选条件状态
class TransactionFilterState {
  final int page;
  final int pageSize;
  final String? accountId;
  final String? categoryId;
  final String? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? keyword;

  const TransactionFilterState({
    this.page = 1,
    this.pageSize = 20,
    this.accountId,
    this.categoryId,
    this.type,
    this.startDate,
    this.endDate,
    this.keyword,
  });

  /// 默认筛选条件（最近30天）
  factory TransactionFilterState.defaultFilter() {
    final now = DateTime.now();
    return TransactionFilterState(
      page: 1,
      pageSize: 20,
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now,
    );
  }

  TransactionFilterState copyWith({
    int? page,
    int? pageSize,
    String? accountId,
    String? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? keyword,
  }) {
    return TransactionFilterState(
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

  /// 重置为默认值
  TransactionFilterState reset() {
    return TransactionFilterState.defaultFilter();
  }

  /// 是否有筛选条件
  bool get hasFilter {
    return accountId != null ||
        categoryId != null ||
        type != null ||
        startDate != null ||
        endDate != null ||
        (keyword != null && keyword!.isNotEmpty);
  }
}

/// 交易筛选条件 Provider
final transactionFilterProvider = NotifierProvider<TransactionFilterNotifier, TransactionFilterState>(() {
  return TransactionFilterNotifier();
});

/// 交易筛选条件 Notifier
class TransactionFilterNotifier extends Notifier<TransactionFilterState> {
  @override
  TransactionFilterState build() {
    return TransactionFilterState.defaultFilter();
  }

  /// 设置页码
  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  /// 设置每页大小
  void setPageSize(int pageSize) {
    if (pageSize > 100) {
      throw Exception('分页大小不能超过100');
    }
    state = state.copyWith(pageSize: pageSize, page: 1);
  }

  /// 设置账户ID
  void setAccountId(String? accountId) {
    state = state.copyWith(accountId: accountId, page: 1);
  }

  /// 设置分类ID
  void setCategoryId(String? categoryId) {
    state = state.copyWith(categoryId: categoryId, page: 1);
  }

  /// 设置交易类型
  void setType(String? type) {
    state = state.copyWith(type: type, page: 1);
  }

  /// 设置开始日期
  void setStartDate(DateTime? startDate) {
    state = state.copyWith(startDate: startDate, page: 1);
  }

  /// 设置结束日期
  void setEndDate(DateTime? endDate) {
    state = state.copyWith(endDate: endDate, page: 1);
  }

  /// 设置日期范围
  void setDateRange(DateTime? startDate, DateTime? endDate) {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
      page: 1,
    );
  }

  /// 设置关键词
  void setKeyword(String? keyword) {
    state = state.copyWith(keyword: keyword, page: 1);
  }

  /// 重置筛选条件
  void reset() {
    state = TransactionFilterState.defaultFilter();
  }

  /// 清除所有筛选条件
  void clearAll() {
    state = const TransactionFilterState();
  }
}