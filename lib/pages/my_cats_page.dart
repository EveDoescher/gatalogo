import '../widgets/app_header_actions.dart';

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
        final activeList = reports.where(
          (report) => report['status'] == 'active',
        );
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
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const BackButton(),
                            const Expanded(
                              child: Text(
                                'Meus Gatos',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textTitle,
                                ),
                              ),
                            ),
                            AppHeaderActions(store: widget.store),
                          ],
                        ),
                      ),
                    ),

                    // Botão Adicionar Gato (em harmonia com o design system, sem FAB)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.xs,
                        ),
                        child: GatalogoButton(
                          text: 'Cadastrar Meu Gato',
                          icon: LucideIcons.plus,
                          onPressed: () =>
                              _open(AddPetPage(store: widget.store)),
                        ),
                      ),
                    ),

                    // Ação de Emergência Rápida: Perdi meu gato agora
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.xs,
                        ),
                        child: InkWell(
                          onTap: () => _open(
                            CreateMissingReportPage(
                              store: widget.store,
                              quickMode: true,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.alertTriangle,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Criar Alerta Rápido',
                                        style: GoogleFonts.fredoka(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.errorText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ative um alerta de busca imediato para um gato seu não cadastrado',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: AppColors.errorText.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  LucideIcons.chevronRight,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Card explicativo sobre a importância das fotos para proteção
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.xl,
                          AppSpacing.xs,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: AppColors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.shieldCheck,
                                color: AppColors.greenProgress,
                                size: 22,
                              ),
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
                                Image.asset(
                                  'assets/images/gato_3.png',
                                  width: 110,
                                ),
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
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.xl,
                          AppSpacing.xxxl,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final cat = store.pets[index];
                            final isMissing = _active.contains(cat.id);
                            final refCount = store
                                .referencePhotosFor(cat.id)
                                .length;

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: GatalogoCard(
                                backgroundColor: AppColors.cardBackground,
                                onTap: () => _open(
                                  PetProfilePage(
                                    catId: cat.id,
                                    store: store,
                                    isMissing: isMissing,
                                    activeReport: _activeReports[cat.id],
                                  ),
                                ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.errorBg,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppRadius.pill,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Desaparecido',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                            Row(
                                              children: [
                                                const Icon(
                                                  LucideIcons.lightbulb,
                                                  size: 11,
                                                  color:
                                                      AppColors.greenProgress,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Adicione mais ângulos para proteção',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors
                                                          .greenProgress,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      LucideIcons.chevronRight,
                                      color: AppColors.textLight,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }, childCount: store.pets.length),
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
  final _collar = TextEditingController();
  final _distinguishingMarks = TextEditingController();
  final _microchip = TextEditingController();
  String? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _preflight.dispose();
    _name.dispose();
    _collar.dispose();
    _distinguishingMarks.dispose();
    _microchip.dispose();
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
        collar: _collar.text.trim(),
        distinguishingMarks: _distinguishingMarks.text.trim(),
        microchip: _microchip.text.trim(),
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
      actions: const [AppHeaderActions()],
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
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: const InputDecoration(
            labelText: 'Nome do seu gato',
            hintText: 'ex: Paçoca, Mingau',
            prefixIcon: Icon(Icons.pets, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _collar,
          maxLength: 50,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: const InputDecoration(
            labelText: 'Coleira (opcional)',
            hintText: 'ex: Vermelha com guizo, azul reflexiva',
            prefixIcon: Icon(LucideIcons.tag, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _distinguishingMarks,
          maxLength: 120,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: const InputDecoration(
            labelText: 'Marcas características (opcional)',
            hintText: 'ex: Mancha branca no peito, orelha cortada, rabo curto',
            prefixIcon: Icon(LucideIcons.sparkles, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _microchip,
          maxLength: 30,
          keyboardType: TextInputType.text,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: const InputDecoration(
            labelText: 'Microchip (opcional)',
            hintText: 'Código ou número do microchip',
            prefixIcon: Icon(LucideIcons.cpu, size: 18),
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
              const Icon(
                LucideIcons.info,
                color: AppColors.textMedium,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Depois de salvar, você poderá adicionar fotos de diferentes ângulos para mapear toda a pelagem e reforçar a identificação.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
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
          appBar: AppBar(actions: const [AppHeaderActions()]),
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
            const AppHeaderActions(),
            IconButton(
              tooltip: 'Editar detalhes',
              icon: const Icon(
                LucideIcons.pencil,
                color: AppColors.textDark,
                size: 20,
              ),
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
              child: CatPhotoView(
                cat.photoPath,
                height: 260,
                borderRadius: AppRadius.card,
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
                      const Icon(
                        LucideIcons.shieldAlert,
                        size: 16,
                        color: AppColors.greenProgress,
                      ),
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
                      color: missing.isEmpty
                          ? AppColors.greenProgress
                          : AppColors.textMedium,
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
            const SizedBox(height: AppSpacing.md),

            // Card de Identificação para Busca
            GatalogoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Identificação para Busca',
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          LucideIcons.pencil,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'Editar',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        onPressed: () =>
                            _editCatDetailsModal(context, cat, store),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    icon: LucideIcons.tag,
                    label: 'Coleira',
                    value: cat.collar?.isNotEmpty == true
                        ? cat.collar!
                        : 'Não informada',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: LucideIcons.sparkles,
                    label: 'Marcas',
                    value: cat.distinguishingMarks?.isNotEmpty == true
                        ? cat.distinguishingMarks!
                        : 'Nenhuma informada',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: LucideIcons.cpu,
                    label: 'Microchip',
                    value: cat.microchip?.isNotEmpty == true
                        ? cat.microchip!
                        : 'Não informado',
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
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.alertTriangle,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          isMissing
                              ? 'Alerta Ativo em Andamento'
                              : 'Alerta Comunitário',
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
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.errorText,
                    ),
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
                          builder: (_) => CreateMissingReportPage(
                            store: store,
                            initialCat: cat,
                          ),
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
                  'Ver todos os meus alertas de busca',
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

Widget _buildDetailRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: AppColors.textMedium),
      const SizedBox(width: 8),
      Text(
        '$label: ',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
        ),
      ),
    ],
  );
}

void _editCatDetailsModal(BuildContext context, Cat cat, CatStore store) {
  final nameController = TextEditingController(text: cat.name ?? '');
  final collarController = TextEditingController(text: cat.collar ?? '');
  final marksController = TextEditingController(
    text: cat.distinguishingMarks ?? '',
  );
  final microchipController = TextEditingController(text: cat.microchip ?? '');
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
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
                  'Editar Dados de Identificação',
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
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do gato',
                prefixIcon: Icon(Icons.pets, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: collarController,
              decoration: const InputDecoration(
                labelText: 'Coleira',
                hintText: 'ex: Vermelha com guizo',
                prefixIcon: Icon(LucideIcons.tag, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: marksController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Marcas características',
                hintText: 'ex: Mancha no peito, orelha cortada',
                prefixIcon: Icon(LucideIcons.sparkles, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: microchipController,
              decoration: const InputDecoration(
                labelText: 'Microchip',
                hintText: 'Código do microchip',
                prefixIcon: Icon(LucideIcons.cpu, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GatalogoButton(
              text: saving ? 'Salvando…' : 'Salvar Alterações',
              isLoading: saving,
              onPressed: saving
                  ? null
                  : () async {
                      setModalState(() => saving = true);
                      try {
                        await store.updateCatDetails(
                          cat.id,
                          name: nameController.text.trim(),
                          collar: collarController.text.trim(),
                          distinguishingMarks: marksController.text.trim(),
                          microchip: microchipController.text.trim(),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          showMessage(
                            context,
                            'Dados atualizados com sucesso.',
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) showMessage(ctx, e);
                      } finally {
                        if (ctx.mounted) setModalState(() => saving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
