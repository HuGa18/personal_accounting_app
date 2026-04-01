import 'package:sqflite/sqflite.dart';
import '../database/db.dart';
import '../models/account.dart';

class AccountRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<Account>> getAll() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Account.fromJson(maps[i]));
  }

  Future<Account?> getById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Account.fromJson(maps.first);
  }

  Future<void> insert(Account account) async {
    final db = await _db;
    await db.insert(
      'accounts',
      account.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Account account) async {
    final db = await _db;
    await db.update(
      'accounts',
      {
        'name': account.name,
        'type': account.type,
        'balance': account.balance,
        'currency': account.currency,
        'color': account.color,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.update(
      'accounts',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}