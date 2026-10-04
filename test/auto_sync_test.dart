import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';

import 'gamification_service_test.dart' show Account;

class SyncProbe extends CatalogSyncService {
  SyncProbe(super.session);
  int calls = 0;
  @override
  Future<bool> sync() async {
    calls++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'auto-sync defaults on and persists the off preference across sessions',
    () async {
      final first = SessionStore();
      expect(first.autoSyncEnabled, true);
      await first.setAutoSyncEnabled(false);
      final second = SessionStore();
      await second.initialize();
      expect(second.autoSyncEnabled, false);
      await second.setAutoSyncEnabled(true);
      expect(
        await const FlutterSecureStorage().read(key: 'auto_sync_enabled'),
        'true',
      );
      first.dispose();
      second.dispose();
    },
  );

  test(
    'off blocks background catalog and analyses but explicit sync still runs',
    () async {
      final session = Account();
      await session.setAutoSyncEnabled(false);
      final sync = SyncProbe(session);
      var networkChecks = 0;
      final store = CatStore(
        session,
        catalogSync: sync,
        networkAvailable: () async {
          networkChecks++;
          return true;
        },
      );
      await store.syncCatalog();
      await store.syncPendingAnalyses();
      expect(sync.calls, 0);
      expect(networkChecks, 0);
      await store.syncCatalog(manual: true);
      await store.syncPendingAnalyses(manual: true);
      expect(sync.calls, 2);
      expect(networkChecks, 2);
      store.dispose();
      session.dispose();
    },
  );
}
