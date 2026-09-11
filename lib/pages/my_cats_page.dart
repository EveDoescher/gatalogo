import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cat.dart';
import '../stores/cat_store.dart';
import '../services/cat_preflight_service.dart';
import '../widgets/app_widgets.dart';
import '../services/product_api_service.dart';
import 'cat_details_page.dart';
import 'cat_gallery_page.dart';
import 'missing_cats_page.dart';

class MyCatsPage extends StatefulWidget {
  const MyCatsPage({super.key, required this.store});
  final CatStore store;
  @override
  State<MyCatsPage> createState() => _MyCatsPageState();
}

class _MyCatsPageState extends State<MyCatsPage> {
  Set<String> _active = {};
  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!widget.store.sessionStore.isSignedIn) return;
    try {
      final reports = await ProductApiService(widget.store.sessionStore)
          .list('/app/reports');
      if (mounted) {
        setState(
          () => _active = reports
              .where((report) => report['status'] == 'active')
              .map((report) => report['cat_client_id'] as String)
              .toSet(),
        );
      }
    } catch (_) {
      /* Keep the last known alert state when offline. */
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadReports();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meus gatos')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _open(AddPetPage(store: widget.store)),
      icon: const Icon(Icons.add),
      label: const Text('Adicionar gato'),
    ),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        return RefreshIndicator(
          onRefresh: _loadReports,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              if (store.pets.isEmpty)
                const EmptyContent(
                  'Quem mora com você?',
                  'Cadastre seus gatos e reúna fotos para ajudar numa eventual busca.',
                ),
              ...store.pets.map(
                (cat) => CatTile(
                  cat,
                  subtitle: [
                    if (_active.contains(cat.id))
                      'Desaparecido · alerta ativo',
                    '${store.referencePhotosFor(cat.id).length + 1} foto(s) no perfil',
                    if (store.referencePhotosFor(cat.id).length < 4)
                      'Adicione outros ângulos',
                  ].join(' · '),
                  onTap: () =>
                      _open(PetProfilePage(catId: cat.id, store: store)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key, required this.store});
  final CatStore store;
  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final _preflight = CatPreflightService();
  final _name = TextEditingController();
  String? _photo;
  bool _busy = false;
  @override
  void dispose() {
    _preflight.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
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
          result.message ?? 'Escolha uma foto com o gato em destaque.',
        );
        return;
      }
      setState(() => _photo = photo.path);
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível abrir a foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_photo == null || _name.text.trim().isEmpty) {
      showMessage(context, 'Informe o nome e adicione uma foto.');
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await widget.store.addFromTempPhoto(
        _photo!,
        isOwned: true,
        name: _name.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PetProfilePage(catId: saved.cat.id, store: widget.store),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Não foi possível salvar. Sua foto pode ser enviada novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Adicionar meu gato')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome do gato'),
        ),
        if (_photo != null) CatPhotoView(_photo!, height: 280),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Fotografar'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              child: const Text('Escolher foto'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Depois, adicione fotos de frente, dos lados e das costas. Elas ajudam a reconhecer seu gato em possíveis avistamentos.',
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Salvando…' : 'Salvar meu gato'),
        ),
      ],
    ),
  );
}

class PetProfilePage extends StatelessWidget {
  const PetProfilePage({super.key, required this.catId, required this.store});
  final String catId;
  final CatStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final found = store.pets.where((cat) => cat.id == catId);
      if (found.isEmpty) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyContent(
            'Gato não disponível',
            'Este cadastro foi removido.',
          ),
        );
      }
      final Cat cat = found.first;
      final photos = store.referencePhotosFor(cat.id);
      final missing = referenceLabels.entries
          .where((entry) => !photos.any((photo) => photo.kind == entry.key))
          .map((entry) => entry.value.toLowerCase())
          .join(', ');
      return Scaffold(
        appBar: AppBar(title: Text(cat.displayName)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CatPhotoView(cat.photoPath, height: 280),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                cat.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              subtitle: Text(
                'Com você no Gatálogo desde ${displayDate(cat.capturedAt)}',
              ),
              trailing: IconButton(
                tooltip: 'Editar perfil',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CatDetailsPage(cat: cat, catStore: store),
                  ),
                ),
              ),
            ),
            Text(
              missing.isEmpty
                  ? 'Você já adicionou fotos de todos os ângulos.'
                  : 'Para completar o álbum: $missing.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CatGalleryPage(cat: cat, store: store),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text('Gerenciar fotos (${photos.length + 1})'),
            ),
            const Divider(height: 36),
            const Text(
              'Se o seu gato desaparecer, informe o último local onde ele foi visto para receber possíveis pistas na região.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateMissingReportPage(store: store, initialCat: cat),
                ),
              ),
              icon: const Icon(Icons.search),
              label: const Text('Declarar desaparecido'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MissingCatsPage(
                    catStore: store,
                    sessionStore: store.sessionStore,
                  ),
                ),
              ),
              child: const Text('Ver meus alertas'),
            ),
          ],
        ),
      );
    },
  );
}
