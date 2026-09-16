import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../pages/inbox_page.dart';
import '../services/social_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';

class ChatIconButton extends StatefulWidget {
  const ChatIconButton({
    super.key,
    required this.sessionStore,
    this.size = 42,
  });

  final SessionStore sessionStore;
  final double size;

  @override
  State<ChatIconButton> createState() => _ChatIconButtonState();
}

class _ChatIconButtonState extends State<ChatIconButton>
    with WidgetsBindingObserver {
  int _unreadCount = 0;
  bool _fetching = false;
  StreamSubscription? _msgSub;
  StreamSubscription? _readSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    final ws = widget.sessionStore.webSocket;
    _msgSub = ws.onMessage.listen((_) => _refresh());
    _readSub = ws.onMessagesRead.listen((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgSub?.cancel();
    _readSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_fetching || !widget.sessionStore.isSignedIn) return;
    _fetching = true;
    try {
      final list = await SocialApiService(widget.sessionStore).conversations();
      int unread = 0;
      for (final conv in list) {
        unread += (conv['unread_count'] as num?)?.toInt() ?? 0;
      }
      if (mounted) {
        setState(() => _unreadCount = unread);
      }
    } catch (_) {
      // Ignora erro de rede em atualização de badge
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.size * 0.48;

    return Semantics(
      label: _unreadCount > 0
          ? 'Mensagens, $_unreadCount não lidas'
          : 'Mensagens',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.size / 2),
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => InboxPage(sessionStore: widget.sessionStore),
                  ),
                )
                .then((_) => _refresh());
          },
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.messageSquare,
                      size: iconSize,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: _unreadCount > 9 ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: _unreadCount > 9 ? BorderRadius.circular(AppRadius.pill) : null,
                        border: Border.all(color: AppColors.surface, width: 1.8),
                      ),
                      child: Center(
                        child: Text(
                          _unreadCount > 99 ? '99+' : '$_unreadCount',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
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
