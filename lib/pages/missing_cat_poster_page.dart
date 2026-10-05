import '../widgets/app_header_actions.dart';
import '../widgets/botanical_scene.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/missing_poster_artwork.dart';
import '../widgets/poster_export_actions.dart';

import '../models/cat.dart';
import '../models/missing_poster.dart';
import '../services/product_api_service.dart';
import '../widgets/poster_settings_editor.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class MissingCatPosterPage extends StatefulWidget {
  const MissingCatPosterPage({
    super.key,
    required this.cat,
    required this.report,
    this.locationName,
    this.catStore,
    this.initialEditing = false,
    this.onUpdated,
  });
  final Cat cat;
  final Map<String, dynamic> report;
  final String? locationName;
  final CatStore? catStore;
  final bool initialEditing;
  final ValueChanged<Map<String, dynamic>>? onUpdated;
  @override
  State<MissingCatPosterPage> createState() => _MissingCatPosterPageState();
}

class _MissingCatPosterPageState extends State<MissingCatPosterPage> {
  late final PosterEditorController _editor;
  late Map<String, dynamic> _report;
  bool _editing = false, _busy = false, _allowExit = false;
  String? _error;
  bool get _active => _report['status'] == 'active';
  @override
  void initState() {
    super.initState();
    _report = Map.of(widget.report);
    _editor = PosterEditorController(_report)..addListener(_changed);
    _editing = widget.initialEditing;
  }

  void _changed() {
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _editor.removeListener(_changed);
    _editor.dispose();
    super.dispose();
  }

  MissingPoster get _poster => MissingPoster(
    cat: widget.cat,
    report: _editor.apply(_report),
    locationName: widget.locationName,
  );

  Future<MissingPoster?> _prepare() async {
    if (!_active) return null;
    final error = _editor.error;
    if (error != null) {
      setState(() {
        _editing = true;
        _error = error;
      });
      return null;
    }
    if (widget.catStore == null) return _poster;
    try {
      final data = await ProductApiService(
        widget.catStore!.sessionStore,
      ).put('/vision/missing-reports/${_report['id']}/poster', _editor.payload);
      if (!mounted) return null;
      setState(() {
        _report.addAll(data);
        _editor.dirty = false;
        _error = null;
      });
      widget.onUpdated?.call(Map.of(_report));
      return _poster;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          if (error is ProductApiException && error.statusCode == 409) {
            _report['status'] = 'resolved';
            widget.onUpdated?.call(Map.of(_report));
          }
        });
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await _prepare();
    if (mounted) {
      setState(() => _busy = false);
      if (saved != null) showMessage(context, 'Cartaz atualizado.');
    }
  }

  Future<bool> _publish() async {
    if (widget.catStore == null) return false;
    await ProductApiService(widget.catStore!.sessionStore)
        .post('/social/reports/${_report['id']}/publish');
    await widget.catStore!.refreshGamification();
    return true;
  }

  Future<void> _close() async {
    if (_busy) return;
    final leave =
        !_editor.dirty ||
        await confirmAction(
          context,
          'Sair sem salvar?',
          'As alterações do cartaz ainda não foram salvas.',
          'Sair sem salvar',
        );
    if (leave && mounted) {
      setState(() => _allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || (!_busy && !_editor.dirty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: BotanicalScaffold(
      level: BotanicalLevel.tertiary,
      mood: BotanicalMood.care,
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        title: const Text('Cartaz de busca'),
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: _busy ? null : _close,
          icon: const Icon(LucideIcons.chevronLeft),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const IllustratedSectionTitle(
            title: 'Ajude a encontrar meu gato',
            art: 'ui/ui_clipboard_paw',
          ),
          const SizedBox(height: 12),
          Text(
            _active
                ? 'Escolha os detalhes e contatos antes de divulgar. A prévia acompanha suas alterações.'
                : 'Busca encerrada. Este cartaz não deve ser divulgado como uma busca ativa.',
            style: const TextStyle(color: AppColors.textMedium),
          ),
          const SizedBox(height: 20),
          if (_active)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(LucideIcons.eye),
                  label: Text('Prévia'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(LucideIcons.settings2),
                  label: Text('Personalizar'),
                ),
              ],
              selected: {_editing},
              onSelectionChanged: _busy
                  ? null
                  : (value) => setState(() => _editing = value.first),
            ),
          const SizedBox(height: 16),
          if (_editing && _active)
            PosterSettingsEditor(controller: _editor, enabled: !_busy)
          else
            MissingPosterArtwork(poster: _poster),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorText),
                ),
              ),
            ),
          if (_active) ...[
            const SizedBox(height: 20),
            if (_editor.dirty) ...[
              const Text(
                'Alterações ainda não salvas',
                style: TextStyle(color: AppColors.textMedium),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(LucideIcons.check),
                label: const Text('Salvar alterações'),
              ),
              const SizedBox(height: 16),
            ],
            PosterExportActions(
              poster: _poster,
              prepare: _prepare,
              onBusyChanged: (value) {
                if (mounted) setState(() => _busy = value);
              },
              onCommunity: widget.catStore == null ? null : _publish,
              onShared: () async {
                await widget.catStore?.recordGamificationAction('share');
                await widget.catStore?.recordHabitatAction(
                  'share',
                  targetType: 'report',
                  targetId: _report['id']?.toString(),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}
