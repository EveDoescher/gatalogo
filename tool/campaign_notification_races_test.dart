// Local inbox races; transport triggers are simulated, no Firebase delivery claim.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/stores/notification_store.dart';

Map<String, dynamic> item(String id) => {
  'id': id,
  'created_at': '2026-10-23T12:00:00Z',
};

void main() {
  for (final boundary in ['refresh', 'clear', 'dispose']) {
    test('DLV05 pending page respects $boundary boundary', () async {
      final page = Completer<List<Map<String, dynamic>>>();
      final saved = Completer<void>();
      var owner = 'a';
      final store = NotificationStore(
        loadItems: () async => [],
        loadPage: (time, id) async {
          if (id != null) return page.future;
          return [for (var i = 0; i < 20; i++) item('$owner-$i')];
        },
        saveRead: (_) => saved.future,
      );
      var disposed = false;
      try {
        await store.refresh();
        final more = store.loadMore();
        final read = store.markRead('a-0');
        if (boundary == 'clear') {
          store.clear();
          owner = 'b';
          await store.refresh();
        } else if (boundary == 'dispose') {
          store.dispose();
          disposed = true;
        } else {
          await store.refresh();
        }
        saved.complete();
        await read;
        page.complete([item('a-0'), item('a-old')]);
        await more;
        if (boundary == 'clear') {
          expect(
            store.items.every((e) => '${e['id']}'.startsWith('b-')),
            isTrue,
          );
          expect(store.unreadCount, 20);
        } else if (boundary == 'refresh') {
          expect(store.items.length, 21);
          expect(store.items.map((e) => e['id']).toSet().length, 21);
          expect(
            store.items.singleWhere((e) => e['id'] == 'a-0')['read_at'],
            isNotNull,
          );
          expect(store.unreadCount, 20);
          expect(store.loadingMore, isFalse);
        }
      } finally {
        if (!disposed) store.dispose();
      }
    });
  }
  test('DLV05 failed page can retry without losing current inbox', () async {
    var failed = true;
    final store = NotificationStore(
      loadItems: () async => [],
      saveRead: (_) async {},
      loadPage: (time, id) async {
        if (id == null) return [for (var i = 0; i < 20; i++) item('a-$i')];
        if (failed) throw StateError('synthetic offline');
        return [item('old')];
      },
    );
    try {
      await store.refresh();
      await expectLater(store.loadMore(), throwsStateError);
      expect(store.items.length, 20);
      expect(store.loadingMore, isFalse);
      failed = false;
      await store.loadMore();
      expect(store.items.length, 21);
      expect(store.hasMore, isFalse);
    } finally {
      store.dispose();
    }
  });
}
