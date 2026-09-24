import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/habitat_service.dart';
import '../theme/app_theme.dart';

class HabitatHelpPage extends StatelessWidget {
  const HabitatHelpPage({
    super.key,
    required this.habitat,
    required this.onClose,
  });

  final HabitatService habitat;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const rewards = {
      'catalog': 'Catalogar um gato',
      'reference': 'Adicionar foto de referência',
      'sighting': 'Registrar avistamento',
      'post': 'Publicar na comunidade',
      'comment': 'Comentar',
      'like': 'Curtir',
      'share': 'Compartilhar',
      'care': 'Acompanhar a busca',
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Voltar ao Habitat',
          onPressed: onClose,
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: const Text('Ajuda do Habitat'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Seu quintal',
            style: GoogleFonts.fredoka(
              fontSize: 25,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 12),
          const _Tip(
            icon: LucideIcons.hand,
            text: 'Arraste o chão para mover a câmera e use dois dedos para aproximar ou afastar.',
          ),
          const _Tip(
            icon: LucideIcons.pencil,
            text: 'Abra o menu e ative Editar para organizar os objetos.',
          ),
          const _Tip(
            icon: LucideIcons.cat,
            text: 'Arraste um gato da bandeja até uma célula livre do quintal.',
          ),
          const SizedBox(height: 24),
          Text(
            'Como ganhar moedas',
            style: GoogleFonts.fredoka(
              fontSize: 23,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in rewards.entries)
            if (habitat.rewards[entry.key] case final amount?)
              ListTile(
                dense: true,
                title: Text(entry.value),
                trailing: Text(
                  '+$amount',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: AppColors.achievementText,
                  ),
                ),
                subtitle: habitat.dailyLimits[entry.key] == null
                    ? null
                    : Text(
                        'Até ${habitat.dailyLimits[entry.key]} vezes por dia',
                      ),
              ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: AppColors.green, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(color: AppColors.textDark),
          ),
        ),
      ],
    ),
  );
}
