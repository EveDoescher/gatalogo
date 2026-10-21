import 'package:sqflite/sqflite.dart';

import '../sqlite_id_batches.dart';
import '../../models/cat.dart';
import '../../models/cat_analysis.dart';

/// SQL operations for CatalogRepository; shares the connection owned by CatDatabase.
class CatalogRepository {
  CatalogRepository(this._open);
  final Future<Database> Function() _open;
  Future<Database> get database => _open();

  Future<void> insertCat(Cat cat) async {
    final db = await database;

    await db.insert(
      'cats',
      cat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertCatWithAnalysis(Cat cat, CatAnalysis analysis) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert(
        'cats',
        cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'cat_analyses',
        analysis.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<Cat>> getCats({String? ownerId}) async {
    final db = await database;

    final maps = await db.query(
      'cats',
      where: ownerId == null
          ? 'deleted_at IS NULL AND owner_id IS NULL'
          : 'deleted_at IS NULL AND (owner_id IS NULL OR owner_id = ?)',
      whereArgs: ownerId == null ? null : [ownerId],
      orderBy: 'captured_at DESC',
    );

    return maps.map((map) => Cat.fromMap(map)).toList();
  }

  Future<int> getNextCaptureNumber() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT COALESCE(MAX(capture_number), 0) + 1 AS next_number
    FROM cats
  ''');

    return Sqflite.firstIntValue(result) ?? 1;
  }

  Future<void> updateCatName(String id, String? name) async {
    final db = await database;

    await db.update(
      'cats',
      {
        'name': name,
        'sync_state': 'dirty',
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCatDetails(
    String id, {
    String? name,
    String? microchip,
    String? collar,
    String? distinguishingMarks,
  }) async {
    final db = await database;

    await db.update(
      'cats',
      {
        'name': name,
        'microchip': microchip,
        'collar': collar,
        'distinguishing_marks': distinguishingMarks,
        'sync_state': 'dirty',
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCatLocation(
    String id, {
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    final db = await database;
    await db.update(
      'cats',
      {
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName,
        'sync_state': 'dirty',
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCatStatus(
    String id,
    String status, {
    int? automaticRetryCount,
  }) async {
    final db = await database;

    await db.update(
      'cats',
      {
        'status': status,
        ...?automaticRetryCount == null
            ? null
            : {'automatic_retry_count': automaticRetryCount},
        'sync_state': 'dirty',
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCatFavorite(String id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'cats',
      {
        'is_favorite': isFavorite ? 1 : 0,
        'sync_state': 'dirty',
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCatNotes(String id, String? notes) async {
    final db = await database;
    await db.update(
      'cats',
      {
        'notes': notes,
        'sync_state': 'dirty',
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCatWithAnalysis(String catId) async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.delete(
        'cat_analyses',
        where: 'cat_id = ?',
        whereArgs: [catId],
      );
      await transaction.delete('cats', where: 'id = ?', whereArgs: [catId]);
    });
  }

  Future<void> upsertAnalysis(CatAnalysis analysis) async {
    final db = await database;

    await db.insert(
      'cat_analyses',
      analysis.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CatAnalysis>> getAnalyses() async {
    final db = await database;

    final maps = await db.query('cat_analyses');

    return maps.map((map) => CatAnalysis.fromMap(map)).toList();
  }

  Future<List<CatAnalysis>> getAnalysesForCats(Iterable<String> catIds) async {
    final result = <CatAnalysis>[];
    for (final ids in sqliteIdBatches(catIds)) {
      final db = await database;
      final rows = await db.query(
        'cat_analyses',
        where: 'cat_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
      result.addAll(rows.map(CatAnalysis.fromMap));
    }
    return result;
  }

  Future<CatAnalysis?> getAnalysisByCatId(String catId) async {
    final db = await database;

    final maps = await db.query(
      'cat_analyses',
      where: 'cat_id = ?',
      whereArgs: [catId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return CatAnalysis.fromMap(maps.first);
  }

  Future<Cat?> getCatById(String id) async {
    final db = await database;
    final rows = await db.query(
      'cats',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Cat.fromMap(rows.first);
  }

  Future<void> replaceCatFromSync(Cat cat, {CatAnalysis? analysis}) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.insert(
        'cats',
        cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (analysis case final value?) {
        await transaction.insert(
          'cat_analyses',
          value.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
