import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/stores/notification_store.dart';

void main() {
  test(
    'all listeners see the same unread count immediately after reading',
    () async {
      final store = NotificationStore(
        loadItems: () async => [
          {'id': 'a', 'read_at': null},
          {'id': 'b', 'read_at': null},
        ],
        saveRead: (_) async {},
      );
      addTearDown(store.dispose);
      final firstScreen = <int>[], secondScreen = <int>[];
      store.addListener(() => firstScreen.add(store.unreadCount));
      store.addListener(() => secondScreen.add(store.unreadCount));
      await store.refresh();
      await store.markRead('a');
      expect(firstScreen, [2, 1]);
      expect(secondScreen, firstScreen);
      await store.refresh();
      expect(
        store.unreadCount,
        1,
        reason: 'A stale response must not undo a confirmed read',
      );
    },
  );

  test(
    'deduplicates refreshes and retains the snapshot on network failure',
    () async {
      var calls = 0;
      final pending = Completer<List<Map<String, dynamic>>>();
      final store = NotificationStore(
        loadItems: () {
          calls++;
          if (calls > 1) throw StateError('offline');
          return pending.future;
        },
        saveRead: (_) async {},
      );
      addTearDown(store.dispose);
      final first = store.refresh(), second = store.refresh();
      expect(calls, 1);
      pending.complete([
        {'id': 'a'},
      ]);
      await Future.wait([first, second]);
      expect(store.unreadCount, 1);
      await expectLater(store.refresh(), throwsStateError);
      expect(store.unreadCount, 1);
    },
  );

  test(
    'rejects stale requests after account switch and allows a fresh request',
    () async {
      final old = Completer<List<Map<String, dynamic>>>();
      final fresh = Completer<List<Map<String, dynamic>>>();
      var calls = 0;
      final store = NotificationStore(
        loadItems: () => ++calls == 1 ? old.future : fresh.future,
        saveRead: (_) async {},
      );
      addTearDown(store.dispose);
      final previous = store.refresh();
      store.clear();
      final current = store.refresh();
      fresh.complete([
        {'id': 'new'},
      ]);
      await current;
      old.complete([
        {'id': 'old'},
        {'id': 'old2'},
      ]);
      await previous;
      expect(store.items.single['id'], 'new');
    },
  );

  test('failed mark-read keeps the notification unread', () async {
    final store = NotificationStore(
      loadItems: () async => [
        {'id': 'a'},
      ],
      saveRead: (_) async => throw StateError('offline'),
    );
    addTearDown(store.dispose);
    await store.refresh();
    await expectLater(store.markRead('a'), throwsStateError);
    expect(store.unreadCount, 1);
  });
}
