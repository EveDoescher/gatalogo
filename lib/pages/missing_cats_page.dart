import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/cat.dart';
import '../services/cat_preflight_service.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'location_page.dart';
import 'conversation_page.dart';
import 'auth_page.dart';
import 'missing_cat_poster_page.dart';
import 'missing_map_consolidated_page.dart';

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
      widget.catStore.recordGamificationAction('care');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: !widget.sessionStore.isSignedIn
        ? EmptyContent(
            'Receba pistas do seu gato',
            'Entre na sua conta para criar alertas e receber avistamentos.',
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
                          builder: (_) => CreateMissingReportPage(store: widget.catStore),
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
                    label: const Text('Criar alerta', style: TextStyle(color: Colors.white)),
                  ),
                ),
                if (_loading) LinearProgressIndicator(borderRadius: BorderRadius.circular(AppRadius.sm)),
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
                  const EmptyContent(
                    'Nenhum alerta por aqui',
                    'Se um dos seus gatos desaparecer, crie um alerta com o último local onde ele foi visto.',
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
                        (report) => ListTile(
                          leading: Icon(
                            status == 'active'
                                ? Icons.search
                                : Icons.check_circle_outline,
                          ),
                          title: Text(report['name'] as String),
                          subtitle: Text(
                            '${displayDate(report['created_at'])} · ${report['clue_count']} pista(s)',
                          ),
                          trailing: const Icon(Icons.chevron_right),
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
                        ),
                      ),
                ],
              ],
            ),
          ),
  );
}

class CreateMissingReportPage extends StatefulWidget {
  const CreateMissingReportPage({
    super.key,
    required this.store,
    this.initialCat,
  });
  final CatStore store;
  final Cat? initialCat;
  @override
  State<CreateMissingReportPage> createState() =>
      _CreateMissingReportPageState();
}

class _CreateMissingReportPageState extends State<CreateMissingReportPage> {
  final _preflight = CatPreflightService();
  final _quickName = TextEditingController();
  final _quickCollar = TextEditingController();
  final _quickMarks = TextEditingController();

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
    if (widget.initialCat == null && widget.store.pets.isEmpty) {
      _quickMode = true;
    }
  }

  @override
  void dispose() {
    _preflight.dispose();
    _quickName.dispose();
    _quickCollar.dispose();
    _quickMarks.dispose();
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

      await widget.store.syncCatalog();
      final data = await ProductApiService(widget.store.sessionStore)
          .post('/vision/missing-reports', {
            'cat_client_id': catClientId,
            'latitude': _location!.point.latitude,
            'longitude': _location!.point.longitude,
            'radius_meters': _location!.radius,
          });
      data['name'] = catName;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MissingReportDetailPage(report: data, store: widget.store),
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
  Widget build(BuildContext context) => Scaffold(
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
        'Criar Alerta de Busca',
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

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Alternador de modo se o usuário já tiver pets
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
              // Modo Alerta Rápido de Emergência
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 22),
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
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                decoration: const InputDecoration(
                  labelText: 'Nome do gato (ou deixe provisório)',
                  hintText: 'ex: Pipoca, Amarelinho',
                  prefixIcon: Icon(Icons.pets, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _quickCollar,
                maxLength: 50,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                decoration: const InputDecoration(
                  labelText: 'Coleira (opcional)',
                  hintText: 'ex: Vermelha com sino, azul reflexiva',
                  prefixIcon: Icon(LucideIcons.tag, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _quickMarks,
                maxLength: 120,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                decoration: const InputDecoration(
                  labelText: 'Marcas características (opcional)',
                  hintText: 'ex: Mancha no peito, orelha cortada, rabo curto',
                  prefixIcon: Icon(LucideIcons.sparkles, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (_quickPhoto != null) ...[
                CatPhotoView(_quickPhoto!, height: 220, borderRadius: AppRadius.card),
                const SizedBox(height: AppSpacing.md),
              ],

              Row(
                children: [
                  Expanded(
                    child: GatalogoSecondaryButton(
                      text: 'Tirar Foto',
                      icon: LucideIcons.camera,
                      onPressed: _busyPhoto || _saving ? null : () => _pickQuickPhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GatalogoSecondaryButton(
                      text: 'Escolher da Galeria',
                      icon: LucideIcons.image,
                      onPressed: _busyPhoto || _saving ? null : () => _pickQuickPhoto(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Modo Pet Cadastrado
              DropdownButtonFormField<String>(
                initialValue: pets.any((c) => c.id == _catId) ? _catId : pets.first.id,
                decoration: const InputDecoration(
                  labelText: 'Selecione o gato',
                  prefixIcon: Icon(Icons.pets, size: 18),
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
                    CatPhotoView(cat.photoPath, height: 220, borderRadius: AppRadius.card),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.store.referencePhotosFor(cat.id).length + 1} foto(s) no perfil de identificação',
                      style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
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
              'Defina o ponto e o raio aproximado da busca. O endereço exato não é exposto publicamente para proteger sua privacidade.',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
            ),
            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
                side: BorderSide(
                  color: _location == null ? AppColors.primary : AppColors.border,
                  width: _location == null ? 1.5 : 1.0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                        final cat = pets.firstWhere((c) => c.id == _catId, orElse: () => pets.first);
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
                        setState(() => _location = location);
                      }
                    },
              icon: Icon(
                _location == null ? LucideIcons.mapPin : LucideIcons.checkCircle,
                size: 20,
                color: _location == null ? AppColors.primary : AppColors.greenProgress,
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

            GatalogoButton(
              text: _saving ? 'Ativando alerta…' : 'Ativar Alerta de Busca',
              isLoading: _saving,
              onPressed: _saving ? null : _create,
            ),
          ],
        );
      },
    ),
  );
}

class MissingReportDetailPage extends StatefulWidget {
  const MissingReportDetailPage({
    super.key,
    required this.report,
    required this.store,
  });
  final Map<String, dynamic> report;
  final CatStore store;
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
      final data = {
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
          _report['name'] ?? 'Detalhes do Alerta',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
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
                    child: Stack(
                      children: [
                        CatPhotoView(
                          cat.photoPath,
                          height: 200,
                          fit: BoxFit.cover,
                          borderRadius: AppRadius.photo,
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.zoomIn,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Toque para ampliar',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.errorBg : AppColors.greenLight,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: isActive ? AppColors.error.withValues(alpha: 0.3) : AppColors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isActive ? 'Em busca ativa' : 'Alerta concluído',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isActive ? AppColors.error : AppColors.greenLink,
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
                    const Icon(LucideIcons.mapPin, size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Área de Monitoramento',
                      style: GoogleFonts.fredoka(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Raio de busca: ${((_report['radius_meters'] as num) / 1000).toStringAsFixed(1)} km ao redor do ponto inicial.',
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
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
                            side: const BorderSide(color: AppColors.borderProfile),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
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
            backgroundColor: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.search, size: 18, color: AppColors.greenLink),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Pistas e Avistamentos',
                      style: GoogleFonts.fredoka(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A inteligência do Gatálogo cruza fotos registradas na região para encontrar semelhanças com o seu gato.',
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CluesPage(report: _report, store: widget.store),
                          ),
                        ),
                        icon: const Icon(Icons.pets, size: 16),
                        label: const Text('Explorar Avistamentos'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          try {
                            final clues = await ProductApiService(widget.store.sessionStore)
                                .list('/app/reports/${_report['id']}/clues');
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
                          } catch (e) {
                            if (context.mounted) showMessage(context, e);
                          }
                        },
                        icon: const Icon(LucideIcons.map, size: 16),
                        label: const Text('Mapa Consolidado'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card 4: Cartaz Digital de Busca
          if (cat != null) ...[
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
                    child: const Icon(LucideIcons.fileText, size: 22, color: AppColors.error),
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
                          'Cartaz com QR code para compartilhar no WhatsApp e redes sociais.',
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MissingCatPosterPage(
                          cat: cat,
                          report: _report,
                          catStore: widget.store,
                        ),
                      ),
                    ),
                    child: Text(
                      'Gerar',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: BorderSide(
                    color: selectedLocation == null ? AppColors.primary : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
                  selectedLocation == null ? LucideIcons.mapPin : LucideIcons.checkCircle,
                  size: 18,
                  color: selectedLocation == null ? AppColors.primary : AppColors.greenProgress,
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
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
                decoration: const InputDecoration(
                  labelText: 'Observação do avistamento',
                  hintText: 'ex: Visto atravessando a rua perto da praça às 17h.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GatalogoButton(
                text: 'Salvar Avistamento',
                onPressed: () async {
                  if (selectedLocation == null) {
                    showMessage(context, 'Escolha o local do avistamento no mapa.');
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
                      showMessage(context, 'Avistamento registrado com sucesso.');
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

    final confirmedList =
        _clues.where((c) => c['status'] == 'confirmed').toList();
    final pendingList =
        _clues.where((c) => c['status'] == 'pending').toList();
    final dismissedList =
        _clues.where((c) => c['status'] == 'dismissed').toList();

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
          'Pistas e Avistamentos',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
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
            icon: const Icon(LucideIcons.refreshCw, size: 20, color: AppColors.textDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Todas (${_clues.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pendentes (${pendingList.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('confirmed', 'Reconhecidas (${confirmedList.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('dismissed', 'Descartadas (${dismissedList.length})'),
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
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                        ? EmptyContent(
                            _filter == 'all'
                                ? 'Ainda sem pistas'
                                : 'Nenhuma pista neste filtro',
                            _filter == 'all'
                                ? 'Os possíveis avistamentos cruzados pela inteligência artificial aparecerão aqui.'
                                : 'Não há registros com o status selecionado no momento.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final clue = filteredList[index];
                              return _buildTimelineItem(clue, index == filteredList.length - 1);
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

    final distanceKm = ((clue['distance_meters'] as num? ?? 0) / 1000).toStringAsFixed(1);
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
              Container(
                width: 2,
                height: 110,
                color: AppColors.borderLight,
              ),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        const Spacer(),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.photo),
                          child: SizedBox(
                            width: 62,
                            height: 62,
                            child: PrivateCluePhoto(
                              path: clue['photo_url'] as String,
                              session: widget.store.sessionStore,
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
                        const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textLight),
                      ],
                    ),

                    if (status == 'dismissed') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _reopenClue(clue),
                          icon: const Icon(LucideIcons.undo, size: 14, color: AppColors.primary),
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

class PrivateCluePhoto extends StatefulWidget {
  const PrivateCluePhoto({
    super.key,
    required this.path,
    required this.session,
  });
  final String path;
  final SessionStore session;
  @override
  State<PrivateCluePhoto> createState() => _PrivateCluePhotoState();
}

class _PrivateCluePhotoState extends State<PrivateCluePhoto> {
  late Future<Uint8List> _photo;
  @override
  void initState() {
    super.initState();
    _photo = ProductApiService(widget.session).photo(widget.path);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 240,
    width: double.infinity,
    child: FutureBuilder<Uint8List>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () => showFullscreenMemoryImage(
              context,
              bytes: snapshot.data!,
              title: 'Foto do Avistamento',
            ),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 240,
                  child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.zoomIn,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Toque para ampliar',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: () => setState(
              () =>
                  _photo = ProductApiService(widget.session).photo(widget.path),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar carregar foto'),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    ),
  );
}

class ClueDetailPage extends StatefulWidget {
  const ClueDetailPage({
    super.key,
    required this.clue,
    required this.report,
    required this.store,
  });
  final Map<String, dynamic> clue, report;
  final CatStore store;
  @override
  State<ClueDetailPage> createState() => _ClueDetailPageState();
}

class _ClueDetailPageState extends State<ClueDetailPage> {
  late Map<String, dynamic> _clue;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _clue = Map.of(widget.clue);
  }

  Future<void> _decide(bool confirm) async {
    if (!confirm) {
      final shouldDismiss = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: Text(
            'Descartar avistamento?',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
          content: Text(
            'Tem certeza de que este avistamento não é do seu gato? Você poderá desfazer e reabrir a pista a qualquer momento.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, descartar'),
            ),
          ],
        ),
      );
      if (shouldDismiss != true) return;
    }

    setState(() => _busy = true);
    try {
      final result = await ProductApiService(widget.store.sessionStore).post(
        '/vision/matches/${_clue['id']}/${confirm ? 'confirm' : 'dismiss'}',
      );
      if (mounted) setState(() => _clue.addAll(result));
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen() async {
    setState(() => _busy = true);
    try {
      final result = await ProductApiService(widget.store.sessionStore).post(
        '/vision/matches/${_clue['id']}/reopen',
      );
      if (mounted) {
        setState(() => _clue.addAll(result));
        showMessage(context, 'Pista reaberta com sucesso.');
      }
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.store.cats.where(
      (cat) => cat.id == widget.report['cat_client_id'],
    );
    final myCat = cats.isEmpty ? null : cats.first;
    final isFriendSighting = widget.clue['conversation_id'] != null;
    final isPending = _clue['status'] == 'pending' && widget.report['status'] == 'active';
    final isConfirmed = _clue['status'] == 'confirmed';
    final isDismissed = _clue['status'] == 'dismissed';

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
          'Detalhes do Avistamento',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        children: [
          // Destaque Especial: Avistamento por um Amigo
          if (isFriendSighting) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.socialPurpleBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.socialPurple.withValues(alpha: 0.5),
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.heartHandshake,
                          color: AppColors.socialPurpleText,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avistado por um Amigo!',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.socialPurpleText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Um amigo da sua rede registrou esta foto e pode fornecer detalhes cruciais sobre onde o gatinho estava.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.socialPurpleText,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationPage(
                            sessionStore: widget.store.sessionStore,
                            conversationId: widget.clue['conversation_id'] as String,
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.messageCircle, size: 16),
                      label: const Text('Conversar no Chat com seu Amigo'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Card: Foto do Gato Avistado
          GatalogoCard(
            backgroundColor: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.camera, size: 18, color: AppColors.textTitle),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Foto do Avistamento',
                      style: GoogleFonts.fredoka(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.photo),
                  child: PrivateCluePhoto(
                    path: widget.clue['photo_url'] as String,
                    session: widget.store.sessionStore,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 14, color: AppColors.textMedium),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Visto em ${displayDate(widget.clue['created_at'])}, a ~${((widget.clue['distance_meters'] as num) / 1000).toStringAsFixed(1)} km do ponto de busca.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.clue['note'] != null && (widget.clue['note'] as String).trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.fileText, size: 14, color: AppColors.textMedium),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Observação: "${widget.clue['note']}"',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.clue['latitude'] != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationPage(
                          initial: LatLng(
                            (widget.clue['latitude'] as num).toDouble(),
                            (widget.clue['longitude'] as num).toDouble(),
                          ),
                          readOnly: true,
                        ),
                      ),
                    ),
                    icon: const Icon(LucideIcons.mapPin, size: 16),
                    label: const Text('Ver Ponto no Mapa'),
                  ),
                ],
              ],
            ),
          ),

          // Comparação com o gato cadastrado
          if (myCat != null) ...[
            const SizedBox(height: AppSpacing.md),
            GatalogoCard(
              backgroundColor: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pets, size: 18, color: AppColors.primaryDark),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Comparar com ${myCat.displayName}',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => showFullscreenImage(
                      context,
                      imagePath: myCat.photoPath,
                      title: myCat.displayName,
                    ),
                    child: Stack(
                      children: [
                        CatPhotoView(
                          myCat.photoPath,
                          height: 170,
                          borderRadius: AppRadius.photo,
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.zoomIn,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Toque para ampliar',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Decisão de reconhecimento
          if (isPending) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Este é o seu gato?',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reconhecer uma pista ajuda a registrar o histórico de localização.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenProgress,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _busy ? null : () => _decide(true),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('É meu gato!'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMedium,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _busy ? null : () => _decide(false),
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: const Text('Não é ele'),
                  ),
                ),
              ],
            ),
          ],
          if (isDismissed) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.xCircle, size: 20, color: AppColors.textMedium),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Pista Descartada',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Você indicou anteriormente que este gato não é o seu. Se mudou de ideia ou quer reavaliar com mais calma, você pode desfazer o descarte a qualquer momento.',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _busy ? null : _reopen,
                      icon: const Icon(LucideIcons.undo, size: 16),
                      label: const Text('Desfazer descarte / Reabrir pista'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isConfirmed) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.greenProgress.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.checkCircle, size: 20, color: AppColors.greenProgress),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Pista Reconhecida',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greenProgress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Você confirmou que este avistamento é do seu gato. O ponto foi registrado no histórico e mapa consolidado da busca.',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textDark),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                      ),
                      onPressed: _busy ? null : _reopen,
                      icon: const Icon(LucideIcons.undo, size: 14),
                      label: const Text('Mudar de ideia / Reabrir análise'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
