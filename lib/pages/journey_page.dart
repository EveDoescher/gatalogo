import 'package:flutter/material.dart';

import '../stores/cat_store.dart';
import '../services/product_api_service.dart';
import '../widgets/botanical_scene.dart';
import '../widgets/game_components.dart';
import '../widgets/progress_components.dart';
import '../widgets/milestone_widgets.dart';
import 'capture_page.dart';
import 'habitat_page.dart';
import 'social_page.dart';
import 'library_page.dart';

List<Map<String, dynamic>> localJourney(CatStore store) =>
    store.progress.achievements;

class JourneyPage extends StatefulWidget {
  const JourneyPage({
    super.key,
    required this.store,
    this.initialSection = 'daily',
  });
  final CatStore store;
  final String initialSection;
  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  late String _section;
  String _filter = 'all';
  final _selectedSection = GlobalKey();
  void _revealSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selected = _selectedSection.currentContext;
      if (mounted && selected != null) {
        Scrollable.ensureVisible(selected, alignment: .5);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _revealSection();
    widget.store.refreshGamification();
  }

  Future<void> _continue(Map<String, dynamic> goal) async {
    final active = ValueNotifier(true);
    final page = switch (goal['destination']) {
      'habitat' => HabitatPage(
        sessionStore: widget.store.sessionStore,
        catStore: widget.store,
        active: active,
      ),
      'social' || 'missing' => SocialPage(
        sessionStore: widget.store.sessionStore,
        catStore: widget.store,
      ),
      'collection' => CatAlbumPage(catStore: widget.store),
      _ => CapturePage(catStore: widget.store),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    active.dispose();
    await widget.store.refreshGamification();
  }

  Future<void> _highlights() async {
    final owned = widget.store.progress.achievements
        .where((g) => g['completed'] == true)
        .toList();
    final selected = Set<String>.from(
      widget.store.progress.summary['highlighted_medals'] as List? ?? [],
    );
    String? error;
    bool saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Medalhas no seu perfil', style: GameStyle.title(25)),
              const Text(
                'Escolha até cinco medalhas. A audiência do seu perfil continua valendo.',
              ),
              if (owned.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Suas medalhas obtidas aparecerão aqui.'),
                ),
              for (final g in owned)
                CheckboxListTile(
                  title: Text('${g['title']}'),
                  secondary: AchievementMedal(goal: g, size: 40),
                  value: selected.contains(g['id']),
                  onChanged: saving
                      ? null
                      : (value) => update(() {
                          if (value == true && selected.length < 5) {
                            selected.add('${g['id']}');
                          } else if (value != true) {
                            selected.remove('${g['id']}');
                          }
                        }),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await ProductApiService(widget.store.sessionStore)
                              .put('/app/journey/highlights', {
                                'ids': selected.toList(),
                              });
                          await widget.store.refreshGamification();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        } catch (_) {
                          if (sheetContext.mounted) {
                            update(() {
                              saving = false;
                              error =
                                  'Não foi possível salvar. Tente novamente.';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Salvando…' : 'Salvar destaques'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    mood: BotanicalMood.album,
    backgroundColor: GameStyle.canvas,
    appBar: AppBar(title: const Text('Missões e conquistas')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final progress = widget.store.progress;
        final rows = switch (_section) {
          'initial' => progress.initialMissions,
          'weekly' => progress.weeklyMissions,
          'challenge' => progress.challenges,
          'achievement' => progress.achievements,
          _ => progress.dailyMissions,
        };
        final calendar = progress.summary['calendar'] as Map? ?? {};
        final title = switch (_section) {
          'initial' => 'Os primeiros passos',
          'weekly' => 'Histórias desta semana',
          'challenge' => 'Desafios da temporada',
          'achievement' => 'Seu mural de conquistas',
          _ => 'Sua jornada de hoje',
        };
        final description = switch (_section) {
          'initial' => 'Aprenda no seu ritmo. Cada objetivo é concluído uma vez; atividades já realizadas também contam.',
          'weekly' => 'Três objetivos maiores, de segunda a domingo. Uma ação também pode avançar suas diárias.',
          'challenge' => 'Jornadas longas e difíceis com reconhecimento especial. As datas pertencem à temporada.',
          'achievement' => 'Marcos permanentes da sua história. Cada medalha tem uma condição e um prêmio próprios.',
          _ => 'Três objetivos disponíveis ao mesmo tempo. Descobrir e enriquecer fichas vem primeiro.',
        };
        return RefreshIndicator(
          onRefresh: widget.store.refreshGamification,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in const {
                      'initial': 'Iniciais',
                      'daily': 'Diárias',
                      'weekly': 'Semanais',
                      'challenge': 'Desafios',
                      'achievement': 'Conquistas',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.value),
                          key: _section == item.key ? _selectedSection : null,
                          selected: _section == item.key,
                          onSelected: (_) =>
                              setState(() => _section = item.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IllustratedPaperHeading(
                title: title,
                description: description,
                art: _section == 'achievement'
                    ? 'rewards/reward_trophy_paw_gold'
                    : 'ui/ui_clipboard_checklist',
              ),
              const SizedBox(height: 16),
              MilestoneNotice(
                offline: progress.offline,
                enabled: progress.summary['rewards_enabled'] != false,
              ),
              if (_section == 'daily' || _section == 'weekly')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: MilestoneCountdown(
                    resetAt:
                        calendar[_section == 'daily'
                                ? 'daily_reset_at'
                                : 'weekly_reset_at']
                            as String?,
                    serverNow: calendar['server_now'] as String?,
                    onExpired: widget.store.refreshGamification,
                  ),
                ),
              if (_section == 'achievement') ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in const {
                      'all': 'Todas',
                      'progress': 'Em andamento',
                      'done': 'Obtidas',
                    }.entries)
                      ChoiceChip(
                        label: Text(option.value),
                        selected: _filter == option.key,
                        onSelected: (_) => setState(() => _filter = option.key),
                      ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _highlights,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Escolher medalhas do perfil'),
                ),
              ],
              if (rows.isEmpty)
                BotanicalEmpty(
                  title: _section == 'challenge'
                      ? 'A próxima temporada ainda não começou'
                      : 'Seu progresso aparecerá aqui',
                  description: _section == 'challenge'
                      ? 'Seus gatos, registros e conquistas continuam. Quando houver uma temporada ativa, suas etapas e prêmios aparecerão aqui.'
                      : 'Entre na sua conta ou atualize para carregar os marcos confirmados.',
                  art: 'rewards/reward_star_gold',
                ),
              for (final goal in rows.where(
                (g) =>
                    _section != 'achievement' ||
                    _filter == 'all' ||
                    (_filter == 'done'
                        ? g['completed'] == true
                        : g['completed'] != true),
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _section == 'achievement'
                      ? BotanicalPaper(
                          foliage: false,
                          child: InkWell(
                            onTap: () => showAchievement(context, goal),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    AchievementMedal(goal: goal, size: 70),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${goal['title']}',
                                            style: GameStyle.title(21),
                                          ),
                                          Text(
                                            goal['completed'] == true
                                                ? 'Medalha obtida · toque para ver'
                                                : '${goal['progress']} de ${goal['target']} ${goal['unit'] ?? ''}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text('${goal['description'] ?? ''}'),
                                if (goal['completed'] != true) ...[
                                  const SizedBox(height: 12),
                                  GameProgress(
                                    current: goal['progress'] as num? ?? 0,
                                    target: goal['target'] as num? ?? 1,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : GoalCard(
                          goal: {...goal, 'server_now': calendar['server_now']},
                          onTap: () => _continue(goal),
                        ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
