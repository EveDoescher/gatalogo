import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'game_components.dart';
import 'milestone_widgets.dart';

class JournalPanel extends StatelessWidget {
  const JournalPanel({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? AppColors.cardAltBackground,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
    ),
    child: child,
  );
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap});
  final Map<String, dynamic> goal;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final current = (goal['progress'] as num? ?? 0).toInt();
    final target = (goal['target'] as num? ?? 1).toInt();
    final done = goal['completed'] == true;
    final icon = challengeIcon('${goal['id']}');
    return Semantics(
      label:
          '${goal['title']}. $current de $target. ${done ? 'Concluído' : 'Em andamento'}',
      child: GameNote(
        color: done ? GameStyle.greenPaper : GameStyle.paper,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GameSeal(icon: icon, done: done, size: 49),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${goal['title']}', style: GameStyle.title(21)),
                      if (done)
                        Text(
                          goal['type'] == 'achievement'
                              ? 'Medalha conquistada'
                              : 'Concluída · recompensa recebida',
                          style: const TextStyle(
                            color: AppColors.greenLink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (!done && goal['period'] != null)
                        Text(switch (goal['type']) {
                          'daily' => 'Missão de hoje',
                          'weekly' => 'Missão da semana',
                          'initial' => 'Missão inicial',
                          'achievement' => 'Conquista permanente',
                          _ => 'Desafio sazonal',
                        }, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (goal['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${goal['description']}'),
              ),
            const SizedBox(height: 16),
            Text(
              '$current de $target ${goal['unit'] ?? 'etapas'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            GameProgress(current: current, target: target, gold: done),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((goal['xp_reward'] as num? ?? 0) > 0)
                  GameReward(value: '+${goal['xp_reward']} XP'),
                if ((goal['coin_reward'] as num? ?? 0) > 0)
                  GameReward(value: '+${goal['coin_reward']}', coins: true),
                if (done)
                  const Icon(
                    Icons.verified_rounded,
                    color: AppColors.greenLink,
                  ),
              ],
            ),
            if (goal['reset_at'] != null) ...[
              const SizedBox(height: 12),
              MilestoneCountdown(
                resetAt: goal['reset_at'] as String?,
                serverNow: goal['server_now'] as String?,
              ),
            ],
            if ((goal['ranking_points'] as num? ?? 0) > 0)
              Text(
                '${goal['ranking_points']} pontos no ranking',
                style: const TextStyle(fontSize: 12),
              ),
            if (!done && onTap != null)
              TextButton(onPressed: onTap, child: const Text('Continuar')),
          ],
        ),
      ),
    );
  }
}

class RecordStateNotice extends StatelessWidget {
  const RecordStateNotice({super.key, required this.state, this.reason});
  final String state;
  final String? reason;
  static String label(String state) => switch (state) {
    'failed' => 'Análise não concluída',
    'confirmed' => 'Confirmado',
    'recorded' => 'Registro confirmado · recompensas pausadas',
    'needs_review' => 'Precisa de revisão',
    'ineligible' => 'Não elegível para prêmio',
    'analyzing' => 'Em análise',
    'offline' => 'Aguardando conexão',
    'local' => 'Salvo no aparelho',
    _ => 'Aguardando confirmação',
  };
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: JournalPanel(
      color: state == 'confirmed'
          ? AppColors.greenLight
          : AppColors.cardBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            state == 'confirmed'
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: AppColors.greenLink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label(state),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (reason != null) ...[
                  const SizedBox(height: 4),
                  Text(reason!),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
