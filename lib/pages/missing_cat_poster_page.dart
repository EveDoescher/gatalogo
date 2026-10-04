import '../widgets/botanical_scene.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/cat.dart';
import '../models/missing_poster.dart';
import '../services/cat_sharing_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/post_composer.dart';

class MissingCatPosterPage extends StatelessWidget {
  const MissingCatPosterPage({
    super.key,
    required this.cat,
    required this.report,
    this.locationName,
    this.catStore,
  });

  final Cat cat;
  final Map<String, dynamic> report;
  final String? locationName;
  final CatStore? catStore;

  String get _qrPayload {
    final reportId = report['id'] ?? '';
    return 'https://gatalogo.app/busca/$reportId';
  }

  @override
  Widget build(BuildContext context) {
    final catName = cat.displayName;
    final dateStr = displayDate(report['created_at']);
    final poster = MissingPoster(
      cat: cat,
      report: report,
      locationName: locationName,
    );
    final locStr = poster.address ?? 'Endereço não informado';

    return BotanicalScaffold(
      level: BotanicalLevel.tertiary,
      mood: BotanicalMood.care,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 1.2),
            ),
            child: const Icon(
              LucideIcons.chevronLeft,
              color: AppColors.textDark,
              size: 22,
            ),
          ),
        ),
        title: Text(
          'Cartaz de busca',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          const IllustratedSectionTitle(
            title: 'Seu cartaz de busca',
            art: 'ui/ui_clipboard_paw',
          ),
          const SizedBox(height: 16),
          // O Cartaz
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.error, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Faixa PROCURA-SE
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    'PROCURA-SE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Foto Grande do Gato
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: CatPhotoView(cat.photoPath, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Nome do Gato em destaque
                Text(
                  catName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Desaparecido desde $dateStr',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: AppSpacing.md),

                // Informações e Características
                _buildPosterField(
                  icon: LucideIcons.mapPin,
                  title: 'Último local visto',
                  value: locStr,
                ),
                for (final detail in poster.characteristics.entries) ...[
                  const SizedBox(height: 8),
                  _buildPosterField(
                    icon: LucideIcons.tag,
                    title: detail.key,
                    value: detail.value,
                  ),
                ],
                for (final contact in poster.contacts) ...[
                  const SizedBox(height: 8),
                  _buildPosterField(
                    icon: LucideIcons.phone,
                    title: contact['whatsapp'] == true
                        ? 'Telefone / WhatsApp'
                        : 'Telefone',
                    value: contact['phone'] as String,
                  ),
                ],
                if (poster.contacts.isEmpty) ...[
                  const SizedBox(height: 8),
                  _buildPosterField(
                    icon: LucideIcons.messageCircle,
                    title: 'Contato',
                    value: 'Pelo chat do app Gatálogo',
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: AppSpacing.md),

                // QR Code e Chamada para Ação
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: QrImageView(
                        data: _qrPayload,
                        version: QrVersions.auto,
                        size: 82,
                        gapless: false,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Viu este gato?',
                            style: GoogleFonts.fredoka(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Escaneie o QR Code ou fotografe pelo aplicativo Gatálogo para alertar o tutor imediatamente.',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: AppColors.textMedium,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Botões de Ação
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            onPressed: () => _publishToCommunity(context, locStr),
            icon: const Icon(LucideIcons.globe, size: 18),
            label: Text(
              'Compartilhar na comunidade',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            onPressed: () async {
              final shared = await CatSharingService.shareMissingPoster(
                cat: cat,
                report: report,
                locationName: locStr,
              );
              if (shared) {
                await catStore?.recordGamificationAction('share');
                await catStore?.recordHabitatAction(
                  'share',
                  targetType: 'report',
                  targetId: report['id']?.toString(),
                );
              }
            },
            icon: const Icon(LucideIcons.share2, size: 18),
            label: Text(
              'Compartilhar em outros apps',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publishToCommunity(BuildContext context, String locStr) async {
    final session = catStore?.sessionStore;
    if (session == null) return;
    final post = await showPostComposer(
      context,
      session: session,
      initialCat: cat,
      initialLocation: locStr,
      initialNote: CatSharingService.buildMissingPosterText(
        cat: cat,
        report: report,
        locationName: locStr,
      ),
    );
    if (post != null) {
      await catStore?.recordGamificationAction('post');
      if (context.mounted) {
        showMessage(context, 'Alerta compartilhado na comunidade.');
      }
    }
  }

  Widget _buildPosterField({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.error),
        const SizedBox(width: 6),
        Text(
          '$title: ',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
