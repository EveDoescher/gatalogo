import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../services/favorites_manager.dart';
import '../services/location_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/post_composer.dart';
import '../widgets/app_header_actions.dart';
import 'cat_gallery_page.dart';
import 'location_page.dart';

class CatDetailsPage extends StatefulWidget {
  const CatDetailsPage({super.key, required this.cat, required this.catStore});

  final Cat cat;
  final CatStore catStore;

  @override
  State<CatDetailsPage> createState() => _CatDetailsPageState();
}

class _CatDetailsPageState extends State<CatDetailsPage> {
  bool _busy = false;
  final FavoritesManager _favoritesManager = FavoritesManager.instance;

  @override
  void initState() {
    super.initState();
    _favoritesManager.initialize();
    widget.catStore.loadReferencePhotos(widget.cat.id);
    _checkAndEnrichLocation(widget.cat);
  }

  Future<void> _checkAndEnrichLocation(Cat cat) async {
    if (cat.latitude == null || cat.longitude == null) return;
    final current = cat.locationName?.trim() ?? '';
    final hasNumber = RegExp(r'\b\d+\b').hasMatch(current);
    final partsCount = current.split(',').length;
    // Se o endereco atual contiver numero ou faltar municipio
    if (current.isEmpty || hasNumber || partsCount <= 3) {
      final enriched = await LocationService.getLocationName(
        cat.latitude!,
        cat.longitude!,
      );
      if (enriched != null &&
          enriched.isNotEmpty &&
          enriched != current &&
          mounted) {
        await widget.catStore.updateCatLocation(
          cat.id,
          latitude: cat.latitude!,
          longitude: cat.longitude!,
          locationName: enriched,
        );
      }
    }
  }

  String _formatFullDate(DateTime date) {
    const months = [
      'jan.',
      'fev.',
      'mar.',
      'abr.',
      'mai.',
      'jun.',
      'jul.',
      'ago.',
      'set.',
      'out.',
      'nov.',
      'dez.',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} às $hour:$minute';
  }

  Future<void> _rename(Cat cat) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(name: cat.name),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await widget.catStore.updateCatName(cat.id, result);
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível salvar o nome.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Cat cat) async {
    if (!await confirmAction(
      context,
      'Remover este gato?',
      'O cadastro e as fotos serão removidos da sua coleção. Esta ação será enviada à sua conta quando houver conexão.',
      'Remover',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.catStore.deleteCat(cat.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGallery(Cat cat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CatGalleryPage(cat: cat, store: widget.catStore),
      ),
    );
    if (mounted) {
      await widget.catStore.loadReferencePhotos(cat.id);
      setState(() {});
    }
  }

  int? _resolveConfidence(CatAnalysis? analysis) {
    if (analysis?.confidence == null) return null;
    final val = analysis!.confidence!;
    if (val <= 1.0 && val > 0) return (val * 100).round();
    return val.round().clamp(1, 100);
  }

  String _formatPercentage(double value) {
    final normalized = value <= 1.0 && value > 0 ? value * 100 : value;
    return '${normalized.round()}%';
  }

  String _formatHairType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Não informado';
    final normalized = raw.trim().toLowerCase();
    if (normalized.contains('curt') || normalized.contains('short')) {
      return 'Curto';
    }
    if (normalized.contains('méd') ||
        normalized.contains('med') ||
        normalized.contains('medium')) {
      return 'Médio';
    }
    if (normalized.contains('long') || normalized.contains('comprid')) {
      return 'Longo';
    }
    if (normalized.contains('sem') ||
        normalized.contains('hairless') ||
        normalized.contains('careca')) {
      return 'Sem pelo';
    }
    if (normalized.contains('ondul') ||
        normalized.contains('wavy') ||
        normalized.contains('curly') ||
        normalized.contains('cresp')) {
      return 'Ondulado';
    }
    return raw.trim();
  }

  void _showConfidenceModal(BuildContext context, String confidenceDisplay) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5CDC3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confiança da IA ($confidenceDisplay)',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Como funciona a estimativa visual',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'O índice de confiança representa a certeza dos modelos de visão computacional na identificação das cores, padrão e pelagem do gato.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Critérios avaliados:',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildConfidenceBullet(
                        'Iluminação adequada e nitidez da fotografia',
                      ),
                      _buildConfidenceBullet(
                        'Visibilidade dos padrões e contraste da pelagem',
                      ),
                      _buildConfidenceBullet(
                        'Enquadramento do corpo e ângulos de referência',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    'Entendi',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 5, color: AppColors.primary),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNotes(Cat cat) async {
    final controller = TextEditingController(text: cat.notes ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Row(
          children: [
            const Icon(
              LucideIcons.bookOpen,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Diario do Gato',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTitle,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anotacoes e lembretes sobre este gatinho (habitos, local preferido, comida, etc.):',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                style: GoogleFonts.nunito(color: AppColors.textTitle),
                decoration: InputDecoration(
                  hintText: 'Escreva suas observacoes...',
                  hintStyle: GoogleFonts.nunito(color: AppColors.textMedium),
                  filled: true,
                  fillColor: AppColors.cardAltBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                color: AppColors.textMedium,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNotes = controller.text.trim();
              Navigator.pop(ctx);
              await widget.catStore.updateCatNotes(
                cat.id,
                newNotes.isEmpty ? null : newNotes,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: Text(
              'Salvar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCat(Cat cat, [CatAnalysis? analysis]) async {
    final post = await showPostComposer(
      context,
      session: widget.catStore.sessionStore,
      cats: [cat],
      initialCat: cat,
    );
    if (post != null && mounted) {
      showMessage(context, 'Descoberta compartilhada na comunidade.');
      await widget.catStore.recordGamificationAction('post');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.catStore, _favoritesManager]),
      builder: (context, _) {
        final found = widget.catStore.cats.where(
          (cat) => cat.id == widget.cat.id,
        );
        final cat = found.isEmpty ? widget.cat : found.first;
        final CatAnalysis? analysis = widget.catStore.analysisFor(cat.id);
        final referencePhotos = widget.catStore.referencePhotosFor(cat.id);
        final isFavorite = _favoritesManager.isFavorite(cat.id);

        final catName = cat.name?.trim().isNotEmpty == true
            ? cat.name!.trim()
            : 'Gato';
        final catCode = 'Gato #${cat.captureNumber.toString().padLeft(3, '0')}';

        // Localização formatada e sanitizada
        final rawLocation = cat.locationName?.trim();
        final hasLocation = rawLocation != null && rawLocation.isNotEmpty;
        final rawParts = hasLocation ? rawLocation.split(',') : <String>[];
        // Remove partes que sejam puramente números (resquícios de números de residência)
        final locationParts = rawParts
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p))
            .toList();

        final locationStreet = locationParts.isNotEmpty
            ? locationParts.first.replaceFirst(RegExp(r'\s+\d+.*$'), '').trim()
            : 'Localização não informada';
        final locationCity = locationParts.length > 1
            ? locationParts.sublist(1).join(', ')
            : '';
        final locationDisplay = locationCity.isNotEmpty
            ? '$locationStreet,\n$locationCity'
            : locationStreet;
        final sanitizedLocation = locationCity.isNotEmpty
            ? '$locationStreet, $locationCity'
            : locationStreet;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Folhas decorativas sutis no fundo
              Positioned(
                right: -25,
                bottom: 80,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.85,
                    child: Image.asset(
                      'assets/images/Folha_6.png',
                      width: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: 240,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.75,
                    child: Image.asset(
                      'assets/images/Folha_1.png',
                      width: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Conteúdo Rolável
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Foto Grande de Capa com Botões Flutuantes
                    Stack(
                      children: [
                        SizedBox(
                          height: 330,
                          width: double.infinity,
                          child: CatPhotoView(
                            cat.photoPath,
                            height: 330,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Botão Voltar (topo esquerdo)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 10,
                          left: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(230),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                LucideIcons.chevronLeft,
                                size: 22,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 10,
                          right: 66,
                          child: AppHeaderActions(store: widget.catStore),
                        ),
                        // Botão Opções (topo direito)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 10,
                          right: 16,
                          child: PopupMenuButton<String>(
                            enabled: !_busy,
                            onSelected: (value) {
                              if (value == 'rename') _rename(cat);
                              if (value == 'delete') _delete(cat);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: AppColors.surface,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.edit3,
                                      size: 18,
                                      color: AppColors.textDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Editar nome',
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.trash2,
                                      size: 18,
                                      color: Color(0xFFD32F2F),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Excluir gato',
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFD32F2F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(230),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                LucideIcons.moreVertical,
                                size: 20,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Cards de Conteúdo (Sobreposição garantida sobre a foto)
                    Transform.translate(
                      offset: const Offset(0, -26),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card 1: Informações Principais (fundo #FAF3F0, raio 26)
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D000000),
                                    blurRadius: 10,
                                    offset: Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nome + Folha decorativa + Botão de Favorito
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    catName,
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 28,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color:
                                                          AppColors.textTitle,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Image.asset(
                                                  'assets/images/Folha_3.png',
                                                  width: 22,
                                                  fit: BoxFit.contain,
                                                ),
                                              ],
                                            ),
                                            Text(
                                              catCode,
                                              style: GoogleFonts.nunito(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Botão Favorito Circular
                                      GestureDetector(
                                        onTap: () => widget.catStore
                                            .toggleFavorite(cat.id),
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3ECE5),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFE5DDD3),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Icon(
                                            LucideIcons.heart,
                                            size: 18,
                                            color: isFavorite
                                                ? AppColors.error
                                                : AppColors.textMedium,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Grade 2 Colunas: Primeiro avistamento e Localização
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Coluna 1: Primeiro avistamento
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              LucideIcons.calendar,
                                              size: 22,
                                              color: AppColors.textMedium,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Primeiro avistamento',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textLight,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatFullDate(
                                                      cat.capturedAt,
                                                    ),
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.textDark,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Coluna 2: Localização
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              LucideIcons.mapPin,
                                              size: 22,
                                              color: AppColors.textMedium,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Localização',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textLight,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    locationDisplay,
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.textDark,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Card 2: Análise da Pelagem com estados reais (analisando, erro com retry, pendente e concluído)
                            _buildAnalysisCard(cat, analysis),

                            const SizedBox(height: 16),

                            // Card 3: Fotos Adicionais
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cabeçalho
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.image,
                                        size: 18,
                                        color: AppColors.textDark,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Fotos adicionais',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.nunito(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _openGallery(cat),
                                        child: Row(
                                          children: [
                                            Text(
                                              referencePhotos.length == 1
                                                  ? '1 Foto'
                                                  : '${referencePhotos.length} Fotos',
                                              style: GoogleFonts.nunito(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textMedium,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              LucideIcons.chevronRight,
                                              size: 16,
                                              color: AppColors.textMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Miniaturas e Botão de Adicionar
                                  SizedBox(
                                    height: 88,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        // Fotos existentes
                                        ...referencePhotos.map(
                                          (photo) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 12,
                                            ),
                                            child: GestureDetector(
                                              onTap: () => _openGallery(cat),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: SizedBox(
                                                  width: 88,
                                                  height: 88,
                                                  child: Image.file(
                                                    File(photo.localPath),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        Container(
                                                          color: const Color(
                                                            0xFFEAE6DC,
                                                          ),
                                                          child: const Icon(
                                                            LucideIcons.image,
                                                            color: AppColors
                                                                .textLight,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Botão Adicionar fotos
                                        GestureDetector(
                                          onTap: () => _openGallery(cat),
                                          child: Container(
                                            width: 88,
                                            height: 88,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE6EADF),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  LucideIcons.plus,
                                                  size: 22,
                                                  color: Color(0xFF6B8563),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Adicionar\nfotos',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(
                                                      0xFF5A7352,
                                                    ),
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Mensagem discreta quando ainda não há fotos adicionais de poses
                                        if (referencePhotos.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 14,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Adicione fotos de diferentes\nângulos para enriquecer o perfil.',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textMedium,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Card 4: Diario & Anotacoes (Etapa 8)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.bookOpen,
                                        size: 18,
                                        color: AppColors.textDark,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Diario & Anotacoes',
                                          style: GoogleFonts.nunito(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _editNotes(cat),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                LucideIcons.edit3,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                cat.notes?.trim().isNotEmpty ==
                                                        true
                                                    ? 'Editar'
                                                    : 'Adicionar',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (cat.notes != null &&
                                      cat.notes!.trim().isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.borderLight,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        cat.notes!.trim(),
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          color: AppColors.textDark,
                                          height: 1.4,
                                        ),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: () => _editNotes(cat),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderLight,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              LucideIcons.circlePlus,
                                              size: 16,
                                              color: AppColors.textMedium,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Registre habitos, locais favoritos ou lembretes...',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 12,
                                                  color: AppColors.textMedium,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Card 5: Historico de Avistamentos (Etapa 8)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.history,
                                        size: 18,
                                        color: AppColors.textDark,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Historico de Avistamentos',
                                          style: GoogleFonts.nunito(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Registro inicial
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    'Primeiro Registro',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.textDark,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.greenLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Original',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.greenLink,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_formatFullDate(cat.capturedAt)} • ${hasLocation ? sanitizedLocation : "Localizacao salva"}',
                                              style: GoogleFonts.nunito(
                                                fontSize: 11,
                                                color: AppColors.textMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (referencePhotos.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    for (final photo in referencePhotos) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.primary,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Foto de Referencia (${photo.kind})',
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                                Text(
                                                  'Atualizado em ${_formatFullDate(photo.updatedAt)}',
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 11,
                                                    color: AppColors.textMedium,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(
                              height: 90,
                            ), // Espaço para os botões fixos
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Barra de Ações Inferior Fixa
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background.withAlpha(245),
                    border: const Border(
                      top: BorderSide(color: Color(0xFFEFE7DE), width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Botão Ver no mapa
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LocationPage(
                                  catStore: widget.catStore,
                                  catId: cat.id,
                                  initial:
                                      cat.latitude != null &&
                                          cat.longitude != null
                                      ? LatLng(cat.latitude!, cat.longitude!)
                                      : null,
                                  readOnly: true,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.greenButton,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.map,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Ver no mapa',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botao Compartilhar
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _shareCat(cat, analysis),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.share2,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Compartilhar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalysisCard(Cat cat, CatAnalysis? analysis) {
    if (cat.status == 'analyzing') {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 18,
                  color: AppColors.textDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Análise da pelagem',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Analisando com Inteligência Artificial...',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Identificando padrões e cores da descoberta.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (cat.status == 'failed') {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 18,
                  color: Color(0xFFD32F2F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Análise da pelagem',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Não foi possível concluir a análise.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O servidor não respondeu ou houve instabilidade de conexão.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => widget.catStore.retryAnalysis(cat.id),
              icon: const Icon(
                LucideIcons.refreshCw,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'Tentar novamente',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (cat.status == 'pending_analysis' || cat.status == 'pending') {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.cloud,
                  size: 18,
                  color: AppColors.textMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Análise pendente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A análise será concluída assim que houver conexão com o servidor.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => widget.catStore.retryAnalysis(cat.id),
              icon: const Icon(
                LucideIcons.refreshCw,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                'Analisar agora',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final confVal = _resolveConfidence(analysis);
    final confidenceDisplay = confVal != null ? '$confVal%' : 'Não informada';
    final coatType = analysis?.coatType ?? 'Não informado';
    final hairType = _formatHairType(analysis?.hairType);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 18,
                color: AppColors.textDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Análise da pelagem',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (confVal != null)
                InkWell(
                  onTap: () => _showConfidenceModal(context, confidenceDisplay),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Confiança: $confidenceDisplay',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMedium,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.helpCircle,
                          size: 15,
                          color: AppColors.textMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cores principais',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (analysis?.colors.isNotEmpty == true)
                      ...analysis!.colors
                          .take(3)
                          .map(
                            (c) => _ColorItem(
                              label: c.name,
                              percentage: _formatPercentage(c.percentage),
                            ),
                          )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Cores naturais registradas',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Padrão',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coatType,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tipo de pelagem',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hairType,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorItem extends StatelessWidget {
  const _ColorItem({required this.label, required this.percentage});

  final String label;
  final String percentage;

  Color _resolveColor(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.contains('pret') || normalized.contains('black')) {
      return const Color(0xFF242424);
    }
    if (normalized.contains('branc') || normalized.contains('white')) {
      return const Color(0xFFFAF9F6);
    }
    if (normalized.contains('laranj') ||
        normalized.contains('orange') ||
        normalized.contains('ruiv') ||
        normalized.contains('red') ||
        normalized.contains('vermelh')) {
      return const Color(0xFFE27238);
    }
    if (normalized.contains('cinz') ||
        normalized.contains('gray') ||
        normalized.contains('grey') ||
        normalized.contains('azul') ||
        normalized.contains('blue')) {
      return const Color(0xFF8A939E);
    }
    if (normalized.contains('crem') ||
        normalized.contains('cream') ||
        normalized.contains('beg') ||
        normalized.contains('beige')) {
      return const Color(0xFFF3E7D3);
    }
    if (normalized.contains('marr') ||
        normalized.contains('brown') ||
        normalized.contains('chocolat')) {
      return const Color(0xFF6E4A35);
    }
    if (normalized.contains('canel') || normalized.contains('cinnamon')) {
      return const Color(0xFF9E5B32);
    }
    if (normalized.contains('fawn') || normalized.contains('fulv')) {
      return const Color(0xFFCCA98A);
    }
    if (normalized.contains('lil') ||
        normalized.contains('lilac') ||
        normalized.contains('lavend')) {
      return const Color(0xFFB5A8B2);
    }
    if (normalized.contains('dourad') ||
        normalized.contains('gold') ||
        normalized.contains('amarel') ||
        normalized.contains('yellow')) {
      return const Color(0xFFE5B548);
    }
    return const Color(0xFFB0A89F);
  }

  @override
  Widget build(BuildContext context) {
    final circleColor = _resolveColor(label);
    final isVeryLight = circleColor.computeLuminance() > 0.72;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isVeryLight
                    ? const Color(0xFFD5CDC3)
                    : Colors.black.withAlpha(20),
                width: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            percentage,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.name});
  final String? name;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFCFAF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        'Nome do gato',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.words,
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        decoration: InputDecoration(
          labelText: 'Nome',
          labelStyle: GoogleFonts.nunito(color: AppColors.textMedium),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: AppColors.textMedium,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Salvar',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
