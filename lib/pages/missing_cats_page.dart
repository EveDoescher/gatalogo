import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/cat.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../widgets/app_widgets.dart';
import 'location_page.dart';
import 'conversation_page.dart';
import 'my_cats_page.dart';
import 'account_page.dart';

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
      title: const Text('Gatos desaparecidos'),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: widget.sessionStore.isSignedIn
        ? FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateMissingReportPage(store: widget.catStore),
                ),
              );
              if (mounted) _load();
            },
            label: const Text('Criar alerta'),
            icon: const Icon(Icons.add),
          )
        : null,
    body: !widget.sessionStore.isSignedIn
        ? EmptyContent(
            'Receba pistas do seu gato',
            'Entre na sua conta para criar alertas e receber avistamentos.',
            action: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AccountPage(sessionStore: widget.sessionStore),
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
                if (_loading) const LinearProgressIndicator(),
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
    return Scaffold(
      appBar: AppBar(title: Text(_report['name'] ?? 'Detalhes do alerta')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (cats.isNotEmpty) CatPhotoView(cats.first.photoPath, height: 260),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _report['status'] == 'active'
                  ? Icons.search
                  : Icons.check_circle_outline,
            ),
            title: Text(
              _report['status'] == 'active' ? 'Em busca' : 'Alerta concluído',
            ),
            subtitle: Text('Aberto em ${displayDate(_report['created_at'])}'),
          ),
          Text(
            'Raio de busca: ${((_report['radius_meters'] as num) / 1000).toStringAsFixed(1)} km',
          ),
          TextButton.icon(
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
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ver área de busca'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CluesPage(report: _report, store: widget.store),
              ),
            ),
            icon: const Icon(Icons.pets_outlined),
            label: const Text('Ver possíveis avistamentos'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Uma pista pode ajudar a encontrar seu gato. Confira a foto e o contexto antes de agir.',
          ),
          if (_report['status'] == 'active')
            TextButton.icon(
              onPressed: _busy ? null : _editArea,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Ajustar área de busca'),
            ),
          if (_report['status'] == 'active')
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: OutlinedButton(
                onPressed: _busy ? null : _resolve,
                child: Text(_busy ? 'Encerrando…' : 'Encerrar alerta'),
              ),
            ),
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
        if (_loading) const LinearProgressIndicator(),
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
          return Image.memory(snapshot.data!, fit: BoxFit.contain);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do avistamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Gato avistado', style: Theme.of(context).textTheme.titleLarge),
          PrivateCluePhoto(
            path: widget.clue['photo_url'] as String,
            session: widget.store.sessionStore,
          ),
          Text(
            'Visto em ${displayDate(widget.clue['created_at'])}, a cerca de ${((widget.clue['distance_meters'] as num) / 1000).toStringAsFixed(1)} km do ponto da busca.',
          ),
          if (widget.clue['note'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(widget.clue['note'] as String),
            ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Seu gato', style: Theme.of(context).textTheme.titleLarge),
            CatPhotoView(cats.first.photoPath, height: 200),
          ],
          const SizedBox(height: 16),
          const Text(
            'Este pode ser seu gato. Reconhecer uma pista não encerra o alerta; encerre a busca somente quando fizer sentido para você.',
          ),
          if (_clue['status'] == 'pending' &&
              widget.report['status'] == 'active') ...[
            FilledButton(
              onPressed: _busy ? null : () => _decide(true),
              child: const Text('Reconheço meu gato'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _decide(false),
              child: const Text('Não é meu gato'),
            ),
          ],
          if (_clue['latitude'] != null)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationPage(
                    initial: LatLng(
                      (_clue['latitude'] as num).toDouble(),
                      (_clue['longitude'] as num).toDouble(),
                    ),
                    readOnly: true,
                  ),
                ),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver local do avistamento'),
            ),
          if (_clue['conversation_id'] != null)
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationPage(
                    sessionStore: widget.store.sessionStore,
                    conversationId: _clue['conversation_id'] as String,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Conversar com amigo'),
            ),
        ],
      ),
    );
  }
}
