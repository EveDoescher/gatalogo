import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/favorites_manager.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/inbox_button.dart';
import 'cat_details_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.catStore});

  final CatStore catStore;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';
  String _selectedFilter = 'todos';
  bool _showFilters = true;
  final FavoritesManager _favoritesManager = FavoritesManager.instance;

  @override
  void initState() {
    super.initState();
    _favoritesManager.initialize();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Folhagens decorativas das bordas (Figma Tela 4)
            Positioned(
              left: -15,
              top: 40,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: 1.6,
                  child: Image.asset(
                    'assets/images/Folha_3.png',
                    width: 48,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -20,
              top: 260,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.85,
                  child: Transform.flip(
                    flipX: true,
                    child: Transform.rotate(
                      angle: -0.28,
                      child: Image.asset(
                        'assets/images/Folha_1.png',
                        width: 90,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: 25,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.85,
                  child: Transform.rotate(
                    angle: 3.14,
                    child: Image.asset(
                      'assets/images/Folha_2.png',
                      width: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // Conteúdo principal
            AnimatedBuilder(
              animation: Listenable.merge([widget.catStore, _favoritesManager]),
              builder: (context, _) {
                final allDiscoveries = widget.catStore.discoveries;

                final filteredCats = allDiscoveries.where((cat) {
                  final matchesQuery =
                      '${cat.displayName} ${cat.captureNumber} ${cat.locationName ?? ''}'
                          .toLowerCase()
                          .contains(_query.toLowerCase().trim());
                  if (!matchesQuery) return false;

                  switch (_selectedFilter) {
                    case 'recentes':
                      return true;
                    case 'com_nome':
                      return cat.name != null && cat.name!.trim().isNotEmpty;
                    case 'favoritos':
                      return _favoritesManager.isFavorite(cat.id);
                    default:
                      return true;
                  }
                }).toList();

                if (_selectedFilter == 'recentes') {
                  filteredCats.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
                }

                return Column(
                  children: [
                    // Topo: Barra com Logo + Avatar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Logo.png',
                            height: 44,
                            fit: BoxFit.contain,
                          ),
                          const Spacer(),
                          InboxButton(store: widget.catStore, size: 44),
                          const SizedBox(width: 10),
                          UserAvatarButton(
                            sessionStore: widget.catStore.sessionStore,
                            catStore: widget.catStore,
                            size: 44,
                          ),
                        ],
                      ),
                    ),

                    // Barra de Busca com o Gatinho debruçado com micro-animação
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: 84,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Campo de Busca
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: SizedBox(
                                height: 48,
                                child: TextField(
                                  onChanged: (val) => setState(() => _query = val),
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    hintText: 'Buscar gatos na sua coleção...',
                                    hintStyle: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textLight,
                                    ),
                                    prefixIcon: const Icon(
                                      LucideIcons.search,
                                      size: 19,
                                      color: AppColors.textLight,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        LucideIcons.slidersHorizontal,
                                        size: 19,
                                        color: _showFilters
                                            ? AppColors.primary
                                            : AppColors.textDark,
                                      ),
                                      onPressed: () => setState(
                                        () => _showFilters = !_showFilters,
                                      ),
                                      tooltip: 'Filtros',
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1.2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Gatinho ilustrado
                            Positioned(
                              right: 28,
                              bottom: 32,
                              child: IgnorePointer(
                                child: Image.asset(
                                  'assets/images/gato_3.png',
                                  width: 130,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Filtros horizontais em estilo cápsula (Pills)
                    AnimatedCrossFade(
                      firstChild: Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'Todos (${allDiscoveries.length})',
                                key: 'todos',
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Recentes',
                                key: 'recentes',
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Com nome',
                                key: 'com_nome',
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Favoritos',
                                key: 'favoritos',
                              ),
                              const SizedBox(width: 20),
                            ],
                          ),
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                      crossFadeState: _showFilters
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 250),
                    ),

                    const SizedBox(height: 8),

                    // Grid de Gatos
                    Expanded(
                      child: widget.catStore.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : filteredCats.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/gato_2.png',
                                          height: 100,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Nenhum gato encontrado',
                                          style: GoogleFonts.fredoka(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Fotografe novos gatos na rua para expandir seu herbário felino!',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.74,
                                  ),
                                  itemCount: filteredCats.length,
                                  itemBuilder: (context, index) {
                                    final cat = filteredCats[index];
                                    final isFav = _favoritesManager.isFavorite(cat.id);

                                    // Staggered animated entrance for items
                                    return TweenAnimationBuilder<double>(
                                      duration: Duration(milliseconds: 250 + (index % 6) * 50),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (context, val, child) {
                                        return Opacity(
                                          opacity: val,
                                          child: Transform.translate(
                                            offset: Offset(0, (1.0 - val) * 20),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _CollectionCatCard(
                                        cat: cat,
                                        isFavorite: isFav,
                                        formattedDate: _formatDate(cat.capturedAt),
                                        onToggleFavorite: () => _favoritesManager.toggleFavorite(cat.id),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CatDetailsPage(
                                              cat: cat,
                                              catStore: widget.catStore,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String key}) {
    final isSelected = _selectedFilter == key;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}

class _CollectionCatCard extends StatefulWidget {
  const _CollectionCatCard({
    required this.cat,
    required this.isFavorite,
    required this.formattedDate,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final Cat cat;
  final bool isFavorite;
  final String formattedDate;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  State<_CollectionCatCard> createState() => _CollectionCatCardState();
}

class _CollectionCatCardState extends State<_CollectionCatCard> with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleHeartTap() {
    _heartController.forward(from: 0.0);
    widget.onToggleFavorite();
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.cat.name?.trim().isNotEmpty == true
        ? widget.cat.name!.trim()
        : 'Gato';
    final catCode =
        'Gato #${widget.cat.captureNumber.toString().padLeft(3, '0')}';
    final locationText = widget.cat.locationName?.isNotEmpty == true
        ? widget.cat.locationName!.split(',').take(2).join(',').trim()
        : 'Centro,\nLimeira - SP';

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem do Gato com recorte suave diagonal
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: ClipPath(
                  clipper: _CardImageClipper(),
                  child: SizedBox(
                    height: 114,
                    width: double.infinity,
                    child: CatPhotoView(
                      widget.cat.photoPath,
                      fit: BoxFit.cover,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),

              // Informações do Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Nome do Gato em Fredoka
                      Text(
                        catName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fredoka(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      // Código / Identificador
                      Text(
                        catCode,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Linha com Data, Local e Botão de Favoritar
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Data
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.calendar,
                                      size: 11,
                                      color: AppColors.textLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.formattedDate,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMedium,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Localização
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        LucideIcons.mapPin,
                                        size: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationText,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMedium,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Botão de Favoritar Animado
                          GestureDetector(
                            onTap: _handleHeartTap,
                            behavior: HitTestBehavior.opaque,
                            child: ScaleTransition(
                              scale: _heartScale,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: widget.isFavorite
                                      ? AppColors.primaryLight
                                      : AppColors.cardBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.isFavorite
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: 1.0,
                                  ),
                                ),
                                child: Icon(
                                  widget.isFavorite
                                      ? Icons.favorite
                                      : LucideIcons.heart,
                                  size: 16,
                                  color: widget.isFavorite
                                      ? AppColors.primary
                                      : AppColors.textMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
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
  );
}
}

class _CardImageClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    // Curva sutil da esquerda descendo suavemente para a direita como no Figma
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height - 12,
      size.width,
      size.height - 2,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
