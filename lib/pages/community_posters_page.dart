import 'package:flutter/services.dart';

import '../models/missing_poster.dart';
import '../widgets/missing_poster_artwork.dart';
import '../widgets/poster_export_actions.dart';
import '../widgets/botanical_scene.dart';
import '../widgets/game_components.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';

import '../stores/session_store.dart';
import '../services/product_api_service.dart';
import '../config/api_config.dart';

class CommunityPostersPage extends StatefulWidget {
  const CommunityPostersPage({super.key, required this.session});
  final SessionStore session;
  @override
  State<CommunityPostersPage> createState() => _CommunityPostersPageState();
}

class _CommunityPostersPageState extends State<CommunityPostersPage> {
  List<Map<String, dynamic>> _reports = [];
  String? _error;
  bool _loading = true;
  final Set<String> _posted = {}, _busy = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ProductApiService(widget.session)
          .list('/social/reports');
      if (mounted) {
        setState(() {
          _reports = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _repost(String id) async {
    final store = AppStoreScope.maybeOf(context);
    setState(() => _busy.add(id));
    try {
      await ProductApiService(widget.session)
          .post('/social/reports/$id/repost');
      if (mounted) setState(() => _posted.add(id));
      await store?.refreshGamification();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    mood: BotanicalMood.care,
    appBar: AppBar(title: const Text('Cartazes de busca')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const IllustratedPaperHeading(
            title: 'Ajude um gato a voltar para casa',
            description: 'Compartilhe dentro da comunidade para ajudar. O cartaz mantém o vínculo e o estado da busca original.',
            art: 'icons/icon_search_paw_magnifier',
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (!_loading && _reports.isEmpty)
            const BotanicalEmpty(
              title: 'Nenhum cartaz ativo no momento.',
              description:
                  'Os cartazes das buscas da comunidade aparecerão aqui.',
              art: 'ui/ui_clipboard_paw',
            ),
          for (final report in _reports)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GamePhotoMount(
                      child: AspectRatio(
                        aspectRatio: 1.6,
                        child: Image.network(
                          '${ApiConfig.baseUrl}${report['photo_url']}',
                          headers: {
                            'Authorization':
                                'Bearer ${widget.session.session?.accessToken ?? ''}',
                          },
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) =>
                              const Icon(Icons.pets, size: 64),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${report['name']}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${report['status'] == 'active' ? 'Busca ativa' : 'Caso encerrado'} · cartaz de ${report['author']}',
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityCasePage(
                            session: widget.session,
                            reportId: report['id'] as String,
                          ),
                        ),
                      ),
                      child: const Text('Abrir busca e contatos'),
                    ),

                    if (report['is_owner'] != true &&
                        report['status'] == 'active')
                      TextButton.icon(
                        onPressed:
                            _busy.contains(report['id']) ||
                                _posted.contains(report['id'])
                            ? null
                            : () => _repost(report['id'] as String),
                        icon: const Icon(Icons.repeat),
                        label: Text(
                          _posted.contains(report['id'])
                              ? 'Publicado na comunidade'
                              : 'Repostar na comunidade',
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class CommunityCasePage extends StatefulWidget {
  const CommunityCasePage({
    super.key,
    required this.session,
    required this.reportId,
  });
  final SessionStore session;
  final String reportId;
  @override
  State<CommunityCasePage> createState() => _CommunityCasePageState();
}

class _CommunityCasePageState extends State<CommunityCasePage> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _data = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final api = ProductApiService(widget.session);
    final data = await api.get('/social/reports/${widget.reportId}');
    if (data['status'] == 'active' && data['photo_url'] != null) {
      data['_photoBytes'] = await api.photo(data['photo_url'] as String);
    }
    return data;
  }

  Future<MissingPoster?> _prepare() async {
    final data = await _fetch();
    if (mounted) setState(() => _data = Future.value(data));
    if (data['status'] != 'active') return null;
    return MissingPoster.publicReport(
      report: data,
      photoBytes: data['_photoBytes'],
    );
  }

  Future<bool> _publish(Map<String, dynamic> data) async {
    await ProductApiService(widget.session).post(
      '/social/reports/${widget.reportId}/${data['is_owner'] == true ? 'publish' : 'repost'}',
    );
    if (mounted) await AppStoreScope.maybeOf(context)?.refreshGamification();
    return true;
  }

  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    mood: BotanicalMood.care,
    appBar: AppBar(title: const Text('Busca por um gato')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _data = _fetch()),
              child: const Text('Tentar novamente'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final active = data['status'] == 'active';
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _data = _fetch());
            await _data;
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const IllustratedSectionTitle(
                title: 'Uma busca da comunidade',
                art: 'icons/icon_search_paw_magnifier',
              ),
              const SizedBox(height: 18),
              Text(
                '${data['name']}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${active ? 'Busca ativa' : 'Caso encerrado'} · ${data['author']}',
              ),
              const SizedBox(height: 20),
              if (active)
                MissingPosterArtwork(
                  poster: MissingPoster.publicReport(
                    report: data,
                    photoBytes: data['_photoBytes'],
                  ),
                ),
              if (data['description'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('${data['description']}'),
                ),
              const SizedBox(height: 20),
              if (data['message'] != null) Text('${data['message']}'),
              if (active) ...[
                const SizedBox(height: 20),
                const Text(
                  'Viu um gato parecido? Registre a foto e a localização pelo Gatalogar. O aplicativo verifica possíveis correspondências e envia a pista ao tutor.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Observe à distância. Não persiga, toque ou tente capturar o animal.',
                ),
                for (final contact in (data['contacts'] as List? ?? []))
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: SelectableText('${contact['phone']}'),
                    trailing: IconButton(
                      tooltip: 'Copiar telefone',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: '${contact['phone']}'),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Telefone copiado.')),
                          );
                        }
                      },
                    ),
                    subtitle: Text(
                      contact['whatsapp'] == true
                          ? 'Contato do tutor · WhatsApp'
                          : 'Contato do tutor',
                    ),
                  ),
                const SizedBox(height: 20),
                PosterExportActions(
                  poster: MissingPoster.publicReport(
                    report: data,
                    photoBytes: data['_photoBytes'],
                  ),
                  prepare: _prepare,
                  onCommunity: () => _publish(data),
                  onShared: () async {},
                  communityLabel: data['is_owner'] == true
                      ? 'Publicar na comunidade'
                      : 'Repostar na comunidade',
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('Esta busca não recebe novos reposts premiados.'),
                ),
            ],
          ),
        );
      },
    ),
  );
}
