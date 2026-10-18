import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/services/push_notification_service.dart';
import 'package:catlogue/stores/session_store.dart';

class _Source implements PushMessagingSource {
  final incoming = StreamController<RemoteMessage>.broadcast();
  final opened = StreamController<RemoteMessage>.broadcast();
  final tokens = StreamController<String>.broadcast();
  RemoteMessage? initial;
  Completer<RemoteMessage?>? pendingInitial;
  bool allowed = true;
  int permissionCalls = 0, tokenCalls = 0;
  @override
  bool get supported => true;
  @override
  Future<void> initialize() async {}
  @override
  Stream<RemoteMessage> get messages => incoming.stream;
  @override
  Stream<RemoteMessage> get openedMessages => opened.stream;
  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Future<RemoteMessage?> initialMessage() async =>
      pendingInitial == null ? initial : pendingInitial!.future;
  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return allowed;
  }

  @override
  Future<String?> token() async {
    tokenCalls++;
    return null;
  }

  Future<void> close() async {
    await incoming.close();
    await opened.close();
    await tokens.close();
  }
}

class _SignedIn extends SessionStore {
  @override
  bool get isSignedIn => true;
}

RemoteMessage notice(String id) => RemoteMessage(
  data: {'notification_id': id},
  notification: const RemoteNotification(title: 'Quintal pronto'),
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'closed-app tap is consumed once; delivered tap is never queued again',
    () async {
      final session = SessionStore(),
          source = _Source()..initial = notice('cold');
      final service = PushNotificationService(session, source: source);
      await service.initialize();
      expect(service.takePendingOpenedNotification(), 'cold');
      expect(service.takePendingOpenedNotification(), isNull);
      final opened = <String>[];
      final subscription = service.onOpenedNotification.listen(opened.add);
      source.opened.add(notice('active'));
      source.opened.add(notice('active'));
      await flush();
      expect(opened, ['active']);
      expect(service.takePendingOpenedNotification(), isNull);
      await subscription.cancel();
      source.opened.add(notice('next-cold'));
      await flush();
      expect(service.takePendingOpenedNotification(), 'next-cold');
      await service.dispose();
      await source.close();
      session.dispose();
    },
  );
  test(
    'foreground retries refresh inbox and show the message only once',
    () async {
      final session = SessionStore(), source = _Source();
      final service = PushNotificationService(session, source: source);
      final ids = <String>[], messages = <PushMessage>[];
      final first = service.onNotification.listen(ids.add),
          second = service.onMessage.listen(messages.add);
      await service.initialize();
      await service.initialize();
      source.incoming.add(notice('a'));
      source.incoming.add(notice('a'));
      source.incoming.add(notice('b'));
      source.incoming.add(const RemoteMessage(data: {'notification_id': ''}));
      await flush();
      expect(ids, ['a', 'b']);
      expect(messages.map((m) => m.id), ids);
      await first.cancel();
      await second.cancel();
      await service.dispose();
      expect(source.incoming.hasListener, isFalse);
      expect(source.opened.hasListener, isFalse);
      expect(source.tokens.hasListener, isFalse);
      source.incoming.add(notice('late'));
      source.opened.add(notice('late'));
      await flush();
      await service.dispose();
      await source.close();
      session.dispose();
    },
  );
  test(
    'late initial callback does not reopen a tap already delivered',
    () async {
      final session = SessionStore(),
          source = _Source()..pendingInitial = Completer<RemoteMessage?>();
      final service = PushNotificationService(session, source: source);
      final ids = <String>[];
      final subscription = service.onOpenedNotification.listen(ids.add);
      final initializing = service.initialize();
      await flush();
      source.opened.add(notice('same'));
      await flush();
      source.pendingInitial!.complete(notice('same'));
      await initializing;
      await flush();
      expect(ids, ['same']);
      expect(service.takePendingOpenedNotification(), isNull);
      await subscription.cancel();
      await service.dispose();
      await source.close();
      session.dispose();
    },
  );
  test(
    'disposal during initial-message lookup cannot attach new listeners',
    () async {
      final session = SessionStore(),
          source = _Source()..pendingInitial = Completer<RemoteMessage?>();
      final service = PushNotificationService(session, source: source);
      final initializing = service.initialize();
      await flush();
      await service.dispose();
      source.pendingInitial!.complete(notice('late'));
      await initializing;
      expect(service.takePendingOpenedNotification(), isNull);
      expect(
        source.incoming.hasListener ||
            source.opened.hasListener ||
            source.tokens.hasListener,
        isFalse,
      );
      await source.close();
      session.dispose();
    },
  );
  test(
    'denied permission leaves inbox available without requesting a token',
    () async {
      final session = _SignedIn(), source = _Source()..allowed = false;
      final service = PushNotificationService(session, source: source);
      final ids = <String>[];
      final subscription = service.onNotification.listen(ids.add);
      await service.initialize();
      expect(source.permissionCalls, 1);
      expect(source.tokenCalls, 0);
      source.incoming.add(notice('inbox'));
      await flush();
      expect(ids, ['inbox']);
      await subscription.cancel();
      await service.dispose();
      await source.close();
      session.dispose();
    },
  );
}
