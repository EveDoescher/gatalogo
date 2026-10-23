// Common service contract for both frozen Flutter versions; no UI comparison.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/stores/cat_store.dart';

class _Account extends SessionStore {
  _Account(this.profile);
  Map<String, dynamic> profile;
  @override
  bool get isSignedIn => true;
  @override
  AuthSession get session => AuthSession(
    userId: profile['id'],
    email: 'crossed@example.invalid',
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
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'BR04 common real HTTP commit-loss restart and owner isolation',
    () async {
      final options = jsonDecode(
        Platform.environment['QUALITY_CROSSED_CLIENT']!,
      ) as Map<String, dynamic>;
      HttpOverrides.global = null;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(options['database']);
      final account = _Account(Map<String, dynamic>.from(options['account']));
      final store = _Store(account), db = CatDatabase.instance;
      final habitat = HabitatService(account, store, database: db);
      try {
        await habitat.load();
        expect(habitat.productionOffline, isFalse);
        if (options['phase'] == 'before') {
          expect(habitat.productionStock['apple'], 9);
          await expectLater(
            habitat.produce('order', 'chicken', {
              'payment': 'products',
              'quantity': 2,
              'product_option': 'fruit',
            }),
            throwsA(
              isA<ProductApiException>().having(
                (e) => e.statusCode,
                'transport failure status',
                isNull,
              ),
            ),
          );
          final cached = await db.readHabitatCache(account.session.userId);
          expect(cached!['snapshot']['pending_production'], hasLength(1));
        } else {
          expect(habitat.productionStock['apple'], 6);
          expect(habitat.productionRows('tasks'), hasLength(1));
          await habitat.produce('order', 'chicken', {
            'payment': 'products',
            'quantity': 2,
            'product_option': 'fruit',
          });
          expect(habitat.productionStock['apple'], 6);
          expect(habitat.productionRows('tasks'), hasLength(1));
          final cached = await db.readHabitatCache(account.session.userId);
          expect(cached!['snapshot']['pending_production'], isEmpty);
          account.profile = Map<String, dynamic>.from(options['other']);
          await habitat.load();
          expect(habitat.productionStock['apple'], 9);
          expect(habitat.productionRows('tasks'), isEmpty);
          account.profile = Map<String, dynamic>.from(options['account']);
          await habitat.load();
          expect(habitat.productionStock['apple'], 6);
          expect(habitat.productionRows('tasks'), hasLength(1));
        }
      } finally {
        habitat.dispose();
        store.dispose();
        account.dispose();
        await (await db.database).close();
      }
    },
  );
}
