import 'package:flutter/material.dart';

import '../stores/cat_store.dart';
import 'app_widgets.dart';
import 'inbox_button.dart';

class AppStoreScope extends InheritedWidget {
  const AppStoreScope({super.key, required this.store, required super.child});
  final CatStore store;

  static CatStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStoreScope>()?.store;

  @override
  bool updateShouldNotify(AppStoreScope oldWidget) => store != oldWidget.store;
}

class AppHeaderActions extends StatelessWidget {
  const AppHeaderActions({super.key, this.store});
  final CatStore? store;

  @override
  Widget build(BuildContext context) {
    final current = store ?? AppStoreScope.maybeOf(context);
    if (current == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InboxButton(store: current),
          const SizedBox(width: 8),
          UserAvatarButton(
            sessionStore: current.sessionStore,
            catStore: current,
          ),
        ],
      ),
    );
  }
}
