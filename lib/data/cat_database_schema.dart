import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class CatDatabaseSchema {
  Future<Database> open() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'gatalogo.db');

    return openDatabase(
      path,
      version: 17,

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
        ,microchip TEXT
        ,collar TEXT
        ,distinguishing_marks TEXT
        ,is_favorite INTEGER NOT NULL DEFAULT 0
        ,individual_id TEXT
        ,notes TEXT
      )
    ''');
        await db.execute('''
  CREATE TABLE cat_analyses (
    cat_id TEXT PRIMARY KEY,
    analysis_status TEXT NOT NULL,
    coat_type TEXT,
    hair_type TEXT,
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
        await _createReferencePhotoTable(db);
        await _createHabitatCacheTable(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 17) {
          await db.execute('ALTER TABLE cats ADD COLUMN individual_id TEXT');
        }
        if (oldVersion == 15) {
          await db.execute(
            'ALTER TABLE habitat_cache ADD COLUMN pending_purchases TEXT',
          );
        }
        if (oldVersion < 15) {
          await _createHabitatCacheTable(db);
        }
        if (oldVersion < 14) {
          final columns = await db.rawQuery('PRAGMA table_info(cats)');
          final names = columns.map((c) => c['name'] as String).toSet();
          if (!names.contains('is_favorite')) {
            await db.execute(
              'ALTER TABLE cats ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (!names.contains('notes')) {
            await db.execute('ALTER TABLE cats ADD COLUMN notes TEXT');
          }
        }
        if (oldVersion < 13) {
          final columns = await db.rawQuery('PRAGMA table_info(cats)');
          final names = columns.map((c) => c['name'] as String).toSet();
          if (!names.contains('microchip')) {
            await db.execute('ALTER TABLE cats ADD COLUMN microchip TEXT');
          }
          if (!names.contains('collar')) {
            await db.execute('ALTER TABLE cats ADD COLUMN collar TEXT');
          }
          if (!names.contains('distinguishing_marks')) {
            await db.execute(
              'ALTER TABLE cats ADD COLUMN distinguishing_marks TEXT',
            );
          }
        }
        if (oldVersion < 12) {
          final columns = await db.rawQuery('PRAGMA table_info(cat_analyses)');
          final hasHairType = columns.any(
            (column) => column['name'] == 'hair_type',
          );
          if (!hasHairType) {
            await db.execute(
              'ALTER TABLE cat_analyses ADD COLUMN hair_type TEXT',
            );
          }
        }
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
          await _createReferencePhotoTable(db);
        }
      },
    );
  }

  Future<void> _createReferencePhotoTable(DatabaseExecutor db) async {
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

  Future<void> _createHabitatCacheTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habitat_cache (
        owner_id TEXT PRIMARY KEY,
        snapshot TEXT,
        draft TEXT,
        pending_purchases TEXT
      )
    ''');
  }
}
