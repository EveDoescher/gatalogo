import '../widgets/botanical_scene.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import 'missing_cats_page.dart';

class MissingMapConsolidatedPage extends StatefulWidget {
  const MissingMapConsolidatedPage({
    super.key,
    required this.report,
    this.clues,
    required this.store,
    this.cat,
  });

  final Map<String, dynamic> report;
  final List<Map<String, dynamic>>? clues;
  final CatStore store;
  final Cat? cat;

  @override
  State<MissingMapConsolidatedPage> createState() =>
      _MissingMapConsolidatedPageState();
}

class _MissingMapConsolidatedPageState
    extends State<MissingMapConsolidatedPage> {
  final _map = MapController();
  Map<String, dynamic>? _selectedClue;
  List<Map<String, dynamic>> _clues = [];

  @override
  void initState() {
    super.initState();
    if (widget.clues != null) {
      _clues = List.of(widget.clues!);
    } else {
      _fetchClues();
    }
  }

  Future<void> _fetchClues() async {
    try {
      final rows = await ProductApiService(widget.store.sessionStore)
          .list('/app/reports/${widget.report['id']}/clues');
      if (mounted) {
        setState(() => _clues = rows);
        _fitAllMarkers();
      }
    } catch (_) {}
  }

  LatLng get _reportPoint => LatLng(
    (widget.report['latitude'] as num).toDouble(),
    (widget.report['longitude'] as num).toDouble(),
  );

  double get _reportRadius =>
      (widget.report['radius_meters'] as num?)?.toDouble() ?? 2000.0;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _fitAllMarkers() {
    final points = <LatLng>[_reportPoint];
    for (final clue in _clues) {
      if (clue['latitude'] != null && clue['longitude'] != null) {
        points.add(
          LatLng(
            (clue['latitude'] as num).toDouble(),
            (clue['longitude'] as num).toDouble(),
          ),
        );
      }
    }
    if (points.length == 1) {
      _map.move(_reportPoint, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // Marcador do Ponto Inicial de Desaparecimento
    markers.add(
      Marker(
        point: _reportPoint,
        width: 48,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(LucideIcons.home, size: 22, color: Colors.white),
          ),
        ),
      ),
    );

    // Marcadores das pistas com coordenadas reveladas
    final cluesWithCoords = _clues
        .where((c) => c['latitude'] != null && c['longitude'] != null)
        .toList();

    for (final clue in cluesWithCoords) {
      final point = LatLng(
        (clue['latitude'] as num).toDouble(),
        (clue['longitude'] as num).toDouble(),
      );
      final isSelected = _selectedClue?['id'] == clue['id'];
      final status = clue['status'] as String? ?? 'pending';

      Color pinColor;
      IconData pinIcon;
      if (status == 'confirmed') {
        pinColor = AppColors.greenProgress;
        pinIcon = LucideIcons.check;
      } else if (status == 'dismissed') {
        pinColor = AppColors.textLight;
        pinIcon = LucideIcons.x;
      } else {
        pinColor = AppColors.primary;
        pinIcon = LucideIcons.search;
      }

      markers.add(
        Marker(
          point: point,
          width: isSelected ? 50 : 40,
          height: isSelected ? 50 : 40,
          child: GestureDetector(
            onTap: () => setState(() => _selectedClue = clue),
            child: Container(
              decoration: BoxDecoration(
                color: pinColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.textTitle : Colors.white,
                  width: isSelected ? 3 : 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  pinIcon,
                  size: isSelected ? 22 : 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
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
          'Mapa de Avistamentos',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
          const AppHeaderActions(),
          IconButton(
            tooltip: 'Enquadrar todos',
            icon: const Icon(LucideIcons.maximize2, color: AppColors.textDark),
            onPressed: _fitAllMarkers,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _reportPoint,
              initialZoom: 14,
              onTap: (_, _) => setState(() => _selectedClue = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.catlogue',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _reportPoint,
                    radius: _reportRadius,
                    useRadiusInMeter: true,
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderStrokeWidth: 1.5,
                    borderColor: AppColors.error.withValues(alpha: 0.7),
                  ),
                ],
              ),
              MarkerLayer(markers: markers),
              const SimpleAttributionWidget(
                source: Text('© OpenStreetMap contributors'),
              ),
            ],
          ),

          // Legenda no topo
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(AppColors.error, 'Ponto de fuga'),
                    const SizedBox(width: 14),
                    _buildLegendItem(AppColors.greenProgress, 'Confirmado'),
                    const SizedBox(width: 14),
                    _buildLegendItem(AppColors.primary, 'Pendente'),
                    const SizedBox(width: 14),
                    _buildLegendItem(AppColors.textLight, 'Descartado'),
                  ],
                ),
              ),
            ),
          ),

          // Card flutuante com a pista selecionada
          if (_selectedClue != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.photo),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: PrivateCluePhoto(
                          path: _selectedClue!['photo_url'] as String,
                          session: widget.store.sessionStore,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedClue!['status'] == 'confirmed'
                                ? 'Pista confirmada'
                                : _selectedClue!['status'] == 'dismissed'
                                ? 'Pista descartada'
                                : 'Avistamento recebido',
                            style: GoogleFonts.fredoka(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~${((_selectedClue!['distance_meters'] as num) / 1000).toStringAsFixed(1)} km do ponto de fuga',
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
                        backgroundColor: AppColors.primary,
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
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClueDetailPage(
                            clue: _selectedClue!,
                            report: widget.report,
                            store: widget.store,
                          ),
                        ),
                      ),
                      child: Text(
                        'Ver',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => setState(() => _selectedClue = null),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
