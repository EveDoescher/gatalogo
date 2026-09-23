import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';
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
  String? _selectedAnalysisStatus;
  String? _selectedColor;
  String? _selectedCoatPattern;
  String? _selectedNeighborhood;
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
      'dez.',
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

            AnimatedBuilder(
              animation: Listenable.merge([widget.catStore, _favoritesManager]),
              builder: (context, _) {
                final allDiscoveries = widget.catStore.discoveries;

                final filteredCats = allDiscoveries.where((cat) {
                  final analysis = widget.catStore.analysisFor(cat.id);

                  final query = _query.toLowerCase().trim();
                  if (query.isNotEmpty) {
                    final searchCorpus = [
                      cat.displayName,
                      cat.captureNumber.toString(),
                      cat.locationName ?? '',
                      analysis?.coatType ?? '',
                      analysis?.primaryColor ?? '',
                      ...?analysis?.colors.map((c) => c.name),
                    ].join(' ').toLowerCase();

                    if (!searchCorpus.contains(query)) {
                      return false;
                    }
                  }

                  switch (_selectedFilter) {
                    case 'recentes':
                      break;
                    case 'com_nome':
                      if (cat.name == null || cat.name!.trim().isEmpty) {
                        return false;
                      }
                      break;
                    case 'favoritos':
                      if (!_favoritesManager.isFavorite(cat.id)) return false;
                      break;
                  }

                  if (_selectedAnalysisStatus != null &&
                      _selectedAnalysisStatus != 'all') {
                    final effectiveStatus = analysis?.status.name ?? cat.status;
                    switch (_selectedAnalysisStatus) {
                      case 'completed':
                        if (effectiveStatus != 'completed' &&
                            cat.status != 'completed') {
                          return false;
                        }
                        break;
                      case 'pending':
                        final isPending =
                            effectiveStatus == 'pending' ||
                            effectiveStatus == 'pending_analysis' ||
                            effectiveStatus == 'analyzing' ||
                            cat.status == 'pending_analysis' ||
                            cat.status == 'pending' ||
                            cat.status == 'analyzing';
                        if (!isPending) return false;
                        break;
                      case 'failed':
                        if (effectiveStatus != 'failed' &&
                            cat.status != 'failed') {
                          return false;
                        }
                        break;
                    }
                  }

                  if (_selectedColor != null && _selectedColor != 'all') {
                    final targetColor = _selectedColor!.toLowerCase();
                    final primaryMatch =
                        analysis?.primaryColor?.toLowerCase() == targetColor;
                    final listMatch =
                        analysis?.colors.any(
                          (c) => c.name.toLowerCase().contains(targetColor),
                        ) ==
                        true;
                    if (!primaryMatch && !listMatch) return false;
                  }

                  if (_selectedCoatPattern != null &&
                      _selectedCoatPattern != 'all') {
                    final targetPattern = _selectedCoatPattern!.toLowerCase();
                    final patternMatch =
                        analysis?.coatType?.toLowerCase().contains(
                          targetPattern,
                        ) ==
                        true;
                    if (!patternMatch) return false;
                  }

                  if (_selectedNeighborhood != null &&
                      _selectedNeighborhood != 'all') {
                    final targetNeigh = _selectedNeighborhood!.toLowerCase();
                    final neighMatch =
                        cat.locationName?.toLowerCase().contains(targetNeigh) ==
                        true;
                    if (!neighMatch) return false;
                  }

                  return true;
                }).toList();

                if (_selectedFilter == 'recentes') {
                  filteredCats.sort(
                    (a, b) => b.capturedAt.compareTo(a.capturedAt),
                  );
                }

                return Column(
                  children: [
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

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: 84,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: SizedBox(
                                height: 48,
                                child: TextField(
                                  onChanged: (val) =>
                                      setState(() => _query = val),
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
                            Positioned(
                              right: 28,
                              bottom: 32,
                              child: IgnorePointer(
                                child: Image.asset(
                                  'assets/images/gato_3.png',
                                  width: 76,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Padding(
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
                            const SizedBox(width: 8),
                            _buildFilterActionChip(
                              label: 'Filtros avançados',
                              count: _activeFiltersCount,
                              onTap: () =>
                                  _openAdvancedFiltersModal(allDiscoveries),
                            ),
                            const SizedBox(width: 20),
                          ],
                        ),
                      ),
                    ),

                    if (_activeFiltersCount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    if (_selectedAnalysisStatus != null &&
                                        _selectedAnalysisStatus != 'all')
                                      _buildActiveFilterBadge(
                                        label: _analysisStatusLabel(
                                          _selectedAnalysisStatus!,
                                        ),
                                        onRemove: () => setState(
                                          () => _selectedAnalysisStatus = null,
                                        ),
                                      ),
                                    if (_selectedCoatPattern != null &&
                                        _selectedCoatPattern != 'all')
                                      _buildActiveFilterBadge(
                                        label: 'Padrão: $_selectedCoatPattern',
                                        onRemove: () => setState(
                                          () => _selectedCoatPattern = null,
                                        ),
                                      ),
                                    if (_selectedColor != null &&
                                        _selectedColor != 'all')
                                      _buildActiveFilterBadge(
                                        label: 'Cor: $_selectedColor',
                                        onRemove: () => setState(
                                          () => _selectedColor = null,
                                        ),
                                      ),
                                    if (_selectedNeighborhood != null &&
                                        _selectedNeighborhood != 'all')
                                      _buildActiveFilterBadge(
                                        label: 'Bairro: $_selectedNeighborhood',
                                        onRemove: () => setState(
                                          () => _selectedNeighborhood = null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _clearAdvancedFilters,
                              child: Text(
                                'Limpar',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async {
                          await widget.catStore.syncCatalog(manual: true);
                        },
                        child: widget.catStore.isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              )
                            : filteredCats.isEmpty
                            ? Center(
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
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
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  6,
                                  20,
                                  24,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.74,
                                    ),
                                itemCount: filteredCats.length,
                                itemBuilder: (context, index) {
                                  final cat = filteredCats[index];
                                  final isFav = _favoritesManager.isFavorite(
                                    cat.id,
                                  );

                                  return TweenAnimationBuilder<double>(
                                    duration: Duration(
                                      milliseconds: 250 + (index % 6) * 50,
                                    ),
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
                                      analysis: widget.catStore.analysisFor(
                                        cat.id,
                                      ),
                                      isFavorite: isFav,
                                      formattedDate: _formatDate(
                                        cat.capturedAt,
                                      ),
                                      onToggleFavorite: () => widget.catStore
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
                                    ),
                                  );
                                },
                              ),
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

  int get _activeFiltersCount {
    var count = 0;
    if (_selectedAnalysisStatus != null && _selectedAnalysisStatus != 'all') {
      count++;
    }
    if (_selectedColor != null && _selectedColor != 'all') {
      count++;
    }
    if (_selectedCoatPattern != null && _selectedCoatPattern != 'all') {
      count++;
    }
    if (_selectedNeighborhood != null && _selectedNeighborhood != 'all') {
      count++;
    }
    return count;
  }

  void _clearAdvancedFilters() {
    setState(() {
      _selectedAnalysisStatus = null;
      _selectedColor = null;
      _selectedCoatPattern = null;
      _selectedNeighborhood = null;
    });
  }

  String _analysisStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Status: Concluída';
      case 'pending':
        return 'Status: Pendente';
      case 'failed':
        return 'Status: Com falha';
      default:
        return 'Status: $status';
    }
  }

  void _openAdvancedFiltersModal(List<Cat> allDiscoveries) {
    final neighborhoods = <String>{};
    for (final cat in allDiscoveries) {
      final loc = cat.locationName;
      if (loc != null && loc.trim().isNotEmpty) {
        final parts = loc
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          neighborhoods.add(parts[1]);
        } else if (parts.isNotEmpty) {
          neighborhoods.add(parts.first);
        }
      }
    }
    final sortedNeighborhoods = neighborhoods.toList()..sort();

    final patterns = <String>{};
    for (final cat in allDiscoveries) {
      final analysis = widget.catStore.analysisFor(cat.id);
      if (analysis?.coatType != null && analysis!.coatType!.trim().isNotEmpty) {
        patterns.add(analysis.coatType!.trim());
      }
    }
    const basePatterns = [
      'Sólido',
      'Bicolor',
      'Tricolor',
      'Malhado (Tabby)',
      'Tartaruga (Tortie)',
      'Colorpoint',
    ];
    for (final p in basePatterns) {
      patterns.add(p);
    }
    final sortedPatterns = patterns.toList()..sort();

    final colors = <String>{};
    for (final cat in allDiscoveries) {
      final analysis = widget.catStore.analysisFor(cat.id);
      if (analysis?.primaryColor != null &&
          analysis!.primaryColor!.trim().isNotEmpty) {
        colors.add(analysis.primaryColor!.trim());
      }
      if (analysis?.colors != null) {
        for (final c in analysis!.colors) {
          if (c.name.trim().isNotEmpty) colors.add(c.name.trim());
        }
      }
    }
    const baseColors = [
      'Preto',
      'Branco',
      'Laranja',
      'Cinza',
      'Marrom',
      'Creme',
    ];
    for (final c in baseColors) {
      colors.add(c);
    }
    final sortedColors = colors.toList()..sort();

    String? tempStatus = _selectedAnalysisStatus;
    String? tempPattern = _selectedCoatPattern;
    String? tempColor = _selectedColor;
    String? tempNeigh = _selectedNeighborhood;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Filtros avançados',
                        style: GoogleFonts.fredoka(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatus = null;
                            tempPattern = null;
                            tempColor = null;
                            tempNeigh = null;
                          });
                        },
                        child: Text(
                          'Limpar',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          size: 20,
                          color: AppColors.textMedium,
                        ),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterSectionTitle('Status da análise'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildModalFilterChip(
                                label: 'Todas',
                                isSelected:
                                    tempStatus == null || tempStatus == 'all',
                                onTap: () =>
                                    setModalState(() => tempStatus = null),
                              ),
                              _buildModalFilterChip(
                                label: 'Concluídas',
                                isSelected: tempStatus == 'completed',
                                onTap: () => setModalState(
                                  () => tempStatus = 'completed',
                                ),
                              ),
                              _buildModalFilterChip(
                                label: 'Pendentes',
                                isSelected: tempStatus == 'pending',
                                onTap: () =>
                                    setModalState(() => tempStatus = 'pending'),
                              ),
                              _buildModalFilterChip(
                                label: 'Com falha',
                                isSelected: tempStatus == 'failed',
                                onTap: () =>
                                    setModalState(() => tempStatus = 'failed'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildFilterSectionTitle('Padrão da pelagem'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildModalFilterChip(
                                label: 'Todos',
                                isSelected:
                                    tempPattern == null || tempPattern == 'all',
                                onTap: () =>
                                    setModalState(() => tempPattern = null),
                              ),
                              ...sortedPatterns.map(
                                (p) => _buildModalFilterChip(
                                  label: p,
                                  isSelected: tempPattern == p,
                                  onTap: () => setModalState(
                                    () => tempPattern = tempPattern == p
                                        ? null
                                        : p,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildFilterSectionTitle('Cor predominante'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildModalFilterChip(
                                label: 'Todas',
                                isSelected:
                                    tempColor == null || tempColor == 'all',
                                onTap: () =>
                                    setModalState(() => tempColor = null),
                              ),
                              ...sortedColors.map(
                                (c) => _buildModalFilterChip(
                                  label: c,
                                  isSelected: tempColor == c,
                                  onTap: () => setModalState(
                                    () => tempColor = tempColor == c ? null : c,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildFilterSectionTitle('Bairro / Região'),
                          if (sortedNeighborhoods.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Nenhum bairro registrado ainda na sua coleção.',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textLight,
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildModalFilterChip(
                                  label: 'Todos',
                                  isSelected:
                                      tempNeigh == null || tempNeigh == 'all',
                                  onTap: () =>
                                      setModalState(() => tempNeigh = null),
                                ),
                                ...sortedNeighborhoods.map(
                                  (n) => _buildModalFilterChip(
                                    label: n,
                                    isSelected: tempNeigh == n,
                                    onTap: () => setModalState(
                                      () =>
                                          tempNeigh = tempNeigh == n ? null : n,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedAnalysisStatus = tempStatus;
                        _selectedCoatPattern = tempPattern;
                        _selectedColor = tempColor;
                        _selectedNeighborhood = tempNeigh;
                      });
                      Navigator.pop(modalContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Aplicar filtros',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildModalFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterActionChip({
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    final hasActive = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasActive ? AppColors.primaryLight : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasActive ? AppColors.primary : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.slidersHorizontal,
              size: 14,
              color: hasActive ? AppColors.primary : AppColors.textMedium,
            ),
            const SizedBox(width: 6),
            Text(
              hasActive ? '$label ($count)' : label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: hasActive ? FontWeight.w800 : FontWeight.w700,
                color: hasActive ? AppColors.primary : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBadge({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              LucideIcons.x,
              size: 13,
              color: AppColors.primary,
            ),
          ),
        ],
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
    this.analysis,
    required this.isFavorite,
    required this.formattedDate,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final Cat cat;
  final CatAnalysis? analysis;
  final bool isFavorite;
  final String formattedDate;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  State<_CollectionCatCard> createState() => _CollectionCatCardState();
}

class _CollectionCatCardState extends State<_CollectionCatCard>
    with SingleTickerProviderStateMixin {
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
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
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
    final rawLocation = widget.cat.locationName?.trim();
    final locationText = rawLocation != null && rawLocation.isNotEmpty
        ? (rawLocation.contains(',')
              ? rawLocation.replaceFirst(',', ',\n')
              : rawLocation)
        : 'Localização\nnão informada';

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
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
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
                  if (widget.cat.status == 'failed' ||
                      widget.analysis?.status == AnalysisStatus.failed)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.alertTriangle,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Falha',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (widget.cat.status == 'analyzing' ||
                      widget.analysis?.status == AnalysisStatus.analyzing)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Análise...',
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

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Text(
                          catCode,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 6),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
