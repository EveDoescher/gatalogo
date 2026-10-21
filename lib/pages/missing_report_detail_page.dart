import '../widgets/botanical_scene.dart';
import '../widgets/game_components.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/cat.dart';
import '../services/location_service.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'location_page.dart';
import 'missing_cat_poster_page.dart';
import 'missing_map_consolidated_page.dart';

import 'clues_page.dart';

class MissingReportDetailPage extends StatefulWidget {
  const MissingReportDetailPage({
    super.key,
    required this.report,
    required this.store,
    this.openPosterInitially = false,
  });
  final Map<String, dynamic> report;
  final CatStore store;
  final bool openPosterInitially;
  @override
  State<MissingReportDetailPage> createState() =>
      _MissingReportDetailPageState();
}

class _MissingReportDetailPageState extends State<MissingReportDetailPage> {
  late Map<String, dynamic> _report;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _report = Map.of(widget.report);
    if (widget.openPosterInitially) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final cat = widget.store.pets
            .where((cat) => cat.id == _report['cat_client_id'])
            .firstOrNull;
        if (cat != null) _openPoster(cat, editing: true);
      });
    }
  }

  Future<void> _editArea() async {
    final selected = await Navigator.push<LocationSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPage(
          initial: LatLng(
            (_report['latitude'] as num).toDouble(),
            (_report['longitude'] as num).toDouble(),
          ),
          radius: _report['radius_meters'] as int,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final address = await LocationService.getLocationName(
        selected.point.latitude,
        selected.point.longitude,
      );
      final data = {
        'last_seen_address': address,
        'latitude': selected.point.latitude,
        'longitude': selected.point.longitude,
        'radius_meters': selected.radius,
      };
      await ProductApiService(widget.store.sessionStore)
          .request('PUT', '/app/reports/${_report['id']}', data);
      if (mounted) setState(() => _report.addAll(data));
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPoster(Cat cat, {bool editing = false}) async {
    String? address = _report['last_seen_address']?.toString();
    address ??= await LocationService.getLocationName(
      (_report['latitude'] as num).toDouble(),
      (_report['longitude'] as num).toDouble(),
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MissingCatPosterPage(
          cat: cat,
          initialEditing: editing,
          onUpdated: (data) {
            if (mounted) setState(() => _report.addAll(data));
          },
          report: _report,
          catStore: widget.store,
          locationName: address,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _resolve() async {
    if (!await confirmAction(
      context,
      'Encerrar este alerta?',
      'Encerre quando seu gato estiver seguro ou quando quiser parar esta busca. O histórico será mantido.',
      'Encerrar alerta',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ProductApiService(widget.store.sessionStore)
          .post('/vision/missing-reports/${_report['id']}/resolve');
      if (mounted) setState(() => _report['status'] = 'resolved');
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.store.cats.where(
      (cat) => cat.id == _report['cat_client_id'],
    );
    final isActive = _report['status'] == 'active';
    final cat = cats.isEmpty ? null : cats.first;

    return BotanicalScaffold(
      mood: BotanicalMood.care,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 1.2),
            ),
            child: const Icon(
              LucideIcons.chevronLeft,
              color: AppColors.textDark,
              size: 22,
            ),
          ),
        ),
        title: Text(
          _report['name'] ?? 'Detalhes do Alerta',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          // Card 1: Perfil do Gato e Status
          GatalogoCard(
            backgroundColor: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cat != null)
                  GestureDetector(
                    onTap: () => showFullscreenImage(
                      context,
                      imagePath: cat.photoPath,
                      title: cat.displayName,
                    ),
                    child: GamePhotoCard(
                      cat: cat,
                      height: 190,
                      showName: false,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat?.displayName ?? _report['name'] ?? 'Gato',
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Alerta aberto em ${displayDate(_report['created_at'])}',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.errorBg
                            : AppColors.greenLight,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: isActive
                              ? AppColors.error.withValues(alpha: 0.3)
                              : AppColors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isActive ? 'Em busca ativa' : 'Alerta concluído',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isActive
                              ? AppColors.error
                              : AppColors.greenLink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Card 2: Área de Busca
          GatalogoCard(
            backgroundColor: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GatalogoArt.image(
                      'environment/environment_cat_map',
                      width: 42,
                      height: 46,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Área de Monitoramento',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Raio de busca: ${((_report['radius_meters'] as num) / 1000).toStringAsFixed(1)} km ao redor do ponto inicial.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPage(
                              initial: LatLng(
                                (_report['latitude'] as num).toDouble(),
                                (_report['longitude'] as num).toDouble(),
                              ),
                              radius: _report['radius_meters'] as int,
                              readOnly: true,
                            ),
                          ),
                        ),
                        icon: const Icon(LucideIcons.map, size: 16),
                        label: const Text('Ver Mapa'),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(
                              color: AppColors.borderProfile,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: _busy ? null : _editArea,
                          icon: const Icon(LucideIcons.edit3, size: 16),
                          label: const Text('Ajustar Área'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Card 3: Pistas e Avistamentos
          GatalogoCard(
            backgroundColor: AppColors.cardBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GatalogoArt.image(
                      'icons/icon_search_paw_magnifier',
                      width: 42,
                      height: 46,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Pistas e Avistamentos',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A inteligência do Gatálogo cruza fotos registradas na região para encontrar semelhanças com o seu gato.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CluesPage(report: _report, store: widget.store),
                    ),
                  ),
                  icon: const Icon(Icons.pets, size: 16),
                  label: Text(
                    'Explorar Avistamentos',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    try {
                      final clues = await ProductApiService(
                        widget.store.sessionStore,
                      ).list('/app/reports/${_report['id']}/clues');
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MissingMapConsolidatedPage(
                              report: _report,
                              clues: clues,
                              store: widget.store,
                              cat: cat,
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) showMessage(context, error);
                    }
                  },
                  icon: const Icon(LucideIcons.map, size: 16),
                  label: Text(
                    'Ver Mapa Consolidado',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card 4: Cartaz Digital de Busca
          if (cat != null && isActive) ...[
            const SizedBox(height: AppSpacing.md),
            GatalogoCard(
              backgroundColor: AppColors.surface,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      size: 22,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cartaz Digital de Busca',
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Escolha informações e contatos, publique na comunidade ou exporte para compartilhar e imprimir.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _openPoster(cat),
                    child: Text(
                      'Abrir',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isActive) ...[
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: _busy ? null : _resolve,
                icon: const Icon(LucideIcons.checkCircle, size: 18),
                label: Text(
                  _busy ? 'Encerrando…' : 'Encerrar este alerta',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
