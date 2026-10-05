import 'package:flutter/material.dart';

import '../stores/cat_store.dart';
import '../widgets/progress_components.dart';
import '../widgets/game_components.dart';
import 'journey_page.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key, required this.store});
  final CatStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => RefreshIndicator(
      onRefresh: store.refreshGamification,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: GameNotebook(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Desafios da temporada',
                          style: GameStyle.title(26),
                        ),
                      ),
                      Image.asset(
                        'assets/gatalogo_asset_library/cats/cat_orange_sleeping.png',
                        width: 70,
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jornadas longas, etapas claras e prêmios exclusivos. Cada desafio pertence a uma temporada.',
                  ),
                  const SizedBox(height: 20),
                  if (store.progress.challenges.isEmpty)
                    const RecordStateNotice(
                      state: 'local',
                      reason: 'Ainda não há uma temporada ativa. Suas missões e conquistas continuam disponíveis no mural.',
                    ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JourneyPage(store: store),
                      ),
                    ),
                    child: const Text('Ver minhas missões e conquistas'),
                  ),
                  LayoutBuilder(
                    builder: (context, box) {
                      final columns = box.maxWidth >= 620 ? 2 : 1;
                      final width =
                          (box.maxWidth - (columns - 1) * 16) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 18,
                        children: [
                          for (final goal in store.progress.challenges)
                            SizedBox(
                              width: width,
                              child: GoalCard(goal: goal),
                            ),
                        ],
                      );
                    },
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
