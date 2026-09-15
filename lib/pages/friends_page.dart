import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/social_api_service.dart';
import '../services/product_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import 'conversation_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.sessionStore});

  final SessionStore sessionStore;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final SocialApiService _api;
  late final ProductApiService _product;
  final _inviteController = TextEditingController();
  bool _loading = false;
  bool _busy = false;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _invites = [];
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _api = SocialApiService(widget.sessionStore);
    _product = ProductApiService(widget.sessionStore);
    _load();
    _wsSub = widget.sessionStore.webSocket.onNotification.listen((_) => _load());
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.sessionStore.isSignedIn) return;
    setState(() => _loading = true);
    try {
      final data = await Future.wait([
        _api.friends(),
        _api.invites(),
      ]);
      if (mounted) {
        setState(() {
          _friends = data[0];
          _invites = data[1];
        });
      }
    } catch (_) {
      // Offline fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decideInvite(String inviteId, bool accept) async {
    final inviteIdx = _invites.indexWhere((i) => i['id'] == inviteId);
    if (inviteIdx == -1) return;
    final invite = _invites[inviteIdx];
    final sender = (invite['sender'] as Map?) != null
        ? Map<String, dynamic>.from(invite['sender'] as Map)
        : null;

    setState(() {
      _invites.removeAt(inviteIdx);
      if (accept && sender != null) {
        _friends.add(sender);
      }
    });

    try {
      await _api.decideInvite(inviteId, accept);
      _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _invites.insert(inviteIdx, invite);
          if (accept && sender != null) {
            _friends.removeWhere((f) => f['id'] == sender['id']);
          }
        });
        showMessage(context, 'Não foi possível responder ao convite: $e');
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final idx = _friends.indexWhere((f) => f['id']?.toString() == friendId);
    if (idx == -1) return;
    final removed = _friends[idx];

    setState(() {
      _friends.removeAt(idx);
    });

    try {
      await _api.removeFriend(friendId);
      _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _friends.insert(idx, removed);
        });
        showMessage(context, 'Não foi possível remover amigo: $e');
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final received = _invites.where(
      (item) =>
          item['status'] == 'pending' &&
          (item['recipient'] as Map?)?['id'] == widget.sessionStore.session?.userId,
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Meus Amigos',
          style: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.textMedium, size: 18),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading && _friends.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // 1. Campo de Adicionar Amigo
                  GatalogoCard(
                    backgroundColor: AppColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.userPlus, color: AppColors.primaryDark, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Adicionar Conexão',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTitle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Digite o @nome da pessoa para conversarem e trocarem pistas:',
                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inviteController,
                                autocorrect: false,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                                decoration: InputDecoration(
                                  hintText: '@nome_do_amigo',
                                  prefixIcon: const Icon(LucideIcons.atSign, size: 18),
                                  filled: true,
                                  fillColor: AppColors.inputBg,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.input),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                          final clean = _inviteController.text
                                              .trim()
                                              .replaceFirst('@', '')
                                              .toLowerCase();
                                          if (clean.isEmpty) return;
                                          final messenger = ScaffoldMessenger.of(context);
                                          await _api.invite(clean);
                                          _inviteController.clear();
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(content: Text('Convite enviado para @$clean!')),
                                            );
                                          }
                                        }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                ),
                                child: const Icon(LucideIcons.send, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Convites Pendentes
                  if (received.isNotEmpty) ...[
                    Text(
                      'Convites Recebidos (${received.length})',
                      style: GoogleFonts.fredoka(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...received.map((invite) {
                      final senderName = (invite['sender'] as Map?)?['username'] ?? 'explorador';
                      final inviteId = invite['id'] as String;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GatalogoCard(
                          backgroundColor: AppColors.primarySoftBg,
                          child: Row(
                            children: [
                              const Icon(LucideIcons.mail, size: 20, color: AppColors.primaryDark),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '@$senderName quer ser seu amigo!',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Aceitar',
                                icon: const Icon(LucideIcons.check, color: AppColors.greenLink),
                                onPressed: () => _decideInvite(inviteId, true),
                              ),
                              IconButton(
                                tooltip: 'Recusar',
                                icon: const Icon(LucideIcons.x, color: AppColors.error),
                                onPressed: () => _decideInvite(inviteId, false),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                  ],

                  // 3. Lista de Amigos
                  Row(
                    children: [
                      Text(
                        'Amigos & Conversas (${_friends.length})',
                        style: GoogleFonts.fredoka(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_friends.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Image.asset('assets/images/gato_2.png', width: 80),
                          const SizedBox(height: 10),
                          Text(
                            'Nenhum amigo adicionado ainda',
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Envie um convite usando o @nome de um amigo para começarem a trocar mensagens!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._friends.map((friend) {
                      final friendName = friend['username']?.toString() ?? 'amigo';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GatalogoCard(
                          backgroundColor: AppColors.surface,
                          onTap: _busy
                              ? null
                              : () => _run(() async {
                                    final conv = await _product.post(
                                      '/app/friends/${friend['id']}/conversation',
                                    );
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ConversationPage(
                                            sessionStore: widget.sessionStore,
                                            conversationId: conv['id'] as String,
                                          ),
                                        ),
                                      );
                                    }
                                  }),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoftBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.borderProfile, width: 1.4),
                                ),
                                child: const Icon(
                                  LucideIcons.user,
                                  color: AppColors.primaryDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '@$friendName',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textTitle,
                                      ),
                                    ),
                                    Text(
                                      'Toque para abrir a conversa',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: AppColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.greenLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.messageCircle,
                                  size: 18,
                                  color: AppColors.greenLink,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remover amigo',
                                icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.textLight),
                                onPressed: () async {
                                  final remove = await confirmAction(
                                    context,
                                    'Remover amigo?',
                                    'Deseja remover @$friendName da sua lista de amigos?',
                                    'Remover',
                                  );
                                  if (remove) {
                                    await _removeFriend(friend['id'] as String);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
