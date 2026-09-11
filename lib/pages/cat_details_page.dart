import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../services/favorites_manager.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
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
      'dez.'
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

  Future<void> _addPhoto(Cat cat) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (photo == null) return;
    setState(() => _busy = true);
    try {
      await widget.catStore.addReferencePhoto(cat.id, 'detail', photo.path);
      if (mounted) {
        showMessage(context, 'Foto adicional adicionada com sucesso!');
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Não foi possível salvar a foto adicional.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareCat(Cat cat) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Compartilhando descoberta de ${cat.displayName} no Gatálogo!',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
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
        final catCode =
            'Gato #${cat.captureNumber.toString().padLeft(3, '0')}';

        // Localização formatada
        final locationParts = (cat.locationName ?? 'Centro, Limeira - SP')
            .split(',');
        final locationDistrict = locationParts.first.trim();
        final locationCity = locationParts.length > 1
            ? locationParts.sublist(1).join(',').trim()
            : 'Limeira - SP';

        // Análise
        final confidenceInt = analysis?.confidence != null
            ? (analysis!.confidence! * 100).round()
            : 95;
        final coatType = analysis?.coatType ?? 'Tricolor';
        final hairType = analysis?.primaryColor ?? 'Curta';

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
              CustomScrollView(
                slivers: [
                  // Foto Grande de Capa com Botões Flutuantes
                  SliverToBoxAdapter(
                    child: Stack(
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
                  ),

                  // Cards de Conteúdo
                  SliverToBoxAdapter(
                    child: Transform.translate(
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
                                                      color: AppColors.textTitle,
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
                                        onTap: () => _favoritesManager
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
                                            isFavorite
                                                ? Icons.favorite
                                                : LucideIcons.heart,
                                            size: 18,
                                            color: isFavorite
                                                ? AppColors.primary
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
                                                      color: AppColors.textLight,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatFullDate(
                                                        cat.capturedAt),
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
                                                      color: AppColors.textLight,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '$locationDistrict,\n$locationCity',
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

                            // Card 2: Análise da Pelagem
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cabeçalho da Análise
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.sparkles,
                                        size: 18,
                                        color: AppColors.textDark,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Análise da pelagem',
                                        style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Confiança: $confidenceInt%',
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

                                  const SizedBox(height: 18),

                                  // Conteúdo: Cores Principais + Padrão + Tipo
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Lado Esquerdo: Cores Principais
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                            if (analysis?.colors.isNotEmpty ==
                                                true)
                                              ...analysis!.colors.take(3).map(
                                                    (c) => _ColorItem(
                                                      label: c.name,
                                                      percentage:
                                                          '${(c.percentage * 100).round()}%',
                                                    ),
                                                  )
                                            else ...[
                                              const _ColorItem(
                                                  label: 'Cor',
                                                  percentage: '60%'),
                                              const _ColorItem(
                                                  label: 'Cor',
                                                  percentage: '60%'),
                                              const _ColorItem(
                                                  label: 'Cor',
                                                  percentage: '60%'),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Lado Direito: Padrão e Tipo de Pelagem
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                            ),

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
                                      Text(
                                        'Fotos adicionais',
                                        style: GoogleFonts.nunito(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CatGalleryPage(
                                              cat: cat,
                                              store: widget.catStore,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${referencePhotos.length} Fotos',
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
                                                right: 12),
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
                                                        0xFFEAE6DC),
                                                    child: const Icon(
                                                      LucideIcons.image,
                                                      color:
                                                          AppColors.textLight,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Se não tiver fotos adicionais, exibe uma miniatura da foto principal
                                        if (referencePhotos.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: SizedBox(
                                                width: 88,
                                                height: 88,
                                                child: CatPhotoView(
                                                    cat.photoPath),
                                              ),
                                            ),
                                          ),

                                        // Botão Adicionar fotos
                                        GestureDetector(
                                          onTap: () => _addPhoto(cat),
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
                                                    color:
                                                        const Color(0xFF5A7352),
                                                    height: 1.1,
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

                            const SizedBox(height: 90), // Espaço para os botões fixos
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
                      top: BorderSide(
                        color: Color(0xFFEFE7DE),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Botão Ver no mapa
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LocationPage(
                                  catStore: widget.catStore,
                                  catId: cat.id,
                                  initial: cat.latitude != null &&
                                          cat.longitude != null
                                      ? LatLng(cat.latitude!, cat.longitude!)
                                      : null,
                                  readOnly: true,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              LucideIcons.map,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Ver no mapa',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.greenButton,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botão Compartilhar
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _shareCat(cat),
                            icon: const Icon(
                              LucideIcons.share2,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Compartilhar',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
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
}

class _ColorItem extends StatelessWidget {
  const _ColorItem({required this.label, required this.percentage});

  final String label;
  final String percentage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFD6CEC5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(width: 16),
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
