import 'package:sqflite/sqflite.dart';
import '../database/db.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../utils/id_utils.dart';

/// 用户选择记录（用于学习用户习惯）
class UserSelectionRecord {
  final String id;
  final String merchantName;
  final String categoryId;
  final int selectionCount;
  final DateTime lastSelectedAt;
  final DateTime createdAt;

  UserSelectionRecord({
    required this.id,
    required this.merchantName,
    required this.categoryId,
    this.selectionCount = 1,
    required this.lastSelectedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_name': merchantName,
      'category_id': categoryId,
      'selection_count': selectionCount,
      'last_selected_at': lastSelectedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserSelectionRecord.fromJson(Map<String, dynamic> map) {
    return UserSelectionRecord(
      id: map['id'],
      merchantName: map['merchant_name'],
      categoryId: map['category_id'],
      selectionCount: map['selection_count'] ?? 1,
      lastSelectedAt: DateTime.parse(map['last_selected_at']),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  UserSelectionRecord copyWith({
    String? id,
    String? merchantName,
    String? categoryId,
    int? selectionCount,
    DateTime? lastSelectedAt,
    DateTime? createdAt,
  }) {
    return UserSelectionRecord(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      categoryId: categoryId ?? this.categoryId,
      selectionCount: selectionCount ?? this.selectionCount,
      lastSelectedAt: lastSelectedAt ?? this.lastSelectedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 分类匹配结果
class CategoryMatchResult {
  final Category? category;
  final double score;
  final String matchType; // 'keyword', 'user_history', 'default'
  final String? matchedKeyword;

  CategoryMatchResult({
    this.category,
    required this.score,
    required this.matchType,
    this.matchedKeyword,
  });
}

/// 智能分类服务
/// 
/// 功能：
/// - 基于关键词匹配算法智能推荐分类
/// - 学习用户选择习惯，优化推荐准确性
/// - 内置完善的二级分类体系
class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final CategoryRepository _categoryRepository = CategoryRepository();
  
  /// 关键词匹配权重
  static const double _keywordMatchWeight = 1.0;
  static const double _userHistoryWeight = 2.0;
  static const double _recentUsageWeight = 0.5;
  
  /// 最低匹配分数阈值
  static const double _minScoreThreshold = 0.3;

  /// 初始化用户选择记录表
  Future<void> initUserSelectionTable() async {
    final db = await DatabaseHelper.instance.database;
    
    // 检查表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='user_selections'"
    );
    
    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE user_selections (
          id TEXT PRIMARY KEY,
          merchant_name TEXT NOT NULL,
          category_id TEXT NOT NULL,
          selection_count INTEGER DEFAULT 1,
          last_selected_at TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_user_selections_merchant ON user_selections(merchant_name)');
      await db.execute('CREATE INDEX idx_user_selections_category ON user_selections(category_id)');
    }
  }

  /// 根据商户名称推荐分类
  /// 
  /// 算法优先级：
  /// 1. 用户历史选择（权重最高）
  /// 2. 关键词匹配
  /// 3. 默认分类
  Future<CategoryMatchResult> recommendCategory(
    String merchantName, {
    String? type,
  }) async {
    await initUserSelectionTable();
    
    if (merchantName.trim().isEmpty) {
      return _getDefaultCategory(type ?? 'expense');
    }

    final normalizedName = _normalizeMerchantName(merchantName);
    
    // 1. 首先检查用户历史选择
    final userHistoryResult = await _matchFromUserHistory(normalizedName);
    if (userHistoryResult != null && userHistoryResult.score >= _minScoreThreshold) {
      return userHistoryResult;
    }

    // 2. 关键词匹配
    final keywordResult = await _matchFromKeywords(normalizedName, type);
    if (keywordResult != null && keywordResult.score >= _minScoreThreshold) {
      // 如果有用户历史记录，增加权重
      if (userHistoryResult != null) {
        return CategoryMatchResult(
          category: keywordResult.category,
          score: keywordResult.score + userHistoryResult.score * 0.5,
          matchType: 'keyword_with_history',
          matchedKeyword: keywordResult.matchedKeyword,
        );
      }
      return keywordResult;
    }

    // 3. 返回默认分类
    return _getDefaultCategory(type ?? 'expense');
  }

  /// 从用户历史选择中匹配
  Future<CategoryMatchResult?> _matchFromUserHistory(String merchantName) async {
    final db = await DatabaseHelper.instance.database;
    
    // 精确匹配商户名称
    final exactMatch = await db.query(
      'user_selections',
      where: 'merchant_name = ?',
      whereArgs: [merchantName],
      orderBy: 'selection_count DESC, last_selected_at DESC',
      limit: 1,
    );

    if (exactMatch.isNotEmpty) {
      final record = UserSelectionRecord.fromJson(exactMatch.first);
      final category = await _categoryRepository.getById(record.categoryId);
      
      if (category != null) {
        // 根据选择次数和时间衰减计算分数
        final daysSinceLastSelection = DateTime.now()
            .difference(record.lastSelectedAt)
            .inDays;
        final timeDecay = 1.0 / (1.0 + daysSinceLastSelection * 0.1);
        final countBoost = 1.0 + (record.selectionCount * 0.1);
        
        return CategoryMatchResult(
          category: category,
          score: _userHistoryWeight * timeDecay * countBoost,
          matchType: 'user_history',
        );
      }
    }

    // 模糊匹配（包含关系）
    final fuzzyMatches = await db.query(
      'user_selections',
      where: 'merchant_name LIKE ?',
      whereArgs: ['%$merchantName%'],
      orderBy: 'selection_count DESC, last_selected_at DESC',
      limit: 5,
    );

    if (fuzzyMatches.isNotEmpty) {
      for (var match in fuzzyMatches) {
        final record = UserSelectionRecord.fromJson(match);
        final category = await _categoryRepository.getById(record.categoryId);
        
        if (category != null) {
          final daysSinceLastSelection = DateTime.now()
              .difference(record.lastSelectedAt)
              .inDays;
          final timeDecay = 1.0 / (1.0 + daysSinceLastSelection * 0.1);
          final countBoost = 1.0 + (record.selectionCount * 0.1);
          
          // 模糊匹配分数降低
          return CategoryMatchResult(
            category: category,
            score: _userHistoryWeight * timeDecay * countBoost * 0.8,
            matchType: 'user_history_fuzzy',
          );
        }
      }
    }

    return null;
  }

  /// 从关键词匹配分类
  Future<CategoryMatchResult?> _matchFromKeywords(String merchantName, String? type) async {
    final categories = await _categoryRepository.getAll(type: type);
    
    Category? bestMatch;
    double bestScore = 0;
    String? matchedKeyword;

    for (var category in categories) {
      if (category.keywords.isEmpty) continue;

      for (var keyword in category.keywords) {
        final score = _calculateKeywordScore(merchantName, keyword);
        
        if (score > bestScore) {
          bestScore = score;
          bestMatch = category;
          matchedKeyword = keyword;
        }
      }
    }

    if (bestMatch != null) {
      return CategoryMatchResult(
        category: bestMatch,
        score: _keywordMatchWeight * bestScore,
        matchType: 'keyword',
        matchedKeyword: matchedKeyword,
      );
    }

    return null;
  }

  /// 计算关键词匹配分数
  double _calculateKeywordScore(String merchantName, String keyword) {
    if (keyword.isEmpty) return 0;
    
    final normalizedKeyword = keyword.toLowerCase();
    final normalizedName = merchantName.toLowerCase();
    
    // 完全匹配
    if (normalizedName == normalizedKeyword) {
      return 1.0;
    }
    
    // 包含匹配
    if (normalizedName.contains(normalizedKeyword)) {
      // 根据关键词长度计算分数，长关键词更精确
      return 0.5 + (keyword.length / merchantName.length) * 0.5;
    }
    
    // 部分匹配（关键词的前几个字符）
    if (normalizedKeyword.length >= 2) {
      final prefix = normalizedKeyword.substring(0, normalizedKeyword.length ~/ 2);
      if (normalizedName.contains(prefix)) {
        return 0.3;
      }
    }

    return 0;
  }

  /// 获取默认分类
  Future<CategoryMatchResult> _getDefaultCategory(String type) async {
    final categories = await _categoryRepository.getAll(type: type);
    
    // 查找"其他"分类
    final defaultCategory = categories.firstWhere(
      (c) => c.name.contains('其他'),
      orElse: () => categories.first,
    );

    return CategoryMatchResult(
      category: defaultCategory,
      score: 0.1,
      matchType: 'default',
    );
  }

  /// 记录用户选择的分类（用于学习）
  Future<void> recordUserSelection(String merchantName, String categoryId) async {
    await initUserSelectionTable();
    
    final db = await DatabaseHelper.instance.database;
    final normalizedName = _normalizeMerchantName(merchantName);
    
    // 检查是否已存在
    final existing = await db.query(
      'user_selections',
      where: 'merchant_name = ? AND category_id = ?',
      whereArgs: [normalizedName, categoryId],
    );

    final now = DateTime.now();

    if (existing.isNotEmpty) {
      // 更新选择次数和最后选择时间
      final record = UserSelectionRecord.fromJson(existing.first);
      await db.update(
        'user_selections',
        {
          'selection_count': record.selectionCount + 1,
          'last_selected_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [record.id],
      );
    } else {
      // 插入新记录
      await db.insert('user_selections', {
        'id': IdUtils.generateWithPrefix('us_'),
        'merchant_name': normalizedName,
        'category_id': categoryId,
        'selection_count': 1,
        'last_selected_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    }
  }

  /// 获取商户的历史选择记录
  Future<List<UserSelectionRecord>> getMerchantHistory(String merchantName) async {
    await initUserSelectionTable();
    
    final db = await DatabaseHelper.instance.database;
    final normalizedName = _normalizeMerchantName(merchantName);
    
    final results = await db.query(
      'user_selections',
      where: 'merchant_name LIKE ?',
      whereArgs: ['%$normalizedName%'],
      orderBy: 'selection_count DESC, last_selected_at DESC',
      limit: 10,
    );

    return results.map((map) => UserSelectionRecord.fromJson(map)).toList();
  }

  /// 获取分类的推荐商户列表
  Future<List<String>> getMerchantsForCategory(String categoryId) async {
    await initUserSelectionTable();
    
    final db = await DatabaseHelper.instance.database;
    
    final results = await db.query(
      'user_selections',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'selection_count DESC',
      limit: 20,
    );

    return results.map((map) => map['merchant_name'] as String).toList();
  }

  /// 清除用户选择历史
  Future<void> clearUserSelectionHistory() async {
    await initUserSelectionTable();
    
    final db = await DatabaseHelper.instance.database;
    await db.delete('user_selections');
  }

  /// 删除特定商户的选择历史
  Future<void> deleteMerchantHistory(String merchantName) async {
    await initUserSelectionTable();
    
    final db = await DatabaseHelper.instance.database;
    final normalizedName = _normalizeMerchantName(merchantName);
    
    await db.delete(
      'user_selections',
      where: 'merchant_name = ?',
      whereArgs: [normalizedName],
    );
  }

  /// 标准化商户名称
  String _normalizeMerchantName(String merchantName) {
    // 移除空格、特殊字符，转小写
    return merchantName
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  /// 批量推荐分类
  Future<Map<String, CategoryMatchResult>> batchRecommendCategories(
    List<String> merchantNames, {
    String? type,
  }) async {
    final results = <String, CategoryMatchResult>{};
    
    for (var merchantName in merchantNames) {
      results[merchantName] = await recommendCategory(merchantName, type: type);
    }
    
    return results;
  }

  /// 获取推荐分类（带多个候选）
  Future<List<CategoryMatchResult>> getTopCategoryRecommendations(
    String merchantName, {
    String? type,
    int limit = 3,
  }) async {
    await initUserSelectionTable();
    
    final results = <CategoryMatchResult>[];
    final normalizedName = _normalizeMerchantName(merchantName);
    
    // 获取用户历史匹配
    final userHistory = await getMerchantHistory(merchantName);
    for (var record in userHistory.take(limit)) {
      final category = await _categoryRepository.getById(record.categoryId);
      if (category != null) {
        final daysSinceLastSelection = DateTime.now()
            .difference(record.lastSelectedAt)
            .inDays;
        final timeDecay = 1.0 / (1.0 + daysSinceLastSelection * 0.1);
        final countBoost = 1.0 + (record.selectionCount * 0.1);
        
        results.add(CategoryMatchResult(
          category: category,
          score: _userHistoryWeight * timeDecay * countBoost,
          matchType: 'user_history',
        ));
      }
    }
    
    // 获取关键词匹配
    final categories = await _categoryRepository.getAll(type: type);
    for (var category in categories) {
      if (results.any((r) => r.category?.id == category.id)) continue;
      if (category.keywords.isEmpty) continue;
      
      double bestScore = 0;
      String? matchedKeyword;
      
      for (var keyword in category.keywords) {
        final score = _calculateKeywordScore(normalizedName, keyword);
        if (score > bestScore) {
          bestScore = score;
          matchedKeyword = keyword;
        }
      }
      
      if (bestScore >= _minScoreThreshold) {
        results.add(CategoryMatchResult(
          category: category,
          score: _keywordMatchWeight * bestScore,
          matchType: 'keyword',
          matchedKeyword: matchedKeyword,
        ));
      }
    }
    
    // 排序并返回前N个
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }
}
