import 'package:sqflite/sqflite.dart';
import '../database/db.dart';
import '../models/category.dart';

class CategoryRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<Category>> getAll({String? type}) async {
    final db = await _db;
    
    List<Map<String, dynamic>> maps;
    if (type != null) {
      maps = await db.query(
        'categories',
        where: 'type = ? AND is_deleted = ?',
        whereArgs: [type, 0],
        orderBy: 'name ASC',
      );
    } else {
      maps = await db.query(
        'categories',
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'name ASC',
      );
    }

    return List.generate(maps.length, (i) => Category.fromJson(maps[i]));
  }

  Future<Category?> getById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Category.fromJson(maps.first);
  }

  Future<List<Category>> getByParentId(String parentId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'parent_id = ? AND is_deleted = ?',
      whereArgs: [parentId, 0],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Category.fromJson(maps[i]));
  }

  Future<Category?> matchCategory(String merchantName) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'is_deleted = ?',
      whereArgs: [0],
    );

    for (var map in maps) {
      final category = Category.fromJson(map);
      for (var keyword in category.keywords) {
        if (merchantName.contains(keyword)) {
          return category;
        }
      }
    }

    final defaultCategory = await db.query(
      'categories',
      where: 'name = ? AND is_deleted = ?',
      whereArgs: ['其他支出', 0],
    );
    if (defaultCategory.isNotEmpty) {
      return Category.fromJson(defaultCategory.first);
    }

    return null;
  }

  Future<void> insert(Category category) async {
    final db = await _db;
    await db.insert(
      'categories',
      category.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Category category) async {
    final db = await _db;
    await db.update(
      'categories',
      {
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'parent_id': category.parentId,
        'type': category.type,
        'keywords': category.keywords.join(','),
        'is_system': category.isSystem ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.update(
      'categories',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}