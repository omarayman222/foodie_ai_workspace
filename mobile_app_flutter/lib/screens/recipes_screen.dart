import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<Recipe> _aiRecipes     = [];
  List<Recipe> _searchResults = [];
  bool _loading   = true;
  bool _searching = false;
  String? _error;
  bool _showSearch = false;

  late TabController _tabCtrl;

  // Cuisine — single select
  static const _cuisines = ['Any', 'Egyptian', 'Italian', 'Mexican', 'Japanese', 'Indian', 'American', 'Mediterranean', 'Chinese', 'French', 'Thai'];
  String _selectedCuisine = 'Any';

  // Category — multi select
  static const _categories = ['Healthy', 'Sweet', 'Sour', 'Spicy', 'Side Item', 'Quick Cook', 'Comfort Food', 'Vegetarian'];
  final Set<String> _selectedCategories = {};

  static const _categoryColors = {
    'Healthy':      Color(0xFF3D9A40),
    'Sweet':        Color(0xFFD44D8C),
    'Sour':         Color(0xFFBBA000),
    'Spicy':        Color(0xFFD4421E),
    'Side Item':    Color(0xFF8D6E63),
    'Quick Cook':   Color(0xFFE07B00),
    'Comfort Food': Color(0xFFB85C00),
    'Vegetarian':   Color(0xFF2E7D32),
  };

  static const _categoryEmoji = {
    'Healthy': '🥗', 'Sweet': '🍰', 'Sour': '🍋', 'Spicy': '🌶️',
    'Side Item': '🍞', 'Quick Cook': '⚡', 'Comfort Food': '🍲', 'Vegetarian': '🥦',
  };

  static const _foodImages = [
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80',
    'https://images.unsplash.com/photo-1555949258-eb67b1ef0ceb?w=600&q=80',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&q=80',
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80',
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80',
    'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=600&q=80',
    'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=600&q=80',
  ];

  bool get _noFilters =>
      _searchCtrl.text.trim().isEmpty &&
      _selectedCuisine == 'Any' &&
      _selectedCategories.isEmpty;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await _api.getRecommendations();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      final list = data['recipes'] ?? data['top_recipes'] ?? [];
      setState(() {
        _aiRecipes = (list as List).map((r) => Recipe.fromJson(r)).toList();
        _loading   = false;
      });
    } else {
      setState(() { _error = result['message']; _loading = false; });
    }
  }

  Future<void> _search(String q) async {
    final cuisine = _selectedCuisine == 'Any' ? '' : _selectedCuisine;
    // Combine text query + selected category names as keywords
    final catKeywords = _selectedCategories.join(' ');
    final combined = [q.trim(), catKeywords].where((s) => s.isNotEmpty).join(' ');

    if (combined.isEmpty && cuisine.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final result = await _api.searchRecipes(q: combined, cuisine: cuisine);
    if (!mounted) return;
    if (result['success'] == true) {
      final list = result['data']['recipes'] as List? ?? [];
      setState(() { _searchResults = list.map((r) => Recipe.fromJson(r)).toList(); _searching = false; });
    } else {
      setState(() => _searching = false);
    }
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        _selectedCategories.add(cat);
      }
    });
    _search(_searchCtrl.text);
  }

  void _clearFilters() {
    setState(() {
      _selectedCuisine = 'Any';
      _selectedCategories.clear();
      _searchCtrl.clear();
      _searchResults.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: _showSearch ? 140 : 180,
            pinned: true,
            backgroundColor: const Color(0xFFE04A18),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchCtrl.clear();
                    _searchResults.clear();
                  }
                }),
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
              title: _showSearch
                  ? TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: 'Search recipes…',
                        hintStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
                        border: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _search,
                    )
                  : Text('AI Recommendations',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
              background: _showSearch
                  ? Container(color: const Color(0xFFE04A18))
                  : Stack(fit: StackFit.expand, children: [
                      Image.network(
                        'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=800&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE04A18)),
                      ),
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0x44000000), Color(0xCC000000)],
                      ))),
                    ]),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [Tab(text: 'AI Picks'), Tab(text: 'Search')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [

            // ── Tab 1: AI Picks ──────────────────────────────────
            _loading
                ? _SkeletonList()
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _aiRecipes.isEmpty
                        ? _EmptyView()
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: cs.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                              itemCount: _aiRecipes.length,
                              itemBuilder: (ctx, i) {
                                final recipe = _aiRecipes[i];
                                final badgeColor = [
                                  const Color(0xFFFF6B00), const Color(0xFF11998e),
                                  const Color(0xFF4776E6), const Color(0xFFDA22FF),
                                  const Color(0xFF0099F7),
                                ][i % 5];
                                return _SwipeableCard(
                                  key: ValueKey(recipe.id),
                                  recipe: recipe,
                                  onFavourite: () async {
                                    await _api.addFavourite({
                                      'recipeId': recipe.id, 'recipeName': recipe.title,
                                      'recipeImage': recipe.imageUrl, 'prepTime': recipe.prepTime,
                                      'totalTime': recipe.totalTime, 'servings': recipe.servings,
                                      'cuisine': recipe.cuisine,
                                    });
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                      content: Row(children: [
                                        const Text('❤️  '),
                                        Expanded(child: Text('Saved "${recipe.title}"', overflow: TextOverflow.ellipsis)),
                                      ]),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ));
                                  },
                                  onSkip: () {
                                    setState(() => _aiRecipes.removeAt(i));
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                      content: Text('Skipped "${recipe.title}"'),
                                      backgroundColor: Colors.grey[700],
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                      action: SnackBarAction(
                                        label: 'Undo', textColor: Colors.white,
                                        onPressed: () => setState(() => _aiRecipes.insert(i, recipe)),
                                      ),
                                    ));
                                  },
                                  child: _RecipeCard(
                                    recipe: recipe,
                                    fallbackImage: _foodImages[i % _foodImages.length],
                                    badge: '#${i + 1} Pick',
                                    badgeColor: badgeColor,
                                    onTap: () => Navigator.push(ctx, MaterialPageRoute(
                                        builder: (_) => RecipeDetailScreen(recipe: recipe))),
                                  ),
                                );
                              },
                            ),
                          ),

            // ── Tab 2: Search ─────────────────────────────────────
            Column(children: [

              // ── Cuisine chips ──────────────────────────────
              SizedBox(
                height: 44,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  scrollDirection: Axis.horizontal,
                  children: _cuisines.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c, style: GoogleFonts.poppins(fontSize: 12)),
                      selected: _selectedCuisine == c,
                      onSelected: (_) {
                        setState(() => _selectedCuisine = c);
                        _search(_searchCtrl.text);
                      },
                      selectedColor: cs.primary.withValues(alpha: 0.15),
                      checkmarkColor: cs.primary,
                    ),
                  )).toList(),
                ),
              ),

              // ── Category chips ─────────────────────────────
              SizedBox(
                height: 44,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  scrollDirection: Axis.horizontal,
                  children: _categories.map((cat) {
                    final selected = _selectedCategories.contains(cat);
                    final color = _categoryColors[cat] ?? Colors.grey;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _toggleCategory(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? color : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? color : Colors.grey[300]!,
                              width: 1.2,
                            ),
                            boxShadow: selected
                                ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(0, 2))]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_categoryEmoji[cat] ?? '', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                cat,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                  color: selected ? Colors.white : Colors.grey[700],
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Active filters summary + clear ─────────────
              if (!_noFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Row(children: [
                    Icon(Icons.filter_list_rounded, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      [
                        if (_selectedCuisine != 'Any') _selectedCuisine,
                        ..._selectedCategories,
                      ].join(' · '),
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    )),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Text('Clear', style: GoogleFonts.poppins(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),

              // ── Results or recommendations ─────────────────
              Expanded(
                child: _noFilters
                    // No search text + no filters → show AI recommendations
                    ? _loading
                        ? _SkeletonList()
                        : _aiRecipes.isEmpty
                            ? _EmptyView()
                            : Column(children: [
                                Container(
                                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                                  alignment: Alignment.centerLeft,
                                  child: Row(children: [
                                    const Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFFFF9800)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI Recommendations — search or filter to explore',
                                      style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[600]),
                                    ),
                                  ]),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                    itemCount: _aiRecipes.length,
                                    itemBuilder: (ctx, i) => _RecipeCard(
                                      recipe: _aiRecipes[i],
                                      fallbackImage: _foodImages[i % _foodImages.length],
                                      badge: 'AI Pick',
                                      badgeColor: const Color(0xFFFF6B00),
                                      onTap: () => Navigator.push(ctx, MaterialPageRoute(
                                          builder: (_) => RecipeDetailScreen(recipe: _aiRecipes[i]))),
                                    ),
                                  ),
                                ),
                              ])
                    // Search / filter active → show results
                    : _searching
                        ? _SkeletonList()
                        : _searchResults.isEmpty
                            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text('No recipes found',
                                    style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Try different keywords or fewer filters',
                                    style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                              ]))
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                itemCount: _searchResults.length,
                                itemBuilder: (ctx, i) => _RecipeCard(
                                  recipe: _searchResults[i],
                                  fallbackImage: _foodImages[i % _foodImages.length],
                                  onTap: () => Navigator.push(ctx, MaterialPageRoute(
                                      builder: (_) => RecipeDetailScreen(recipe: _searchResults[i]))),
                                ),
                              ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loader ────────────────────────────────────────────────────────
class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(20),
    itemCount: 4,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        height: 260,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      ),
    ),
  );
}

// ── Swipeable wrapper ──────────────────────────────────────────────────────
class _SwipeableCard extends StatelessWidget {
  final Recipe recipe;
  final Widget child;
  final VoidCallback onFavourite;
  final VoidCallback onSkip;

  const _SwipeableCard({
    super.key,
    required this.recipe,
    required this.child,
    required this.onFavourite,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) { onFavourite(); return false; }
        onSkip(); return true;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(color: Colors.green[400], borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 4),
          Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 4),
          Text('Skip', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
      child: child,
    );
  }
}

// ── Recipe card ────────────────────────────────────────────────────────────
class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final String fallbackImage;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.fallbackImage,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe.imageUrl.isNotEmpty ? recipe.imageUrl : fallbackImage;
    final color    = badgeColor ?? const Color(0xFFFF6B00);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(children: [
            Stack(children: [
              Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.network(fallbackImage, height: 200, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 200, color: color.withValues(alpha: 0.2),
                          child: Center(child: Icon(Icons.restaurant_rounded, size: 60, color: color))))),
              Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 100,
                  decoration: const BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xEE000000)])))),
              if (badge != null) Positioned(top: 12, left: 12, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: Text(badge!, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
              Positioned(bottom: 12, left: 14, right: 14, child: Text(recipe.title,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                if (recipe.prepTime.isNotEmpty) ...[_StatChip(Icons.soup_kitchen_outlined, 'Prep ${recipe.prepTime}', const Color(0xFF4776E6)), const SizedBox(width: 8)],
                if (recipe.totalTime.isNotEmpty) ...[_StatChip(Icons.timer_outlined, recipe.totalTime, const Color(0xFF11998e)), const SizedBox(width: 8)],
                if (recipe.servings.isNotEmpty) _StatChip(Icons.people_outline, recipe.servings, const Color(0xFFFF6B00)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Cook Now', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent)),
      const SizedBox(height: 16),
      Text('Oops!', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded),
          label: Text('Try Again', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
    ]),
  ));
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.kitchen_outlined, size: 80, color: Colors.grey),
      const SizedBox(height: 20),
      Text('Your pantry is empty!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Add ingredients to your pantry to get AI recipe recommendations.',
          textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
    ]),
  ));
}
