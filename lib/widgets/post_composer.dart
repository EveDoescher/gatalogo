import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cat.dart';
import '../services/image_compression_service.dart';
import '../services/social_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

Future<Map<String, dynamic>?> showPostComposer(
  BuildContext context, {
  required SessionStore session,
  List<Cat> cats = const [],
  Cat? initialCat,
  String? initialNote,
  String? initialLocation,
}) async {
  if (!session.isSignedIn) {
    showMessage(context, 'Entre na sua conta para publicar na comunidade.');
    return null;
  }
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => PostComposer(
      session: session,
      cats: cats,
      initialCat: initialCat,
      initialNote: initialNote,
      initialLocation: initialLocation,
    ),
  );
}

class PostComposer extends StatefulWidget {
  const PostComposer({
    super.key,
    required this.session,
    this.cats = const [],
    this.initialCat,
    this.initialNote,
    this.initialLocation,
  });
  final SessionStore session;
  final List<Cat> cats;
  final Cat? initialCat;
  final String? initialNote, initialLocation;
  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  late final TextEditingController _name, _note, _location;
  Cat? _cat;
  String? _photo;
  bool _busy = false, _public = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cat =
        widget.initialCat ?? (widget.cats.isEmpty ? null : widget.cats.first);
    _photo = _cat?.photoPath;
    _name = TextEditingController(text: _cat?.displayName ?? '');
    _note = TextEditingController(text: widget.initialNote ?? '');
    _location = TextEditingController(
      text: widget.initialLocation ?? _cat?.locationName ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file != null && mounted) {
        setState(() {
          _photo = file.path;
          _cat = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível abrir a galeria. Tente novamente.',
        );
      }
    }
  }

  Future<void> _publish() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty || _photo == null) {
      setState(() => _error = 'Adicione uma foto e o nome do gato.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = File(_photo!);
      if (!await file.exists()) {
        throw const FormatException(
          'A foto não está disponível. Escolha outra imagem.',
        );
      }
      final api = SocialApiService(widget.session);
      final bytes = await ImageCompressionService.compressImage(
        await file.readAsBytes(),
      );
      final photoUrl = await api.uploadPostPhoto(bytes, 'post.jpg');
      final post = await api.createPost(
        catName: _name.text.trim(),
        note: _note.text.trim(),
        locationName: _location.text.trim().isEmpty
            ? null
            : _location.text.trim(),
        photoUrl: photoUrl,
        isPublic: _public,
      );
      if (mounted) Navigator.pop(context, post);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : 'Não foi possível publicar. Sua postagem está aqui para tentar novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Postar no feed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.cats.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(_cat?.id),
                initialValue: _cat?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Gato da coleção'),
                items: widget.cats
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text(
                          cat.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (id) => setState(() {
                        _cat = widget.cats.firstWhere((cat) => cat.id == id);
                        _photo = _cat!.photoPath;
                        _name.text = _cat!.displayName;
                        _location.text = _cat!.locationName ?? '';
                      }),
              ),
              const SizedBox(height: 12),
            ],
            if (_photo != null)
              CatPhotoView(_photo!, height: 170, borderRadius: 16),
            TextButton.icon(
              onPressed: _busy ? null : _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _photo == null ? 'Adicionar foto' : 'Escolher outra foto',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nome do gato'),
            ),
            TextField(
              controller: _note,
              enabled: !_busy,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'O que você quer compartilhar?',
              ),
            ),
            TextField(
              controller: _location,
              enabled: !_busy,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Local (opcional)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _public,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _public = value),
              title: const Text('Publicar para toda a comunidade'),
              subtitle: Text(
                _public
                    ? 'Todos podem ver esta postagem.'
                    : 'Somente seus amigos podem ver esta postagem.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorText),
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _publish,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_busy ? 'Publicando…' : 'Publicar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
