import 'package:sqflite/sqflite.dart';
import '../database/db.dart';
import '../models/budget.dart';

class BudgetRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<Budget>> getAll() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Budget.fromJson(maps[i]));
  }

  Future<Budget?> getById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Budget.fromJson(maps.first);
  }

  Future<List<Budget>> getByCategoryId(String categoryId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'category_id = ? AND is_deleted = ?',
      whereArgs: [categoryId, 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Budget.fromJson(maps[i]));
  }

  Future<void> insert(Budget budget) async {
    final db = await _db;
    await db.insert(
      'budgets',
      budget.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Budget budget) async {
    final db = await _db;
    await db.update(
      'budgets',
      {
        'category_id': budget.categoryId,
        'amount': budget.amount,
        'period': budget.period,
        'start_day': budget.startDay,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.update(
      'budgets',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}