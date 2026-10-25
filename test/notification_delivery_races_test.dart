import 'dart:async';
import 'dart:convert';

import 'package:catlogue/controllers/account_activity_controller.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/services/push_notification_service.dart';
import 'package:catlogue/services/websocket_service.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Socket extends Fake implements WebSocketService {
  final events = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get onNotification => events.stream;
}

class _Push extends Fake implements PushNotificationService {
  final events = StreamController<String>.broadcast();
  @override
  Stream<String> get onNotification => events.stream;
}

class _Account extends Fake implements SessionStore {
  String owner = 'A';
  @override
  final webSocket = _Socket();
  @override
  final pushNotifications = _Push();
  @override
  bool get isSignedIn => true;
  @override
  AuthSession get session => AuthSession(
    userId: owner,
    email: 'fixture@test.invalid',
    accessToken: owner,
    refreshToken: 'fixture',
  );
  @override
  Future<String?> accessToken({bool refresh = false}) async => owner;

  Future<void> close() async {
    await webSocket.events.close();
    await pushNotifications.events.close();
  }
}

Map<String, dynamic> notice(String id) => {
  'id': id,
  'created_at': '2026-10-24T12:00:00Z',
  'read_at': null,
};
http.Response page(List<Map<String, dynamic>> rows) =>
    http.Response(jsonEncode(rows), 200);
List<Map<String, dynamic>> firstPage() => [
  for (var i = 20; i >= 1; i--) notice('n${i.toString().padLeft(2, '0')}'),
];
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final wsFirst in [true, false]) {
    test(
      'DLV05 real activity bridge coalesces WS/push wsFirst=$wsFirst',
      () async {
        final account = _Account();
        final activity = AccountActivityController(account, () async {});
        final response = Completer<http.Response>();
        var gets = 0;
        try {
          await http.runWithClient(
            () async {
              if (wsFirst) {
                account.webSocket.events.add({'id': 'same'});
              } else {
                account.pushNotifications.events.add('same');
              }
              await flush();
              expect(gets, 1);
              if (wsFirst) {
                account.pushNotifications.events.add('same');
              } else {
                account.webSocket.events.add({'id': 'same'});
              }
              await flush();
              expect(gets, 1);
              response.complete(page([notice('same')]));
              await flush();
              expect(activity.notifications.items.single['id'], 'same');
              expect(activity.notifications.unreadCount, 1);
              account.webSocket.events.add({'id': 'same'});
              account.pushNotifications.events.add('same');
              await flush();
              expect(gets, 2);
              expect(activity.notifications.items, hasLength(1));
              expect(activity.notifications.unreadCount, 1);
            },
            () => MockClient((_) {
              gets++;
              return response.future;
            }),
          );
        } finally {
          activity.dispose();
          await account.close();
        }
      },
    );
  }

  test(
    'DLV05 refresh loadMore and read acknowledgment preserve pages and count',
    () async {
      final account = _Account();
      final activity = AccountActivityController(account, () async {});
      final more = Completer<http.Response>(),
          refresh = Completer<http.Response>(),
          read = Completer<http.Response>();
      var gets = 0, posts = 0;
      try {
        await http.runWithClient(
          () async {
            await activity.notifications.refresh();
            expect(activity.notifications.hasMore, isTrue);
            final pendingMore = activity.notifications.loadMore();
            final pendingRead = activity.notifications.markRead('n20');
            await flush();
            expect(gets, 2);
            expect(posts, 1);
            final pendingRefresh = activity.notifications.refresh();
            await flush();
            expect(gets, 3);
            read.complete(http.Response('{}', 200));
            await pendingRead;
            refresh.complete(page(firstPage()));
            await pendingRefresh;
            more.complete(page([notice('n01'), notice('n00')]));
            await pendingMore;
            expect(activity.notifications.items, hasLength(21));
            expect(
              activity.notifications.items.map((n) => n['id']).toSet(),
              hasLength(21),
            );
            expect(activity.notifications.items.first['id'], 'n20');
            expect(activity.notifications.items.last['id'], 'n00');
            expect(activity.notifications.items.first['read_at'], isNotNull);
            expect(activity.notifications.unreadCount, 20);
            expect(activity.notifications.hasMore, isFalse);
          },
          () => MockClient((request) {
            if (request.method == 'POST') {
              posts++;
              return read.future;
            }
            gets++;
            if (gets == 1) return Future.value(page(firstPage()));
            if (gets == 2) {
              expect(request.url.queryParameters['cursor_id'], 'n01');
              return more.future;
            }
            return refresh.future;
          }),
        );
      } finally {
        activity.dispose();
        await account.close();
      }
    },
  );

  for (final oldRequest in ['refresh', 'loadMore']) {
    test(
      'DLV05 old $oldRequest response cannot cross account clear boundary',
      () async {
        final account = _Account();
        final activity = AccountActivityController(account, () async {});
        final old = Completer<http.Response>();
        var callsA = 0;
        try {
          await http.runWithClient(
            () async {
              if (oldRequest == 'loadMore')
                await activity.notifications.refresh();
              final pending = oldRequest == 'loadMore'
                  ? activity.notifications.loadMore()
                  : activity.notifications.refresh();
              await flush();
              account.owner = 'B';
              activity.notifications.clear(); // Same boundary invoked by CatStore on account change (RES-03).
              await activity.notifications.refresh();
              old.complete(page([notice('A-private')]));
              await pending;
              expect(activity.notifications.items.single['id'], 'B');
              expect(activity.notifications.unreadCount, 1);
            },
            () => MockClient((request) {
              if (request.headers['Authorization'] == 'Bearer B')
                return Future.value(page([notice('B')]));
              callsA++;
              if (oldRequest == 'loadMore' && callsA == 1)
                return Future.value(page(firstPage()));
              return old.future;
            }),
          );
        } finally {
          activity.dispose();
          await account.close();
        }
      },
    );
  }

  test(
    'DLV05 disposed activity ignores late response and future transport events',
    () async {
      final account = _Account();
      final activity = AccountActivityController(account, () async {});
      final response = Completer<http.Response>();
      var gets = 0;
      try {
        await http.runWithClient(
          () async {
            final pending = activity.notifications.refresh();
            await flush();
            activity.dispose();
            response.complete(page([notice('late')]));
            await pending;
            account.webSocket.events.add({'id': 'after-dispose'});
            account.pushNotifications.events.add('after-dispose');
            await flush();
            expect(gets, 1);
            expect(activity.notifications.items, isEmpty);
          },
          () => MockClient((_) {
            gets++;
            return response.future;
          }),
        );
      } finally {
        await account.close();
      }
    },
  );
}
