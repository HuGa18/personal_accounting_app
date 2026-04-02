import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import 'transaction_filter_provider.dart';

/// 交易仓库 Provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// 交易列表 Provider
/// 使用 AsyncNotifierProvider 管理异步状态
final transactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(() {
  return TransactionsNotifier();
});

/// 交易列表 Notifier
class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    final repository = ref.read(transactionRepositoryProvider);
    final filter = ref.watch(transactionFilterProvider);
    
    return repository.getByPage(
      page: filter.page,
      pageSize: filter.pageSize,
      accountId: filter.accountId,
      categoryId: filter.categoryId,
      type: filter.type,
      startDate: filter.startDate,
      endDate: filter.endDate,
    );
  }

  /// 添加交易
  Future<void> add(Transaction transaction) async {
    if (transaction.amount <= 0) {
      throw Exception('交易金额必须大于0');
    }
    
    final repository = ref.read(transactionRepositoryProvider);
    await repository.insert(transaction);
    ref.invalidateSelf();
  }

  /// 批量添加交易
  Future<void> addBatch(List<Transaction> transactions) async {
    if (transactions.isEmpty) {
      return;
    }
    
    // 验证所有交易金额
    for (var tx in transactions) {
      if (tx.amount <= 0) {
        throw Exception('交易金额必须大于0');
      }
    }
    
    final repository = ref.read(transactionRepositoryProvider);
    await repository.insertBatch(transactions);
    ref.invalidateSelf();
  }

  /// 更新交易
  Future<void> updateTransaction(Transaction transaction) async {
    if (transaction.amount <= 0) {
      throw Exception('交易金额必须大于0');
    }
    
    final repository = ref.read(transactionRepositoryProvider);
    await repository.update(transaction);
    ref.invalidateSelf();
  }

  /// 删除交易（逻辑删除）
  Future<void> delete(String id) async {
    final repository = ref.read(transactionRepositoryProvider);
    await repository.delete(id);
    ref.invalidateSelf();
  }

  /// 按账户查询
  Future<List<Transaction>> getByAccountId(String accountId) async {
    final repository = ref.read(transactionRepositoryProvider);
    return repository.getByAccountId(accountId);
  }

  /// 按分类查询
  Future<List<Transaction>> getByCategoryId(String categoryId) async {
    final repository = ref.read(transactionRepositoryProvider);
    return repository.getByCategoryId(categoryId);
  }

  /// 按日期范围查询
  Future<List<Transaction>> getByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final repository = ref.read(transactionRepositoryProvider);
    return repository.getByDateRange(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// 分页查询
  Future<List<Transaction>> getByPage({
    required int page,
    required int pageSize,
    String? accountId,
    String? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (pageSize > 100) {
      throw Exception('分页大小不能超过100');
    }
    
    final repository = ref.read(transactionRepositoryProvider);
    return repository.getByPage(
      page: page,
      pageSize: pageSize,
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// 刷新交易列表
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// 单个交易 Provider
final transactionProvider = FutureProvider.family<Transaction?, String>((ref, id) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getById(id);
});

/// 按账户筛选的交易列表 Provider
final transactionsByAccountProvider = FutureProvider.family<List<Transaction>, String>((ref, accountId) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getByAccountId(accountId);
});

/// 按分类筛选的交易列表 Provider
final transactionsByCategoryProvider = FutureProvider.family<List<Transaction>, String>((ref, categoryId) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getByCategoryId(categoryId);
});