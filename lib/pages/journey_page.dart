import '../widgets/botanical_scene.dart';

import 'package:flutter/material.dart';

import '../stores/cat_store.dart';
import '../services/product_api_service.dart';
import '../widgets/progress_components.dart';
import '../widgets/game_components.dart';

/// Offline views use confirmed cached progress only.
List<Map<String, dynamic>> localJourney(CatStore store) =>
    store.progress.challenges;

class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key, required this.store});
  final CatStore store;
  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  String _filter = 'all';
  List<Map<String, dynamic>> _history = [];
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.store.refreshGamification();
    if (!widget.store.sessionStore.isSignedIn) return;
    try {
      final rows = await ProductApiService(widget.store.sessionStore)
          .list('/app/journey');
      if (mounted) {
        setState(() {
          _history = rows;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Sem conexão. Exibindo o último progresso confirmado.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    mood: BotanicalMood.album,
    backgroundColor: GameStyle.canvas,
    appBar: AppBar(title: const Text('Missões e conquistas')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final goals = _history.isEmpty ? localJourney(widget.store) : _history;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const IllustratedPaperHeading(
                title: 'Pequenas missões, novas histórias',
                description: 'Uma missão diária e duas semanais. Sem perder XP por fazer uma pausa.',
                art: 'ui/ui_clipboard_checklist',
              ),
              const SizedBox(height: 24),
              for (final mission in widget.store.progress.missions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GoalCard(goal: mission),
                ),
              if (widget.store.progress.missions.isEmpty)
                const RecordStateNotice(
                  state: 'local',
                  reason: 'Conecte sua conta para acompanhar as missões confirmadas.',
                ),
              const SizedBox(height: 16),
              Text('Seu mural de medalhas', style: GameStyle.title(26)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const {
                    'all': 'Todas',
                    'progress': 'Em andamento',
                    'done': 'Concluídas',
                    'available': 'Disponíveis',
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: _filter == option.key,
                      onSelected: (_) => setState(() => _filter = option.key),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!),
                ),
              const SizedBox(height: 16),
              for (final goal in goals.where(
                (g) => switch (_filter) {
                  'done' => g['completed'] == true || g['unlocked'] == true,
                  'progress' =>
                    g['completed'] != true && (g['progress'] as num? ?? 0) > 0,
                  'available' =>
                    g['completed'] != true && (g['progress'] as num? ?? 0) == 0,
                  _ => true,
                },
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GoalCard(
                    goal: {
                      ...goal,
                      'completed':
                          goal['completed'] == true || goal['unlocked'] == true,
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
