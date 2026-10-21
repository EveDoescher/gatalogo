import '../widgets/conversation_composer.dart';
import '../controllers/conversation_controller.dart';
import '../widgets/chat_message_bubble.dart';
import '../formatters/app_dates.dart';
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
  late final ConversationController _conversation;
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _preparingAttachment = false;
  bool get _sending => _preparingAttachment || _conversation.sending;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isMuted = false;

  String? get _myUserId => widget.sessionStore.session?.userId;

  @override
  void initState() {
    super.initState();
    _conversation = ConversationController(
      widget.sessionStore,
      widget.conversationId,
      username: widget.initialUsername,
      otherUserId: widget.otherUserId,
      avatarUrl: widget.initialAvatarUrl,
      isOnline: widget.initialIsOnline ?? false,
      sightingContext: widget.initialSightingContext ?? false,
      onScroll: (animate) => _scrollToBottom(animate: animate),
      onClearComposer: _controller.clear,
      onRestoreComposer: (text) {
        if (_controller.text.isEmpty) _controller.text = text;
      },
      onError: (text) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(text)));
        }
      },
    )..addListener(_onConversationChanged);
    _conversation.start();
  }

  void _onConversationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _conversation.removeListener(_onConversationChanged);
    _conversation.dispose();
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;

      setState(() => _preparingAttachment = true);
      final bytes = await picked.readAsBytes();
      final filename = picked.name.isNotEmpty ? picked.name : 'chat_photo.jpg';

      await _conversation.uploadPhoto(bytes, filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao processar foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _preparingAttachment = false);
    }
  }

  Future<void> _sendCurrentLocation() async {
    setState(() => _preparingAttachment = true);
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

      await _conversation.sendMessage(
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
      if (mounted) setState(() => _preparingAttachment = false);
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

    _conversation.sendMessage(
      type: 'cat_card',
      catData: catData,
      body: 'Ficha de ${cat.displayName}',
    );
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
                              _conversation.toggleReaction(msg, key);
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
                    _conversation.replyingTo = msg;
                    _conversation.editingMessage = null;
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
                      _conversation.editingMessage = msg;
                      _conversation.replyingTo = null;
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
              await _conversation.deleteMessage(msg);
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

  Widget _buildAvatar() {
    final avatarWidget = FramedUserAvatar(
      url: _conversation.avatarUrl,
      size: 38,
    );

    return Stack(
      children: [
        avatarWidget,
        if (_conversation.isOnline)
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
    final titleText = _conversation.username == null
        ? 'Conversa'
        : '@${_conversation.username}';

    // Subtítulo inteligente: digitando... > online > visto por último > amigo
    Widget subtitleWidget;
    if (_conversation.otherUserTyping) {
      subtitleWidget = Text(
        'digitando...',
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          color: AppColors.greenProgress,
        ),
      );
    } else if (_conversation.isOnline) {
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
    } else if (_conversation.lastSeenAt != null) {
      subtitleWidget = Text(
        'Visto por último ${AppDates.lastSeen(_conversation.lastSeenAt!)}',
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
        ? _conversation.messages
        : _conversation.messages
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
              if (_conversation.sightingContext)
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

              if (_conversation.error != null)
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
                          _conversation.error!,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.errorText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        onPressed: _conversation.load,
                      ),
                    ],
                  ),
                ),

              // Lista de Mensagens
              Expanded(
                child: _conversation.loading
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
                                    _conversation.sendMessage(
                                      body: 'Olá! Tudo bem?',
                                    );
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
                          final isOptimistic = _conversation.optimisticIds
                              .contains(message.id);
                          final showDateHeader =
                              index == 0 ||
                              AppDates.isDifferentLocalDay(
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
                                      AppDates.chatDay(message.createdAt),
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
                                    child: ChatMessageBubble(
                                      message: message,
                                      mine: mine,
                                      isOptimistic: isOptimistic,
                                      currentUserId: _myUserId,
                                      username: _conversation.username,
                                      accessToken: widget
                                          .sessionStore
                                          .session
                                          ?.accessToken,
                                      onReact: _conversation.toggleReaction,
                                      onOpenPhoto: _openFullscreenImage,
                                      onOpenLocation: _openLocationMap,
                                      onOpenCat: _openCatDetails,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              ConversationComposer(
                controller: _controller,
                busy: _sending,
                replyingTo: _conversation.replyingTo,
                editingMessage: _conversation.editingMessage,
                currentUserId: _myUserId,
                username: _conversation.username,
                onChanged: _conversation.onTextChanged,
                onSend: () => _conversation.sendMessage(body: _controller.text),
                onAttachment: _showAttachmentMenu,
                onQuickReplies: _showQuickRescueReplies,
                onCancelReply: () => _conversation.replyingTo = null,
                onCancelEdit: () {
                  _conversation.editingMessage = null;
                  _controller.clear();
                },
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
