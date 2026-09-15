import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/social_api_service.dart';
import '../services/product_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.sessionStore,
    required this.conversationId,
  });
  final SessionStore sessionStore;
  final String conversationId;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  late final SocialApiService _api;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false, _fetching = false;
  String? _error;
  String? _username;
  bool _sightingContext = false;
  Timer? _timer;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _api = SocialApiService(widget.sessionStore);
    _load();
    _wsSub = widget.sessionStore.webSocket.onMessage.listen((data) {
      if (data['conversation_id'] == widget.conversationId) {
        _load();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final metadata = await ProductApiService(widget.sessionStore)
          .get('/app/conversations/${widget.conversationId}');
      final messages = await _api.messages(widget.conversationId);
      if (mounted) {
        setState(() {
          _username = metadata['username'] as String?;
          _sightingContext = metadata['sighting_context'] == true;
          _messages = messages;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    _controller.clear();

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = <String, dynamic>{
      'id': tempId,
      'sender_id': widget.sessionStore.session?.userId,
      'body': body,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _sending = true;
      _messages = [..._messages, optimisticMsg];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: AppDurations.fast,
          curve: AppCurves.enter,
        );
      }
    });

    try {
      await _api.sendMessage(widget.conversationId, body);
      await _load();
    } on SocialApiException catch (error) {
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => m['id'] != tempId).toList();
          _controller.text = body;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => m['id'] != tempId).toList();
          _controller.text = body;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Hoje';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Hoje';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        return 'Ontem';
      }
      final months = [
        'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
      ];
      return '${dt.day} de ${months[dt.month - 1]}';
    } catch (_) {
      return 'Hoje';
    }
  }

  bool _isDifferentDay(dynamic t1, dynamic t2) {
    if (t1 == null || t2 == null) return false;
    try {
      final d1 = DateTime.parse(t1.toString()).toLocal();
      final d2 = DateTime.parse(t2.toString()).toLocal();
      return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _username == null ? 'Conversa' : '@$_username';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySoftBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderProfile, width: 1.4),
              ),
              child: const Icon(LucideIcons.user, size: 18, color: AppColors.primaryDark),
            ),
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
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.users,
                        size: 12,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Amigo no Gatálogo',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
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
      body: Stack(
        children: [
          // Folha decorativa de fundo aconchegante
          Positioned(
            bottom: 70,
            right: -25,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: Image.asset(
                  'assets/images/Folha_2.png',
                  width: 95,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Conteúdo de Mensagens
          Column(
            children: [
              if (_sightingContext)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, size: 20, color: AppColors.greenLink),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pista de avistamento',
                              style: GoogleFonts.fredoka(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.greenLink,
                              ),
                            ),
                            Text(
                              'Compartilhem detalhes para ajudar a reencontrar o gato desaparecido.',
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
                      const Icon(LucideIcons.alertCircle, size: 18, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
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

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/images/gato_1.png', width: 85),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Diga um "Miau!" 🐾',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Envie a primeira mensagem para começar a conversar.',
                                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _controller.text = 'Miau! Tudo bem? 🐾';
                                      _send();
                                    },
                                    icon: const Icon(Icons.pets, size: 16, color: AppColors.primary),
                                    label: Text(
                                      'Mandar "Miau!" rápido',
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.borderProfile),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final mine = message['sender_id'] == widget.sessionStore.session?.userId;
                              final bodyText = message['body']?.toString() ?? '';
                              final timeStr = _formatTime(message['created_at']);

                              // Separador de Data estilo WhatsApp
                              final showDateHeader = index == 0 ||
                                  _isDifferentDay(
                                    _messages[index - 1]['created_at'],
                                    message['created_at'],
                                  );

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDateHeader)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBackground,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.borderLight),
                                        ),
                                        child: Text(
                                          _formatDate(message['created_at']),
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Align(
                                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                                        ),
                                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
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
                                            Text(
                                              bodyText,
                                              style: GoogleFonts.nunito(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textDark,
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                const Spacer(),
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
                                                   Icon(
                                                     (message['read_at'] != null || message['is_read'] == true)
                                                         ? LucideIcons.checkCheck
                                                         : LucideIcons.check,
                                                     size: 14,
                                                     color: (message['read_at'] != null || message['is_read'] == true)
                                                         ? AppColors.greenProgress
                                                         : AppColors.textLight,
                                                   ),
                                                 ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),

              // Barra de Envio estilo WhatsApp com tema Gatálogo
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(top: BorderSide(color: AppColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      // Botão rápido de emoji/patinha (44x44 touch target)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoftBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderProfile, width: 1.2),
                        ),
                        child: IconButton(
                          tooltip: 'Enviar patinha',
                          icon: const Icon(Icons.pets, size: 18, color: AppColors.primary),
                          onPressed: () {
                            _controller.text = '${_controller.text} 🐾'.trim();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Campo de entrada de texto em pílula
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 4,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            hintText: 'Mensagem...',
                            hintStyle: GoogleFonts.nunito(
                              fontSize: 15,
                              color: AppColors.textLight,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botão de Enviar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Enviar',
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.send, color: Colors.white, size: 18),
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
}
