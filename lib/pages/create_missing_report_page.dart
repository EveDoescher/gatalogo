import '../widgets/botanical_scene.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/cat.dart';
import '../services/location_service.dart';
import '../services/cat_preflight_service.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'location_page.dart';

import 'missing_report_detail_page.dart';

class CreateMissingReportPage extends StatefulWidget {
  const CreateMissingReportPage({
    super.key,
    required this.store,
    this.initialCat,
    this.quickMode = false,
  });
  final CatStore store;
  final Cat? initialCat;
  final bool quickMode;
  @override
  State<CreateMissingReportPage> createState() =>
      _CreateMissingReportPageState();
}

class _CreateMissingReportPageState extends State<CreateMissingReportPage> {
  final _preflight = CatPreflightService();
  final _quickName = TextEditingController();
  final _quickCollar = TextEditingController();
  final _quickMarks = TextEditingController();
  final _quickMicrochip = TextEditingController();
  final _address = TextEditingController();

  String? _catId;
  String? _quickPhoto;
  bool _quickMode = false;
  LocationSelection? _location;
  bool _saving = false;
  bool _busyPhoto = false;

  @override
  void initState() {
    super.initState();
    _catId = widget.initialCat?.id;
    _quickMode = widget.quickMode || widget.store.pets.isEmpty;
    _catId ??= widget.store.pets.isEmpty ? null : widget.store.pets.first.id;
  }

  @override
  void dispose() {
    _preflight.dispose();
    _quickName.dispose();
    _quickCollar.dispose();
    _quickMarks.dispose();
    _quickMicrochip.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickQuickPhoto(ImageSource source) async {
    setState(() => _busyPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo == null) return;
      final result = await _preflight
          .validate(photo.path)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => const CapturePreflightResult.accepted(),
          );
      if (!mounted) return;
      if (!result.accepted) {
        showMessage(
          context,
          result.message ?? 'Escolha uma foto onde o gato apareça com clareza.',
        );
        return;
      }
      setState(() => _quickPhoto = photo.path);
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível carregar a foto.');
    } finally {
      if (mounted) setState(() => _busyPhoto = false);
    }
  }

  Future<void> _create() async {
    if (_location == null) {
      showMessage(context, 'Escolha o último ponto conhecido no mapa.');
      return;
    }

    if (_address.text.trim().isEmpty) {
      showMessage(context, 'Informe o endereço do último local visto.');
      return;
    }

    if (_quickMode) {
      if (_quickPhoto == null) {
        showMessage(context, 'Adicione uma foto recente do gato.');
        return;
      }
    } else {
      if (_catId == null) {
        showMessage(context, 'Selecione o gato para o alerta.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      String catClientId = _catId ?? '';
      String catName = 'Gato Desaparecido';

      if (_quickMode) {
        final assignedName = _quickName.text.trim().isNotEmpty
            ? _quickName.text.trim()
            : 'Gato Desaparecido';
        final saved = await widget.store.addFromTempPhoto(
          _quickPhoto!,
          isOwned: true,
          name: assignedName,
          collar: _quickCollar.text.trim(),
          microchip: _quickMicrochip.text.trim(),
          locationName: _address.text.trim(),
          distinguishingMarks: _quickMarks.text.trim(),
          latitude: _location!.point.latitude,
          longitude: _location!.point.longitude,
        );
        catClientId = saved.cat.id;
        catName = saved.cat.displayName;
      } else {
        final cat = widget.store.pets.firstWhere((c) => c.id == _catId);
        catName = cat.displayName;
      }

      await widget.store.syncCatalog(manual: true);
      final data = await ProductApiService(widget.store.sessionStore)
          .post('/vision/missing-reports', {
            'cat_client_id': catClientId,
            'latitude': _location!.point.latitude,
            'longitude': _location!.point.longitude,
            'radius_meters': _location!.radius,
            'last_seen_address': _address.text.trim(),
          });
      data['name'] = catName;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MissingReportDetailPage(
              report: data,
              store: widget.store,
              openPosterInitially: true,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    level: BotanicalLevel.tertiary,
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
        'Criar alerta',
        style: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textTitle,
        ),
      ),
    ),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final pets = widget.store.pets;

        final inputDecoration = InputDecoration(
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        );

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const IllustratedSectionTitle(
              title: 'Vamos ajudar na busca',
              art: 'ui/ui_clipboard_paw',
            ),
            const SizedBox(height: 18),
            if (pets.isNotEmpty) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Gato Cadastrado'),
                    icon: Icon(Icons.pets, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Alerta Rápido'),
                    icon: Icon(LucideIcons.zap, size: 16),
                  ),
                ],
                selected: {_quickMode},
                onSelectionChanged: _saving
                    ? null
                    : (val) => setState(() {
                        _quickMode = val.first;
                        _location = null;
                      }),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            if (_quickMode) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      color: AppColors.error,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Alerta Imediato: Adicione a melhor foto recente que tiver e indique onde o gato sumiu.',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.errorText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextField(
                controller: _quickName,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                decoration: inputDecoration.copyWith(
                  labelText: 'Nome do gato (ou deixe provisório)',
                  hintText: 'ex: Pipoca, Amarelinho',
                  prefixIcon: const Icon(Icons.pets, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _quickCollar,
                maxLength: 50,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                decoration: inputDecoration.copyWith(
                  labelText: 'Coleira (opcional)',
                  hintText: 'ex: Vermelha com sino, azul reflexiva',
                  prefixIcon: const Icon(LucideIcons.tag, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _quickMarks,
                maxLength: 120,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                decoration: inputDecoration.copyWith(
                  labelText: 'Marcas características (opcional)',
                  hintText: 'ex: Mancha no peito, orelha cortada, rabo curto',
                  prefixIcon: const Icon(LucideIcons.sparkles, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextField(
                controller: _quickMicrochip,
                enabled: !_saving,
                style: const TextStyle(color: AppColors.textDark),
                decoration: inputDecoration.copyWith(
                  labelText: 'Microchip (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              if (_quickPhoto != null) ...[
                CatPhotoView(
                  _quickPhoto!,
                  height: 220,
                  borderRadius: AppRadius.card,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              Row(
                children: [
                  Expanded(
                    child: GatalogoSecondaryButton(
                      text: 'Tirar Foto',
                      icon: LucideIcons.camera,
                      onPressed: _busyPhoto || _saving
                          ? null
                          : () => _pickQuickPhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GatalogoSecondaryButton(
                      text: 'Galeria',
                      icon: LucideIcons.image,
                      onPressed: _busyPhoto || _saving
                          ? null
                          : () => _pickQuickPhoto(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: pets.any((c) => c.id == _catId)
                    ? _catId
                    : pets.first.id,
                decoration: inputDecoration.copyWith(
                  labelText: 'Selecione o gato',
                  prefixIcon: const Icon(Icons.pets, size: 18),
                ),
                dropdownColor: AppColors.inputBg,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                items: pets
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _catId = value;
                        _location = null;
                      }),
              ),
              const SizedBox(height: AppSpacing.md),
              () {
                final cat = pets.firstWhere(
                  (c) => c.id == (_catId ?? pets.first.id),
                  orElse: () => pets.first,
                );
                return Column(
                  children: [
                    CatPhotoView(
                      cat.photoPath,
                      height: 220,
                      borderRadius: AppRadius.card,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.store.referencePhotosFor(cat.id).length + 1} foto(s) no perfil de identificação',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                );
              }(),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Seleção de Local e Raio
            Text(
              'Onde ele foi visto pela última vez?',
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Defina a área usada para procurar avistamentos. Você poderá escolher se o endereço aparece no cartaz.',
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
                  color: _location == null
                      ? AppColors.primary
                      : AppColors.border,
                  width: _location == null ? 1.5 : 1.0,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      LatLng? initialPoint;
                      if (_location != null) {
                        initialPoint = _location!.point;
                      } else if (!_quickMode && _catId != null) {
                        final cat = pets.firstWhere(
                          (c) => c.id == _catId,
                          orElse: () => pets.first,
                        );
                        if (cat.latitude != null && cat.longitude != null) {
                          initialPoint = LatLng(cat.latitude!, cat.longitude!);
                        }
                      }

                      final location = await Navigator.push<LocationSelection>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPage(
                            initial: initialPoint,
                            radius: _location?.radius ?? 2000,
                          ),
                        ),
                      );
                      if (location != null && mounted) {
                        final previousAddress = _address.text;
                        setState(() => _location = location);
                        final address = await LocationService.getLocationName(
                          location.point.latitude,
                          location.point.longitude,
                        );
                        if (mounted &&
                            _location == location &&
                            _address.text == previousAddress &&
                            address != null) {
                          setState(() => _address.text = address);
                        }
                      }
                    },
              icon: Icon(
                _location == null
                    ? LucideIcons.mapPin
                    : LucideIcons.checkCircle,
                size: 20,
                color: _location == null
                    ? AppColors.primary
                    : AppColors.greenProgress,
              ),
              label: Text(
                _location == null
                    ? 'Toque para escolher local e raio no mapa'
                    : 'Área definida: ${(_location!.radius / 1000).toStringAsFixed(1)} km de raio',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            TextField(
              controller: _address,
              enabled: !_saving,
              maxLength: 500,
              style: const TextStyle(color: AppColors.textDark),
              decoration: inputDecoration.copyWith(
                labelText: 'Endereço do último local visto',
                hintText: 'Rua, número, bairro e cidade',
              ),
            ),
            const SizedBox(height: 16),
            const BotanicalPaper(
              foliage: false,
              child: Text(
                'Ao ativar o alerta, o Gatálogo começa a procurar correspondências. Na próxima tela você escolhe o que divulgar, os telefones e o WhatsApp do cartaz.',
              ),
            ),
            const SizedBox(height: 20),
            GatalogoButton(
              text: _saving
                  ? 'Ativando alerta…'
                  : 'Ativar alerta e preparar cartaz',
              isLoading: _saving,
              onPressed: _saving ? null : _create,
            ),
          ],
        );
      },
    ),
  );
}
