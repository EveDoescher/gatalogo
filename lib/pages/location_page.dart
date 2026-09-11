import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../stores/cat_store.dart';
import '../widgets/app_widgets.dart';

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
  LatLng? _point;
  late double _radius;
  bool _saving = false;
  DateTime _observedAt = DateTime.now();
  @override
  void initState() {
    super.initState();
    _point = widget.initial;
    _radius = (widget.radius ?? 2000).toDouble();
  }

  @override
  void dispose() {
    _map.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final position = await LocationService.getCurrentLocation().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted) return;
      if (position == null) {
        showMessage(
          context,
          'Localização indisponível. Toque no mapa para escolher o ponto.',
        );
        return;
      }
      setState(() => _point = LatLng(position.latitude, position.longitude));
      _map.move(_point!, 15);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Não foi possível obter sua localização. Escolha o ponto no mapa.',
        );
      }
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.catId != null ? 'Registrar avistamento' : 'Localização',
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _point ?? const LatLng(-14.2, -51.9),
              initialZoom: _point == null ? 4 : 14,
              onTap: widget.readOnly || _saving
                  ? null
                  : (_, point) => setState(() => _point = point),
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
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: .15),
                      borderStrokeWidth: 1,
                      borderColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              if (_point != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point!,
                      child: Icon(
                        Icons.location_on,
                        size: 42,
                        color: Theme.of(context).colorScheme.primary,
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.readOnly
                      ? 'Local registrado'
                      : 'Toque no mapa no local onde o gato foi visto.',
                ),
                if (!widget.readOnly) ...[
                  TextButton.icon(
                    onPressed: _saving ? null : _locate,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Usar minha localização'),
                  ),
                  if (widget.radius != null) ...[
                    Text(
                      'Raio de busca: ${(_radius / 1000).toStringAsFixed(1)} km',
                    ),
                    Slider(
                      value: _radius,
                      min: 100,
                      max: 50000,
                      divisions: 499,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _radius = value),
                    ),
                  ],
                  if (widget.catId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        'Visto em ${displayDate(_observedAt)} às ${TimeOfDay.fromDateTime(_observedAt).format(context)}',
                      ),
                      onPressed: _saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _observedAt,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date == null || !context.mounted) return;
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                  _observedAt,
                                ),
                              );
                              if (time == null || !mounted) return;
                              final chosen = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                              if (chosen.isAfter(DateTime.now())) {
                                if (context.mounted) {
                                  showMessage(
                                    context,
                                    'Escolha uma data e hora que já passaram.',
                                  );
                                }
                                return;
                              }
                              setState(() => _observedAt = chosen);
                            },
                    ),
                  if (widget.catId != null)
                    TextField(
                      controller: _note,
                      maxLength: 1000,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observação (opcional)',
                        hintText: 'Ex.: visto perto da praça',
                      ),
                    ),
                  FilledButton(
                    onPressed: _point == null || _saving ? null : _save,
                    child: Text(
                      _saving
                          ? 'Salvando…'
                          : widget.catId == null
                          ? 'Usar este ponto'
                          : 'Registrar avistamento',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
