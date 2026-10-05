import '../widgets/botanical_scene.dart';

import 'dart:async';

import '../widgets/app_widgets.dart';

import 'package:flutter/material.dart';

import '../stores/cat_store.dart';
import '../models/cat.dart';
import '../widgets/progress_components.dart';
import '../widgets/game_components.dart';
import '../services/product_api_service.dart';
import '../services/experience_service.dart';
import 'cat_details_page.dart';
import 'library_page.dart';
import 'habitat_page.dart';

class DiscoveryResultPage extends StatefulWidget {
  const DiscoveryResultPage({
    super.key,
    required this.store,
    this.catId,
    this.eventId,
  });
  final CatStore store;
  final String? catId;
  final String? eventId;
  @override
  State<DiscoveryResultPage> createState() => _DiscoveryResultPageState();
}

class _DiscoveryResultPageState extends State<DiscoveryResultPage> {
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _suggestions = [];
  String? _error;
  bool _busy = false;
  bool _reveal = true;
  String? _celebrated;
  final _habitatActive = ValueNotifier(true);
  Cat? get _cat {
    final id = widget.catId ?? _event?['record_id'];
    for (final cat in widget.store.cats) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  Map<String, dynamic>? get _result {
    if (widget.eventId != null) {
      for (final event in widget.store.progress.results) {
        if (event['event_id'] == widget.eventId) return event;
      }
    } else {
      final latest = widget.store.progress.resultFor(widget.catId ?? '');
      if (latest != null) return latest;
    }
    return _event;
  }

  @override
  void initState() {
    super.initState();
    unawaited(widget.store.progress.track('result_opened'));
    _load();
  }

  @override
  void dispose() {
    _habitatActive.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await widget.store.refreshGamification();
      if (widget.eventId != null) {
        final event = await widget.store.progress.fetchResult(widget.eventId!);
        if (!mounted) return;
        setState(() => _event = event);
      }
      final cat = _cat;
      if (cat != null && widget.store.sessionStore.isSignedIn) {
        final outcome = await ProductApiService(widget.store.sessionStore)
            .get('/app/progress/records/${cat.id}');
        if (mounted) setState(() => _event = outcome);
        final data = await ProductApiService(widget.store.sessionStore)
            .list('/app/progress/records/${cat.id}/suggestions');
        if (mounted) setState(() => _suggestions = data);
      }
    } catch (_) {
      /* The saved photo and cached outcome remain available. */
    }
  }

  Future<void> _review() async {
    final event = _result;
    if (event?['event_id'] == null) return;
    final attrs = Map<String, dynamic>.from(event?['attributes'] as Map? ?? {});
    final choices = <String, List<String>>{
      'primary_color': [
        'Preto',
        'Branco',
        'Cinza',
        'Laranja',
        'Marrom',
        'Creme',
        'Outro',
      ],
      'coat_type': [
        'Sólido',
        'Bicolor',
        'Tricolor',
        'Rajado',
        'Tuxedo',
        'Escaminha',
        'Colorpoint',
        'Outro',
      ],
      'hair_type': ['Curto', 'Médio', 'Longo', 'Sem pelo', 'Outro'],
    };
    for (final entry in choices.entries) {
      if (!entry.value.contains(attrs[entry.key])) {
        attrs[entry.key] = entry.value.last;
      }
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Revisar atributos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A IA pode errar. Confirme apenas o que consegue observar nesta foto.',
                ),
                for (final entry in choices.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: attrs[entry.key] as String,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: switch (entry.key) {
                          'primary_color' => 'Cor',
                          'coat_type' => 'Padrão',
                          _ => 'Pelo',
                        },
                      ),
                      items: entry.value
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => update(() => attrs[entry.key] = v),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    await _perform(() async {
      _event = await ProductApiService(widget.store.sessionStore)
          .put('/app/progress/results/${event!['event_id']}/attributes', attrs);
    });
  }

  Future<void> _identify() async {
    final cat = _cat;
    if (cat == null) return;
    String query = '';
    final known = <String, Cat>{};
    for (final other in widget.store.cats.where(
      (c) => c.id != cat.id && c.individualId != 'pending',
    )) {
      final id = other.individualId ?? other.id;
      if (!known.containsKey(id) || other.id == id) known[id] = other;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .85,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Qual gato está nesta foto?', style: GameStyle.title(25)),
              const SizedBox(height: 12),
              CatPhotoView(cat.photoPath, height: 190, fit: BoxFit.contain),
              const SizedBox(height: 12),
              const Text(
                'Compare os detalhes. A IA sugere semelhanças; você confirma a identidade.',
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, cat.id),
                icon: const Icon(Icons.add),
                label: const Text('É outro gato · nova descoberta'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Ainda não sei · manter pendente'),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Procurar no meu catálogo',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (text) => update(() => query = text.toLowerCase()),
              ),
              const SizedBox(height: 12),
              for (final other
                  in (known.values
                      .where((c) => c.displayName.toLowerCase().contains(query))
                      .toList()
                    ..sort(
                      (a, b) =>
                          (_suggestions.any((s) => s['client_id'] == b.id)
                                  ? 1
                                  : 0)
                              .compareTo(
                                _suggestions.any((s) => s['client_id'] == a.id)
                                    ? 1
                                    : 0,
                              ),
                    )))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(other.displayName, style: GameStyle.title(20)),
                      if (_suggestions.any((s) => s['client_id'] == other.id))
                        const Text('Possível conhecido · sugestão da IA'),
                      CatPhotoView(
                        other.photoPath,
                        height: 170,
                        fit: BoxFit.contain,
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          other.individualId ?? other.id,
                        ),
                        child: const Text('É este gato · acrescentar registro'),
                      ),
                    ],
                  ),
                ),
              if (known.isEmpty)
                const Text(
                  'Ainda não há outros gatos no seu catálogo para comparar.',
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    var contribution = 'encounter';
    if (choice != cat.id && mounted) {
      final picked = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'O que esta foto acrescenta?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final option in const {
                  'angle': 'Outro ângulo do gato',
                  'detail': 'Um detalhe novo na ficha',
                  'clearer': 'Uma foto mais nítida',
                  'encounter': 'Só registrar este reencontro',
                }.entries)
                  ListTile(
                    title: Text(option.value),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, option.key),
                  ),
              ],
            ),
          ),
        ),
      );
      if (picked == null) return;
      contribution = picked;
    }
    await _perform(() async {
      await widget.store.identifyRecord(
        cat.id,
        choice,
        contributionType: contribution,
      );
      _event = null;
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await widget.store.refreshGamification();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final cat = _cat;
      final result = _result;
      if (result != null &&
          result['state'] == 'confirmed' &&
          _celebrated != result['event_id']) {
        _celebrated = result['event_id'] as String?;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ExperienceService.instance.celebrate();
        });
      }
      final state =
          result?['state'] as String? ??
          (!widget.store.sessionStore.isSignedIn
              ? 'local'
              : widget.store.progress.offline
              ? 'offline'
              : cat?.status == 'failed'
              ? 'failed'
              : cat?.status == 'analyzing'
              ? 'analyzing'
              : 'pending');
      final credits = result?['credits'] as Map? ?? {};
      final attrs = result?['attributes'] as Map? ?? {};
      final bonuses = result?['bonuses'] as List? ?? [];
      final reduceMotion =
          MediaQuery.disableAnimationsOf(context) ||
          !ExperienceService.instance.motion ||
          !_reveal;
      final title = switch (result?['record_type']) {
        'complement' => 'Um complemento para o álbum!',
        'encounter' => 'Reencontro guardado no álbum',
        'pending_identity' => 'Vamos reconhecer este gato',
        'owned' => 'Um registro de cuidado',
        _ =>
          state == 'confirmed' ? 'Descoberta confirmada!' : 'Uma nova história',
      };
      return BotanicalScaffold(
        mood: BotanicalMood.album,
        backgroundColor: GameStyle.canvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Seu registro', style: GameStyle.title(22)),
          actions: [
            if (_reveal && state == 'confirmed')
              TextButton(
                onPressed: () => setState(() => _reveal = false),
                child: const Text('Pular animação'),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: GameStyle.title(28),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (cat != null)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(
                                '${result?['event_id']}-$reduceMotion',
                              ),
                              tween: Tween(
                                begin: reduceMotion ? 1 : .96,
                                end: 1,
                              ),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) =>
                                  Transform.scale(scale: value, child: child),
                              child: GamePhotoCard(cat: cat, height: 210),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (attrs.isNotEmpty) ...[
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: attrs.values
                              .where((v) => v != null)
                              .map(
                                (v) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: GameStyle.paper,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: GameStyle.edge),
                                  ),
                                  child: Text(
                                    '$v',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : _review,
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Revisar atributos'),
                        ),
                      ],
                      RecordStateNotice(
                        state: state,
                        reason:
                            result?['reason'] as String? ??
                            (result == null
                                ? 'Sua foto está salva. Créditos e desafios serão confirmados após a sincronização.'
                                : null),
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Créditos confirmados',
                          style: GameStyle.title(21),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            GameReward(
                              value: '${credits['xp'] ?? 0} XP',
                              large: true,
                            ),
                            GameReward(
                              value: '${credits['coins'] ?? 0}',
                              coins: true,
                              large: true,
                            ),
                          ],
                        ),
                        for (final bonus in bonuses)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GamePanel(
                              color: GameStyle.greenPaper,
                              child: Row(
                                children: [
                                  const GameSeal(done: true, size: 42),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${bonus['title']}',
                                          style: GameStyle.title(19),
                                        ),
                                        Text(
                                          '+${bonus['xp']} XP · ${bonus['coins']} moedas',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        for (final item
                            in (result['unlocked_items'] as List? ?? []))
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GamePanel(
                              child: Row(
                                children: [
                                  GameItemArt('${item['sku']}', size: 72),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Novo no seu Quintal!',
                                          style: GameStyle.title(21),
                                        ),
                                        Text(
                                          '${item['name']} · nível ${item['level']}',
                                        ),
                                        const Text(
                                          'Já está no inventário.',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (result['summary'] is Map)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Saldo: ${result['summary']['xp']} XP · ${result['summary']['balance']} moedas',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if (result['identity_corrected'] == true)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Identificação corrigida. O saldo já considera o ajuste.',
                            ),
                          ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (cat?.individualId != null &&
                          result != null &&
                          cat!.individualId != result['individual_id'])
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Identificação salva. A confirmação depende da sincronização.',
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (cat != null)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _identify,
                          icon: const Icon(Icons.pets_outlined),
                          label: Text(
                            cat.individualId == 'pending'
                                ? 'Comparar e confirmar o gato'
                                : 'Identificar ou corrigir o gato',
                          ),
                        ),
                      if (cat != null && cat.status == 'failed')
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _perform(
                                  () => widget.store.retryAnalysis(cat.id),
                                ),
                          child: const Text('Tentar analisar novamente'),
                        ),
                      const SizedBox(height: 12),
                      GameButton(
                        label: 'Ver meus desafios',
                        icon: Icons.auto_stories_rounded,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/collection'),
                            builder: (_) => LibraryPage(
                              catStore: widget.store,
                              initialTab: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GameButton(
                        label: 'Ir ao Quintal',
                        icon: Icons.yard_rounded,
                        green: true,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/habitat'),
                            builder: (_) => HabitatPage(
                              sessionStore: widget.store.sessionStore,
                              catStore: widget.store,
                              active: _habitatActive,
                            ),
                          ),
                        ),
                      ),
                      if (cat != null)
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CatDetailsPage(
                                cat: cat,
                                catStore: widget.store,
                              ),
                            ),
                          ),
                          child: const Text('Abrir ficha e fotos'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
