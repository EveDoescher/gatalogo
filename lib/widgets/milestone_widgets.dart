import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'game_components.dart';
import 'botanical_scene.dart';

String medalAsset(String id) => switch (id) {
  'first' => 'reward_medal_paw_coral',
  'collector_5' || 'collector_10' => 'reward_medal_paw_gold',
  'master_collector' || 'legend_collector' => 'reward_trophy_paw_gold',
  'helper' || 'care_10' => 'reward_shield_paw_gold',
  'colors' => 'reward_seal_paw_coral',
  'days' => 'reward_medal_star_gold_ribbon_01',
  'angles' || 'album_10' => 'reward_medal_star_gold_ribbon_02',
  _ => 'reward_star_gold',
};

class MilestoneCountdown extends StatefulWidget {
  const MilestoneCountdown({
    super.key,
    required this.resetAt,
    this.serverNow,
    this.label = 'Novas missões em',
    this.onExpired,
    this.style,
  });
  final String? resetAt, serverNow;
  final String label;
  final VoidCallback? onExpired;
  final TextStyle? style;
  @override
  State<MilestoneCountdown> createState() => _MilestoneCountdownState();
}

class _MilestoneCountdownState extends State<MilestoneCountdown> {
  Timer? _timer;
  final Stopwatch _elapsed = Stopwatch();
  Duration _initial = Duration.zero;
  bool _expired = false;
  void _start() {
    _timer?.cancel();
    _expired = false;
    _elapsed.reset();
    _elapsed.start();
    final end = DateTime.tryParse(widget.resetAt ?? '');
    final now = DateTime.tryParse(widget.serverNow ?? '') ?? DateTime.now();
    _initial = end?.difference(now) ?? Duration.zero;
    if (end != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_initial - _elapsed.elapsed <= Duration.zero && !_expired) {
          _expired = true;
          _timer?.cancel();
          widget.onExpired?.call();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(MilestoneCountdown old) {
    super.didUpdateWidget(old);
    if (old.resetAt != widget.resetAt || old.serverNow != widget.serverNow) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.resetAt == null) return const SizedBox.shrink();
    final seconds = math.max(0, (_initial - _elapsed.elapsed).inSeconds);
    String two(int n) => n.toString().padLeft(2, '0');
    final days = seconds ~/ 86400;
    final time =
        '${two((seconds ~/ 3600) % 24)}:${two((seconds ~/ 60) % 60)}:${two(seconds % 60)}';
    return Text(
      seconds == 0
          ? 'Atualizando missões…'
          : '${widget.label} ${days > 0 ? '$days dias · ' : ''}$time',
      style:
          widget.style ??
          const TextStyle(color: AppColors.textMedium, fontSize: 12),
    );
  }
}

class AchievementMedal extends StatelessWidget {
  const AchievementMedal({
    super.key,
    required this.goal,
    this.size = 64,
    this.onTap,
  });
  final Map<String, dynamic> goal;
  final double size;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label:
        '${goal['title']}. ${goal['completed'] == true ? 'Medalha obtida' : '${goal['progress']} de ${goal['target']} ${goal['unit'] ?? ''}'}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: size,
        height: size,
        child: Opacity(
          opacity: goal['completed'] == true ? 1 : .48,
          child: Image.asset(
            'assets/gatalogo_asset_library/rewards/${medalAsset('${goal['id']}')}.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

Future<void> showAchievement(
  BuildContext context,
  Map<String, dynamic> goal, {
  bool celebration = false,
  Widget? actions,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => AchievementPresentation(
    goal: goal,
    celebration: celebration,
    actions: actions,
  ),
);

class AchievementPresentation extends StatelessWidget {
  const AchievementPresentation({
    super.key,
    required this.goal,
    this.celebration = false,
    this.actions,
  });
  final Map<String, dynamic> goal;
  final bool celebration;
  final Widget? actions;
  @override
  Widget build(BuildContext context) {
    final done = goal['completed'] == true;
    final date = DateTime.tryParse('${goal['unlocked_at'] ?? ''}');
    final legacy = goal['legacy_reward_unknown'] == true;
    final xp = done
        ? goal['xp_received'] ?? goal['xp_reward']
        : goal['xp_reward'];
    final coins = done
        ? goal['coin_received'] ?? goal['coin_reward']
        : goal['coin_reward'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  celebration
                      ? 'Uma conquista para guardar!'
                      : done
                      ? 'Seu marco, sua história'
                      : 'Seu próximo marco',
                  style: GameStyle.title(25),
                ),
              ),
              IconButton(
                tooltip: 'Fechar conquista',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox(
              height: 230,
              width: 280,
              child: CustomPaint(
                painter: _MedalSparkles(value),
                child: Center(
                  child: Transform.scale(
                    scale: .65 + .35 * value,
                    child: AchievementMedal(goal: goal, size: 185),
                  ),
                ),
              ),
            ),
          ),
          Text(
            '${goal['title']}',
            style: GameStyle.title(29),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text('${goal['description'] ?? ''}', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (!done)
            GameProgress(
              current: goal['progress'] as num? ?? 0,
              target: goal['target'] as num? ?? 1,
              label:
                  '${goal['progress'] ?? 0} de ${goal['target'] ?? 1} ${goal['unit'] ?? ''}',
            ),
          if (date != null)
            Text(
              'Conquistada em ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (!legacy && (xp as num? ?? 0) > 0)
                GameReward(value: '+$xp XP'),
              if (!legacy && (coins as num? ?? 0) > 0)
                GameReward(value: '+$coins', coins: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            legacy
                ? 'Medalha preservada do seu histórico'
                : done
                ? 'Recompensa recebida'
                : 'Recompensa ao alcançar este marco',
            style: const TextStyle(
              color: AppColors.greenLink,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (goal['ranking_points'] != null)
            Text('${goal['ranking_points']} pontos no ranking de marcos'),
          if (actions != null) ...[const SizedBox(height: 20), actions!],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MedalSparkles extends CustomPainter {
  _MedalSparkles(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE3AE47).withValues(alpha: .4 + .6 * progress);
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi * 2 / 14;
      final radius = 85 + 24 * progress;
      final x = size.width / 2 + math.cos(a) * radius;
      final y = size.height / 2 + math.sin(a) * radius;
      final r = i.isEven ? 5.0 : 3.0;
      final path = Path()
        ..moveTo(x, y - r)
        ..lineTo(x + r / 2, y)
        ..lineTo(x, y + r)
        ..lineTo(x - r / 2, y)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MedalSparkles old) => old.progress != progress;
}

class MilestoneNotice extends StatelessWidget {
  const MilestoneNotice({
    super.key,
    required this.offline,
    required this.enabled,
  });
  final bool offline, enabled;
  @override
  Widget build(BuildContext context) => !offline && enabled
      ? const SizedBox.shrink()
      : BotanicalPaper(
          foliage: false,
          child: Text(
            offline ? 'Sem conexão. Exibindo o último progresso confirmado.' : 'Recompensas ainda não ativadas nesta conta. Atividades válidas ficam registradas.',
          ),
        );
}
