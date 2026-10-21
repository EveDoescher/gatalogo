import '../widgets/botanical_scene.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';

import 'auth_page.dart';

import 'create_missing_report_page.dart';
import 'missing_report_detail_page.dart';

export 'create_missing_report_page.dart';
export 'missing_report_detail_page.dart';
export 'clues_page.dart';
export '../widgets/private_clue_photo.dart';
export 'clue_detail_page.dart';

class MissingCatsPage extends StatefulWidget {
  const MissingCatsPage({
    super.key,
    required this.catStore,
    required this.sessionStore,
  });
  final CatStore catStore;
  final SessionStore sessionStore;
  @override
  State<MissingCatsPage> createState() => _MissingCatsPageState();
}

class _MissingCatsPageState extends State<MissingCatsPage> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ProductApiService(widget.sessionStore)
          .list('/app/reports');
      if (mounted) setState(() => _reports = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    mood: BotanicalMood.care,
    appBar: AppBar(
      title: Text(
        'Gatos desaparecidos',
        style: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textTitle,
        ),
      ),
      actions: [
        const AppHeaderActions(),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: !widget.sessionStore.isSignedIn
        ? SingleChildScrollView(
            child: BotanicalEmpty(
              title: 'Receba pistas do seu gato',
              description: 'Entre na sua conta para criar alertas e receber avistamentos.',
              art: 'environment/environment_signpost_cat',
              action: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthPage(
                      sessionStore: widget.sessionStore,
                      onContinueOffline: () => Navigator.pop(context),
                    ),
                  ),
                ),
                child: const Text('Entrar na conta'),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateMissingReportPage(store: widget.catStore),
                        ),
                      );
                      if (mounted) _load();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Criar alerta',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                if (_loading)
                  LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                if (_error != null)
                  EmptyContent(
                    'Não foi possível carregar',
                    _error!,
                    action: TextButton(
                      onPressed: _load,
                      child: const Text('Tentar novamente'),
                    ),
                  ),
                if (!_loading && _error == null && _reports.isEmpty)
                  const BotanicalEmpty(
                    title: 'Nenhum alerta por aqui',
                    description: 'Se um dos seus gatos desaparecer, crie um alerta com o último local onde ele foi visto.',
                    art: 'environment/environment_signpost_cat',
                  ),
                for (final status in ['active', 'resolved']) ...[
                  if (_reports.any((item) => item['status'] == status))
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        status == 'active' ? 'Em busca' : 'Concluídos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ..._reports
                      .where((item) => item['status'] == status)
                      .map(
                        (report) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: GatalogoCard(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MissingReportDetailPage(
                                    report: report,
                                    store: widget.catStore,
                                  ),
                                ),
                              );
                              if (mounted) _load();
                            },
                            child: Row(
                              children: [
                                GatalogoArt.image(
                                  status == 'active'
                                      ? 'icons/icon_search_paw_magnifier'
                                      : 'icons/icon_heart_coral',
                                  width: 52,
                                  height: 58,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        report['name'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${displayDate(report['created_at'])} · ${report['clue_count'] ?? 0} pista(s)',
                                      ),
                                      if (report['last_seen_address'] != null)
                                        Text(
                                          '${report['last_seen_address']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
  );
}
