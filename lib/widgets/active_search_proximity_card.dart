import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../pages/location_page.dart';
import '../pages/missing_map_consolidated_page.dart';
import '../services/location_service.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// Card de Proximidade / Geofencing da Busca Ativa
///
/// Monitora se o usuário está dentro ou próximo do raio de busca de algum gato
/// desaparecido ativo e exibe um card com atalho para o mapa de pistas
/// e envio de avistamentos pela comunidade.
class ActiveSearchProximityCard extends StatefulWidget {
  const ActiveSearchProximityCard({
    super.key,
    required this.sessionStore,
    required this.catStore,
    this.onDismiss,
  });

  final SessionStore sessionStore;
  final CatStore catStore;
  final VoidCallback? onDismiss;

  @override
  State<ActiveSearchProximityCard> createState() =>
      _ActiveSearchProximityCardState();
}

class _ActiveSearchProximityCardState extends State<ActiveSearchProximityCard> {
  Map<String, dynamic>? _nearbyReport;
  bool _dismissed = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkProximity();
  }

  Future<void> _checkProximity() async {
    if (!widget.sessionStore.isSignedIn || _dismissed) return;
    setState(() => _checking = true);

    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos == null || !mounted) {
        setState(() => _checking = false);
        return;
      }

      final items = await ProductApiService(widget.sessionStore).list(
        '/app/reports/nearby?latitude=${pos.latitude}&longitude=${pos.longitude}&radius_km=15.0',
      );

      if (!mounted) return;
      setState(() {
        _checking = false;
        _nearbyReport = items.isNotEmpty ? items.first : null;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openSightingModal() async {
    if (_nearbyReport == null) return;
    final noteController = TextEditingController();
    LocationSelection? selectedLocation;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
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
                    'Registrar Avistamento',
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
                'Avistou ${_nearbyReport!['name']}? Registre onde ele estava para ajudar o tutor.',
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: BorderSide(
                    color: selectedLocation == null
                        ? AppColors.primary
                        : AppColors.greenProgress,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                ),
                onPressed: () async {
                  final initial = LatLng(
                    (_nearbyReport!['latitude'] as num).toDouble(),
                    (_nearbyReport!['longitude'] as num).toDouble(),
                  );
                  final loc = await Navigator.push<LocationSelection>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationPage(
                        initial: initial,
                        radius: 1000,
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
                      ? 'Marcar ponto exato no mapa'
                      : 'Local selecionado no mapa',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'O que ele estava fazendo? Correndo, assustado, em qual direção?',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                  fillColor: AppColors.inputBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () async {
                  final lat = selectedLocation?.point.latitude ??
                      (_nearbyReport!['latitude'] as num).toDouble();
                  final lon = selectedLocation?.point.longitude ??
                      (_nearbyReport!['longitude'] as num).toDouble();

                  try {
                    final catId = _nearbyReport!['cat_client_id'] as String;
                    final note = noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim();

                    final isLocalCat = widget.catStore.cats.any((c) => c.id == catId);
                    if (isLocalCat) {
                      await widget.catStore.recordSighting(
                        catId,
                        latitude: lat,
                        longitude: lon,
                        note: note,
                      );
                    } else {
                      await ProductApiService(widget.sessionStore).post(
                        '/vision/sightings',
                        {
                          'cat_client_id': catId,
                          'latitude': lat,
                          'longitude': lon,
                          'note': ?note,
                          'observed_at': DateTime.now().toUtc().toIso8601String(),
                        },
                      );
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showMessage(context, 'Avistamento registrado com sucesso.');
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      showMessage(ctx, 'Erro ao registrar avistamento: $e');
                    }
                  }
                },
                icon: const Icon(LucideIcons.send, size: 16),
                label: const Text('Enviar Avistamento'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _nearbyReport == null || _checking) {
      return const SizedBox.shrink();
    }

    final report = _nearbyReport!;
    final name = report['name'] as String? ?? 'Gatinho';
    final distanceMeters = (report['distance_meters'] as num?)?.toDouble() ?? 0.0;
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);
    final photoUrl = report['photo_url'] as String?;
    final isOwner = report['is_owner'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.shortcutYellowBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.shortcutYellowIcon.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de status com badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.shortcutYellowIcon.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.radar,
                    size: 16,
                    color: AppColors.shortcutYellowIcon,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwner
                            ? 'Seu gato está em busca ativa'
                            : 'Busca Ativa na sua Região',
                        style: GoogleFonts.fredoka(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      Text(
                        'A cerca de $distanceKm km de onde você está',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dispensar aviso',
                  icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textLight),
                  onPressed: () {
                    setState(() => _dismissed = true);
                    widget.onDismiss?.call();
                  },
                ),
              ],
            ),
          ),

          // Informações do Gato
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: AppColors.borderLight,
                    child: photoUrl != null
                        ? _ReportPhotoThumbnail(
                            url: photoUrl,
                            session: widget.sessionStore,
                          )
                        : const Icon(
                            Icons.pets,
                            size: 28,
                            color: AppColors.textMedium,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Procura-se: $name',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? 'Acompanhe as pistas recebidas ou veja o mapa.'
                            : 'Fique de olho ao redor! Qualquer pista é fundamental.',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Ações de emergência e mapa
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: BorderSide(
                        color: AppColors.shortcutYellowIcon.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MissingMapConsolidatedPage(
                          report: report,
                          store: widget.catStore,
                        ),
                      ),
                    ),
                    icon: const Icon(LucideIcons.map, size: 14),
                    label: Text(
                      'Ver no Mapa',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _openSightingModal,
                      icon: const Icon(LucideIcons.eye, size: 14),
                      label: Text(
                        'Avistei ele!',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportPhotoThumbnail extends StatefulWidget {
  const _ReportPhotoThumbnail({
    required this.url,
    required this.session,
  });

  final String url;
  final SessionStore session;

  @override
  State<_ReportPhotoThumbnail> createState() => _ReportPhotoThumbnailState();
}

class _ReportPhotoThumbnailState extends State<_ReportPhotoThumbnail> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = ProductApiService(widget.session).photo(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
