import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../formatters/app_dates.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

/// Message presentation; navigation and mutations are owned by its caller.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.isOptimistic,
    required this.currentUserId,
    required this.username,
    required this.accessToken,
    required this.onReact,
    required this.onOpenPhoto,
    required this.onOpenLocation,
    required this.onOpenCat,
  });
  final ChatMessage message;
  final bool mine;
  final bool isOptimistic;
  final String? currentUserId;
  final String? username;
  final String? accessToken;
  final void Function(ChatMessage, String) onReact;
  final ValueChanged<String> onOpenPhoto;
  final void Function(double, double, String) onOpenLocation;
  final ValueChanged<Map<String, dynamic>> onOpenCat;

  @override
  Widget build(BuildContext context) {
    final timeStr = AppDates.chatTime(message.createdAt);

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
              final hasReacted = users.contains(currentUserId);
              final icon = _reactionIcon(key);
              final iconColor = _reactionColor(key);

              return GestureDetector(
                onTap: () => onReact(message, key),
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
    final senderMine = reply['sender_id'] == currentUserId;
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
            senderMine ? 'Você' : '@$username',
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

    final token = accessToken;
    final fullUrl = mediaUrl.startsWith('http')
        ? mediaUrl
        : '${ApiConfig.baseUrl}$mediaUrl${token != null ? '?token=$token' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onOpenPhoto(mediaUrl),
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
                  onPressed: () => onOpenLocation(lat, lng, title),
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
              onPressed: () => onOpenCat(catData),
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
}
