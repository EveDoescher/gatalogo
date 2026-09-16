import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../models/conversation_summary.dart';
import '../services/social_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/gatalogo_components.dart';
import 'conversation_page.dart';
import 'friends_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    required this.sessionStore,
    this.embedded = false,
  });

  final SessionStore sessionStore;
  final bool embedded;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late final SocialApiService _api;
  bool _loading = false;
  String? _error;
  List<ConversationSummary> _conversations = [];
  StreamSubscription? _msgSub;
  StreamSubscription? _readSub;
  StreamSubscription? _presenceSub;

  @override
  void initState() {
    super.initState();
    _api = SocialApiService(widget.sessionStore);
    _load();

    final ws = widget.sessionStore.webSocket;
    _msgSub = ws.onMessage.listen((_) => _load(silent: true));
    _readSub = ws.onMessagesRead.listen((_) => _load(silent: true));
    _presenceSub = ws.onPresence.listen((data) {
      final userId = data['user_id']?.toString();
      final isOnline = data['is_online'] == true;
      if (userId != null && mounted) {
        setState(() {
          _conversations = _conversations.map((conv) {
            if (conv.otherUserId == userId) {
              return ConversationSummary(
                id: conv.id,
                otherUserId: conv.otherUserId,
                otherUsername: conv.otherUsername,
                otherAvatarUrl: conv.otherAvatarUrl,
                isOnline: isOnline,
                lastSeenAt: conv.lastSeenAt,
                lastMessage: conv.lastMessage,
                unreadCount: conv.unreadCount,
                sightingContext: conv.sightingContext,
                updatedAt: conv.updatedAt,
              );
            }
            return conv;
          }).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _readSub?.cancel();
    _presenceSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!widget.sessionStore.isSignedIn) return;
    if (!silent) setState(() => _loading = true);

    try {
      final list = await _api.conversations();
      final summaries = list.map((m) => ConversationSummary.fromMap(m)).toList();
      if (mounted) {
        setState(() {
          _conversations = summaries;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _error = 'Não foi possível carregar as conversas.');
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _openConversation(String conversationId, [ConversationSummary? conv]) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ConversationPage(
              sessionStore: widget.sessionStore,
              conversationId: conversationId,
              initialUsername: conv?.otherUsername,
              initialAvatarUrl: conv?.otherAvatarUrl,
              initialIsOnline: conv?.isOnline,
              initialSightingContext: conv?.sightingContext,
              otherUserId: conv?.otherUserId,
            ),
          ),
        )
        .then((_) => _load(silent: true));
  }

  Widget _buildAvatar(ConversationSummary conv) {
    final avatarUrl = conv.otherAvatarUrl;
    final initial = conv.otherUsername.isNotEmpty
        ? conv.otherUsername[0].toUpperCase()
        : '?';

    Widget avatarContent;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final fullUrl = avatarUrl.startsWith('http')
          ? avatarUrl
          : '${ApiConfig.baseUrl}$avatarUrl';
      avatarContent = ClipOval(
        child: Image.network(
          fullUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackAvatar(initial),
        ),
      );
    } else {
      avatarContent = _fallbackAvatar(initial);
    }

    return Stack(
      children: [
        avatarContent,
        if (conv.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.greenProgress,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallbackAvatar(String initial) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primarySoftBg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderProfile, width: 1.4),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/gato_1.png',
              width: 90,
              errorBuilder: (_, _, _) => const Icon(
                LucideIcons.messageCircle,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhuma conversa ainda',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Suas conversas com amigos e avisos de resgate de gatos perdidos aparecerão aqui.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FriendsPage(sessionStore: widget.sessionStore),
                  ),
                );
              },
              icon: const Icon(LucideIcons.users, size: 18),
              label: Text(
                'Conversar com Amigos',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading && _conversations.isEmpty
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null && _conversations.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: GoogleFonts.nunito(color: AppColors.errorText)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _load(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            : _conversations.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => _load(),
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final lastMsg = conv.lastMessage;
                        final preview = lastMsg?.previewText ?? 'Conversa iniciada';
                        final isUnread = conv.unreadCount > 0;

                        return GatalogoCard(
                          backgroundColor: isUnread
                              ? AppColors.primarySoftBg.withValues(alpha: 0.35)
                              : AppColors.surface,
                          onTap: () => _openConversation(conv.id, conv),
                          child: Row(
                            children: [
                              _buildAvatar(conv),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '@${conv.otherUsername}',
                                            style: GoogleFonts.fredoka(
                                              fontSize: 16,
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: AppColors.textTitle,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          conv.formattedTime,
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            fontWeight: isUnread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isUnread
                                                ? AppColors.primary
                                                : AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (conv.sightingContext) ...[
                                          Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.greenLight,
                                              borderRadius:
                                                  BorderRadius.circular(AppRadius.xs),
                                              border: Border.all(
                                                color: AppColors.green
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.pets,
                                                  size: 10,
                                                  color: AppColors.greenLink,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Pista',
                                                  style: GoogleFonts.fredoka(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.greenLink,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        Expanded(
                                          child: Text(
                                            preview,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.nunito(
                                              fontSize: 13,
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isUnread
                                                  ? AppColors.textDark
                                                  : AppColors.textMedium,
                                            ),
                                          ),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(
                                                AppRadius.pill,
                                              ),
                                            ),
                                            child: Text(
                                              conv.unreadCount.toString(),
                                              style: GoogleFonts.fredoka(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        title: Text(
          'Mensagens',
          style: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Nova conversa com amigo',
            icon: const Icon(LucideIcons.userPlus, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendsPage(sessionStore: widget.sessionStore),
                ),
              );
            },
          ),
        ],
      ),
      body: content,
    );
  }
}
