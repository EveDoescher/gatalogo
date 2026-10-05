import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cat.dart';
import '../services/image_compression_service.dart';
import '../services/social_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'illustrated_home_components.dart';

import 'package:uuid/uuid.dart';

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
  return Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PostComposer(
        session: session,
        cats: cats,
        initialCat: initialCat,
        initialNote: initialNote,
        initialLocation: initialLocation,
      ),
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
  bool _busy = false, _public = true, _allowExit = false;
  String _requestId = const Uuid().v4();
  String? _attemptContent;
  String? _uploadedPhoto;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCat;
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
          _uploadedPhoto = null;
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
    if (_note.text.trim().isEmpty && _photo == null) {
      setState(() => _error = 'Escreva algo ou adicione uma foto.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = SocialApiService(widget.session);
      if (_photo != null && _uploadedPhoto == null) {
        final file = File(_photo!);
        if (!await file.exists()) {
          throw const FormatException(
            'A foto não está disponível. Escolha outra imagem.',
          );
        }
        final bytes = await ImageCompressionService.compressImage(
          await file.readAsBytes(),
        );
        _uploadedPhoto = await api.uploadPostPhoto(bytes, 'post.jpg');
        if (_uploadedPhoto == null) {
          throw const FormatException(
            'Não foi possível enviar a foto. Sua publicação foi preservada para tentar novamente.',
          );
        }
      }
      final content = [
        _name.text.trim(),
        _note.text.trim(),
        _location.text.trim(),
        _uploadedPhoto ?? '',
        _public.toString(),
      ].join('\u0000');
      if (_attemptContent != null && _attemptContent != content) {
        _requestId = const Uuid().v4();
      }
      _attemptContent = content;
      final post = await api.createPost(
        catName: _name.text.trim(),
        note: _note.text.trim(),
        locationName: _location.text.trim().isEmpty
            ? null
            : _location.text.trim(),
        photoUrl: _uploadedPhoto,
        requestId: _requestId,
        isPublic: _public,
      );
      if (mounted) {
        setState(() => _allowExit = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, post);
      }
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

  bool get _hasDraft =>
      _note.text.isNotEmpty ||
      _photo != null ||
      _name.text.isNotEmpty ||
      _location.text.isNotEmpty;
  Future<void> _close() async {
    if (_busy) return;
    final leave =
        !_hasDraft ||
        await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Descartar publicação?'),
                content: const Text(
                  'Seu texto e os anexos ainda não foram publicados.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Continuar escrevendo'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            ) ==
            true;
    if (leave && mounted) {
      setState(() => _allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _editDetails({required bool location}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                location ? 'Adicionar local' : 'Gato da publicação',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (!location && widget.cats.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _cat?.id ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Selecionar um dos meus gatos',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Sem associação'),
                    ),
                    for (final cat in widget.cats)
                      DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.displayName),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    _cat = id == null || id.isEmpty
                        ? null
                        : widget.cats.firstWhere((cat) => cat.id == id);
                    _name.text = _cat?.displayName ?? '';
                  }),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: location ? _location : _name,
                autofocus: true,
                maxLength: location ? 500 : 100,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: location
                      ? 'Local (opcional)'
                      : 'Nome do gato (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Concluir'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || (!_busy && !_hasDraft),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Fechar publicação',
          onPressed: _busy ? null : _close,
          icon: const Icon(Icons.close),
        ),
        title: const Text('Nova publicação', style: TextStyle(fontSize: 19)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _busy || (_note.text.trim().isEmpty && _photo == null)
                  ? null
                  : _publish,
              child: Text(_busy ? 'Publicando…' : 'Publicar'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        FramedUserAvatar(
                          url: widget.session.avatarUrl,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.session.session?.username ??
                                    'Sua publicação',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              PopupMenuButton<bool>(
                                enabled: !_busy,
                                initialValue: _public,
                                tooltip: 'Quem pode ver a publicação',
                                onSelected: (value) =>
                                    setState(() => _public = value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: true,
                                    child: Text('Toda a comunidade'),
                                  ),
                                  PopupMenuItem(
                                    value: false,
                                    child: Text('Somente amigos'),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.greenLight,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppColors.green),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _public
                                            ? Icons.public
                                            : Icons.people_outline,
                                        size: 16,
                                        color: AppColors.greenLink,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          _public
                                              ? 'Toda a comunidade'
                                              : 'Somente amigos',
                                          maxLines: 2,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.greenLink,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.expand_more,
                                        size: 17,
                                        color: AppColors.greenLink,
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sua mensagem',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${_note.text.characters.length}/2000',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      enabled: !_busy,
                      minLines: _photo == null ? 5 : 3,
                      maxLines: null,
                      maxLength: 2000,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        color: AppColors.textDark,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Compartilhe algo com a comunidade…',
                        hintStyle: TextStyle(color: AppColors.textMedium),
                        contentPadding: EdgeInsets.all(16),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.cardAltBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: AppColors.greenLink,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    if (_photo != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Foto anexada',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CatPhotoView(_photo!, height: 240),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: IconButton.filled(
                              tooltip: 'Remover foto',
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _photo = null;
                                      _uploadedPhoto = null;
                                    }),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_name.text.isNotEmpty || _location.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (_name.text.isNotEmpty)
                            InputChip(
                              avatar: const Icon(Icons.pets_outlined, size: 16),
                              label: Text(_name.text),
                              onPressed: _busy
                                  ? null
                                  : () => _editDetails(location: false),
                              onDeleted: _busy
                                  ? null
                                  : () => setState(() {
                                      _name.clear();
                                      _cat = null;
                                    }),
                            ),
                          if (_location.text.isNotEmpty)
                            InputChip(
                              avatar: const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                              ),
                              label: Text(
                                _location.text,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _editDetails(location: true),
                              onDeleted: _busy
                                  ? null
                                  : () => setState(_location.clear),
                            ),
                        ],
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.errorText),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Adicionar à publicação',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.greenLink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ComposerAction(
                        label: 'Foto',
                        icon: Icons.photo_library_outlined,
                        onPressed: _busy ? null : _pickPhoto,
                      ),
                      _ComposerAction(
                        label: 'Gato',
                        icon: Icons.pets_outlined,
                        onPressed: _busy
                            ? null
                            : () => _editDetails(location: false),
                      ),
                      _ComposerAction(
                        label: 'Local',
                        icon: Icons.location_on_outlined,
                        onPressed: _busy
                            ? null
                            : () => _editDetails(location: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.greenLink,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.green),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(64, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
  );
}
