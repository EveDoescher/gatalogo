import '../widgets/botanical_scene.dart';
import '../widgets/illustrated_home_components.dart';
import '../widgets/app_header_actions.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../data/cat_database.dart';
import '../models/cat.dart';
import '../models/chat_message.dart';
import '../services/location_service.dart';
import '../services/social_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import 'cat_details_page.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.sessionStore,
    required this.conversationId,
    this.catStore,
    this.otherUserId,
    this.initialUsername,
    this.initialAvatarUrl,
    this.initialIsOnline,
    this.initialSightingContext,
  });

  final SessionStore sessionStore;
  final String conversationId;
  final CatStore? catStore;
  final String? otherUserId;
  final String? initialUsername;
  final String? initialAvatarUrl;
  final bool? initialIsOnline;
  final bool? initialSightingContext;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  late final SocialApiService _api;
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  final Set<String> _optimisticIds = {};

  bool _loading = true;
  bool _sending = false;
  bool _fetching = false;
  String? _error;

  String? _username;
  String? _otherUserId;
  String? _avatarUrl;
  bool _isOnline = false;
  DateTime? _lastSeenAt;
  bool _sightingContext = false;
  bool _otherUserTyping = false;
  Timer? _otherTypingDebounceTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  bool _isMuted = false;

  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  Timer? _fallbackPollTimer;
  Timer? _myTypingTimer;
  bool _amTyping = false;

  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _reactionSub;
  StreamSubscription? _editSub;
  StreamSubscription? _deleteSub;

  String? get _myUserId => widget.sessionStore.session?.userId;

  @override
  void initState() {
    super.initState();
    _api = SocialApiService(widget.sessionStore);
    _username = widget.initialUsername;
    _otherUserId = widget.otherUserId;
    _avatarUrl = widget.initialAvatarUrl;
    _isOnline = widget.initialIsOnline ?? false;
    _sightingContext = widget.initialSightingContext ?? false;

    _setupRealtime();
    _load();
  }

  @override
  void dispose() {
    _fallbackPollTimer?.cancel();
    _otherTypingDebounceTimer?.cancel();
    _myTypingTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _presenceSub?.cancel();
    _reactionSub?.cancel();
    _editSub?.cancel();
    _deleteSub?.cancel();

    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    final ws = widget.sessionStore.webSocket;

    // 1. Mensagens em tempo real pontuais
    _msgSub = ws.onNewMessage.listen((data) {
      if (data['conversation_id'] == widget.conversationId) {
        final newMsg = ChatMessage.fromMap(data);
        _handleIncomingMessage(newMsg);
      }
    });

    // 2. Indicador de digitação
    _typingSub = ws.onTyping.listen((data) {
      if (data['conversation_id'] == widget.conversationId &&
          data['user_id'] != _myUserId) {
        final isTyping = data['is_typing'] == true;
        if (mounted) {
          setState(() {
            _otherUserTyping = isTyping;
          });
        }
        _otherTypingDebounceTimer?.cancel();
        if (isTyping) {
          _otherTypingDebounceTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _otherUserTyping = false);
          });
        }
      }
    });

    // 3. Confirmação de leitura
    _readSub = ws.onMessagesRead.listen((data) {
      if (data['conversation_id'] == widget.conversationId) {
        final readAtStr = data['read_at'];
        final readAt = readAtStr != null
            ? DateTime.tryParse(readAtStr)
            : DateTime.now();
        if (mounted) {
          setState(() {
            _messages = _messages.map((m) {
              if (m.isMine(_myUserId)) {
                return m.copyWith(isRead: true, readAt: readAt);
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 4. Presença online / visto por último
    _presenceSub = ws.onPresence.listen((data) {
      final userId = data['user_id']?.toString();
      if (userId != null && (_otherUserId == null || userId == _otherUserId)) {
        if (mounted) {
          setState(() {
            _isOnline = data['is_online'] == true;
            if (data['last_seen_at'] != null) {
              _lastSeenAt = DateTime.tryParse(data['last_seen_at'].toString());
            }
          });
        }
      }
    });

    // 5. Reações pontuais
    _reactionSub = ws.onMessageReaction.listen((data) {
      if (data['conversation_id'] == widget.conversationId) {
        final msgId = data['message_id']?.toString();
        final rawMap = data['reactions'] as Map?;
        if (msgId != null && rawMap != null && mounted) {
          final updatedReactions = <String, List<String>>{};
          rawMap.forEach((k, v) {
            if (v is List) {
              updatedReactions[k.toString()] = v
                  .map((e) => e.toString())
                  .toList();
            }
          });
          setState(() {
            _messages = _messages.map((m) {
              if (m.id == msgId) {
                return m.copyWith(reactions: updatedReactions);
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 6. Mensagem editada pontual
    _editSub = ws.onMessageEdited.listen((data) {
      if (data['conversation_id'] == widget.conversationId) {
        final msgId = data['message_id']?.toString();
        final newBody = data['body']?.toString() ?? '';
        if (msgId != null && mounted) {
          setState(() {
            _messages = _messages.map((m) {
              if (m.id == msgId) {
                return m.copyWith(body: newBody, isEdited: true);
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 7. Mensagem apagada pontual
    _deleteSub = ws.onMessageDeleted.listen((data) {
      if (data['conversation_id'] == widget.conversationId) {
        final msgId = data['message_id']?.toString();
        if (msgId != null && mounted) {
          setState(() {
            _messages = _messages.map((m) {
              if (m.id == msgId) {
                return m.copyWith(isDeleted: true, body: 'Mensagem apagada');
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 8. Fallback de polling a cada 30s APENAS se o WebSocket NÃO estiver conectado
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!widget.sessionStore.webSocket.isConnected) {
        _load(silent: true);
      }
    });
  }

  void _handleIncomingMessage(ChatMessage newMsg) {
    if (!mounted) return;
    setState(() {
      final existingIndex = _messages.indexWhere((m) => m.id == newMsg.id);
      if (existingIndex >= 0) {
        _messages[existingIndex] = newMsg;
      } else {
        _messages = [..._messages, newMsg];
      }
    });

    // Se a mensagem for do outro usuário, marcar como lida imediatamente
    if (!newMsg.isMine(_myUserId)) {
      _api.markRead(widget.conversationId);
      widget.sessionStore.webSocket.sendRead(widget.conversationId);
    }

    _scrollToBottom();
  }

  Future<void> _load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent && mounted) setState(() => _loading = true);

    try {
      final detailsFuture = _api.conversationDetails(widget.conversationId);
      final messagesFuture = _api.messages(widget.conversationId);

      final results = await Future.wait([detailsFuture, messagesFuture]);
      final details = results[0] as Map<String, dynamic>;
      final rawMessages = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _username = details['username']?.toString() ?? _username;
          _otherUserId = details['other_user_id']?.toString() ?? _otherUserId;
          _avatarUrl = details['avatar_url']?.toString() ?? _avatarUrl;
          if (details['is_online'] != null) {
            _isOnline = details['is_online'] == true;
          }
          if (details['last_seen_at'] != null) {
            _lastSeenAt = DateTime.tryParse(details['last_seen_at'].toString());
          }
          _sightingContext = details['sighting_context'] == true;

          _messages = rawMessages.map((m) => ChatMessage.fromMap(m)).toList();
          _error = null;
        });

        // Marcar como lida na abertura
        _api.markRead(widget.conversationId);
        widget.sessionStore.webSocket.sendRead(widget.conversationId);
        _scrollToBottom(animate: false);
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _error = error.toString());
    } finally {
      _fetching = false;
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_amTyping) {
      _amTyping = true;
      widget.sessionStore.webSocket.sendTyping(widget.conversationId, true);
    }

    _myTypingTimer?.cancel();
    _myTypingTimer = Timer(const Duration(seconds: 3), () {
      if (_amTyping) {
        _amTyping = false;
        widget.sessionStore.webSocket.sendTyping(widget.conversationId, false);
      }
    });
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: AppDurations.fast,
          curve: AppCurves.enter,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _sendMessage({
    String body = '',
    String type = 'text',
    String? mediaUrl,
    double? locationLat,
    double? locationLng,
    String? locationTitle,
    Map<String, dynamic>? catData,
  }) async {
    final trimmedBody = body.trim();
    if (type == 'text' && trimmedBody.isEmpty && _editingMessage == null) {
      return;
    }
    if (_sending) return;

    // Se estiver no modo de edição de mensagem
    if (_editingMessage != null) {
      await _commitEdit(trimmedBody);
      return;
    }

    final replyId = _replyingTo?.id;
    final replyMap = _replyingTo != null
        ? {
            'id': _replyingTo!.id,
            'sender_id': _replyingTo!.senderId,
            'body': _replyingTo!.previewText,
          }
        : null;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = ChatMessage(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: _myUserId ?? 'me',
      body: trimmedBody,
      type: type,
      mediaUrl: mediaUrl,
      locationLat: locationLat,
      locationLng: locationLng,
      locationTitle: locationTitle,
      catData: catData,
      replyToId: replyId,
      replyTo: replyMap,
      createdAt: DateTime.now(),
    );

    setState(() {
      _sending = true;
      _optimisticIds.add(tempId);
      _messages = [..._messages, optimisticMsg];
      _replyingTo = null;
    });
    _controller.clear();
    _scrollToBottom();

    // Notificar fim de digitação
    if (_amTyping) {
      _amTyping = false;
      widget.sessionStore.webSocket.sendTyping(widget.conversationId, false);
    }

    try {
      final sentData = await _api.sendMessage(
        widget.conversationId,
        body: trimmedBody,
        type: type,
        mediaUrl: mediaUrl,
        locationLat: locationLat,
        locationLng: locationLng,
        locationTitle: locationTitle,
        catData: catData,
        replyToId: replyId,
      );

      final realMsg = ChatMessage.fromMap(sentData);
      if (mounted) {
        setState(() {
          _optimisticIds.remove(tempId);
          _messages = _messages
              .map((m) => m.id == tempId ? realMsg : m)
              .toList();
        });
      }
    } on SocialApiException catch (error) {
      _rollbackOptimistic(tempId, trimmedBody, error.message);
    } catch (e) {
      _rollbackOptimistic(tempId, trimmedBody, 'Erro ao enviar mensagem: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _rollbackOptimistic(
    String tempId,
    String originalText,
    String errorMsg,
  ) {
    if (!mounted) return;
    setState(() {
      _messages = _messages.where((m) => m.id != tempId).toList();
      _optimisticIds.remove(tempId);
      if (_controller.text.isEmpty && originalText.isNotEmpty) {
        _controller.text = originalText;
      }
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMsg)));
  }

  Future<void> _commitEdit(String newBody) async {
    final target = _editingMessage;
    if (target == null) return;

    setState(() {
      _editingMessage = null;
      _sending = true;
    });
    _controller.clear();

    try {
      final updated = await _api.editMessage(
        widget.conversationId,
        target.id,
        newBody,
      );
      final updatedMsg = ChatMessage.fromMap(updated);
      if (mounted) {
        setState(() {
          _messages = _messages
              .map((m) => m.id == target.id ? updatedMsg : m)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao editar mensagem: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;

      setState(() => _sending = true);
      final bytes = await picked.readAsBytes();
      final filename = picked.name.isNotEmpty ? picked.name : 'chat_photo.jpg';

      final mediaUrl = await _api.uploadChatPhoto(
        widget.conversationId,
        bytes,
        filename,
      );

      if (mediaUrl != null) {
        await _sendMessage(body: '', type: 'photo', mediaUrl: mediaUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao enviar imagem.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao processar foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendCurrentLocation() async {
    setState(() => _sending = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível obter a localização. Verifique as permissões de GPS.',
              ),
            ),
          );
        }
        return;
      }

      final addressName = await LocationService.getLocationName(
        pos.latitude,
        pos.longitude,
      );

      await _sendMessage(
        type: 'location',
        locationLat: pos.latitude,
        locationLng: pos.longitude,
        locationTitle: addressName ?? 'Ponto GPS de Resgate',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao obter localização: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showCatSelectorSheet() async {
    List<Cat> availableCats = [];
    if (widget.catStore != null && widget.catStore!.cats.isNotEmpty) {
      availableCats = widget.catStore!.cats;
    } else {
      try {
        availableCats = await CatDatabase.instance.getCats(
          ownerId: widget.sessionStore.session?.userId,
        );
      } catch (_) {}
    }

    if (!mounted) return;

    if (availableCats.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Nenhum gato cadastrado',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Você ainda não registrou nenhum pet ou avistamento no Gatálogo para compartilhar.',
            style: GoogleFonts.nunito(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  'Selecione uma Ficha de Gato',
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableCats.length,
                  itemBuilder: (context, index) {
                    final cat = availableCats[index];
                    final analysis = widget.catStore?.analysisFor(cat.id);
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: File(cat.photoPath).existsSync()
                            ? Image.file(
                                File(cat.photoPath),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: AppColors.primarySoftBg,
                                child: const Icon(
                                  Icons.pets,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                      ),
                      title: Text(
                        cat.displayName,
                        style: GoogleFonts.fredoka(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '#${cat.captureNumber.toString().padLeft(3, '0')} • ${cat.isOwned ? 'Meu Pet' : 'Avistamento'}',
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
                      trailing: const Icon(
                        LucideIcons.send,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendCatCard(cat, analysis);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendCatCard(Cat cat, dynamic analysis) {
    final catData = <String, dynamic>{
      'id': cat.id,
      'name': cat.displayName,
      'capture_number': cat.captureNumber,
      'photo_path': cat.photoPath,
      'coat': analysis?.coatType ?? 'Desconhecido',
      'color': analysis?.primaryColor ?? 'Indeterminado',
      'is_owned': cat.isOwned,
      'location_name': cat.locationName,
    };

    _sendMessage(
      type: 'cat_card',
      catData: catData,
      body: 'Ficha de ${cat.displayName}',
    );
  }

  IconData _reactionIcon(String key) {
    switch (key) {
      case 'heart':
        return LucideIcons.heart;
      case 'paw':
        return Icons.pets;
      case 'like':
      case 'thumbs_up':
        return LucideIcons.thumbsUp;
      case 'check':
      case 'confirmed':
        return LucideIcons.badgeCheck;
      case 'search':
        return LucideIcons.search;
      case 'alert':
        return LucideIcons.alertTriangle;
      default:
        return LucideIcons.messageSquare;
    }
  }

  Color _reactionColor(String key) {
    switch (key) {
      case 'heart':
        return const Color(0xFFEF4444);
      case 'paw':
        return AppColors.primary;
      case 'like':
      case 'thumbs_up':
        return const Color(0xFF3B82F6);
      case 'check':
      case 'confirmed':
        return AppColors.greenProgress;
      case 'search':
        return const Color(0xFF8B5CF6);
      case 'alert':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.textDark;
    }
  }

  void _showQuickRescueReplies() {
    const suggestions = [
      ('Vi o gato por aqui agora!', LucideIcons.eye),
      ('Pode me mandar mais detalhes da coleira?', LucideIcons.tag),
      ('Estou a caminho do local.', LucideIcons.mapPin),
      ('Gato seguro comigo, tudo bem!', LucideIcons.shieldCheck),
      ('Precisa de ajuda com caixa de transporte?', Icons.pets),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Text(
                  'Respostas Rapidas de Resgate',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
              ),
              const Divider(),
              ...suggestions.map(
                (item) => ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoftBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.$2,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  title: Text(
                    item.$1,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    LucideIcons.arrowUpRight,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _controller.text = item.$1;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Compartilhar no Chat',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    icon: LucideIcons.camera,
                    label: 'Câmera',
                    color: const Color(0xFFE056FD),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendPhoto(ImageSource.camera);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: LucideIcons.image,
                    label: 'Galeria',
                    color: const Color(0xFF686DE0),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendPhoto(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: LucideIcons.mapPin,
                    label: 'Localização',
                    color: const Color(0xFF30336B),
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendCurrentLocation();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.pets,
                    label: 'Ficha Pet',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCatSelectorSheet();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageContextMenu(ChatMessage msg) {
    final isMine = msg.isMine(_myUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A API armazena os identificadores das reações como texto.
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      [
                        (
                          'heart',
                          LucideIcons.heart,
                          const Color(0xFFEF4444),
                          'Amei',
                        ),
                        ('paw', Icons.pets, AppColors.primary, 'Patinha'),
                        (
                          'like',
                          LucideIcons.thumbsUp,
                          const Color(0xFF3B82F6),
                          'Legal',
                        ),
                        (
                          'check',
                          LucideIcons.badgeCheck,
                          AppColors.greenProgress,
                          'Confirmado',
                        ),
                        (
                          'search',
                          LucideIcons.search,
                          const Color(0xFF8B5CF6),
                          'Buscando',
                        ),
                        (
                          'alert',
                          LucideIcons.alertTriangle,
                          const Color(0xFFF59E0B),
                          'Atenção',
                        ),
                      ].map((item) {
                        final key = item.$1;
                        final icon = item.$2;
                        final color = item.$3;
                        final label = item.$4;
                        final hasReacted =
                            msg.reactions[key]?.contains(_myUserId) ?? false;
                        return Tooltip(
                          message: label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.pop(ctx);
                              _toggleReaction(msg, key);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasReacted
                                    ? color.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: hasReacted
                                    ? Border.all(
                                        color: color.withValues(alpha: 0.4),
                                        width: 1.2,
                                      )
                                    : null,
                              ),
                              child: Icon(icon, size: 20, color: color),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const Divider(height: 1),

              // Responder
              ListTile(
                leading: const Icon(
                  LucideIcons.reply,
                  size: 20,
                  color: AppColors.textDark,
                ),
                title: Text(
                  'Responder',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyingTo = msg;
                    _editingMessage = null;
                  });
                },
              ),

              // Copiar
              if (msg.body.isNotEmpty)
                ListTile(
                  leading: const Icon(
                    LucideIcons.copy,
                    size: 20,
                    color: AppColors.textDark,
                  ),
                  title: Text(
                    'Copiar texto',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: msg.body));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Mensagem copiada para a área de transferência.',
                        ),
                      ),
                    );
                  },
                ),

              // Editar (somente mensagens próprias de texto)
              if (isMine && msg.isText && !msg.isDeleted)
                ListTile(
                  leading: const Icon(
                    LucideIcons.edit2,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'Editar mensagem',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _editingMessage = msg;
                      _replyingTo = null;
                      _controller.text = msg.body;
                    });
                  },
                ),

              // Apagar (somente mensagens próprias)
              if (isMine && !msg.isDeleted)
                ListTile(
                  leading: const Icon(
                    LucideIcons.trash2,
                    size: 20,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Apagar mensagem',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(msg);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReaction(ChatMessage msg, String reaction) async {
    // Atualização otimista
    final myId = _myUserId ?? 'me';
    final currentList = List<String>.from(msg.reactions[reaction] ?? []);
    final alreadyReacted = currentList.contains(myId);

    if (alreadyReacted) {
      currentList.remove(myId);
    } else {
      currentList.add(myId);
    }

    final newReactions = Map<String, List<String>>.from(msg.reactions);
    if (currentList.isEmpty) {
      newReactions.remove(reaction);
    } else {
      newReactions[reaction] = currentList;
    }

    setState(() {
      _messages = _messages
          .map((m) => m.id == msg.id ? m.copyWith(reactions: newReactions) : m)
          .toList();
    });

    try {
      await _api.toggleMessageReaction(widget.conversationId, msg.id, reaction);
    } catch (_) {
      // Reverte em caso de falha de rede
      if (mounted) {
        setState(() {
          _messages = _messages.map((m) => m.id == msg.id ? msg : m).toList();
        });
      }
    }
  }

  void _confirmDelete(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Apagar mensagem?',
          style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Esta mensagem será apagada para todos na conversa.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _messages = _messages
                    .map(
                      (m) => m.id == msg.id
                          ? m.copyWith(
                              isDeleted: true,
                              body: 'Mensagem apagada',
                            )
                          : m,
                    )
                    .toList();
              });
              try {
                await _api.deleteMessage(widget.conversationId, msg.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao apagar mensagem: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Apagar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenImage(String imageUrl) {
    final token = widget.sessionStore.session?.accessToken;
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiConfig.baseUrl}$imageUrl${token != null ? '?token=$token' : ''}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BotanicalScaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            actions: const [AppHeaderActions()],
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Foto de Resgate',
              style: GoogleFonts.fredoka(color: Colors.white, fontSize: 18),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.6,
              maxScale: 4.5,
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.alertCircle,
                      color: Colors.white70,
                      size: 40,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Não foi possível carregar a imagem',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openLocationMap(double lat, double lng, String title) {
    final point = LatLng(lat, lng);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppColors.textDark),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.catlogue',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.mapPin,
                            color: Colors.white,
                            size: 24,
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
    );
  }

  void _openCatDetails(Map<String, dynamic> catData) {
    final catId = catData['id']?.toString();
    if (widget.catStore != null && catId != null) {
      final localCat = widget.catStore!.cats
          .where((c) => c.id == catId)
          .firstOrNull;
      if (localCat != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CatDetailsPage(cat: localCat, catStore: widget.catStore!),
          ),
        );
        return;
      }
    }

    // Modal informativo do gato compartilhado
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.pets, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              catData['name']?.toString() ?? 'Ficha do Pet',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (catData['photo_path'] != null &&
                File(catData['photo_path'].toString()).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(catData['photo_path'].toString()),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '• Número: #${catData['capture_number'] ?? '000'}',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            Text(
              '• Pelagem: ${catData['coat'] ?? 'Não especificada'}',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            Text(
              '• Cor Primária: ${catData['color'] ?? 'Não especificada'}',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            if (catData['location_name'] != null)
              Text(
                '• Local de Origem: ${catData['location_name']}',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Hoje';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Ontem';
    }
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return '${local.day} de ${months[local.month - 1]}';
  }

  String _formatLastSeen(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'hoje às $h:$m';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'ontem às $h:$m';
    }
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return '${local.day} de ${months[local.month - 1]} às $h:$m';
  }

  bool _isDifferentDay(DateTime d1, DateTime d2) {
    final l1 = d1.toLocal();
    final l2 = d2.toLocal();
    return l1.year != l2.year || l1.month != l2.month || l1.day != l2.day;
  }

  Widget _buildAvatar() {
    final avatarWidget = FramedUserAvatar(url: _avatarUrl, size: 38);

    return Stack(
      children: [
        avatarWidget,
        if (_isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11,
              height: 11,
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

  @override
  Widget build(BuildContext context) {
    final titleText = _username == null ? 'Conversa' : '@$_username';

    // Subtítulo inteligente: digitando... > online > visto por último > amigo
    Widget subtitleWidget;
    if (_otherUserTyping) {
      subtitleWidget = Text(
        'digitando...',
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          color: AppColors.greenProgress,
        ),
      );
    } else if (_isOnline) {
      subtitleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.greenProgress,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Online',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.greenProgress,
            ),
          ),
        ],
      );
    } else if (_lastSeenAt != null) {
      subtitleWidget = Text(
        'Visto por último ${_formatLastSeen(_lastSeenAt!)}',
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
        ),
        overflow: TextOverflow.ellipsis,
      );
    } else {
      subtitleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.users, size: 12, color: AppColors.textLight),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Amigo no Gatálogo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      );
    }

    final filteredMessages = _searchQuery.isEmpty
        ? _messages
        : _messages
              .where(
                (m) =>
                    m.body.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (m.locationTitle != null &&
                        m.locationTitle!.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        )),
              )
              .toList();

    return BotanicalScaffold(
      level: BotanicalLevel.tertiary,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              });
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar mensagens...',
                  hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.textLight,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleText,
                          style: GoogleFonts.fredoka(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitleWidget,
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          const AppHeaderActions(),
          if (!_isSearching)
            IconButton(
              tooltip: 'Buscar mensagens',
              icon: const Icon(
                LucideIcons.search,
                color: AppColors.textDark,
                size: 20,
              ),
              onPressed: () => setState(() => _isSearching = true),
            ),
          PopupMenuButton<String>(
            icon: const Icon(
              LucideIcons.moreVertical,
              color: AppColors.textDark,
              size: 20,
            ),
            onSelected: (action) {
              if (action == 'search') {
                setState(() => _isSearching = true);
              } else if (action == 'mute') {
                setState(() => _isMuted = !_isMuted);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isMuted
                          ? 'Conversa silenciada.'
                          : 'Notificações reativadas para esta conversa.',
                    ),
                  ),
                );
              } else if (action == 'block') {
                _showBlockDialog();
              } else if (action == 'report') {
                _showReportDialog();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(LucideIcons.search, size: 18),
                    SizedBox(width: 8),
                    Text('Buscar na conversa'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      _isMuted ? LucideIcons.bell : LucideIcons.bellOff,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isMuted
                          ? 'Reativar notificações'
                          : 'Silenciar notificações',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(LucideIcons.userX, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'Bloquear contato',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(LucideIcons.flag, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Denunciar', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Folha decorativa de fundo
          Positioned(
            bottom: 70,
            right: -25,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: Image.asset(
                  'assets/gatalogo_asset_library/flora/flora_branch_pale_diagonal_01.png',
                  width: 95,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Conteúdo do Chat
          Column(
            children: [
              // Banner Interativo de Avistamento / Resgate
              if (_sightingContext)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.pets,
                            size: 20,
                            color: AppColors.greenLink,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pista de avistamento ativa',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.greenLink,
                                  ),
                                ),
                                Text(
                                  'Compartilhem fotos e localizações para auxiliar no resgate.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildBannerActionButton(
                            icon: LucideIcons.camera,
                            label: 'Foto',
                            onTap: () => _pickAndSendPhoto(ImageSource.camera),
                          ),
                          const SizedBox(width: 8),
                          _buildBannerActionButton(
                            icon: LucideIcons.mapPin,
                            label: 'Localização',
                            onTap: _sendCurrentLocation,
                          ),
                          const SizedBox(width: 8),
                          _buildBannerActionButton(
                            icon: Icons.pets,
                            label: 'Ficha do Pet',
                            onTap: _showCatSelectorSheet,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.all(AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.errorText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),

              // Lista de Mensagens
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : filteredMessages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/gatalogo_asset_library/cats/cat_orange_camera.png',
                                width: 85,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Nenhuma mensagem encontrada'
                                    : 'Inicie a conversa',
                                style: GoogleFonts.fredoka(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTitle,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tente buscar com outros termos.'
                                    : 'Envie a primeira mensagem para começar a conversar.',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppColors.textMedium,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _sendMessage(body: 'Olá! Tudo bem?');
                                  },
                                  icon: const Icon(
                                    Icons.pets,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  label: Text(
                                    'Enviar saudação inicial',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.borderProfile,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) {
                          final message = filteredMessages[index];
                          final mine = message.isMine(_myUserId);
                          final isOptimistic = _optimisticIds.contains(
                            message.id,
                          );
                          final showDateHeader =
                              index == 0 ||
                              _isDifferentDay(
                                filteredMessages[index - 1].createdAt,
                                message.createdAt,
                              );

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.borderLight,
                                      ),
                                    ),
                                    child: Text(
                                      _formatDate(message.createdAt),
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMedium,
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Align(
                                  alignment: mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: GestureDetector(
                                    onLongPress: () =>
                                        _showMessageContextMenu(message),
                                    child: _buildMessageBubble(
                                      message,
                                      mine,
                                      isOptimistic,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Barra de pré-visualização de Reply
              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoftBg,
                    border: Border(
                      top: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.reply,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Respondendo a ${_replyingTo!.isMine(_myUserId) ? 'Você' : '@$_username'}',
                              style: GoogleFonts.fredoka(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Text(
                              _replyingTo!.previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          size: 18,
                          color: AppColors.textDark,
                        ),
                        onPressed: () => setState(() => _replyingTo = null),
                      ),
                    ],
                  ),
                ),

              // Barra de pré-visualização de Edição
              if (_editingMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    border: const Border(
                      top: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.edit2,
                        size: 18,
                        color: AppColors.greenLink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Editando mensagem',
                              style: GoogleFonts.fredoka(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.greenLink,
                              ),
                            ),
                            Text(
                              _editingMessage!.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          size: 18,
                          color: AppColors.textDark,
                        ),
                        onPressed: () {
                          setState(() {
                            _editingMessage = null;
                            _controller.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // Barra de Envio
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                      top: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Botão de Anexo (+)
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoftBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderProfile,
                            width: 1.2,
                          ),
                        ),
                        child: IconButton(
                          tooltip: 'Anexar',
                          icon: const Icon(
                            LucideIcons.plus,
                            size: 20,
                            color: AppColors.primaryDark,
                          ),
                          onPressed: _showAttachmentMenu,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Campo de entrada de texto
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: _onTextChanged,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            hintText: _editingMessage != null
                                ? 'Editar mensagem...'
                                : 'Mensagem...',
                            hintStyle: GoogleFonts.nunito(
                              fontSize: 15,
                              color: AppColors.textLight,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.borderLight,
                                width: 1.2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.borderLight,
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Botão rápido de respostas de resgate
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoftBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderProfile,
                            width: 1.2,
                          ),
                        ),
                        child: IconButton(
                          tooltip: 'Respostas rápidas de resgate',
                          icon: const Icon(
                            Icons.pets,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          onPressed: _showQuickRescueReplies,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Botão de Enviar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _editingMessage != null
                              ? AppColors.greenProgress
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: _editingMessage != null
                              ? 'Salvar edição'
                              : 'Enviar',
                          onPressed: _sending
                              ? null
                              : () => _sendMessage(body: _controller.text),
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _editingMessage != null
                                      ? LucideIcons.check
                                      : LucideIcons.send,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.greenLink),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.greenLink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool mine,
    bool isOptimistic,
  ) {
    final timeStr = _formatTime(message.createdAt);

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.80,
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.greenLight : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 3),
              bottomRight: Radius.circular(mine ? 3 : 16),
            ),
            border: Border.all(
              color: mine
                  ? AppColors.greenProgress.withValues(alpha: 0.28)
                  : AppColors.borderLight,
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Citação / Reply se houver
              if (message.replyTo != null) _buildReplyQuote(message.replyTo!),

              // Mensagem Apagada
              if (message.isDeleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.ban,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Mensagem apagada',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                )
              // Foto enviada
              else if (message.isPhoto)
                _buildPhotoMessage(message)
              // Localização enviada
              else if (message.isLocation)
                _buildLocationMessage(message)
              // Ficha de gato enviada
              else if (message.isCatCard)
                _buildCatCardMessage(message)
              // Texto comum
              else
                Text(
                  message.body,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    height: 1.35,
                  ),
                ),

              const SizedBox(height: 4),

              // Rodapé: horário, editada, recibo de leitura
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  if (message.isEdited && !message.isDeleted) ...[
                    Text(
                      '(editada) ',
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                  if (timeStr.isNotEmpty) ...[
                    Text(
                      timeStr,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                  if (mine) ...[
                    const SizedBox(width: 4),
                    if (isOptimistic)
                      const Icon(
                        LucideIcons.clock,
                        size: 11,
                        color: AppColors.textLight,
                      )
                    else
                      Icon(
                        (message.isRead || message.readAt != null)
                            ? LucideIcons.checkCheck
                            : LucideIcons.check,
                        size: 14,
                        color: (message.isRead || message.readAt != null)
                            ? AppColors.greenProgress
                            : AppColors.textLight,
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Badges de Reações com Ícones Reais
        if (message.reactions.isNotEmpty) ...[
          const SizedBox(height: 3),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: message.reactions.entries.map((entry) {
              final key = entry.key;
              final users = entry.value;
              final hasReacted = users.contains(_myUserId);
              final icon = _reactionIcon(key);
              final iconColor = _reactionColor(key);

              return GestureDetector(
                onTap: () => _toggleReaction(message, key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: hasReacted
                        ? iconColor.withValues(alpha: 0.14)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: hasReacted
                          ? iconColor.withValues(alpha: 0.5)
                          : AppColors.borderLight,
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: iconColor),
                      const SizedBox(width: 4),
                      Text(
                        users.length.toString(),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: hasReacted ? iconColor : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildReplyQuote(Map<String, dynamic> reply) {
    final senderMine = reply['sender_id'] == _myUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderMine ? 'Você' : '@$_username',
            style: GoogleFonts.fredoka(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply['body']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoMessage(ChatMessage message) {
    final mediaUrl = message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.imageOff,
            size: 16,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Text(
            'Foto não disponível',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      );
    }

    final token = widget.sessionStore.session?.accessToken;
    final fullUrl = mediaUrl.startsWith('http')
        ? mediaUrl
        : '${ApiConfig.baseUrl}$mediaUrl${token != null ? '?token=$token' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openFullscreenImage(mediaUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              fullUrl,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 190,
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                height: 140,
                color: Colors.black12,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.alertCircle, color: AppColors.textLight),
                      SizedBox(height: 4),
                      Text('Falha ao carregar foto'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (message.body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            message.body,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationMessage(ChatMessage message) {
    final lat = message.locationLat ?? 0.0;
    final lng = message.locationLng ?? 0.0;
    final title = message.locationTitle ?? 'Ponto de Localização';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoftBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.mapPin,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.fredoka(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openLocationMap(lat, lng, title),
                  icon: const Icon(LucideIcons.map, size: 15),
                  label: Text(
                    'Abrir no Mapa',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (message.body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            message.body,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCatCardMessage(ChatMessage message) {
    final catData = message.catData ?? {};
    final name = catData['name']?.toString() ?? 'Gato';
    final number = catData['capture_number']?.toString() ?? '001';
    final coat = catData['coat']?.toString() ?? 'Desconhecido';
    final color = catData['color']?.toString() ?? 'Indeterminado';
    final photoPath = catData['photo_path']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (photoPath != null && File(photoPath).existsSync())
                    ? Image.file(
                        File(photoPath),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: AppColors.primarySoftBg,
                        child: const Icon(
                          Icons.pets,
                          color: AppColors.primaryDark,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.fredoka(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoftBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${number.padLeft(3, '0')}',
                            style: GoogleFonts.fredoka(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$coat • $color',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openCatDetails(catData),
              icon: const Icon(Icons.pets, size: 14, color: AppColors.primary),
              label: Text(
                'Ver no Catálogo',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.primaryDark,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderProfile),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Bloquear contato?',
          style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Este usuário não poderá mais lhe enviar mensagens ou interagir com suas postagens.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contato bloqueado com sucesso.')),
              );
            },
            child: const Text(
              'Bloquear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Denunciar usuário',
          style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Descreva o motivo da denúncia (spam, conteúdo impróprio, etc.):',
              style: GoogleFonts.nunito(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.nunito(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Motivo...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Denúncia enviada para a equipe de moderação. Obrigado!',
                  ),
                ),
              );
            },
            child: const Text(
              'Enviar Denúncia',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
