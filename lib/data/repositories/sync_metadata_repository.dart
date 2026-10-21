import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../models/cat.dart';

/// SQL operations for SyncMetadataRepository; shares the connection owned by CatDatabase.
class SyncMetadataRepository {
  SyncMetadataRepository(this._open);
  final Future<Database> Function() _open;
  Future<Database> get database => _open();

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
}
