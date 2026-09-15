import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/social_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import 'auth_page.dart';
import 'friends_page.dart';
import 'journey_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({
    super.key,
    required this.sessionStore,
    this.catStore,
  });

  final SessionStore sessionStore;
  final CatStore? catStore;

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  late final SocialApiService _api;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _feed = [];
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _api = SocialApiService(widget.sessionStore);
    _load();
    _wsSub = widget.sessionStore.webSocket.onFeedUpdate.listen(_handleFeedUpdate);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  void _handleFeedUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type']?.toString();
    final itemId = data['item_id']?.toString();

    if (type == 'like_update' && itemId != null) {
      final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
      if (index != -1) {
        final raw = _feed[index]['payload'];
        final payload = raw is Map<String, dynamic>
            ? raw
            : (_feed[index]['payload'] = Map<String, dynamic>.from(raw as Map? ?? {}));
        final likesCount = (data['likes_count'] as num?)?.toInt();
        final eventUserId = data['user_id']?.toString();
        final isMe = eventUserId != null && eventUserId == widget.sessionStore.session?.userId;

        setState(() {
          if (likesCount != null) payload['likes_count'] = likesCount;
          if (isMe && data.containsKey('liked')) {
            payload['has_liked'] = data['liked'] == true;
          }
        });
      }
    } else if (type == 'new_comment' && itemId != null) {
      final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
      if (index != -1) {
        final raw = _feed[index]['payload'];
        final payload = raw is Map<String, dynamic>
            ? raw
            : (_feed[index]['payload'] = Map<String, dynamic>.from(raw as Map? ?? {}));
        final newComment = data['comment'];
        final comments = List<dynamic>.from(payload['comments'] as List? ?? []);
        if (newComment is Map && !comments.any((c) => c is Map && c['id'] == newComment['id'])) {
          comments.add(newComment);
          setState(() {
            payload['comments'] = comments;
          });
        }
      }
    } else if (type == 'new_post') {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.sessionStore.isSignedIn) return;
    setState(() => _loading = true);
    try {
      final items = await _api.feed();
      if (mounted) {
        setState(() {
          _feed = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike(String itemId) async {
    final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
    if (index == -1) return;

    final rawPayload = _feed[index]['payload'];
    final Map<String, dynamic> payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (_feed[index]['payload'] = Map<String, dynamic>.from(rawPayload as Map? ?? {}));

    final wasLiked = payload['has_liked'] == true;
    final currentLikes = (payload['likes_count'] as num?)?.toInt() ?? 0;
    final newLiked = !wasLiked;
    final newLikes = newLiked ? (currentLikes + 1) : (currentLikes > 0 ? currentLikes - 1 : 0);

    // Atualização otimista imediata na memória
    setState(() {
      payload['has_liked'] = newLiked;
      payload['likes_count'] = newLikes;
    });

    try {
      final result = await _api.toggleLike(itemId);
      if (mounted) {
        setState(() {
          payload['has_liked'] = result['liked'] == true;
          payload['likes_count'] = result['likes_count'] ?? payload['likes_count'];
        });
      }
    } catch (e) {
      // Reverter se houver erro de rede
      if (mounted) {
        setState(() {
          payload['has_liked'] = wasLiked;
          payload['likes_count'] = currentLikes;
        });
        showMessage(context, 'Não foi possível curtir agora: $e');
      }
    }
  }

  void _showCommentsModal(String itemId, String postTitle) {
    final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
    if (index == -1) return;

    final rawPayload = _feed[index]['payload'];
    final Map<String, dynamic> payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (_feed[index]['payload'] = Map<String, dynamic>.from(rawPayload as Map? ?? {}));

    final textController = TextEditingController();
    List<dynamic> comments = List.from(payload['comments'] as List? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SizedBox(
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.messageCircle, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Comentários • $postTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textLight),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.borderLight),
                  Expanded(
                    child: comments.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum comentário ainda. Deixe uma mensagem!',
                              style: GoogleFonts.nunito(color: AppColors.textMedium),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: comments.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final comment = comments[i] as Map;
                              final author = comment['username']?.toString() ?? 'amigo';
                              final text = comment['text']?.toString() ?? '';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.pets, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          '@$author',
                                          style: GoogleFonts.fredoka(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      text,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          decoration: InputDecoration(
                            hintText: 'Escreva um comentário...',
                            hintStyle: GoogleFonts.nunito(fontSize: 13),
                            filled: true,
                            fillColor: AppColors.inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(LucideIcons.send, size: 18),
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isEmpty) return;
                          textController.clear();

                          final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
                          final myName = widget.sessionStore.session?.email.split('@').first ?? 'eu';
                          final optimisticComment = {
                            'id': tempId,
                            'username': myName,
                            'text': text,
                            'created_at': DateTime.now().toUtc().toIso8601String(),
                          };

                          // 1. Atualização otimista imediata no modal e no feed
                          setModalState(() {
                            comments = [...comments, optimisticComment];
                          });
                          setState(() {
                            payload['comments'] = List.from(comments);
                          });

                          try {
                            final updatedComments = await _api.addComment(itemId, text);
                            if (context.mounted) {
                              setModalState(() {
                                comments = updatedComments;
                              });
                            }
                            if (mounted) {
                              setState(() {
                                payload['comments'] = updatedComments;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setModalState(() {
                                comments = comments.where((c) => (c is Map && c['id'] != tempId)).toList();
                              });
                              showMessage(context, 'Erro ao enviar comentário: $e');
                            }
                            if (mounted) {
                              setState(() {
                                payload['comments'] = List.from(comments);
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showShareCatModal() {
    final cats = widget.catStore?.discoveries ?? [];
    if (cats.isEmpty) {
      showMessage(context, 'Você ainda não tem gatos catalogados para compartilhar.');
      return;
    }

    Cat? selectedCat = cats.first;
    final noteController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.share2, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Postar Gato no Feed',
                        style: GoogleFonts.fredoka(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Compartilhe uma descoberta da sua coleção com seus amigos:',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Cat>(
                    initialValue: selectedCat,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    items: cats.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: Image.file(
                                  File(cat.photoPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: AppColors.cardBackground,
                                    child: const Icon(Icons.pets, size: 16, color: AppColors.primary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              cat.displayName,
                              style: GoogleFonts.fredoka(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textTitle,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCat = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    maxLength: 140,
                    decoration: InputDecoration(
                      hintText: 'Escreva uma observação sobre onde o viu...',
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GatalogoButton(
                    text: submitting ? 'Publicando...' : 'Publicar no Feed',
                    isLoading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            if (selectedCat == null) return;
                            setModalState(() => submitting = true);

                            String? photoBase64;
                            try {
                              final file = File(selectedCat!.photoPath);
                              if (await file.exists()) {
                                final bytes = await file.readAsBytes();
                                photoBase64 = base64Encode(bytes);
                              }
                            } catch (_) {}

                            try {
                              final newPost = await _api.createPost(
                                catName: selectedCat!.displayName,
                                note: noteController.text.trim(),
                                locationName: selectedCat!.locationName,
                                photoBase64: photoBase64,
                              );
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                showMessage(context, 'Publicação compartilhada com seus amigos.');
                                setState(() {
                                  _feed.insert(0, newPost);
                                });
                              }
                            } catch (e) {
                              setModalState(() => submitting = false);
                              if (context.mounted) {
                                showMessage(context, 'Erro ao publicar: $e');
                              }
                            }
                          },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sessionStore.isSignedIn) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Comunidade Felina',
            style: GoogleFonts.fredoka(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.globe,
                    size: 48,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Feed de Amigos & Conexões',
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Entre na sua conta para acompanhar as descobertas e conquistas compartilhadas pelos seus amigos!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GatalogoButton(
                  text: 'Entrar na conta',
                  icon: LucideIcons.logIn,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthPage(
                          sessionStore: widget.sessionStore,
                          onContinueOffline: () => Navigator.pop(context),
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Folhagem decorativa
            Positioned(
              top: -10,
              right: -15,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/Folha_1.png',
                  width: 95,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // Cabeçalho da Comunidade
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                      child: Row(
                        children: [
                          if (Navigator.canPop(context)) ...[
                            IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
                              tooltip: 'Voltar',
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Text(
                            'Comunidade',
                            style: GoogleFonts.fredoka(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          const Spacer(),

                          // Atalho direto para MEUS AMIGOS
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FriendsPage(sessionStore: widget.sessionStore),
                              ),
                            ).then((_) => _load()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.socialPurpleBg,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.socialPurple.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.users, size: 16, color: AppColors.socialPurpleText),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Amigos',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.socialPurpleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Atalho para Jornada
                          if (widget.catStore != null)
                            IconButton(
                              tooltip: 'Minhas Conquistas',
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.achievementBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.achievement.withValues(alpha: 0.4)),
                                ),
                                child: const Icon(LucideIcons.trophy, size: 18, color: AppColors.achievementDark),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => JourneyPage(store: widget.catStore!)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Barra de Ação: Botão Postar Gato
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Feed de Amigos',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showShareCatModal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: Text(
                              'Postar Gato',
                              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Erro de Conexão
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Não foi possível atualizar o feed: $_error',
                                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.errorText),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.refreshCw, size: 16),
                                onPressed: _load,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Feed de Itens Reais
                  if (_feed.isEmpty && !_loading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            children: [
                              Image.asset('assets/images/gato_2.png', width: 90),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhuma atividade recente',
                                style: GoogleFonts.fredoka(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTitle,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Quando você ou seus amigos compartilharem conquistas ou postarem fotos de gatos, elas aparecerão aqui!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FriendsPage(sessionStore: widget.sessionStore),
                                      ),
                                    ).then((_) => _load()),
                                    icon: const Icon(LucideIcons.userPlus, size: 16),
                                    label: const Text('Convidar Amigos'),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: _showShareCatModal,
                                    icon: const Icon(LucideIcons.camera, size: 16),
                                    label: const Text('Postar Gato'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _feed[index];
                            final itemId = item['id']?.toString() ?? '';
                            final author = item['username']?.toString() ?? 'amigo';
                            final type = item['type']?.toString() ?? '';
                            final payload = item['payload'] is Map<String, dynamic>
                                ? (item['payload'] as Map<String, dynamic>)
                                : (item['payload'] = Map<String, dynamic>.from(item['payload'] as Map? ?? {}));

                            // 1. Item do Tipo: Conquista Compartilhada
                            if (type == 'achievement') {
                              final title = payload['title']?.toString() ?? 'Nova Conquista!';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.achievementBg,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.achievement.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.achievement.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(LucideIcons.trophy, size: 20, color: AppColors.achievementDark),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '@$author desbloqueou um marco!',
                                              style: GoogleFonts.fredoka(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.achievementText,
                                              ),
                                            ),
                                            Text(
                                              title,
                                              style: GoogleFonts.nunito(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.pets, size: 16, color: AppColors.achievementText),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // 2. Item do Tipo: Postagem de Gato
                            final catName = payload['cat_name']?.toString() ?? 'Gato';
                            final note = payload['note']?.toString() ?? '';
                            final location = payload['location_name']?.toString();
                            final photoBase64 = payload['photo_base64']?.toString();
                            final hasLiked = payload['has_liked'] == true;
                            final likesCount = (payload['likes_count'] as num?)?.toInt() ?? 0;
                            final commentsList = payload['comments'] as List? ?? [];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Autor e Local
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.primarySoftBg,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.borderProfile, width: 1.2),
                                            ),
                                            child: const Icon(LucideIcons.user, size: 20, color: AppColors.primaryDark),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '@$author',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.fredoka(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textTitle,
                                                  ),
                                                ),
                                                if (location != null && location.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      const Icon(LucideIcons.mapPin, size: 11, color: AppColors.textLight),
                                                      const SizedBox(width: 3),
                                                      Expanded(
                                                        child: Text(
                                                          location,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.nunito(
                                                            fontSize: 11,
                                                            color: AppColors.textLight,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Foto do Gato
                                    if (photoBase64 != null && photoBase64.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(AppRadius.photo),
                                          child: SizedBox(
                                            height: 210,
                                            width: double.infinity,
                                            child: Image.memory(
                                              base64Decode(photoBase64),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Image.asset(
                                                'assets/images/gato_1.png',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Nome do Gato e Mensagem
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            catName,
                                            style: GoogleFonts.fredoka(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textTitle,
                                            ),
                                          ),
                                          if (note.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              note,
                                              style: GoogleFonts.nunito(
                                                fontSize: 13,
                                                color: AppColors.textDark,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Ações Reais: Curtir e Comentar
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                                      child: Row(
                                        children: [
                                          // Botão de Curtir com microinteração
                                          InkWell(
                                            onTap: () => _toggleLike(itemId),
                                            borderRadius: BorderRadius.circular(AppRadius.pill),
                                            child: AnimatedContainer(
                                              duration: AppDurations.fast,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: hasLiked ? AppColors.primarySoftBg : AppColors.cardAltBackground,
                                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                                border: Border.all(
                                                  color: hasLiked ? AppColors.borderProfile : AppColors.borderLight,
                                                  width: 1.1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.pets,
                                                    size: 17,
                                                    color: hasLiked ? AppColors.primary : AppColors.textMedium,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '$likesCount',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: hasLiked ? AppColors.primaryDark : AppColors.textDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          // Botão de Comentar em cápsula
                                          InkWell(
                                            onTap: () => _showCommentsModal(itemId, catName),
                                            borderRadius: BorderRadius.circular(AppRadius.pill),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.cardAltBackground,
                                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                                border: Border.all(color: AppColors.borderLight, width: 1.1),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(LucideIcons.messageCircle, size: 16, color: AppColors.textMedium),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${commentsList.length}',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.textDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          const Spacer(),

                                          IconButton(
                                            tooltip: 'Compartilhar',
                                            icon: const Icon(LucideIcons.share2, size: 18, color: AppColors.textLight),
                                            onPressed: () async {
                                              final shareText = StringBuffer()
                                                ..writeln('$catName no Gatalogo')
                                                ..writeln('Registrado por: @$author');
                                              if (location != null && location.isNotEmpty) {
                                                shareText.writeln('Local: $location');
                                              }
                                              if (note.isNotEmpty) {
                                                shareText.writeln('Nota: $note');
                                              }
                                              shareText.writeln('\nDescubra mais gatos no Gatalogo!');
                                              await Clipboard.setData(ClipboardData(text: shareText.toString()));
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Detalhes copiados para a area de transferencia.'),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _feed.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
