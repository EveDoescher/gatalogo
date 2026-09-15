import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/cat_preflight_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

const referenceLabels = {
  'front': 'Frente',
  'left': 'Lado esquerdo',
  'right': 'Lado direito',
  'back': 'Costas',
};

const referenceDescriptions = {
  'front': 'Focinho e peito bem visíveis',
  'left': 'Perfil do lado esquerdo do corpo',
  'right': 'Perfil do lado direito do corpo',
  'back': 'Costas e cauda do felino',
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

  Future<void> _pickAndAdd(String kind, ImageSource source) async {
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
      if (mounted) {
        showMessage(context, 'Foto de ${referenceLabels[kind]} salva!');
      }
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

  void _showAddPhotoSheet(String kind, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Adicionar foto: $title',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Escolha como deseja registrar essa pose do gatinho.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoftBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        kind == 'front'
                            ? Icons.pets
                            : kind == 'back'
                                ? LucideIcons.alignCenter
                                : LucideIcons.maximize2,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guia da Pose: $title',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            referenceDescriptions[kind] ?? '',
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.camera,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Tirar Foto com Câmera',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                subtitle: Text(
                  'Fotografe o gatinho agora mesmo',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAdd(kind, ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.greenLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.image,
                    color: AppColors.greenLink,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Escolher da Galeria',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                subtitle: Text(
                  'Selecione uma foto já salva',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAdd(kind, ImageSource.gallery);
                },
              ),
              if (widget.cat.photoPath.isNotEmpty) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.copyCheck,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Vincular foto de cadastro',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Text(
                    'Utilizar a foto principal como pose de $title',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await widget.store.addReferencePhoto(
                      widget.cat.id,
                      kind,
                      widget.cat.photoPath,
                    );
                    if (mounted) {
                      showMessage(
                        context,
                        'Foto principal vinculada a $title!',
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _view(String path, String label) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.textDark,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.chevronLeft,
                    color: AppColors.textDark,
                    size: 22,
                  ),
                ),
              ),
              title: Text(
                label,
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: CatPhotoView(path, fit: BoxFit.contain, borderRadius: 0),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
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
          'Fotos de ${widget.cat.displayName}',
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
          final photos = widget.store.referencePhotosFor(widget.cat.id);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Banner explicativo aconchegante
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoftBg,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: AppColors.borderProfile,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: AppColors.primaryDark,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fotos de Reconhecimento',
                                style: GoogleFonts.fredoka(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Registre o gatinho em vários ângulos. Quanto mais ângulos cadastrados, mais fácil identificar este felino no futuro!',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: AppColors.textDark,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Seção Foto Principal
                  Text(
                    'Foto Principal do Registro',
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () => _view(widget.cat.photoPath, 'Foto principal'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CatPhotoView(
                            widget.cat.photoPath,
                            height: 200,
                            fit: BoxFit.cover,
                            borderRadius: 0,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.greenLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Principal',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.greenLink,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Toque para ampliar',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  LucideIcons.zoomIn,
                                  size: 14,
                                  color: AppColors.textLight,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Seção Ângulos de Referência
                  Row(
                    children: [
                      Text(
                        'Ângulos Adicionais',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${photos.length} de 4 salvos',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ...referenceLabels.entries.map((entry) {
                    final kind = entry.key;
                    final label = entry.value;
                    final desc = referenceDescriptions[kind] ?? '';
                    final found = photos.where((p) => p.kind == kind);
                    final photo = found.isEmpty ? null : found.first;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (photo != null) ...[
                            GestureDetector(
                              onTap: () => _view(photo.localPath, label),
                              child: Stack(
                                children: [
                                  CatPhotoView(
                                    photo.localPath,
                                    height: 170,
                                    fit: BoxFit.cover,
                                    borderRadius: 0,
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(210),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.zoomIn,
                                        size: 16,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            label,
                                            style: GoogleFonts.fredoka(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textTitle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (photo != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.greenLight,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'Cadastrada',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.greenLink,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        photo == null
                                            ? desc
                                            : 'Foto cadastrada para reconhecimento',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: AppColors.textMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (photo == null)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.pill),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () => _showAddPhotoSheet(kind, label),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.camera,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Adicionar',
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Trocar foto',
                                        onPressed: _busy
                                            ? null
                                            : () => _showAddPhotoSheet(
                                                kind, label),
                                        icon: const Icon(
                                          LucideIcons.refreshCw,
                                          size: 18,
                                          color: AppColors.textMedium,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remover foto',
                                        onPressed: _busy
                                            ? null
                                            : () async {
                                                if (await confirmAction(
                                                  context,
                                                  'Remover esta foto?',
                                                  'A foto do ângulo $label será removida.',
                                                  'Remover',
                                                )) {
                                                  try {
                                                    await widget.store
                                                        .deleteReferencePhoto(
                                                      widget.cat.id,
                                                      kind,
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
                                        icon: const Icon(
                                          LucideIcons.trash2,
                                          size: 18,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              if (_busy)
                Container(
                  color: Colors.black.withAlpha(50),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
