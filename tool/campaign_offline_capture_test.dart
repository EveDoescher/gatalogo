// Multiple OS processes share only this campaign's SQLite/documents directory.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';

class _Account extends SessionStore {
  _Account(this.options, this.online);
  final Map<String, dynamic> options;
  final bool online;
  @override
  AuthSession get session => AuthSession(
    userId: options['id'],
    email: 'capture@example.com',
    accessToken: options['token'],
    refreshToken: 'unused',
  );
  @override
  bool get isSignedIn => online;
  @override
  Future<String?> accessToken({bool refresh = false}) async =>
      online ? options['token'] : null;
}

class _Store extends CatStore {
  _Store(super.session, this.online, this.analysisEnabled)
    : super(networkAvailable: () async => online);
  final bool online;
  final bool analysisEnabled;
  @override
  Future<void> syncCatalog({bool manual = false}) async {
    if (online) await super.syncCatalog(manual: manual);
  }

  @override
  Future<void> syncPendingAnalyses({bool manual = false}) async {
    if (online && analysisEnabled) {
      await super.syncPendingAnalyses(manual: manual);
    }
  }

  @override
  Future<void> resolvePendingLocations() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('RES01 capture edit reopen synchronize and isolate account across processes', () async {
    final options = jsonDecode(
      Platform.environment['QUALITY_OFFLINE_FLOW']!,
    ) as Map<String, dynamic>;
    final phase = options['phase'] as String;
    final online = phase == 'sync' || phase == 'metadata';
    final analysisEnabled = options['analysis_enabled'] == true;
    HttpOverrides.global = null;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(options['database']);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    messenger.setMockMethodCallHandler(
      paths,
      (_) async => options['documents'],
    );
    messenger.setMockMethodCallHandler(connectivity, (_) async => null);
    messenger.setMockMethodCallHandler(secure, (_) async => null);
    final account = _Account(
      Map<String, dynamic>.from(options['account']),
      online,
    );
    final store = _Store(account, online, analysisEnabled),
        db = CatDatabase.instance;
    final receipt = File(options['receipt']);
    final watch = Stopwatch()..start();
    try {
      await store.loadCats();
      if (online && analysisEnabled) {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (store.isSynchronizing ||
            store.cats.any(
              (cat) =>
                  cat.status == 'pending_analysis' || cat.status == 'analyzing',
            )) {
          expect(
            DateTime.now().isBefore(deadline),
            isTrue,
            reason: 'Controlled analysis must converge',
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await store.syncCatalog(manual: true);
        await store.refreshGamification();
        await store.refreshNotifications();
      }
      if (phase == 'metadata') {
        for (final cat in store.cats.toList()) {
          await store.updateCatDetails(
            cat.id,
            name: cat.isOwned ? 'Lua revista' : 'Praça revista',
            microchip: cat.microchip,
            collar: cat.collar,
            distinguishingMarks: cat.distinguishingMarks,
          );
        }
        await store.syncCatalog(manual: true);
        await receipt.writeAsString(
          jsonEncode(
            store.cats
                .map(
                  (cat) => {
                    'id': cat.id,
                    'owned': cat.isOwned,
                    'name': cat.name,
                  },
                )
                .toList(),
          ),
        );
      }
      if (phase == 'capture') {
        expect(store.cats, isEmpty);
        for (final owned in [false, true]) {
          final result = await store.addFromTempPhoto(
            options['photo'],
            isOwned: owned,
            name: 'initial',
            capturedAt: DateTime.utc(2026, 10, 23, 12),
          );
          expect(result.awaitingConnection, isTrue);
          await store.updateCatDetails(
            result.cat.id,
            name: owned ? ' Lua ' : ' Praça ',
            microchip: ' SYNTHETIC ',
            collar: ' azul ',
            distinguishingMarks: ' fixture ',
          );
        }
        await receipt.writeAsString(
          jsonEncode(
            store.cats
                .map(
                  (cat) => {
                    'id': cat.id,
                    'owned': cat.isOwned,
                    'name': cat.name,
                  },
                )
                .toList(),
          ),
        );
      } else if (phase == 'other') {
        expect(
          store.cats,
          isEmpty,
          reason: 'Another account cannot read the previous account catalog',
        );
      }
      if (phase != 'other') {
        final expected = jsonDecode(await receipt.readAsString()) as List;
        expect(store.cats.length, 2);
        expect(
          store.cats.map((cat) => cat.id).toSet(),
          expected.map((e) => e['id']).toSet(),
        );
        for (final row in expected) {
          final cat = store.cats.singleWhere((cat) => cat.id == row['id']);
          expect(cat.name, row['name']);
          expect(cat.isOwned, row['owned']);
          expect(cat.ownerId, options['account']['id']);
          final completed =
              analysisEnabled && ['sync', 'metadata', 'final'].contains(phase);
          expect(
            store.analysisFor(cat.id)?.status,
            completed ? AnalysisStatus.completed : AnalysisStatus.pending,
          );
          expect(cat.microchip, 'SYNTHETIC');
          expect(cat.collar, 'azul');
          expect(cat.distinguishingMarks, 'fixture');
          expect(p.isWithin(options['documents'], cat.photoPath), isTrue);
          expect(
            await File(cat.photoPath).readAsBytes(),
            orderedEquals(await File(options['photo']).readAsBytes()),
          );
          if (online || phase == 'final') expect(cat.syncState, 'synced');
        }
      }
      await File(options['output']).writeAsString(
        jsonEncode({
          'phase': phase,
          'visible': store.cats.length,
          'ids': store.cats.map((cat) => cat.id).toList(),
          'sync_states': store.cats.map((cat) => cat.syncState).toList(),
          'analysis_enabled': analysisEnabled,
          'elapsed_ms_observed': watch.elapsedMilliseconds,
          'scope': 'real desktop SQLite/files and public CatStore methods; sync/metadata phases use disposable HTTP API; analysis is controlled by explicit fixture option, geolocation disabled',
        }),
      );
    } finally {
      store.dispose();
      account.dispose();
      await (await db.database).close();
      for (final channel in [paths, connectivity, secure]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    }
  });
}
