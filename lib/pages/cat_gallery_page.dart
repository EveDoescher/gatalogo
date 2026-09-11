import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cat.dart';
import '../stores/cat_store.dart';
import '../services/cat_preflight_service.dart';
import '../widgets/app_widgets.dart';

const referenceLabels = {
  'front': 'Frente',
  'left': 'Lado esquerdo',
  'right': 'Lado direito',
  'back': 'Costas',
};

class CatGalleryPage extends StatefulWidget {
  const CatGalleryPage({super.key, required this.cat, required this.store});
  final Cat cat;
  final CatStore store;
  @override
  State<CatGalleryPage> createState() => _CatGalleryPageState();
}

class _CatGalleryPageState extends State<CatGalleryPage> {
  final _preflight = CatPreflightService();
  bool _busy = false;
  @override
  void dispose() {
    _preflight.dispose();
    super.dispose();
  }

  Future<void> _add(String kind) async {
    setState(() => _busy = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
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
      if (!result.accepted) {
        if (mounted) {
          showMessage(
            context,
            result.message ?? 'Refaça a foto com o gato em destaque.',
          );
        }
        return;
      }
      await widget.store.addReferencePhoto(widget.cat.id, kind, photo.path);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Não foi possível adicionar a foto. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _view(String path, String label) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(label)),
        body: Center(
          child: InteractiveViewer(
            minScale: .5,
            maxScale: 5,
            child: CatPhotoView(path, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fotos do gato')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final photos = widget.store.referencePhotosFor(widget.cat.id);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Suas fotos são privadas. Registre o mesmo gato em diferentes ângulos e com boa iluminação.',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _view(widget.cat.photoPath, 'Foto principal'),
              child: CatPhotoView(widget.cat.photoPath, height: 240),
            ),
            const ListTile(title: Text('Foto principal')),
            if (_busy) const LinearProgressIndicator(),
            ...referenceLabels.entries.map((entry) {
              final found = photos.where((photo) => photo.kind == entry.key);
              final photo = found.isEmpty ? null : found.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  if (photo != null)
                    InkWell(
                      onTap: () => _view(photo.localPath, entry.value),
                      child: CatPhotoView(photo.localPath, height: 180),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    subtitle: Text(
                      photo == null
                          ? 'Adicione uma foto deste ângulo'
                          : 'Foto adicionada',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: photo == null
                              ? 'Adicionar foto'
                              : 'Substituir foto',
                          onPressed: _busy ? null : () => _add(entry.key),
                          icon: const Icon(Icons.add_a_photo_outlined),
                        ),
                        if (photo != null)
                          IconButton(
                            tooltip: 'Remover foto',
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (await confirmAction(
                                      context,
                                      'Remover esta foto?',
                                      'As outras fotos serão mantidas.',
                                      'Remover',
                                    )) {
                                      try {
                                        await widget.store.deleteReferencePhoto(
                                          widget.cat.id,
                                          entry.key,
                                        );
                                      } catch (_) {
                                        if (context.mounted) {
                                          showMessage(
                                            context,
                                            'Não foi possível remover a foto.',
                                          );
                                        }
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        );
      },
    ),
  );
}
