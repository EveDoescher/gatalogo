import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/cat.dart';
import '../services/cat_sharing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class MissingCatPosterPage extends StatelessWidget {
  const MissingCatPosterPage({
    super.key,
    required this.cat,
    required this.report,
    this.locationName,
  });

  final Cat cat;
  final Map<String, dynamic> report;
  final String? locationName;

  String get _qrPayload {
    final reportId = report['id'] ?? '';
    return 'https://gatalogo.app/busca/$reportId';
  }

  @override
  Widget build(BuildContext context) {
    final catName = cat.displayName;
    final dateStr = displayDate(report['created_at']);
    final locStr = locationName ?? cat.locationName ?? 'Região monitorada';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
          'Cartaz Digital de Busca',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(LucideIcons.share2, color: AppColors.textDark),
            onPressed: () => CatSharingService.shareMissingPoster(
              cat: cat,
              report: report,
              locationName: locStr,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        children: [
          // O Cartaz
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.error, width: 3.5),
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
                    child: CatPhotoView(
                      cat.photoPath,
                      fit: BoxFit.cover,
                    ),
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
                if (cat.collar?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildPosterField(
                    icon: LucideIcons.tag,
                    title: 'Coleira',
                    value: cat.collar!,
                  ),
                ],
                if (cat.distinguishingMarks?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildPosterField(
                    icon: LucideIcons.sparkles,
                    title: 'Marcas características',
                    value: cat.distinguishingMarks!,
                  ),
                ],
                if (cat.microchip?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildPosterField(
                    icon: LucideIcons.cpu,
                    title: 'Microchip',
                    value: cat.microchip!,
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
                        border: Border.all(color: AppColors.borderLight, width: 1.2),
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
            onPressed: () => CatSharingService.shareMissingPoster(
              cat: cat,
              report: report,
              locationName: locStr,
            ),
            icon: const Icon(LucideIcons.share2, size: 18),
            label: Text(
              'Compartilhar no WhatsApp / Redes',
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            onPressed: () {
              final text = CatSharingService.buildMissingPosterText(
                cat: cat,
                report: report,
                locationName: locStr,
              );
              Clipboard.setData(ClipboardData(text: text));
              showMessage(context, 'Texto do cartaz copiado para a área de transferência.');
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            label: Text(
              'Copiar Texto do Alerta',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
