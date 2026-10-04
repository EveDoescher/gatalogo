import '../widgets/botanical_scene.dart';

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
    return BotanicalScaffold(
      level: BotanicalLevel.tertiary,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Voltar ao Habitat',
          onPressed: onClose,
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: const Text('Ajuda do Habitat'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const IllustratedPaperHeading(
            title: 'Seu quintal',
            description: 'Um guia para cuidar dos gatos e organizar o Habitat.',
            art: 'ui/ui_clipboard_checklist',
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
          const _Tip(
            icon: LucideIcons.heart,
            text: 'Toque em um gato para dar carinho, uma porção diária gratuita ou um petisco de 4 moedas. Cada cuidado aumenta a afinidade uma vez por dia, sem perda por ausência.',
          ),
          const _Tip(
            icon: LucideIcons.flower,
            text: 'Toque em um canteiro para regar. Ele cresce em 12 horas; uma nova rega depois de 6 horas antecipa o crescimento. Aos 20 pontos de afinidade, você ganha Flores da amizade.',
          ),
          const _Tip(
            icon: LucideIcons.waves,
            text: 'Pinte água e terra arrastando os trechos do inventário. Pontes precisam ficar inteiramente sobre a água e permitem a travessia dos gatos. Remova a ponte antes de retirar a água.',
          ),
          const _Tip(
            icon: LucideIcons.armchair,
            text: 'Os gatos exploram camas, barracas, troncos e caixas sozinhos. Toque em um desses móveis para convidar um gatinho.',
          ),
          const SizedBox(height: 24),
          const IllustratedSectionTitle(
            title: 'Como ganhar moedas',
            art: 'rewards/reward_coin_paw_gold',
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
