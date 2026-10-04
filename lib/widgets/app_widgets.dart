import 'botanical_scene.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'illustrated_home_components.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../models/cat.dart';
import '../pages/profile_page.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';

String displayDate(dynamic value) {
  final date = value is DateTime
      ? value.toLocal()
      : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

void showMessage(BuildContext context, Object message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        content: Text(
          message.toString(),
          style: GoogleFonts.nunito(color: AppColors.surface),
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Text(
          title,
          style: GoogleFonts.fredoka(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.nunito(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(color: AppColors.textMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              minimumSize: const Size(80, 48),
            ),
            child: Text(
              action,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ??
    false;

class CatPhotoView extends StatelessWidget {
  const CatPhotoView(
    this.path, {
    super.key,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppRadius.photo,
  });
  final String path;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.file(
      File(path),
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => Container(
        height: height ?? 100,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: const Center(
          child: Icon(
            LucideIcons.imageOff,
            color: AppColors.textLight,
            semanticLabel: 'Foto não disponível',
          ),
        ),
      ),
    ),
  );
}

class CatTile extends StatelessWidget {
  const CatTile(this.cat, {super.key, required this.onTap, this.subtitle});
  final Cat cat;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardAltBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CatPhotoView(cat.photoPath, borderRadius: AppRadius.photo),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.displayName,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle ?? displayDate(cat.capturedAt),
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMedium,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: AppColors.textLight),
        ],
      ),
    ),
  );
}

class EmptyContent extends StatelessWidget {
  const EmptyContent(this.title, this.message, {super.key, this.action});
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: BotanicalEmpty(title: title, description: message, action: action),
  );
}

void showFullscreenImage(
  BuildContext context, {
  required String imagePath,
  String? title,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.chevronLeft,
                color: AppColors.textDark,
                size: 22,
              ),
            ),
          ),
          title: Text(
            title ?? '',
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: CatPhotoView(
              imagePath,
              fit: BoxFit.contain,
              borderRadius: 0,
            ),
          ),
        ),
      ),
    ),
  );
}

void showFullscreenMemoryImage(
  BuildContext context, {
  required Uint8List bytes,
  String? title,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.chevronLeft,
                color: AppColors.textDark,
                size: 22,
              ),
            ),
          ),
          title: Text(
            title ?? '',
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

/// Botão de avatar do usuário reutilizável nos cabeçalhos (Início, Gatalogar, Coleção).
/// Exibe a foto de perfil real sincronizada com o servidor ou o ícone padrão se não houver foto,
/// e ao tocar navega diretamente para o [ProfilePage].
class UserAvatarButton extends StatelessWidget {
  const UserAvatarButton({
    super.key,
    required this.sessionStore,
    this.catStore,
    this.size = 42,
    this.framed = false,
  });

  final SessionStore sessionStore;
  final CatStore? catStore;
  final double size;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionStore,
      builder: (context, _) {
        final avatarUrl = sessionStore.avatarUrl;
        final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
        final fullUrl = hasAvatar
            ? (avatarUrl.startsWith('http')
                  ? avatarUrl
                  : '${ApiConfig.baseUrl}$avatarUrl')
            : null;

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfilePage(sessionStore: sessionStore, catStore: catStore),
            ),
          ),
          borderRadius: BorderRadius.circular(size / 2),
          child: framed
              ? FramedUserAvatar(url: avatarUrl, size: size)
              : Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.borderProfile,
                      width: 1.4,
                    ),
                  ),
                  child: ClipOval(
                    child: hasAvatar
                        ? Image.network(
                            fullUrl!,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(
                                LucideIcons.user,
                                size: size * 0.48,
                                color: AppColors.textLight,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              LucideIcons.user,
                              size: size * 0.48,
                              color: AppColors.textLight,
                            ),
                          ),
                  ),
                ),
        );
      },
    );
  }
}
