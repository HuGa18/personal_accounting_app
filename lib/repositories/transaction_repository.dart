import 'package:sqflite/sqflite.dart' hide Transaction;
import '../database/db.dart';
import '../models/transaction.dart';

class TransactionRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<Transaction>> getAll({
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  }) async {
    final db = await _db;
    
    String where = 'is_deleted = ?';
    List<dynamic> whereArgs = [0];

    if (accountId != null) {
      where += ' AND account_id = ?';
      whereArgs.add(accountId);
    }

    if (categoryId != null) {
      where += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }

    if (startDate != null) {
      where += ' AND transaction_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += ' AND transaction_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (type != null) {
      where += ' AND type = ?';
      whereArgs.add(type);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'transaction_date DESC',
    );

    return List.generate(maps.length, (i) => Transaction.fromJson(maps[i]));
  }

  Future<Transaction?> getById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Transaction.fromJson(maps.first);
  }

  Future<List<Transaction>> getByAccountId(String accountId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'account_id = ? AND is_deleted = ?',
      whereArgs: [accountId, 0],
      orderBy: 'transaction_date DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromJson(maps[i]));
  }

  Future<List<Transaction>> getByCategoryId(String categoryId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'category_id = ? AND is_deleted = ?',
      whereArgs: [categoryId, 0],
      orderBy: 'transaction_date DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromJson(maps[i]));
  }

  Future<List<Transaction>> getByPage({
    required int page,
    required int pageSize,
    String? accountId,
    String? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db;
    final offset = (page - 1) * pageSize;
    
    String where = 'is_deleted = ?';
    List<dynamic> whereArgs = [0];
    
    if (accountId != null) {
      where += ' AND account_id = ?';
      whereArgs.add(accountId);
    }
    
    if (categoryId != null) {
      where += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }
    
    if (type != null) {
      where += ' AND type = ?';
      whereArgs.add(type);
    }
    
    if (startDate != null) {
      where += ' AND transaction_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      where += ' AND transaction_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'transaction_date DESC',
      limit: pageSize,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Transaction.fromJson(maps[i]));
  }

  Future<List<Transaction>> getByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'is_deleted = ? AND transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [0, startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'transaction_date DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromJson(maps[i]));
  }

  Future<void> insert(Transaction transaction) async {
    final db = await _db;
    await db.insert(
      'transactions',
      transaction.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBatch(List<Transaction> transactions) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var transaction in transactions) {
        await txn.insert(
          'transactions',
          transaction.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> update(Transaction transaction) async {
    final db = await _db;
    await db.update(
      'transactions',
      {
        'account_id': transaction.accountId,
        'type': transaction.type,
        'amount': transaction.amount,
        'category_id': transaction.categoryId,
        'sub_category_id': transaction.subCategoryId,
        'merchant_name': transaction.merchantName,
        'description': transaction.description,
        'transaction_date': transaction.transactionDate.toIso8601String(),
        'source': transaction.source,
        'location': transaction.location,
        'tags': transaction.tags.join(','),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.update(
      'transactions',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}