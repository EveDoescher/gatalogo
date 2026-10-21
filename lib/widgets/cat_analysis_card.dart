import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../theme/app_theme.dart';
import 'cat_coat_color_item.dart';

class CatAnalysisCard extends StatelessWidget {
  const CatAnalysisCard({
    super.key,
    required this.cat,
    required this.analysis,
    required this.onRetry,
  });
  final Cat cat;
  final CatAnalysis? analysis;
  final VoidCallback onRetry;
  int? _resolveConfidence(CatAnalysis? analysis) {
    if (analysis?.confidence == null) return null;
    final val = analysis!.confidence!;
    if (val <= 1.0 && val > 0) return (val * 100).round();
    return val.round().clamp(1, 100);
  }

  String _formatPercentage(double value) {
    final normalized = value <= 1.0 && value > 0 ? value * 100 : value;
    return '${normalized.round()}%';
  }

  String _formatHairType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Não informado';
    final normalized = raw.trim().toLowerCase();
    if (normalized.contains('curt') || normalized.contains('short')) {
      return 'Curto';
    }
    if (normalized.contains('méd') ||
        normalized.contains('med') ||
        normalized.contains('medium')) {
      return 'Médio';
    }
    if (normalized.contains('long') || normalized.contains('comprid')) {
      return 'Longo';
    }
    if (normalized.contains('sem') ||
        normalized.contains('hairless') ||
        normalized.contains('careca')) {
      return 'Sem pelo';
    }
    if (normalized.contains('ondul') ||
        normalized.contains('wavy') ||
        normalized.contains('curly') ||
        normalized.contains('cresp')) {
      return 'Ondulado';
    }
    return raw.trim();
  }

  void _showConfidenceModal(BuildContext context, String confidenceDisplay) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5CDC3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confiança da IA ($confidenceDisplay)',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Como funciona a estimativa visual',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'O índice de confiança representa a certeza dos modelos de visão computacional na identificação das cores, padrão e pelagem do gato.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Critérios avaliados:',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildConfidenceBullet(
                        'Iluminação adequada e nitidez da fotografia',
                      ),
                      _buildConfidenceBullet(
                        'Visibilidade dos padrões e contraste da pelagem',
                      ),
                      _buildConfidenceBullet(
                        'Enquadramento do corpo e ângulos de referência',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    'Entendi',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 5, color: AppColors.primary),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cat.status == 'analyzing') {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 18,
                  color: AppColors.textDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Análise da pelagem',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Analisando com Inteligência Artificial...',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Identificando padrões e cores da descoberta.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (cat.status == 'failed') {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 18,
                  color: Color(0xFFD32F2F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Análise da pelagem',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Não foi possível concluir a análise.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O servidor não respondeu ou houve instabilidade de conexão.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                LucideIcons.refreshCw,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'Tentar novamente',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (cat.status == 'pending_analysis' || cat.status == 'pending') {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.cloud,
                  size: 18,
                  color: AppColors.textMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Análise pendente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A análise será concluída assim que houver conexão com o servidor.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                LucideIcons.refreshCw,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                'Analisar agora',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final confVal = _resolveConfidence(analysis);
    final confidenceDisplay = confVal != null ? '$confVal%' : 'Não informada';
    final coatType = analysis?.coatType ?? 'Não informado';
    final hairType = _formatHairType(analysis?.hairType);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 18,
                color: AppColors.textDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Análise da pelagem',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (confVal != null)
                InkWell(
                  onTap: () => _showConfidenceModal(context, confidenceDisplay),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Confiança: $confidenceDisplay',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMedium,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.helpCircle,
                          size: 15,
                          color: AppColors.textMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cores principais',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (analysis?.colors.isNotEmpty == true)
                      ...analysis!.colors
                          .take(3)
                          .map(
                            (c) => CatCoatColorItem(
                              label: c.name,
                              percentage: _formatPercentage(c.percentage),
                            ),
                          )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Cores naturais registradas',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Padrão',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coatType,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tipo de pelagem',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hairType,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
