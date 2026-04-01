import 'package:sqflite/sqflite.dart';
import '../database/db.dart';
import '../models/import_record.dart';

class ImportRecordRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<ImportRecord>> getAll() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'import_records',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'import_date DESC',
    );
    return List.generate(maps.length, (i) => ImportRecord.fromJson(maps[i]));
  }

  Future<ImportRecord?> getById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'import_records',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return ImportRecord.fromJson(maps.first);
  }

  Future<ImportRecord?> findBySourceAndExternalId(String source, String externalId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'import_records',
      where: 'source = ? AND external_id = ? AND is_deleted = ?',
      whereArgs: [source, externalId, 0],
    );
    if (maps.isEmpty) return null;
    return ImportRecord.fromJson(maps.first);
  }

  Future<bool> existsBySourceAndExternalId(String source, String externalId) async {
    final record = await findBySourceAndExternalId(source, externalId);
    return record != null;
  }

  Future<void> insert(ImportRecord record) async {
    final db = await _db;
    await db.insert(
      'import_records',
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBatch(List<ImportRecord> records) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var record in records) {
        await txn.insert(
          'import_records',
          record.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.update(
      'import_records',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}