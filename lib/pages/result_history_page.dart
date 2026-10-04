import '../widgets/botanical_scene.dart';

import 'package:flutter/material.dart';

import '../stores/cat_store.dart';
import '../widgets/progress_components.dart';
import 'discovery_result_page.dart';
import 'community_posters_page.dart';

class ResultHistoryPage extends StatelessWidget {
  const ResultHistoryPage({super.key, required this.store});
  final CatStore store;
  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    mood: BotanicalMood.album,
    appBar: AppBar(title: const Text('Histórico de resultados')),
    body: AnimatedBuilder(
      animation: store,
      builder: (context, _) => RefreshIndicator(
        onRefresh: store.refreshGamification,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const IllustratedSectionHeader(
              title: 'Histórias que você guardou',
              description: 'Acompanhe o estado de cada registro e abra os detalhes do resultado.',
              art: 'ui/ui_notebook_cat',
              accent: 'ui/ui_bookmark_green_cat',
            ),
            const SizedBox(height: 18),
            if (store.progress.results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Os resultados confirmados aparecerão aqui após a sincronização.',
                ),
              ),
            if (store.progress.hasMore)
              TextButton(
                onPressed: store.progress.loadingOlder
                    ? null
                    : store.progress.loadOlder,
                child: Text(
                  store.progress.loadingOlder
                      ? 'Carregando…'
                      : 'Ver resultados anteriores',
                ),
              ),
            for (final result in store.progress.results)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BotanicalPaper(
                  foliage: false,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: GatalogoArt.image(
                      switch (result['record_type']) {
                        'clue' => 'icons/icon_search_paw_magnifier',
                        'post' || 'comment' => 'ui/ui_speech_ellipsis',
                        'repost' => 'ui/ui_note_pinned',
                        _ => 'ui/ui_cat_photos_stack',
                      },
                      width: 44,
                      height: 44,
                    ),
                    title: Text(switch (result['record_type']) {
                      'clue' => 'Sua pista ajudou',
                      'complement' => 'Foto complementar',
                      'post' => 'Publicação',
                      'comment' => 'Comentário',
                      'repost' => 'Cartaz compartilhado',
                      _ => 'Descoberta',
                    }),
                    subtitle: Text(
                      RecordStateNotice.label(
                        result['state'] as String? ?? 'pending',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/result'),
                        builder: (_) => DiscoveryResultPage(
                          store: store,
                          eventId: result['event_id'] as String,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class ContributionPage extends StatefulWidget {
  const ContributionPage({
    super.key,
    required this.store,
    required this.matchId,
  });
  final CatStore store;
  final String matchId;
  @override
  State<ContributionPage> createState() => _ContributionPageState();
}

class _ContributionPageState extends State<ContributionPage> {
  late final Future<Map<String, dynamic>> _data = widget.store.progress.api.get(
    '/app/progress/clues/${widget.matchId}',
  );
  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    mood: BotanicalMood.album,
    appBar: AppBar(title: const Text('Sua contribuição')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            IllustratedGardenStage(
              height: 174,
              child: GatalogoArt.image(
                data['status'] == 'confirmed'
                    ? 'rewards/reward_trophy_paw_gold'
                    : 'environment/environment_signpost_cat',
                width: 140,
                height: 144,
              ),
            ),
            const SizedBox(height: 18),
            RecordStateNotice(
              state: data['status'] == 'confirmed' ? 'confirmed' : 'pending',
              reason: data['message'] as String?,
            ),
            const SizedBox(height: 20),
            Text(
              data['report_status'] == 'active'
                  ? 'Busca em andamento'
                  : 'Caso encerrado',
            ),
            if (data['note'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('${data['note']}'),
              ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityCasePage(
                    session: widget.store.sessionStore,
                    reportId: data['report_id'] as String,
                  ),
                ),
              ),
              child: const Text('Abrir a busca'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Obrigado por ajudar. O crédito depende da confirmação do tutor e aparece uma única vez por busca.',
            ),
          ],
        );
      },
    ),
  );
}
