import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/missing_poster.dart';
import '../services/missing_poster_export.dart';
import 'app_widgets.dart';

class PosterExportActions extends StatefulWidget {
  const PosterExportActions({
    super.key,
    required this.poster,
    required this.onShared,
    this.prepare,
    this.onCommunity,
    this.onBusyChanged,
    this.communityLabel = 'Publicar na comunidade',
  });
  final MissingPoster poster;
  final String communityLabel;
  final Future<MissingPoster?> Function()? prepare;
  final Future<bool> Function()? onCommunity;
  final ValueChanged<bool>? onBusyChanged;
  final Future<void> Function() onShared;
  @override
  State<PosterExportActions> createState() => _PosterExportActionsState();
}

class _PosterExportActionsState extends State<PosterExportActions> {
  bool _busy = false;
  Future<void> _run(
    Future<bool> Function(MissingPoster) action,
    String message, {
    bool share = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      final poster = widget.prepare == null
          ? widget.poster
          : await widget.prepare!();
      if (poster == null) return;
      if (await action(poster)) {
        if (share) await widget.onShared();
        if (mounted) showMessage(context, message);
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Não foi possível exportar o cartaz. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Divulgar cartaz', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      const Text('Compartilhe a imagem ou leve uma cópia para imprimir.'),
      const SizedBox(height: 12),
      if (widget.onCommunity != null) ...[
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  (_) => widget.onCommunity!(),
                  'Cartaz publicado na comunidade.',
                ),
          icon: const Icon(LucideIcons.users),
          label: Text(widget.communityLabel),
        ),
        const SizedBox(height: 8),
      ],
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () {
                final box = context.findRenderObject() as RenderBox?;
                final origin = box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size;
                _run(
                  (poster) => MissingPosterExport.share(poster, origin: origin),
                  'Cartaz compartilhado.',
                  share: true,
                );
              },
        icon: const Icon(LucideIcons.share2),
        label: Text(
          _busy ? 'Preparando cartaz…' : 'Compartilhar em outros apps',
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => _run(
                (poster) => MissingPosterExport.save(poster),
                'Imagem salva.',
              ),
        icon: const Icon(LucideIcons.download),
        label: const Text('Salvar imagem do cartaz'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => _run(
                (poster) => MissingPosterExport.save(poster, printable: true),
                'PDF salvo.',
              ),
        icon: const Icon(LucideIcons.fileText),
        label: const Text('Salvar PDF para imprimir'),
      ),
      TextButton.icon(
        onPressed: _busy
            ? null
            : () => _run(
                (poster) => MissingPosterExport.printPoster(poster),
                'Cartaz enviado para impressão.',
              ),
        icon: const Icon(LucideIcons.printer),
        label: const Text('Imprimir cartaz'),
      ),
    ],
  );
}
