import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

/// 分类仓库 Provider
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

/// 分类列表 Provider
/// 使用 AsyncNotifierProvider 管理异步状态
final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, List<Category>>(() {
  return CategoriesNotifier();
});

/// 分类列表 Notifier
class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final repository = ref.read(categoryRepositoryProvider);
    return repository.getAll();
  }

  /// 添加分类
  Future<void> add(Category category) async {
    final repository = ref.read(categoryRepositoryProvider);
    await repository.insert(category);
    ref.invalidateSelf();
  }

  /// 更新分类
  Future<void> updateItem(Category category) async {
    final repository = ref.read(categoryRepositoryProvider);
    await repository.update(category);
    ref.invalidateSelf();
  }

  /// 删除分类（逻辑删除）
  Future<void> delete(String id) async {
    final repository = ref.read(categoryRepositoryProvider);
    await repository.delete(id);
    ref.invalidateSelf();
  }

  /// 根据父级ID获取子分类
  Future<List<Category>> getByParentId(String parentId) async {
    final repository = ref.read(categoryRepositoryProvider);
    return repository.getByParentId(parentId);
  }

  /// 根据商户名称匹配分类
  Future<Category?> matchCategory(String merchantName) async {
    final repository = ref.read(categoryRepositoryProvider);
    return repository.matchCategory(merchantName);
  }

  /// 刷新分类列表
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// 单个分类 Provider
final categoryProvider = FutureProvider.family<Category?, String>((ref, id) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getById(id);
});

/// 按类型筛选的分类列表 Provider
final categoriesByTypeProvider = FutureProvider.family<List<Category>, String>((ref, type) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getAll(type: type);
});

/// 支出分类 Provider
final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getAll(type: 'expense');
});

/// 收入分类 Provider
final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getAll(type: 'income');
});