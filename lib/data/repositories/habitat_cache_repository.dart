import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// SQL operations for HabitatCacheRepository; shares the connection owned by CatDatabase.
class HabitatCacheRepository {
  HabitatCacheRepository(this._open);
  final Future<Database> Function() _open;
  Future<Database> get database => _open();

  Future<Map<String, dynamic>?> readHabitatCache(String ownerId) async {
    final rows = await (await database).query(
      'habitat_cache',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return {
      'snapshot': rows.first['snapshot'] == null
          ? null
          : jsonDecode(rows.first['snapshot'] as String),
      'draft': rows.first['draft'] == null
          ? null
          : jsonDecode(rows.first['draft'] as String),
      'pending_purchases': rows.first['pending_purchases'] == null
          ? null
          : jsonDecode(rows.first['pending_purchases'] as String),
    };
  }

  Future<void> saveHabitatSnapshot(
    String ownerId,
    Map<String, dynamic> snapshot,
  ) async {
    await (await database).rawInsert(
      '''
      INSERT INTO habitat_cache (owner_id, snapshot)
      VALUES (?, ?)
      ON CONFLICT(owner_id) DO UPDATE SET snapshot = excluded.snapshot
    ''',
      [ownerId, jsonEncode(snapshot)],
    );
  }

  Future<void> saveHabitatDraft(
    String ownerId,
    Map<String, dynamic>? draft,
  ) async {
    await (await database).rawInsert(
      '''
      INSERT INTO habitat_cache (owner_id, draft)
      VALUES (?, ?)
      ON CONFLICT(owner_id) DO UPDATE SET draft = excluded.draft
    ''',
      [ownerId, draft == null ? null : jsonEncode(draft)],
    );
  }

  Future<void> saveHabitatPendingPurchases(
    String ownerId,
    Map<String, String> pendingPurchases,
  ) async {
    await (await database).rawInsert(
      '''
      INSERT INTO habitat_cache (owner_id, pending_purchases)
      VALUES (?, ?)
      ON CONFLICT(owner_id) DO UPDATE SET pending_purchases = excluded.pending_purchases
    ''',
      [ownerId, jsonEncode(pendingPurchases)],
    );
  }
}
