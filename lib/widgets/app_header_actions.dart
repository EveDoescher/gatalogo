import 'package:flutter/material.dart';

import '../stores/cat_store.dart';
import 'app_widgets.dart';
import 'inbox_button.dart';
import 'botanical_scene.dart';
import 'illustrated_home_components.dart';

class IllustratedAppHeader extends StatelessWidget {
  const IllustratedAppHeader({
    super.key,
    required this.store,
    this.onWallet,
    this.showWallet = true,
    this.logoWidth = 140,
  });
  final CatStore store;
  final VoidCallback? onWallet;
  final bool showWallet;
  final double logoWidth;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: GatalogoArt.image(
            'branding/brand_gatalogo_logo',
            width: logoWidth,
            height: 48,
          ),
        ),
      ),
      if (showWallet) ...[
        AccountCoinBadge(store: store, onTap: onWallet),
        const SizedBox(width: 5),
      ],
      InboxButton(store: store, size: 36, illustrated: true),
      const SizedBox(width: 5),
      UserAvatarButton(
        sessionStore: store.sessionStore,
        catStore: store,
        size: 45,
        framed: true,
      ),
    ],
  );
}

class AccountCoinBadge extends StatelessWidget {
  const AccountCoinBadge({super.key, required this.store, this.onTap});
  final CatStore store;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Semantics(
      label: 'Moedas: ${store.progress.summary['balance'] ?? 'indisponíveis'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2D7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFCC994D), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HomeArt.image('Coin', width: 22, height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${store.progress.summary['balance'] ?? '—'}',
                  style: HomeArt.title(15),
                ),
              ),
              if (onTap != null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomeArt.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: HomeArt.paper,
                    size: 23,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppStoreScope extends InheritedWidget {
  const AppStoreScope({super.key, required this.store, required super.child});
  final CatStore store;

  static CatStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStoreScope>()?.store;

  @override
  bool updateShouldNotify(AppStoreScope oldWidget) => store != oldWidget.store;
}

class AppHeaderActions extends StatelessWidget {
  const AppHeaderActions({super.key, this.store, this.showAvatar = true});
  final CatStore? store;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final current = store ?? AppStoreScope.maybeOf(context);
    if (current == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InboxButton(store: current, illustrated: true),
          if (showAvatar) const SizedBox(width: 8),
          if (showAvatar)
            UserAvatarButton(
              sessionStore: current.sessionStore,
              catStore: current,
              framed: true,
            ),
        ],
      ),
    );
  }
}
