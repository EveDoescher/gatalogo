import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/cat.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'location_page.dart';
import 'conversation_page.dart';
import 'my_cats_page.dart';
import 'auth_page.dart';

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
  String? _catId;
  LocationSelection? _location;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _catId = widget.initialCat?.id;
  }

  Future<void> _create() async {
    if (_catId == null || _location == null) {
      showMessage(context, 'Escolha o gato e o último ponto conhecido.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.syncCatalog();
      final data = await ProductApiService(widget.store.sessionStore)
          .post('/vision/missing-reports', {
            'cat_client_id': _catId,
            'latitude': _location!.point.latitude,
            'longitude': _location!.point.longitude,
            'radius_meters': _location!.radius,
          });
      final cat = widget.store.pets.firstWhere((cat) => cat.id == _catId);
      data['name'] = cat.displayName;
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
    appBar: AppBar(title: const Text('Criar alerta')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final pets = widget.store.pets;
        if (pets.isEmpty) {
          return EmptyContent(
            'Cadastre seu gato primeiro',
            'Os alertas usam o perfil de um gato da área Meus gatos.',
            action: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPetPage(store: widget.store),
                ),
              ),
              child: const Text('Adicionar meu gato'),
            ),
          );
        }
        final selected = pets.where((cat) => cat.id == _catId);
        final cat = selected.isEmpty ? null : selected.first;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: cat?.id,
              decoration: const InputDecoration(labelText: 'Meu gato'),
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
            if (cat != null) ...[
              const SizedBox(height: 16),
              CatPhotoView(cat.photoPath, height: 220),
              Text(
                '${widget.store.referencePhotosFor(cat.id).length + 1} foto(s) no perfil',
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Escolha o último local onde seu gato foi visto e a área de busca.',
            ),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final location = await Navigator.push<LocationSelection>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPage(
                            initial:
                                _location?.point ??
                                (cat?.latitude == null || cat?.longitude == null
                                    ? null
                                    : LatLng(cat!.latitude!, cat.longitude!)),
                            radius: _location?.radius ?? 2000,
                          ),
                        ),
                      );
                      if (location != null && mounted) {
                        setState(() => _location = location);
                      }
                    },
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _location == null
                    ? 'Escolher local e raio'
                    : 'Área escolhida: ${(_location!.radius / 1000).toStringAsFixed(1)} km',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Você receberá possíveis pistas de gatos vistos na região. A localização exata fica reservada ao acompanhamento do caso.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(_saving ? 'Criando alerta…' : 'Ativar alerta'),
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
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
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
                    label: const Text('Explorar Avistamentos Recebidos'),
                  ),
                ),
              ],
            ),
          ),

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Possíveis avistamentos'),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
              children: [
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
        if (!_loading && _error == null && _clues.isEmpty)
          const EmptyContent(
            'Ainda sem pistas',
            'Os possíveis avistamentos desta busca aparecerão aqui.',
          ),
        ..._clues.map(
          (clue) => Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(clue),
              child: Column(
                children: [
                  PrivateCluePhoto(
                    path: clue['photo_url'] as String,
                    session: widget.store.sessionStore,
                  ),
                  ListTile(
                    title: Text(
                      clue['status'] == 'dismissed'
                          ? 'Pista descartada'
                          : clue['status'] == 'confirmed'
                          ? 'Pista reconhecida'
                          : 'Gato visto na região',
                    ),
                    subtitle: Text(
                      '${displayDate(clue['created_at'])} · cerca de ${((clue['distance_meters'] as num) / 1000).toStringAsFixed(1)} km do ponto informado',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
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

  @override
  Widget build(BuildContext context) {
    final cats = widget.store.cats.where(
      (cat) => cat.id == widget.report['cat_client_id'],
    );
    final myCat = cats.isEmpty ? null : cats.first;
    final isFriendSighting = widget.clue['conversation_id'] != null;
    final isPending = _clue['status'] == 'pending' && widget.report['status'] == 'active';

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
        ],
      ),
    );
  }
}
