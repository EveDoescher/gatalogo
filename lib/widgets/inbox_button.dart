import 'dart:async';

import 'package:flutter/material.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../pages/notifications_page.dart';

class InboxButton extends StatefulWidget {
  const InboxButton({super.key, required this.store});
  final CatStore store;
  @override
  State<InboxButton> createState() => _InboxButtonState();
}

class _InboxButtonState extends State<InboxButton> with WidgetsBindingObserver {
  int _unread = 0;
  bool _fetching = false, _active = true;
  Timer? _timer;
  StreamSubscription? _wsSub;
  StreamSubscription? _pushSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _wsSub = widget.store.sessionStore.webSocket.onNotification.listen((_) {
      _refresh();
    });
    _pushSub = widget.store.sessionStore.pushNotifications.onNotification
        .listen((_) {
          _refresh();
        });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_active) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _refresh();
  }

  Future<void> _refresh() async {
    if (_fetching || !widget.store.sessionStore.isSignedIn) return;
    _fetching = true;
    try {
      final api = ProductApiService(widget.store.sessionStore);
      await api.list('/app/journey');
      final notices = await api.list('/vision/notifications');
      if (mounted) {
        setState(
          () =>
              _unread = notices.where((item) => item['read_at'] == null).length,
        );
      }
    } catch (_) {
      /* Keep the last known inbox count during a connection failure. */
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _pushSub?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Notificações',
    icon: Badge.count(
      count: _unread,
      isLabelVisible: _unread > 0,
      child: const Icon(Icons.notifications_outlined),
    ),
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsPage(store: widget.store),
        ),
      );
      if (mounted) _refresh();
    },
  );
}
