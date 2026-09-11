import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/favorites_manager.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
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
  final FavoritesManager _favoritesManager = FavoritesManager.instance;

  @override
  void initState() {
    super.initState();
    _favoritesManager.initialize();
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
            // Folhas decorativas sutis nas bordas
            Positioned(
              left: 15,
              top: 55,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/Folha_3.png',
                  width: 44,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: -35,
              top: 280,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/images/Folha_1.png',
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              bottom: 40,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/images/Folha_2.png',
                    width: 110,
                    fit: BoxFit.contain,
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
                      return true; // já ordenado por data
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
                    // Cabeçalho fixo com Busca e Filtros
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Topo: Logo + Folhas + Avatar
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/Logo.png',
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE8D6DE),
                                    width: 1.4,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.user,
                                  size: 20,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),

                          // Barra de Busca com Gatinho deitado em cima no canto direito
                          SizedBox(
                            height: 85,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Barra de Busca (embaixo)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5F2),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFFD5CDC8),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: null,
                                      onChanged: (val) => setState(() => _query = val),
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                      decoration: InputDecoration(
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
                                        suffixIcon: const Icon(
                                          LucideIcons.slidersHorizontal,
                                          size: 19,
                                          color: AppColors.textDark,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Gatinho debruçado sobre a barra de busca no lado direito
                                Positioned(
                                  right: 32,
                                  bottom: 34,
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

                          const SizedBox(height: 12),

                          // Pílulas de Filtros horizontais
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/gato_2.png',
                                          height: 90,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Nenhum gato encontrado',
                                          style: GoogleFonts.nunito(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tente ajustar a busca ou o filtro selecionado.',
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
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 8, 20, 24),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.68,
                                  ),
                                  itemCount: filteredCats.length,
                                  itemBuilder: (context, index) {
                                    final cat = filteredCats[index];
                                    final isFav = _favoritesManager
                                        .isFavorite(cat.id);

                                    return _CollectionCatCard(
                                      cat: cat,
                                      isFavorite: isFav,
                                      formattedDate:
                                          _formatDate(cat.capturedAt),
                                      onToggleFavorite: () =>
                                          _favoritesManager
                                              .toggleFavorite(cat.id),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CatDetailsPage(
                                            cat: cat,
                                            catStore: widget.catStore,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1EBE4),
          borderRadius: BorderRadius.circular(20),
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

class _CollectionCatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final catName = cat.name?.trim().isNotEmpty == true
        ? cat.name!.trim()
        : 'Gato';
    final catCode =
        'Gato #${cat.captureNumber.toString().padLeft(3, '0')}';
    final locationText = cat.locationName?.isNotEmpty == true
        ? cat.locationName!.split(',').take(2).join(',').trim()
        : 'Centro,\nLimeira - SP';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFDF8F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFF2ECE6),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem do Gato com recorte diagonal sutil no canto inferior
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              child: ClipPath(
                clipper: _CardImageClipper(),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CatPhotoView(cat.photoPath, fit: BoxFit.cover),
                ),
              ),
            ),

            // Informações do Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do Gato
                    Text(
                      catName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTitle,
                      ),
                    ),
                    // Código / Identificador
                    Text(
                      catCode,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                    const Spacer(),

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
                                      formattedDate,
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
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Botão de Favoritar (círculo com borda sutil)
                        GestureDetector(
                          onTap: onToggleFavorite,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F1EB),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFEBE3D8),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : LucideIcons.heart,
                              size: 16,
                              color: isFavorite
                                  ? AppColors.primary
                                  : AppColors.textMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    // Linha curva diagonal subindo suavemente da esquerda para a direita
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height - 10,
      size.width,
      size.height - 22,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
