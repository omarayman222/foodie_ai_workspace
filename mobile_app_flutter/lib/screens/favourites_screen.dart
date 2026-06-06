import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  final _api = ApiService();
  List<Recipe> _recipes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.getFavourites();
    if (!mounted) return;
    if (result['success'] == true) {
      final list = result['data']['favourites'] as List? ?? [];
      setState(() {
        _recipes = list.map((f) => Recipe(
          id: f['recipeId'] ?? '',
          title: f['recipeName'] ?? '',
          imageUrl: f['recipeImage'] ?? '',
          ingredients: [],
          instructions: [],
          prepTime: f['prepTime'] ?? '',
          totalTime: f['totalTime'] ?? '',
          servings: f['servings'] ?? '',
          cuisine: f['cuisine'] ?? '',
        )).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _remove(Recipe r) async {
    await _api.removeFavourite(r.id);
    setState(() => _recipes.remove(r));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${r.title}" from favourites'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('My Favourites', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_recipes.length} saved',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: cs.primary,
        child: _loading
            ? _Skeleton()
            : _recipes.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recipes.length,
                    itemBuilder: (_, i) => _FavCard(
                      recipe: _recipes[i],
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: _recipes[i]))),
                      onRemove: () => _remove(_recipes[i]),
                    ),
                  ),
      ),
    );
  }
}

class _FavCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _FavCard({required this.recipe, required this.onTap, required this.onRemove});

  static const _fallbacks = [
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&q=80',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&q=80',
    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe.imageUrl.isNotEmpty
        ? recipe.imageUrl
        : _fallbacks[recipe.title.length % _fallbacks.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Image.network(imageUrl, width: 100, height: 90, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 100, height: 90,
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                    child: const Icon(Icons.restaurant_rounded, color: Color(0xFFFF6B00), size: 36),
                  )),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                  if (recipe.totalTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(recipe.totalTime, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                    ]),
                  ],
                  if (recipe.cuisine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(recipe.cuisine, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                  ],
                ]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
              onPressed: onRemove,
              tooltip: 'Remove from favourites',
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 90,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: const Icon(Icons.favorite_border_rounded, size: 56, color: Colors.redAccent),
        ),
        const SizedBox(height: 20),
        Text('No favourites yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Tap the ❤️ on any recipe to save it here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
      ]),
    );
  }
}
