import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/location_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'cat_details_page.dart';

class LocationSelection {
  const LocationSelection(this.point, this.radius);
  final LatLng point;
  final int radius;
}

class LocationPage extends StatefulWidget {
  const LocationPage({
    super.key,
    this.initial,
    this.radius,
    this.catStore,
    this.catId,
    this.readOnly = false,
  });

  final LatLng? initial;
  final int? radius;
  final CatStore? catStore;
  final String? catId;
  final bool readOnly;

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _map = MapController();
  final _note = TextEditingController();
  final _searchController = TextEditingController();
  LatLng? _point;
  late double _radius;
  bool _saving = false;
  bool _locating = false;
  bool _searchingAddress = false;
  final DateTime _observedAt = DateTime.now();
  Cat? _selectedCat;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
    _radius = (widget.radius ?? 500).toDouble();

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });

    if (_point != null) {
      // Ponto inicial fornecido
    } else if (widget.readOnly && widget.catStore != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCatsOnMap();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locate(silent: true, autoSelect: !widget.readOnly);
      });
    }
  }

  void _fitCatsOnMap() {
    if (widget.catStore == null) return;
    final catsWithLoc = widget.catStore!.cats
        .where((c) => c.latitude != null && c.longitude != null)
        .toList();
    if (catsWithLoc.isEmpty) {
      _locate(silent: true, autoSelect: false);
      return;
    }
    if (catsWithLoc.length == 1) {
      final first = catsWithLoc.first;
      _map.move(LatLng(first.latitude!, first.longitude!), 15);
      return;
    }
    final points = catsWithLoc
        .map((c) => LatLng(c.latitude!, c.longitude!))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 80),
      ),
    );
  }

  Map<String, LatLng> _calculateMarkerPositions(List<Cat> cats) {
    final positions = <String, LatLng>{};
    final clusters = <List<Cat>>[];

    for (final cat in cats) {
      if (cat.latitude == null || cat.longitude == null) continue;
      bool added = false;
      for (final cluster in clusters) {
        final ref = cluster.first;
        final dLat = (ref.latitude! - cat.latitude!).abs();
        final dLng = (ref.longitude! - cat.longitude!).abs();
        if (dLat < 0.00015 && dLng < 0.00015) {
          cluster.add(cat);
          added = true;
          break;
        }
      }
      if (!added) {
        clusters.add([cat]);
      }
    }

    for (final cluster in clusters) {
      if (cluster.length == 1) {
        final c = cluster.first;
        positions[c.id] = LatLng(c.latitude!, c.longitude!);
      } else {
        final n = cluster.length;
        final baseLat = cluster.first.latitude!;
        final baseLng = cluster.first.longitude!;
        const radiusDegrees = 0.00028;
        for (int i = 0; i < n; i++) {
          final angle = 2 * math.pi * i / n;
          final offsetLat = radiusDegrees * math.cos(angle);
          final offsetLng = radiusDegrees * math.sin(angle);
          positions[cluster[i].id] =
              LatLng(baseLat + offsetLat, baseLng + offsetLng);
        }
      }
    }
    return positions;
  }

  @override
  void dispose() {
    _map.dispose();
    _note.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performAddressSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _searchingAddress = true);
    try {
      final results = await LocationService.searchAddress(query);
      if (!mounted) return;
      if (results.isNotEmpty) {
        final loc = results.first;
        final targetPoint = LatLng(loc.latitude, loc.longitude);
        setState(() {
          if (!widget.readOnly) {
            _point = targetPoint;
          }
        });
        _map.move(targetPoint, 15);
        showMessage(context, 'Endereço localizado no mapa.');
      } else {
        showMessage(context, 'Nenhum local encontrado para a busca informada.');
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Erro ao buscar o endereço.');
    } finally {
      if (mounted) setState(() => _searchingAddress = false);
    }
  }

  Future<void> _locate({bool silent = false, bool autoSelect = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await LocationService.getCurrentLocation().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      if (position != null) {
        final userPoint = LatLng(position.latitude, position.longitude);
        setState(() {
          if (autoSelect || _point == null) {
            _point = userPoint;
          }
        });
        _map.move(userPoint, 15);
      } else if (!silent) {
        showMessage(
          context,
          'Localização indisponível. Toque no mapa para escolher o ponto.',
        );
      }
    } catch (_) {
      if (mounted && !silent) {
        showMessage(
          context,
          'Não foi possível obter sua localização. Escolha o ponto no mapa.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_point == null) return;
    if (widget.catId == null) {
      Navigator.pop(context, LocationSelection(_point!, _radius.round()));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.catStore!.recordSighting(
        widget.catId!,
        latitude: _point!.latitude,
        longitude: _point!.longitude,
        note: _note.text.trim(),
        observedAt: _observedAt,
      );
      if (mounted) {
        showMessage(
          context,
          'Avistamento salvo. Ele será enviado quando houver conexão.',
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showCatInfo(Cat cat) {
    setState(() => _selectedCat = cat);
    _map.move(LatLng(cat.latitude!, cat.longitude!), 16);
  }

  @override
  Widget build(BuildContext context) {
    // Gatos avistados para renderizar pins no mapa
    final catMarkers = <Marker>[];
    final catsWithLoc = widget.catStore?.cats
            .where((c) => c.latitude != null && c.longitude != null)
            .toList() ??
        [];
    final markerPositions = _calculateMarkerPositions(catsWithLoc);

    for (final cat in catsWithLoc) {
      final pos = markerPositions[cat.id] ??
          LatLng(cat.latitude!, cat.longitude!);
      final isSelected = _selectedCat?.id == cat.id;
      catMarkers.add(
        Marker(
          point: pos,
          width: isSelected ? 54 : 44,
          height: isSelected ? 54 : 44,
          child: GestureDetector(
            onTap: () => _showCatInfo(cat),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryDark : AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Center(
                child: ClipOval(
                  child: SizedBox(
                    width: isSelected ? 42 : 34,
                    height: isSelected ? 42 : 34,
                    child: CatPhotoView(
                      cat.photoPath,
                      fit: BoxFit.cover,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Ponto padrao central se ainda nao houver GPS
    LatLng defaultCenter = const LatLng(-14.2350, -51.9253);
    if (widget.initial != null) {
      defaultCenter = widget.initial!;
    } else if (widget.catStore != null && widget.catStore!.cats.any((c) => c.latitude != null)) {
      final firstWithCoords = widget.catStore!.cats.firstWhere((c) => c.latitude != null);
      defaultCenter = LatLng(firstWithCoords.latitude!, firstWithCoords.longitude!);
    }

    final pageTitle = widget.catId != null
        ? 'Registrar Avistamento'
        : widget.readOnly && widget.catStore != null
            ? 'Meus Avistamentos'
            : 'Localização';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
          pageTitle,
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _point ?? defaultCenter,
                    initialZoom: _point != null ? 15 : 14,
                    onTap: widget.readOnly || _saving
                        ? null
                        : (_, point) {
                            setState(() {
                              _point = point;
                              _selectedCat = null;
                            });
                          },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.catlogue',
                    ),
                    if (_point != null && widget.radius != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _point!,
                            radius: _radius,
                            useRadiusInMeter: true,
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderStrokeWidth: 1.5,
                            borderColor: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    // Pins dos gatos avistados
                    if (catMarkers.isNotEmpty)
                      MarkerLayer(markers: catMarkers),
                    // Pin de seleção de local
                    if (_point != null && (!widget.readOnly || widget.catStore == null))
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _point!,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_on,
                              size: 44,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors'),
                    ),
                  ],
                ),
              ),

              // Painel inferior
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.readOnly && widget.catStore != null && catMarkers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Nenhum gato avistado com coordenadas ainda. Use a câmera ao ar livre para registrar!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ),
                      if (!widget.readOnly) ...[
                        Text(
                          _point == null
                              ? 'Toque no mapa para indicar o local.'
                              : 'Local selecionado no mapa.',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                          ),
                        ),
                        if (widget.radius != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Raio de busca: ${(_radius / 1000).toStringAsFixed(1)} km',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Slider(
                            value: _radius,
                            min: 100,
                            max: 50000,
                            divisions: 499,
                            activeColor: AppColors.primary,
                            inactiveColor: AppColors.borderLight,
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _radius = value),
                          ),
                        ],
                        if (widget.catId != null) ...[
                          TextField(
                            controller: _note,
                            maxLength: 1000,
                            maxLines: 2,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.inputBg,
                              labelText: 'Observação (opcional)',
                              hintText: 'Ex.: visto perto da praça',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.input),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.input),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _point == null || _saving ? null : _save,
                            child: Text(
                              _saving
                                  ? 'Salvando…'
                                  : widget.catId == null
                                      ? 'Usar este ponto'
                                      : 'Registrar avistamento',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Carrossel horizontal de gatos avistados no topo do mapa
          if (widget.readOnly && catsWithLoc.isNotEmpty)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: catsWithLoc.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = catsWithLoc[index];
                    final isSelected = _selectedCat?.id == cat.id;
                    return GestureDetector(
                      onTap: () => _showCatInfo(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryDark
                                : AppColors.borderLight,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CatPhotoView(
                                  cat.photoPath,
                                  fit: BoxFit.cover,
                                  borderRadius: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.displayName,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Barra flutuante de busca de endereço por texto
          Positioned(
            top: widget.readOnly && catsWithLoc.isNotEmpty ? 66 : 16,
            left: 16,
            right: 68,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: AppColors.borderLight, width: 1.2),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.search, size: 18, color: AppColors.textMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performAddressSearch(),
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Buscar rua, bairro ou cidade...',
                        hintStyle: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchingAddress)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textMedium),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.arrowRight, size: 18, color: AppColors.primary),
                    onPressed: _performAddressSearch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ),

          // Botão flutuante para centralizar no GPS
          Positioned(
            top: widget.readOnly && catsWithLoc.isNotEmpty ? 66 : 16,
            right: 16,
            child: GestureDetector(
              onTap: _locating ? null : () => _locate(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                ),
                child: _locating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        LucideIcons.crosshair,
                        size: 20,
                        color: AppColors.textDark,
                      ),
              ),
            ),
          ),

          // Card de detalhes do gato selecionado no mapa
          if (_selectedCat != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.photo),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: CatPhotoView(
                          _selectedCat!.photoPath,
                          fit: BoxFit.cover,
                          borderRadius: 0,
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
                            _selectedCat!.displayName,
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedCat!.locationName ?? 'Localização não informada',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppColors.textMedium,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      onPressed: () {
                        if (widget.catStore != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CatDetailsPage(
                                cat: _selectedCat!,
                                catStore: widget.catStore!,
                              ),
                            ),
                          );
                        }
                      },
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
                      onPressed: () => setState(() => _selectedCat = null),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
