import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../models/cat.dart';
import '../services/cat_sharing_service.dart';
import '../services/image_compression_service.dart';
import '../services/social_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import 'auth_page.dart';
import 'friends_page.dart';
import 'inbox_page.dart';
import 'journey_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({
    super.key,
    required this.sessionStore,
    this.catStore,
    this.initialTab = 0,
  });

  final SessionStore sessionStore;
  final CatStore? catStore;
  final int initialTab;

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  late final SocialApiService _api;
  late final ScrollController _scrollController;
  bool _loading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _feedMode = 'all'; // 'all' (comunidade) ou 'friends'
  final Map<String, Uint8List> _base64Cache = {};
  String? _error;
  List<Map<String, dynamic>> _feed = [];
  StreamSubscription? _wsSub;
  StreamSubscription? _msgSub;
  StreamSubscription? _readSub;
  int _currentTab = 0;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _api = SocialApiService(widget.sessionStore);
    _scrollController = ScrollController()..addListener(_onScroll);
    _load();
    _fetchUnread();
    _wsSub = widget.sessionStore.webSocket.onFeedUpdate.listen(_handleFeedUpdate);
    _msgSub = widget.sessionStore.webSocket.onMessage.listen((_) => _fetchUnread());
    _readSub = widget.sessionStore.webSocket.onMessagesRead.listen((_) => _fetchUnread());
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        !_isLoadingMore &&
        _hasMore &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _fetchUnread() async {
    if (!widget.sessionStore.isSignedIn) return;
    try {
      final list = await _api.conversations();
      int count = 0;
      for (final item in list) {
        count += (item['unread_count'] as num?)?.toInt() ?? 0;
      }
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _wsSub?.cancel();
    _msgSub?.cancel();
    _readSub?.cancel();
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
      _load(refresh: true);
    }
  }

  Future<void> _load({bool refresh = true}) async {
    if (!widget.sessionStore.isSignedIn) return;
    if (refresh) {
      setState(() {
        _loading = true;
        _hasMore = true;
        _error = null;
      });
    }
    try {
      final items = await _api.feed(limit: 15, mode: _feedMode);
      if (mounted) {
        setState(() {
          _feed = items;
          _hasMore = items.length >= 15;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _feed.isEmpty) return;
    final lastItem = _feed.last;
    final cursor = lastItem['created_at']?.toString();
    if (cursor == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final moreItems = await _api.feed(limit: 15, cursor: cursor, mode: _feedMode);
      if (mounted) {
        setState(() {
          final existingIds = _feed.map((it) => it['id']?.toString()).toSet();
          final newUnique = moreItems.where((it) => !existingIds.contains(it['id']?.toString())).toList();
          _feed.addAll(newUnique);
          _hasMore = moreItems.length >= 15;
        });
      }
    } catch (_) {
      // Ignora falha de paginação silenciosamente
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
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

    if (newLiked) {
      widget.catStore?.recordGamificationAction('like');
    }

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
                            widget.catStore?.recordGamificationAction('comment');
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
    Cat? selectedCat = cats.isNotEmpty ? cats.first : null;
    File? customPhotoFile;
    final catNameController = TextEditingController(text: selectedCat?.displayName ?? '');
    final noteController = TextEditingController();
    final locationController = TextEditingController(text: selectedCat?.locationName ?? '');
    bool isCustomPhoto = cats.isEmpty;
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
                        'Postar no Feed',
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

                  // Segmented Switch: Gato Catalogado vs Foto da Hora
                  if (cats.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() {
                              isCustomPhoto = false;
                              if (selectedCat != null) {
                                catNameController.text = selectedCat!.displayName;
                                locationController.text = selectedCat!.locationName ?? '';
                              }
                            }),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isCustomPhoto ? AppColors.primary : AppColors.inputBg,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Da Coleção',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: !isCustomPhoto ? Colors.white : AppColors.textMedium,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() {
                              isCustomPhoto = true;
                              catNameController.text = '';
                            }),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isCustomPhoto ? AppColors.primary : AppColors.inputBg,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Foto da Hora',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCustomPhoto ? Colors.white : AppColors.textMedium,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (!isCustomPhoto && cats.isNotEmpty) ...[
                    Text(
                      'Selecione um gato da sua coleção:',
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                    ),
                    const SizedBox(height: 8),
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
                        if (val != null) {
                          setModalState(() {
                            selectedCat = val;
                            catNameController.text = val.displayName;
                            locationController.text = val.locationName ?? '';
                          });
                        }
                      },
                    ),
                  ] else ...[
                    Text(
                      'Adicione uma foto do gato:',
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                    ),
                    const SizedBox(height: 8),
                    if (customPhotoFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: Image.file(customPhotoFile!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.camera);
                              if (picked != null) {
                                setModalState(() => customPhotoFile = File(picked.path));
                              }
                            },
                            icon: const Icon(LucideIcons.camera, size: 16),
                            label: const Text('Câmera'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery);
                              if (picked != null) {
                                setModalState(() => customPhotoFile = File(picked.path));
                              }
                            },
                            icon: const Icon(LucideIcons.image, size: 16),
                            label: const Text('Galeria'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: catNameController,
                      decoration: InputDecoration(
                        labelText: 'Nome do Gato',
                        hintText: 'Ex: Mingau, Gato da Esquina',
                        filled: true,
                        fillColor: AppColors.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],

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
                            final name = isCustomPhoto
                                ? catNameController.text.trim()
                                : (selectedCat?.displayName ?? '');
                            if (name.isEmpty) {
                              showMessage(context, 'Informe o nome do gato para publicar.');
                              return;
                            }

                            setModalState(() => submitting = true);

                            String? photoUrl;
                            File? photoToUpload;
                            if (isCustomPhoto) {
                              photoToUpload = customPhotoFile;
                            } else if (selectedCat != null) {
                              final f = File(selectedCat!.photoPath);
                              if (await f.exists()) photoToUpload = f;
                            }

                            if (photoToUpload != null) {
                              try {
                                final rawBytes = await photoToUpload.readAsBytes();
                                final compressedBytes = await ImageCompressionService.compressImage(rawBytes);
                                final uploadedUrl = await _api.uploadPostPhoto(
                                  compressedBytes,
                                  'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                );
                                if (uploadedUrl != null) {
                                  photoUrl = uploadedUrl;
                                }
                              } catch (_) {}
                            }

                            try {
                              final location = isCustomPhoto
                                  ? (locationController.text.trim().isNotEmpty ? locationController.text.trim() : null)
                                  : selectedCat?.locationName;

                              final newPost = await _api.createPost(
                                catName: name,
                                note: noteController.text.trim(),
                                locationName: location,
                                photoUrl: photoUrl,
                                isPublic: true,
                              );
                              widget.catStore?.recordGamificationAction('post');
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                showMessage(context, 'Publicação compartilhada com a comunidade.');
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

  Widget _buildPostMedia(Map<String, dynamic> payload) {
    final photoUrl = payload['photo_url']?.toString();
    final photoBase64 = payload['photo_base64']?.toString();

    if (photoUrl != null && photoUrl.isNotEmpty) {
      final token = widget.sessionStore.session?.accessToken;
      final fullUrl = photoUrl.startsWith('http')
          ? photoUrl
          : '${ApiConfig.baseUrl}$photoUrl${token != null ? '?token=$token' : ''}';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.photo),
          child: SizedBox(
            height: 210,
            width: double.infinity,
            child: Image.network(
              fullUrl,
              fit: BoxFit.cover,
              cacheWidth: 800,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(LucideIcons.imageOff, color: AppColors.textLight, size: 28),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      Uint8List? cached = _base64Cache[photoBase64];
      if (cached == null) {
        try {
          cached = base64Decode(photoBase64);
          _base64Cache[photoBase64] = cached;
        } catch (_) {}
      }
      if (cached != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.photo),
            child: SizedBox(
              height: 210,
              width: double.infinity,
              child: Image.memory(
                cached,
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(LucideIcons.imageOff, color: AppColors.textLight, size: 28),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildTipCard(Map<String, dynamic> item, Map<String, dynamic> payload, String itemId) {
    final title = payload['title']?.toString() ?? 'Dica Gatálogo';
    final note = payload['note']?.toString() ?? '';
    final actionText = payload['action_text']?.toString();
    final hasLiked = payload['has_liked'] == true;
    final likesCount = (payload['likes_count'] as num?)?.toInt() ?? 0;
    final commentsList = payload['comments'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      border: Border.all(color: AppColors.primary, width: 1.4),
                    ),
                    child: const Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@gatalogo_oficial',
                              style: GoogleFonts.fredoka(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTitle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'OFICIAL',
                                style: GoogleFonts.nunito(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Guia de Boas Práticas',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.fredoka(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                  if (actionText != null && actionText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Toque no botão central da barra inferior para fotografar seu primeiro gato!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.arrowRight, size: 16),
                      label: Text(actionText),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _toggleLike(itemId),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasLiked ? AppColors.primarySoftBg : AppColors.cardAltBackground,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: hasLiked ? AppColors.primary : AppColors.borderLight,
                          width: 1.1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasLiked ? LucideIcons.heartHandshake : LucideIcons.heart,
                            size: 16,
                            color: hasLiked ? AppColors.primaryDark : AppColors.textMedium,
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
                  InkWell(
                    onTap: () => _showCommentsModal(itemId, title),
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
                    tooltip: 'Compartilhar dica',
                    icon: const Icon(LucideIcons.share2, size: 18, color: AppColors.textLight),
                    onPressed: () {
                      CatSharingService.sharePost(
                        catName: title,
                        author: 'gatalogo_oficial',
                        note: note,
                      );
                      widget.catStore?.recordGamificationAction('share');
                    },
                  ),
                ],
              ),
            ),
          ],
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
                controller: _scrollController,
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

                  // Segmented Bar: Feed Social vs Conversas (com badge de não lidas)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              onTap: () => setState(() => _currentTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentTab == 0 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.newspaper,
                                      size: 16,
                                      color: _currentTab == 0 ? Colors.white : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Feed Social',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _currentTab == 0 ? Colors.white : AppColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              onTap: () => setState(() => _currentTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentTab == 1 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.messageSquare,
                                      size: 16,
                                      color: _currentTab == 1 ? Colors.white : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Conversas',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _currentTab == 1 ? Colors.white : AppColors.textMedium,
                                      ),
                                    ),
                                    if (_unreadMessages > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: _currentTab == 1 ? Colors.white : AppColors.primary,
                                          borderRadius: BorderRadius.circular(AppRadius.pill),
                                        ),
                                        child: Text(
                                          '$_unreadMessages',
                                          style: GoogleFonts.fredoka(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _currentTab == 1 ? AppColors.primary : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_currentTab == 1)
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: InboxPage(
                        sessionStore: widget.sessionStore,
                        embedded: true,
                      ),
                    )
                  else ...[
                    // Barra de Filtro de Feed e Ação de Postar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Row(
                          children: [
                            // Pills: Comunidade vs Amigos
                            InkWell(
                              onTap: () {
                                if (_feedMode != 'all') {
                                  setState(() => _feedMode = 'all');
                                  _load(refresh: true);
                                }
                              },
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _feedMode == 'all' ? AppColors.primary : AppColors.cardAltBackground,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(
                                    color: _feedMode == 'all' ? AppColors.primary : AppColors.borderLight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.globe,
                                      size: 13,
                                      color: _feedMode == 'all' ? Colors.white : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Comunidade',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _feedMode == 'all' ? Colors.white : AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                if (_feedMode != 'friends') {
                                  setState(() => _feedMode = 'friends');
                                  _load(refresh: true);
                                }
                              },
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _feedMode == 'friends' ? AppColors.primary : AppColors.cardAltBackground,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(
                                    color: _feedMode == 'friends' ? AppColors.primary : AppColors.borderLight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.users,
                                      size: 13,
                                      color: _feedMode == 'friends' ? Colors.white : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Amigos',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _feedMode == 'friends' ? Colors.white : AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: _showShareCatModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                              icon: const Icon(LucideIcons.plus, size: 15),
                              label: Text(
                                'Postar Gato',
                                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800),
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

                            if (type == 'tip') {
                              return _buildTipCard(item, payload, itemId);
                            }

                            // 2. Item do Tipo: Postagem de Gato
                            final catName = payload['cat_name']?.toString() ?? 'Gato';
                            final note = payload['note']?.toString() ?? '';
                            final location = payload['location_name']?.toString();
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

                                    // Midia do Gato com cache e streaming de URL
                                    _buildPostMedia(payload),

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
                                            onPressed: () {
                                              CatSharingService.sharePost(
                                                author: author,
                                                catName: catName,
                                                note: note,
                                                location: location,
                                              );
                                              widget.catStore?.recordGamificationAction('share');
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
                  ],

                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
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
