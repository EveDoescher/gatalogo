import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({
    super.key,
    required this.controller,
    required this.busy,
    this.replyingTo,
    this.editingMessage,
    this.currentUserId,
    this.username,
    required this.onChanged,
    required this.onSend,
    required this.onAttachment,
    required this.onQuickReplies,
    required this.onCancelReply,
    required this.onCancelEdit,
  });
  final TextEditingController controller;
  final bool busy;
  final ChatMessage? replyingTo, editingMessage;
  final String? currentUserId, username;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend,
      onAttachment,
      onQuickReplies,
      onCancelReply,
      onCancelEdit;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Barra de pré-visualização de Reply
      if (replyingTo != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.primarySoftBg,
            border: Border(top: BorderSide(color: AppColors.borderLight)),
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
                      'Respondendo a ${replyingTo!.isMine(currentUserId) ? 'Você' : '@$username'}',
                      style: GoogleFonts.fredoka(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      replyingTo!.previewText,
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
                onPressed: onCancelReply,
              ),
            ],
          ),
        ),

      // Barra de pré-visualização de Edição
      if (editingMessage != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            border: const Border(top: BorderSide(color: AppColors.borderLight)),
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
                      editingMessage!.body,
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
                onPressed: onCancelEdit,
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
            border: Border(top: BorderSide(color: AppColors.borderLight)),
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
                  onPressed: onAttachment,
                ),
              ),
              const SizedBox(width: 6),

              // Campo de entrada de texto
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: onChanged,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: editingMessage != null
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
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                        width: 1.2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
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
                  onPressed: onQuickReplies,
                ),
              ),
              const SizedBox(width: 6),

              // Botão de Enviar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: editingMessage != null
                      ? AppColors.greenProgress
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: editingMessage != null ? 'Salvar edição' : 'Enviar',
                  onPressed: busy ? null : onSend,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          editingMessage != null
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
  );
}
