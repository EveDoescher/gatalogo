import 'dart:async';

import '../stores/session_store.dart';
import '../stores/notification_store.dart';
import '../services/product_api_service.dart';

/// Inbox refresh and push/socket subscription lifecycle for an account.
class AccountActivityController {
  AccountActivityController(this.session, this.refreshProgress) {
    final productApi = ProductApiService(session);
    notifications = NotificationStore(
      loadPage: (time, id) async => session.isSignedIn
          ? productApi.list(
              '/vision/notifications?limit=20${time == null ? '' : '&cursor=${Uri.encodeComponent(time)}&cursor_id=${Uri.encodeComponent(id!)}'}',
            )
          : [],
      loadItems: () async =>
          session.isSignedIn ? productApi.list('/vision/notifications') : [],
      saveRead: (id) async {
        await productApi.post('/app/notifications/$id/read');
      },
    );
    _notificationSubscription = session.webSocket.onNotification.listen((_) {
      unawaited(refreshNotifications());
      unawaited(refreshProgress());
    });
    _pushSubscription = session.pushNotifications.onNotification.listen((_) {
      unawaited(refreshNotifications());
      unawaited(refreshProgress());
    });
  }
  final SessionStore session;
  final Future<void> Function() refreshProgress;
  late final NotificationStore notifications;
  StreamSubscription? _notificationSubscription, _pushSubscription;
  Future<void> refreshNotifications() async {
    try {
      await notifications.refresh();
    } catch (_) {
      /* Keep the offline snapshot. */
    }
  }

  void dispose() {
    _notificationSubscription?.cancel();
    _pushSubscription?.cancel();
    notifications.dispose();
  }
}
