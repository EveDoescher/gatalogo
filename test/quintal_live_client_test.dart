import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catlogue/config/api_config.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/game/quintal_scene_target.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/widgets/quintal_object_actions.dart';

// Opt-in only. The Python runner supplies disposable accounts via environment,
// runs two distinct Flutter processes, and closes one HTTP response after commit.
class _Account extends SessionStore {
  _Account(this.profile);
  Map<String, dynamic> profile;
  @override
  bool get isSignedIn => true;
  @override
  AuthSession get session => AuthSession(
    userId: profile['id'],
    email: 'quintal-live@example.invalid',
    accessToken: profile['token'],
    refreshToken: 'unused',
  );
  @override
  Future<String?> accessToken({bool refresh = false}) async => profile['token'];
}

class _Store extends CatStore {
  _Store(super.session);
  @override
  Future<void> refreshGamification() async {}
}

void main() {
  final config = Platform.environment['QUINTAL_LIVE_CLIENT'];
  testWidgets(
    'real HTTP commit loss survives Flutter process restart and account switch',
    (tester) async {
      final options = jsonDecode(config!) as Map<String, dynamic>;
      expect([
        '127.0.0.1',
        'localhost',
        '::1',
      ], contains(Uri.parse(ApiConfig.baseUrl).host));
      // Widget tests block HTTP by default. This explicitly opted-in test uses
      // the real ProductApiService and the loopback fault-injection transport.
      HttpOverrides.global = null;
      GoogleFonts.config.allowRuntimeFetching = false;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await tester.runAsync(
        () => databaseFactory.setDatabasesPath(options['database']),
      );
      final account = _Account(Map<String, dynamic>.from(options['account']));
      final store = _Store(account), db = CatDatabase.instance;
      final h = HabitatService(account, store, database: db);
      final phase = options['phase'];
      await tester.runAsync(h.load);
      expect(h.offline, isFalse);
      expect(h.productionOffline, isFalse);
      final confirmed = <String>[];
      Future<void> showMarket() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuintalObjectActions(
                  habitat: h,
                  target: const QuintalSceneTarget(
                    'market',
                    'market',
                    'market',
                    0,
                    0,
                  ),
                  onClose: () {},
                  onFish: () {},
                  onConfirmed: (_, action) => confirmed.add(action),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      if (phase == 'before') {
        expect(h.productionStock['apple'], 9);
        await showMarket();
        await tester.tap(find.text('Fazer pedido'));
        await tester.pump();
        await tester.ensureVisible(find.text('Frango').first);
        await tester.tap(find.text('Frango').first);
        await tester.pump();
        await tester.ensureVisible(find.text('Frutas').first);
        await tester.tap(find.text('Frutas').first);
        await tester.pump();
        await tester.ensureVisible(find.text('Confirmar encomenda'));
        await tester.tap(find.text('Confirmar encomenda'));
        await tester.pump();
        for (var i = 0; i < 200 && h.productionBusy; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        expect(h.productionBusy, isFalse);
        expect(confirmed, isEmpty);
        expect(h.productionStock['apple'], 9);
        expect(h.productionRows('tasks'), isEmpty);
        final cached = await tester.runAsync(
          () => db.readHabitatCache(account.session.userId),
        );
        expect(cached!['snapshot']['pending_production'], hasLength(1));
        expect(
          find.textContaining('Não foi possível conectar'),
          findsOneWidget,
        );
      } else {
        // This is a new OS process using the same on-disk SQLite cache and a
        // second authenticated session for the temporary account.
        expect(h.productionStock['apple'], 6);
        expect(h.productionStock['pear'], 6);
        expect(h.productionRows('tasks'), hasLength(1));
        await showMarket();
        expect(find.textContaining('Chega em'), findsOneWidget);
        await tester.runAsync(
          () => h.produce('order', 'chicken', {
            'payment': 'products',
            'quantity': 2,
            'product_option': 'fruit',
          }),
        );
        expect(h.productionStock['apple'], 6);
        expect(h.productionRows('tasks'), hasLength(1));
        final cached = await tester.runAsync(
          () => db.readHabitatCache(account.session.userId),
        );
        expect(cached!['snapshot']['pending_production'], isEmpty);
        account.profile = Map<String, dynamic>.from(options['other']);
        await tester.runAsync(h.load);
        expect(h.productionStock['apple'], 9);
        expect(h.productionRows('tasks'), isEmpty);
        account.profile = Map<String, dynamic>.from(options['account']);
        await tester.runAsync(h.load);
        expect(h.productionStock['apple'], 6);
        expect(h.productionRows('tasks'), hasLength(1));
      }
      await tester.pumpWidget(const SizedBox());
      h.dispose();
      store.dispose();
      account.dispose();
      await tester.runAsync(() async => (await db.database).close());
    },
    skip: config == null,
  );
}
