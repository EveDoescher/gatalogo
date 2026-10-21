import '../widgets/botanical_scene.dart';
import '../widgets/game_components.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'location_page.dart';
import 'missing_map_consolidated_page.dart';

import '../widgets/private_clue_photo.dart';
import 'clue_detail_page.dart';

class CluesPage extends StatefulWidget {
  const CluesPage({
    super.key,
    required this.report,
    required this.store,
    this.openMatchId,
  });
  final Map<String, dynamic> report;
  final CatStore store;
  final String? openMatchId;
  @override
  State<CluesPage> createState() => _CluesPageState();
}

class _CluesPageState extends State<CluesPage> {
  List<Map<String, dynamic>> _clues = [];
  bool _loading = true, _opened = false;
  String? _error;
  String _filter = 'all'; // 'all', 'confirmed', 'pending', 'dismissed'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ProductApiService(widget.store.sessionStore)
          .list('/app/reports/${widget.report['id']}/clues');
      if (!mounted) return;
      setState(() {
        _clues = rows;
        _error = null;
      });
      if (!_opened && widget.openMatchId != null) {
        _opened = true;
        final selected = rows.where((row) => row['id'] == widget.openMatchId);
        if (selected.isNotEmpty) _open(selected.first);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> clue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClueDetailPage(
          clue: clue,
          report: widget.report,
          store: widget.store,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _reopenClue(Map<String, dynamic> clue) async {
    try {
      await ProductApiService(widget.store.sessionStore)
          .post('/vision/matches/${clue['id']}/reopen');
      if (mounted) {
        showMessage(context, 'Pista reaberta com sucesso.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _addManualSighting() async {
    final noteController = TextEditingController();
    LocationSelection? selectedLocation;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registrar Avistamento Manual',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTitle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Registre um avistamento mesmo sem foto recente para enriquecer o mapa de buscas.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: BorderSide(
                    color: selectedLocation == null
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                onPressed: () async {
                  final loc = await Navigator.push<LocationSelection>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationPage(
                        initial: LatLng(
                          (widget.report['latitude'] as num).toDouble(),
                          (widget.report['longitude'] as num).toDouble(),
                        ),
                        radius: 500,
                      ),
                    ),
                  );
                  if (loc != null) {
                    setSheetState(() => selectedLocation = loc);
                  }
                },
                icon: Icon(
                  selectedLocation == null
                      ? LucideIcons.mapPin
                      : LucideIcons.checkCircle,
                  size: 18,
                  color: selectedLocation == null
                      ? AppColors.primary
                      : AppColors.greenProgress,
                ),
                label: Text(
                  selectedLocation == null
                      ? 'Marcar local no mapa'
                      : 'Local selecionado no mapa',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: noteController,
                maxLength: 300,
                maxLines: 3,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
                decoration: const InputDecoration(
                  labelText: 'Observação do avistamento',
                  hintText:
                      'ex: Visto atravessando a rua perto da praça às 17h.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GatalogoButton(
                text: 'Salvar Avistamento',
                onPressed: () async {
                  if (selectedLocation == null) {
                    showMessage(
                      context,
                      'Escolha o local do avistamento no mapa.',
                    );
                    return;
                  }
                  final catId = widget.report['cat_client_id'] as String;
                  try {
                    await widget.store.recordSighting(
                      catId,
                      latitude: selectedLocation!.point.latitude,
                      longitude: selectedLocation!.point.longitude,
                      note: noteController.text.trim().isEmpty
                          ? 'Avistamento manual informado pelo tutor'
                          : noteController.text.trim(),
                      observedAt: DateTime.now(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showMessage(
                        context,
                        'Avistamento registrado com sucesso.',
                      );
                      _load();
                    }
                  } catch (e) {
                    if (ctx.mounted) showMessage(ctx, e);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.store.cats.where(
      (c) => c.id == widget.report['cat_client_id'],
    );
    final cat = cats.isEmpty ? null : cats.first;

    final confirmedList = _clues
        .where((c) => c['status'] == 'confirmed')
        .toList();
    final pendingList = _clues.where((c) => c['status'] == 'pending').toList();
    final dismissedList = _clues
        .where((c) => c['status'] == 'dismissed')
        .toList();

    List<Map<String, dynamic>> filteredList;
    if (_filter == 'confirmed') {
      filteredList = confirmedList;
    } else if (_filter == 'pending') {
      filteredList = pendingList;
    } else if (_filter == 'dismissed') {
      filteredList = dismissedList;
    } else {
      filteredList = _clues;
    }

    return BotanicalScaffold(
      mood: BotanicalMood.care,
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
          'Pistas',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
          const AppHeaderActions(),
          IconButton(
            tooltip: 'Mapa Consolidado',
            icon: const Icon(LucideIcons.map, color: AppColors.textDark),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MissingMapConsolidatedPage(
                  report: widget.report,
                  clues: _clues,
                  store: widget.store,
                  cat: cat,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(
              LucideIcons.refreshCw,
              size: 20,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: IllustratedSectionTitle(
              title: 'Pistas e Avistamentos',
              art: 'icons/icon_search_paw_magnifier',
            ),
          ),
          // Barra de Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Todas (${_clues.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'pending',
                    'Pendentes (${pendingList.length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'confirmed',
                    'Reconhecidas (${confirmedList.length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'dismissed',
                    'Descartadas (${dismissedList.length})',
                  ),
                ],
              ),
            ),
          ),

          // Botão Registrar Avistamento Manual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: _addManualSighting,
                icon: const Icon(LucideIcons.plusCircle, size: 16),
                label: Text(
                  'Registrar Avistamento Manual (sem foto)',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error != null
                ? EmptyContent(
                    'Não foi possível carregar',
                    _error!,
                    action: TextButton(
                      onPressed: _load,
                      child: const Text('Tentar novamente'),
                    ),
                  )
                : filteredList.isEmpty
                ? SingleChildScrollView(
                    child: BotanicalEmpty(
                      title: _filter == 'all'
                          ? 'Ainda sem pistas'
                          : 'Nenhuma pista neste filtro',
                      description: _filter == 'all'
                          ? 'Os possíveis avistamentos cruzados pela inteligência artificial aparecerão aqui.'
                          : 'Não há registros com o status selecionado no momento.',
                      art: 'environment/environment_route_dotted_pin_flag',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final clue = filteredList[index];
                      return _buildTimelineItem(
                        clue,
                        index == filteredList.length - 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> clue, bool isLast) {
    final status = clue['status'] as String? ?? 'pending';
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'confirmed') {
      statusColor = AppColors.greenProgress;
      statusLabel = 'Pista reconhecida';
      statusIcon = LucideIcons.checkCircle;
    } else if (status == 'dismissed') {
      statusColor = AppColors.textLight;
      statusLabel = 'Pista descartada';
      statusIcon = LucideIcons.xCircle;
    } else {
      statusColor = AppColors.primary;
      statusLabel = 'Pendente de análise';
      statusIcon = LucideIcons.clock;
    }

    final distanceKm = ((clue['distance_meters'] as num? ?? 0) / 1000)
        .toStringAsFixed(1);
    final dateStr = displayDate(clue['created_at']);
    final note = clue['note'] as String?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna da Timeline (ponto + linha conectora)
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 2),
              ),
              child: Icon(statusIcon, size: 12, color: statusColor),
            ),
            if (!isLast)
              Container(width: 2, height: 110, color: AppColors.borderLight),
          ],
        ),
        const SizedBox(width: 12),

        // Conteúdo do Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => _open(clue),
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        GamePhotoMount(
                          child: SizedBox(
                            width: 62,
                            height: 62,
                            child: PrivateCluePhoto(
                              path: clue['photo_url'] as String,
                              session: widget.store.sessionStore,
                              height: 62,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aprox. $distanceKm km do local de busca',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (note != null && note.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  '"$note"',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                      ],
                    ),

                    if (status == 'dismissed') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _reopenClue(clue),
                          icon: const Icon(
                            LucideIcons.undo,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            'Desfazer descarte',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
