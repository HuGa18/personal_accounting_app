import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../repositories/budget_repository.dart';

/// 预算仓库 Provider
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

/// 预算列表 Provider
/// 使用 AsyncNotifierProvider 管理异步状态
final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(() {
  return BudgetsNotifier();
});

/// 预算列表 Notifier
class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() async {
    final repository = ref.read(budgetRepositoryProvider);
    return repository.getAll();
  }

  /// 添加预算
  Future<void> add(Budget budget) async {
    if (budget.amount <= 0) {
      throw Exception('预算金额必须大于0');
    }
    
    final repository = ref.read(budgetRepositoryProvider);
    await repository.insert(budget);
    ref.invalidateSelf();
  }

  /// 更新预算
  Future<void> update(Budget budget) async {
    if (budget.amount <= 0) {
      throw Exception('预算金额必须大于0');
    }
    
    final repository = ref.read(budgetRepositoryProvider);
    await repository.update(budget);
    ref.invalidateSelf();
  }

  /// 删除预算（逻辑删除）
  Future<void> delete(String id) async {
    final repository = ref.read(budgetRepositoryProvider);
    await repository.delete(id);
    ref.invalidateSelf();
  }

  /// 按分类ID获取预算
  Future<List<Budget>> getByCategoryId(String categoryId) async {
    final repository = ref.read(budgetRepositoryProvider);
    return repository.getByCategoryId(categoryId);
  }

  /// 刷新预算列表
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// 单个预算 Provider
final budgetProvider = FutureProvider.family<Budget?, String>((ref, id) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.getById(id);
});

/// 按分类筛选的预算 Provider
final budgetsByCategoryProvider = FutureProvider.family<List<Budget>, String>((ref, categoryId) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.getByCategoryId(categoryId);
});