import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../stores/cat_store.dart';
import '../pages/notifications_page.dart';
import '../theme/app_theme.dart';

class InboxButton extends StatelessWidget {
  const InboxButton({
    super.key,
    required this.store,
    this.size = 42,
    this.illustrated = false,
  });
  final CatStore store;
  final double size;
  final bool illustrated;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store.notifications,
      builder: (context, _) => GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsPage(store: store)),
          );
          await store.refreshNotifications();
        },
        child: Tooltip(
          message: 'Notificações',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: illustrated ? const Color(0xFFFBF6E8) : AppColors.surface,
              border: Border.all(
                color: illustrated
                    ? const Color(0xFF94724E)
                    : AppColors.borderProfile,
                width: illustrated ? 1.8 : 1.4,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  LucideIcons.bell,
                  size: 20,
                  color: AppColors.textDark,
                ),
                if (store.notifications.unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 200),
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          store.notifications.unreadCount > 99
                              ? '99+'
                              : store.notifications.unreadCount.toString(),
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
