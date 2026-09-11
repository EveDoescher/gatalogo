import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../models/cat_avatar.dart';
import '../models/cat_reference_photo.dart';

class CatDatabase {
  CatDatabase._();

  static final CatDatabase instance = CatDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'gatalogo.db');

    return openDatabase(
      path,
      version: 11,

      onCreate: (db, version) async {
        await db.execute('''
      CREATE TABLE cats (
        id TEXT PRIMARY KEY,
        is_owned INTEGER NOT NULL DEFAULT 0,
        capture_number INTEGER,
        name TEXT,
        photo_path TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        location_name TEXT,
        status TEXT NOT NULL,
        automatic_retry_count INTEGER NOT NULL DEFAULT 0
        ,owner_id TEXT
        ,sync_state TEXT NOT NULL DEFAULT 'dirty'
        ,local_updated_at TEXT
        ,sync_device_id TEXT
        ,sync_revision INTEGER NOT NULL DEFAULT 0
        ,deleted_at TEXT
      )
    ''');
        await db.execute('''
  CREATE TABLE cat_analyses (
    cat_id TEXT PRIMARY KEY,
    analysis_status TEXT NOT NULL,
    coat_type TEXT,
    primary_color TEXT,
    colors_json TEXT NOT NULL,
    confidence REAL,
    pattern_map_json TEXT,
    analyzed_at TEXT,
    FOREIGN KEY (cat_id) REFERENCES cats(id)
  )
''');
        await db.execute('''
      CREATE TABLE app_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
''');
        await _createAvatarTables(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 11) {
          await db.execute(
            'ALTER TABLE cats ADD COLUMN is_owned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE cats ADD COLUMN location_name TEXT');
        }

        if (oldVersion < 3) {
          await db.execute('ALTER TABLE cats ADD COLUMN name TEXT');

          await db.execute(
            'ALTER TABLE cats ADD COLUMN capture_number INTEGER',
          );

          final existingCats = await db.query(
            'cats',
            columns: ['id'],
            orderBy: 'captured_at ASC',
          );

          for (int i = 0; i < existingCats.length; i++) {
            await db.update(
              'cats',
              {'capture_number': i + 1},
              where: 'id = ?',
              whereArgs: [existingCats[i]['id']],
            );
          }
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cat_analyses (
              cat_id TEXT PRIMARY KEY,
              analysis_status TEXT NOT NULL,
              coat_type TEXT,
              primary_color TEXT,
              colors_json TEXT NOT NULL,
              confidence REAL,
              analyzed_at TEXT,
              FOREIGN KEY (cat_id) REFERENCES cats(id)
            )
          ''');
          if (oldVersion < 5) {
            await db.execute(
              'ALTER TABLE cat_analyses '
              'ADD COLUMN pattern_map_json TEXT',
            );
          }
          if (oldVersion < 6) {
            final columns = await db.rawQuery(
              'PRAGMA table_info(cat_analyses)',
            );

            final hasPatternMap = columns.any(
              (column) => column['name'] == 'pattern_map_json',
            );

            if (!hasPatternMap) {
              await db.execute(
                'ALTER TABLE cat_analyses '
                'ADD COLUMN pattern_map_json TEXT',
              );
            }
          }
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE cats '
            'ADD COLUMN automatic_retry_count INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 8) {
          await db.execute('ALTER TABLE cats ADD COLUMN owner_id TEXT');
          await db.execute(
            "ALTER TABLE cats ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'dirty'",
          );
          await db.execute('ALTER TABLE cats ADD COLUMN local_updated_at TEXT');
          await db.execute('ALTER TABLE cats ADD COLUMN sync_device_id TEXT');
          await db.execute(
            'ALTER TABLE cats ADD COLUMN sync_revision INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE cats ADD COLUMN deleted_at TEXT');
          await db.execute(
            "UPDATE cats SET local_updated_at = captured_at WHERE local_updated_at IS NULL",
          );
        }
        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 10) {
          await _createAvatarTables(db);
        }
      },
    );
  }

  Future<void> _createAvatarTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cat_avatars (
        cat_id TEXT PRIMARY KEY,
        version INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        preview_path TEXT,
        texture_paths_json TEXT NOT NULL DEFAULT '{}',
        coat_map_json TEXT,
        error_message TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cat_reference_photos (
        cat_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        local_path TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'ready',
        updated_at TEXT NOT NULL,
        sync_state TEXT NOT NULL DEFAULT 'dirty',
        deleted_at TEXT,
        PRIMARY KEY (cat_id, kind)
      )
    ''');
  }

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

  Future<void> queueSighting(Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('app_metadata', {
      'key': 'sighting:${const Uuid().v4()}',
      'value': jsonEncode(payload),
    });
  }

  Future<List<Map<String, dynamic>>> queuedSightings() async {
    final db = await database;
    final rows = await db.query(
      'app_metadata',
      where: 'key LIKE ?',
      whereArgs: ['sighting:%'],
    );
    return rows
        .map(
          (row) => {
            'queue_key': row['key'],
            ...Map<String, dynamic>.from(
              jsonDecode(row['value'] as String) as Map,
            ),
          },
        )
        .toList();
  }

  Future<void> removeQueuedSighting(String key) async {
    final db = await database;
    await db.delete('app_metadata', where: 'key = ?', whereArgs: [key]);
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

  Future<String> getOrCreateDeviceId() async {
    final db = await database;
    const key = 'sync_device_id';
    final row = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (row.isNotEmpty) {
      return row.first['value'] as String;
    }
    final value = const Uuid().v4();
    await db.insert('app_metadata', {'key': key, 'value': value});
    return value;
  }

  Future<void> bindUnownedCatsToAccount(String ownerId, String deviceId) async {
    final db = await database;
    await db.update('cats', {
      'owner_id': ownerId,
      'sync_state': 'dirty',
      'sync_device_id': deviceId,
      'local_updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'owner_id IS NULL');
  }

  Future<List<Cat>> getCatsForSync(String ownerId) async {
    final db = await database;
    final maps = await db.query(
      'cats',
      where: 'owner_id = ? AND sync_state = ?',
      whereArgs: [ownerId, 'dirty'],
    );
    return maps.map(Cat.fromMap).toList();
  }

  Future<void> markSynced(String id, int revision) async {
    final db = await database;
    await db.update(
      'cats',
      {'sync_state': 'synced', 'sync_revision': revision},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markDeleted(String id, String ownerId, String deviceId) async {
    final db = await database;
    await db.update(
      'cats',
      {
        'owner_id': ownerId,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'sync_state': 'dirty',
        'sync_device_id': deviceId,
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> getSyncCursor(String ownerId) async {
    final db = await database;
    final rows = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: ['sync_cursor_$ownerId'],
      limit: 1,
    );
    return rows.isEmpty ? '0' : rows.first['value'] as String;
  }

  Future<void> setSyncCursor(String ownerId, int cursor) async {
    final db = await database;
    await db.insert('app_metadata', {
      'key': 'sync_cursor_$ownerId',
      'value': '$cursor',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CatAnalysis>> getAnalyses() async {
    final db = await database;

    final maps = await db.query('cat_analyses');

    return maps.map((map) => CatAnalysis.fromMap(map)).toList();
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

  Future<CatAvatar?> getAvatar(String catId) async {
    final db = await database;
    final rows = await db.query(
      'cat_avatars',
      where: 'cat_id = ?',
      whereArgs: [catId],
      limit: 1,
    );
    return rows.isEmpty ? null : CatAvatar.fromMap(rows.first);
  }

  Future<void> upsertAvatar(CatAvatar avatar) async {
    final db = await database;
    await db.insert(
      'cat_avatars',
      avatar.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
