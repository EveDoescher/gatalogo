import 'package:flutter/material.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../widgets/app_widgets.dart';

List<Map<String, dynamic>> localJourney(CatStore store) {
  final days = store.discoveries
      .map((cat) => displayDate(cat.capturedAt))
      .toSet()
      .length;
  final angles = store.cats.fold<int>(
    0,
    (best, cat) => store.referencePhotosFor(cat.id).length > best
        ? store.referencePhotosFor(cat.id).length
        : best,
  );
  return [
    {
      'id': 'first',
      'title': 'Primeira descoberta',
      'description': 'Fotografe seu primeiro gato em um passeio.',
      'target': 1,
      'progress': store.discoveries.isEmpty ? 0 : 1,
    },
    {
      'id': 'angles',
      'title': 'Um novo olhar',
      'description': 'Adicione fotos complementares a um gato.',
      'target': 2,
      'progress': angles.clamp(0, 2),
    },
    {
      'id': 'days',
      'title': 'Olhar atento',
      'description': 'Registre descobertas em três dias diferentes.',
      'target': 3,
      'progress': days.clamp(0, 3),
    },
    {
      'id': 'helper',
      'title': 'Rede de cuidado',
      'description': 'Contribua com um avistamento de um gato desaparecido.',
      'target': 1,
      'progress': 0,
    },
  ];
}

class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key, required this.store});
  final CatStore store;
  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  List<Map<String, dynamic>>? _remote;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.store.sessionStore.isSignedIn) return;
    try {
      await widget.store.syncCatalog();
      final data = await ProductApiService(widget.store.sessionStore)
          .list('/app/journey');
      if (mounted) setState(() => _remote = data);
    } catch (_) {
      /* Local collection progress remains available offline. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sua jornada')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final items = _remote ?? localJourney(widget.store);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Cada encontro conta',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore com cuidado, complete os álbuns e ajude outros gatos a voltar para casa.',
            ),
            const SizedBox(height: 24),
            ...items.map((item) {
              final unlocked =
                  item['unlocked_at'] != null ||
                  (item['progress'] as num) >= (item['target'] as num);
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        unlocked
                            ? Icons.emoji_events
                            : Icons.emoji_events_outlined,
                      ),
                      title: Text(item['title'] as String),
                      subtitle: Text(item['description'] as String),
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(item['title'] as String),
                          content: Text(
                            '${item['description']}\n\n${unlocked ? 'Conquista alcançada!' : '${item['progress']} de ${item['target']}'}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    LinearProgressIndicator(
                      value:
                          ((item['progress'] as num) / (item['target'] as num))
                              .clamp(0, 1)
                              .toDouble(),
                      semanticsLabel: item['title'] as String,
                    ),
                    if (item['unlocked_at'] != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await ProductApiService(
                                      widget.store.sessionStore,
                                    ).post('/app/journey/${item['id']}/share');
                                    if (context.mounted) {
                                      showMessage(
                                        context,
                                        'Conquista compartilhada com seus amigos.',
                                      );
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      showMessage(context, error);
                                    }
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar com amigos'),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    ),
  );
}
