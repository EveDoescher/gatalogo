import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:catlogue/controllers/conversation_controller.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/notification_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'conversation_controller_test.dart' as chat;

class _Account extends SessionStore {
  String? owner = 'a';
  @override
  bool get isSignedIn => false; // Suppress unrelated realtime/preferences IO.
  @override
  bool get autoSyncEnabled => false;
  @override
  AuthSession? get session => owner == null
      ? null
      : AuthSession(
          userId: owner!,
          email: 'scope@example.com',
          accessToken: 'synthetic',
          refreshToken: 'synthetic',
        );
  @override
  Future<String?> accessToken({bool refresh = false}) async => 'synthetic';
  void change(String? next) {
    owner = next;
    notifyListeners();
  }
}

class _Sync extends CatalogSyncService {
  _Sync(super.session);
  Completer<bool>? pending;
  final entered = Completer<void>();
  @override
  Future<bool> sync() {
    if (pending != null && !entered.isCompleted) entered.complete();
    return pending?.future ?? Future.value(true);
  }
}

class _Store extends CatStore {
  _Store(_Account account, _Sync sync, this.network)
    : super(
        account,
        catalogSync: sync,
        networkAvailable: () async => network.value,
      );
  final ValueNotifier<bool> network;
  @override
  Future<void> resolvePendingLocations() async {}
  @override
  Future<void> refreshGamification() async {}
}

class _ChatAccount extends chat.SwitchableAccount {
  void change(String? id) {
    identity = id == null
        ? null
        : AuthSession(
            userId: id,
            email: 'scope@example.com',
            accessToken: 'synthetic',
            refreshToken: 'synthetic',
          );
    notifyListeners();
  }
}

class _History extends chat.Api {
  _History(super.session);
  final historyPending = Completer<List<Map<String, dynamic>>>();
  final entered = Completer<void>();
  @override
  Future<List<Map<String, dynamic>>> messages(String id) {
    if (!entered.isCompleted) entered.complete();
    return historyPending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  final database = CatDatabase.instance;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    folder = await Directory.systemTemp.createTemp('gatalogo-scope-');
    await databaseFactory.setDatabasesPath(folder.path);
    await database.database;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'dev.fluttercommunity.plus/connectivity_status',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
  });
  tearDownAll(() async {
    await (await database.database).close();
    final target = await folder.resolveSymbolicLinks();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    expect(p.isWithin(root, target), isTrue);
    await folder.delete(recursive: true);
  });
  setUp(() async {
    final connection = await database.database;
    await connection.delete('cat_reference_photos');
    await connection.delete('cat_analyses');
    await connection.delete('cats');
  });

  for (final boundary in ['switch', 'logout', 'dispose']) {
    for (final flow in [
      'catalog',
      'analysis-success',
      'analysis-rejected',
      'analysis-retry',
    ]) {
      test(
        'RES03 $flow response after $boundary cannot contaminate state',
        () async {
          final account = _Account(), network = ValueNotifier(false);
          final sync = _Sync(account), store = _Store(account, sync, network);
          final id = '$flow-$boundary';
          final photo = File(p.join(folder.path, '$id.png'));
          await photo.writeAsBytes([1, 2, 3]);
          await database.insertCat(
            Cat(
              id: id,
              captureNumber: 1,
              photoPath: photo.path,
              capturedAt: DateTime.utc(2026),
              ownerId: 'a',
              status: flow == 'catalog' ? 'completed' : 'pending_analysis',
              syncState: 'synced',
            ),
          );
          var disposed = false;
          final response = Completer<http.Response>(),
              entered = Completer<void>();
          final client = MockClient((request) {
            expect(request.url.path, '/analyze');
          expect(request.body, contains(id));
            entered.complete();
            return response.future;
          });
          try {
            await store.loadCats();
            expect(store.cats.any((cat) => cat.id == id), isTrue);
            network.value = true;
            await http.runWithClient(() async {
              if (flow == 'catalog') sync.pending = Completer<bool>();
              final pending = flow == 'catalog'
                  ? store.syncCatalog(manual: true)
                  : store.syncPendingAnalyses(manual: true);
              await (flow == 'catalog' ? sync.entered.future : entered.future)
                  .timeout(const Duration(seconds: 10));
              final before = await database.getCatById(id);
            if (flow != 'catalog') expect(before?.status, 'analyzing');
              final beforeAnalysis = await database.getAnalysisByCatId(id);
              if (boundary == 'dispose') {
                store.dispose();
                disposed = true;
              } else {
                account.change(boundary == 'switch' ? 'b' : null);
                await store.ready;
              }
              final visible = store.cats.map((cat) => cat.id).toList();
              final analysis = store.analysisFor(id)?.toMap();
              if (flow == 'catalog') {
                sync.pending!.complete(true);
              } else if (flow == 'analysis-success') {
                response.complete(
                  http.Response(
                    jsonEncode({'cat_id': id, 'coat_type': 'synthetic'}),
                    200,
                  ),
                );
              } else if (flow == 'analysis-rejected') {
                response.complete(
                  http.Response(
                    jsonEncode({
                      'detail': {
                        'code': 'INVALID_IMAGE',
                        'message': 'synthetic rejection',
                      },
                    }),
                    422,
                  ),
                );
              } else {
                response.complete(http.Response('{}', 503));
              }
              await pending;
              expect(store.cats.map((cat) => cat.id).toList(), visible);
              expect(store.analysisFor(id)?.toMap(), analysis);
              expect((await database.getCatById(id))?.toMap(), before?.toMap());
              expect(
                (await database.getAnalysisByCatId(id))?.toMap(),
                beforeAnalysis?.toMap(),
              );
            }, () => client);
          } finally {
            if (!disposed) store.dispose();
            client.close();
            account.dispose();
            network.dispose();
          }
        },
      );
    }

    test('RES03 chat history and event after $boundary are ignored', () async {
      final account = _ChatAccount()..change('a');
      final socket = chat.Socket(account), api = _History(account);
      final controller = ConversationController(
        account,
        'chat',
        api: api,
        socket: socket,
      );
      var disposed = false;
      try {
        controller.start();
        await api.entered.future;
        if (boundary == 'dispose') {
          controller.dispose();
          disposed = true;
        } else {
          account.change(boundary == 'switch' ? 'b' : null);
        }
        api.historyPending.complete([chat.message('old-a')]);
        socket.incoming.add(chat.message('old-event-a'));
        await Future<void>.delayed(Duration.zero);
        expect(controller.messages, isEmpty);
        expect(controller.optimisticIds, isEmpty);
      } finally {
        if (!disposed) controller.dispose();
        socket.dispose();
        account.dispose();
      }
    });

    test('RES03 inbox response after $boundary is ignored', () async {
      final pending = Completer<List<Map<String, dynamic>>>();
      var calls = 0;
      final store = NotificationStore(
        loadItems: () => calls++ == 0
            ? pending.future
            : Future.value([
                {'id': 'b'},
              ]),
        saveRead: (_) async {},
      );
      var disposed = false, notifications = 0;
      store.addListener(() => notifications++);
      try {
        final request = store.refresh();
        if (boundary == 'dispose') {
          store.dispose();
          disposed = true;
        } else {
          store.clear();
          if (boundary == 'switch') await store.refresh();
        }
        final before = List<Map<String, dynamic>>.from(store.items);
        final beforeNotifications = notifications;
        pending.complete([
          {'id': 'old-a'},
        ]);
        await request;
        expect(store.items, before);
        expect(notifications, beforeNotifications);
      } finally {
        if (!disposed) store.dispose();
      }
    });
  }
}
