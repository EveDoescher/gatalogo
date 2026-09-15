import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../stores/cat_store.dart';
import '../services/cat_preflight_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
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
  Map<String, Map<String, dynamic>> _activeReports = {};
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
        final activeList = reports.where((report) => report['status'] == 'active');
        setState(() {
          _active = activeList
              .map((report) => report['cat_client_id'] as String)
              .toSet();
          _activeReports = {
            for (final r in activeList)
              if (r['cat_client_id'] != null) r['cat_client_id'] as String: r,
          };
        });
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
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Stack(
        children: [
          // Folhagens decorativas
          Positioned(
            top: -15,
            left: -20,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.2,
                child: Image.asset(
                  'assets/images/Folha_2.png',
                  width: 90,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: -10,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/Folha_6.png',
                width: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Conteúdo
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final store = widget.store;
              return RefreshIndicator(
                onRefresh: _loadReports,
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // Cabeçalho
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
                              tooltip: 'Voltar',
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Meus Gatos',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.fredoka(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTitle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoftBg,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.pets, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${store.pets.length}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Botão Adicionar Gato (em harmonia com o design system, sem FAB)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                        child: GatalogoButton(
                          text: 'Cadastrar Meu Gato',
                          icon: LucideIcons.plus,
                          onPressed: () => _open(AddPetPage(store: widget.store)),
                        ),
                      ),
                    ),

                    // Card explicativo sobre a importância das fotos para proteção
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xs),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.shieldCheck, color: AppColors.greenProgress, size: 22),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Fotos de diferentes ângulos ajudam a reconhecer seu gato automaticamente caso ele se perca.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (store.pets.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxxl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/gato_3.png', width: 110),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Quem mora com você?',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTitle,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Cadastre seus gatos e guarde fotos para mantê-los seguros e protegidos.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxxl),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final cat = store.pets[index];
                              final isMissing = _active.contains(cat.id);
                              final refCount = store.referencePhotosFor(cat.id).length;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: GatalogoCard(
                                  backgroundColor: AppColors.cardBackground,
                                  onTap: () => _open(PetProfilePage(
                                    catId: cat.id,
                                    store: store,
                                    isMissing: isMissing,
                                    activeReport: _activeReports[cat.id],
                                  )),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        height: 70,
                                        child: CatPhotoView(
                                          cat.photoPath,
                                          borderRadius: AppRadius.photo,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    cat.displayName,
                                                    style: GoogleFonts.fredoka(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textTitle,
                                                    ),
                                                  ),
                                                ),
                                                if (isMissing)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.errorBg,
                                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                                    ),
                                                    child: Text(
                                                      'Desaparecido',
                                                      style: GoogleFonts.nunito(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.error,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${refCount + 1} foto(s) no álbum de proteção',
                                              style: GoogleFonts.nunito(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMedium,
                                              ),
                                            ),
                                            if (refCount < 3) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '💡 Adicione mais ângulos para proteção',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.greenProgress,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Icon(LucideIcons.chevronRight, color: AppColors.textLight, size: 18),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: store.pets.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(
        'Cadastrar Meu Gato',
        style: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textTitle,
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        TextField(
          controller: _name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
          decoration: const InputDecoration(
            labelText: 'Nome do seu gato',
            hintText: 'ex: Paçoca, Mingau',
            prefixIcon: Icon(Icons.pets, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_photo != null) ...[
          CatPhotoView(_photo!, height: 260, borderRadius: AppRadius.card),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: GatalogoSecondaryButton(
                text: 'Fotografar',
                icon: LucideIcons.camera,
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: GatalogoSecondaryButton(
                text: 'Galeria',
                icon: LucideIcons.image,
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.info, color: AppColors.textMedium, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Depois de salvar, você poderá adicionar fotos dos lados, costas e rosto para reforçar a identificação.',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        GatalogoButton(
          text: _busy ? 'Salvando…' : 'Salvar Gatinho',
          isLoading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    ),
  );
}

class PetProfilePage extends StatelessWidget {
  const PetProfilePage({
    super.key,
    required this.catId,
    required this.store,
    this.isMissing = false,
    this.activeReport,
  });
  final String catId;
  final CatStore store;
  final bool isMissing;
  final Map<String, dynamic>? activeReport;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final found = store.pets.where((cat) => cat.id == catId);
      if (found.isEmpty) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(),
          body: const EmptyContent(
            'Gato não encontrado',
            'Este cadastro pode ter sido removido.',
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            cat.displayName,
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Editar detalhes',
              icon: const Icon(LucideIcons.pencil, color: AppColors.textDark, size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CatDetailsPage(cat: cat, catStore: store),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
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
                    height: 260,
                    borderRadius: AppRadius.card,
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
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
            GatalogoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.displayName,
                    style: GoogleFonts.fredoka(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No seu Gatálogo desde ${displayDate(cat.capturedAt)}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(LucideIcons.shieldAlert, size: 16, color: AppColors.greenProgress),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Álbum de Proteção: ${photos.length + 1} foto(s)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    missing.isEmpty
                        ? 'Álbum completo com todos os ângulos.'
                        : 'Ângulos pendentes: $missing.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: missing.isEmpty ? AppColors.greenProgress : AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GatalogoSecondaryButton(
                    text: 'Gerenciar Fotos (${photos.length + 1})',
                    icon: LucideIcons.images,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CatGalleryPage(cat: cat, store: store),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          isMissing ? 'Alerta Ativo em Andamento' : 'Alerta Comunitário',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.errorText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isMissing
                        ? 'Este gato já está registrado como desaparecido. A comunidade e o sistema de inteligência já estão atentos a possíveis avistamentos.'
                        : 'Se o seu gato sumir ou escapar, crie um alerta com o último local para que a comunidade ajude no reencontro.',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.errorText),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (isMissing)
                    ElevatedButton.icon(
                      onPressed: () {
                        if (activeReport != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MissingReportDetailPage(
                                report: activeReport!,
                                store: store,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MissingCatsPage(
                                catStore: store,
                                sessionStore: store.sessionStore,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      icon: const Icon(LucideIcons.eye, size: 16),
                      label: const Text('Ver Alerta Ativo'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateMissingReportPage(store: store, initialCat: cat),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      icon: const Icon(LucideIcons.search, size: 16),
                      label: const Text('Declarar Desaparecido'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MissingCatsPage(
                      catStore: store,
                      sessionStore: store.sessionStore,
                    ),
                  ),
                ),
                child: Text(
                  'Ver meus alertas de busca',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenLink,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
