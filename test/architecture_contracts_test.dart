import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/config/api_config.dart';
import 'package:catlogue/models/quintal_snapshot.dart';
import 'package:catlogue/controllers/habitat_interaction_state.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('release requires explicit endpoint and development keeps local configuration', () {
    expect(
      () => ApiConfig.validate(release: true, explicitlyConfigured: false),
      throwsStateError,
    );
    ApiConfig.validate(release: false, explicitlyConfigured: false);
    ApiConfig.validate(
      release: true,
      url: 'http://192.168.1.4:8000',
      explicitlyConfigured: true,
    );
    ApiConfig.validate(
      release: true,
      url: 'https://example.com',
      explicitlyConfigured: true,
    );
    for (final url in [
      '',
      'relative/path',
      'ftp://example.com',
      'https://u:p@example.com',
      'https://example.com?secret=x',
    ]) {
      expect(() => ApiConfig.validate(url: url), throwsArgumentError);
    }
  });
  test('missing and legacy production fields preserve unknown data and empty defaults', () {
    final empty = QuintalSnapshot({});
    expect(empty.rows('facilities'), isEmpty);
    expect(empty.stock, isEmpty);
    expect(empty.serverNow, isNull);
    final model = QuintalSnapshot({
      'future_field': {'x': 1},
      'stock': {'corn': 3.0},
      'facilities': [
        {'kind': 'garden', 'level': 2},
      ],
      'catalog': {'recipes': null},
    });
    expect(model.facilityLevel('garden'), 2);
    expect(model.stock, {'corn': 3});
    expect(model.rows('recipes', catalog: true), isEmpty);
    expect(model.wire['future_field'], {'x': 1});
  });
  test('closing edit mode clears selection and tray but preserves server-independent gesture state', () {
    final state = HabitatInteractionState()
      ..editing = true
      ..tray = HabitatTray.inventory
      ..selectedItemId = 'item'
      ..groundSku = 'path'
      ..groundTool = GroundTool.paint;
    state.toggleEditing();
    expect(state.editing, isFalse);
    expect(state.tray, HabitatTray.none);
    expect(state.selectedItemId, isNull);
    expect(state.groundTool, GroundTool.move);
    state.openTray(HabitatTray.cats);
    expect(state.editing, isTrue);
    expect(state.tray, HabitatTray.cats);
  });
  test(
    'parallel database requests share one opening; failed opening can retry',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      final pending = Completer<Database>();
      var opens = 0;
      final facade = CatDatabase.withConnection(() {
        opens++;
        return pending.future;
      });
      final reads = List.generate(8, (_) => facade.database);
      pending.complete(db);
      expect((await Future.wait(reads)).every((v) => identical(v, db)), isTrue);
      expect(opens, 1);
      var attempts = 0;
      final retry = CatDatabase.withConnection(() {
        if (attempts++ == 0) throw StateError('temporary');
        return Future.value(db);
      });
      await expectLater(retry.database, throwsStateError);
      expect(await retry.database, same(db));
      await db.close();
    },
  );
}
