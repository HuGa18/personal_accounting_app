import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../repositories/account_repository.dart';

/// 账户仓库 Provider
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository();
});

/// 账户列表 Provider
/// 使用 AsyncNotifierProvider 管理异步状态
final accountsProvider = AsyncNotifierProvider<AccountsNotifier, List<Account>>(() {
  return AccountsNotifier();
});

/// 账户列表 Notifier
class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final repository = ref.read(accountRepositoryProvider);
    return repository.getAll();
  }

  /// 添加账户
  Future<void> add(Account account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(accountRepositoryProvider);
      await repository.insert(account);
      return repository.getAll();
    });
  }

  /// 更新账户
  Future<void> update(Account account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(accountRepositoryProvider);
      await repository.update(account);
      return repository.getAll();
    });
  }

  /// 更新账户余额
  Future<void> updateBalance(String id, double balance) async {
    final repository = ref.read(accountRepositoryProvider);
    final account = await repository.getById(id);
    
    if (account == null) {
      throw Exception('账户不存在');
    }
    
    await repository.update(account.copyWith(
      balance: balance,
      updatedAt: DateTime.now(),
    ));
    
    // 刷新列表
    ref.invalidateSelf();
  }

  /// 删除账户（逻辑删除）
  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(accountRepositoryProvider);
      await repository.delete(id);
      return repository.getAll();
    });
  }

  /// 刷新账户列表
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// 单个账户 Provider
final accountProvider = FutureProvider.family<Account?, String>((ref, id) async {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getById(id);
});