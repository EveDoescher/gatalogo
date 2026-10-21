import 'package:sqflite/sqflite.dart';

import '../sqlite_id_batches.dart';
import '../../models/cat_reference_photo.dart';

/// SQL operations for ReferencePhotoRepository; shares the connection owned by CatDatabase.
class ReferencePhotoRepository {
  ReferencePhotoRepository(this._open);
  final Future<Database> Function() _open;
  Future<Database> get database => _open();

  Future<List<CatReferencePhoto>> getReferencePhotos(String catId) async {
    final db = await database;
    final rows = await db.query(
      'cat_reference_photos',
      where: 'cat_id = ? AND deleted_at IS NULL',
      whereArgs: [catId],
      orderBy: 'kind ASC',
    );
    return rows.map(CatReferencePhoto.fromMap).toList();
  }

  Future<Map<String, List<CatReferencePhoto>>> getReferencePhotosForCats(
    Iterable<String> catIds,
  ) async {
    final result = <String, List<CatReferencePhoto>>{};
    for (final ids in sqliteIdBatches(catIds)) {
      for (final id in ids) {
        result[id] = [];
      }
      final db = await database;
      final rows = await db.query(
        'cat_reference_photos',
        where:
            'cat_id IN (${List.filled(ids.length, '?').join(',')}) AND deleted_at IS NULL',
        whereArgs: ids,
        orderBy: 'kind ASC',
      );
      for (final row in rows) {
        final photo = CatReferencePhoto.fromMap(row);
        result[photo.catId]!.add(photo);
      }
    }
    return result;
  }

  Future<List<CatReferencePhoto>> getDirtyReferencePhotos(
    String ownerId,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT ref_photo.* FROM cat_reference_photos AS ref_photo
      INNER JOIN cats ON cats.id = ref_photo.cat_id
      WHERE cats.owner_id = ? AND ref_photo.sync_state = 'dirty'
    ''',
      [ownerId],
    );
    return rows.map(CatReferencePhoto.fromMap).toList();
  }

  Future<void> upsertReferencePhoto(CatReferencePhoto photo) async {
    final db = await database;
    await db.insert(
      'cat_reference_photos',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markReferenceSynced(
    String catId,
    String kind, {
    String status = 'ready',
  }) async {
    final db = await database;
    await db.update(
      'cat_reference_photos',
      {'sync_state': 'synced', 'status': status},
      where: 'cat_id = ? AND kind = ?',
      whereArgs: [catId, kind],
    );
  }

  Future<void> markReferenceDeleted(String catId, String kind) async {
    final db = await database;
    await db.update(
      'cat_reference_photos',
      {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'sync_state': 'dirty',
      },
      where: 'cat_id = ? AND kind = ?',
      whereArgs: [catId, kind],
    );
  }

  Future<void> deleteReferencePhotoRecord(String catId, String kind) async {
    final db = await database;
    await db.delete(
      'cat_reference_photos',
      where: 'cat_id = ? AND kind = ?',
      whereArgs: [catId, kind],
    );
  }
}
