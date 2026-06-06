import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _api = ApiService();
  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;

  // Curated fallback food images for when a recipe has no image
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await _api.getRecommendations();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      final list = data['recipes'] ?? data['top_recipes'] ?? [];
      setState(() {
        _recipes = (list as List).map((r) => Recipe.fromJson(r)).toList();
        _loading = false;
      });
    } else {
      setState(() { _error = result['message']; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      body: CustomScrollView(
        slivers: [
          // --- SLIVER APP BAR with food image ---
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFFFF6B00),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'AI Recommendations',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=800&q=80',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFFFF6B00)),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x44000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _load,
              ),
            ],
          ),

          // --- BODY ---
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFF6B00)),
                    SizedBox(height: 16),
                    Text('Finding recipes for you...'),
                  ],
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(child: _ErrorView(message: _error!, onRetry: _load))
          else if (_recipes.isEmpty)
            SliverFillRemaining(child: _EmptyView())
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${_recipes.length} recipes found',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFFF6B00)),
                          const SizedBox(width: 4),
                          Text(
                            'AI Matched',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFFFF6B00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _RecipeCard(
                    recipe: _recipes[i],
                    fallbackImage: _foodImages[i % _foodImages.length],
                    index: i,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: _recipes[i])),
                    ),
                  ),
                  childCount: _recipes.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final String fallbackImage;
  final int index;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.fallbackImage,
    required this.index,
    required this.onTap,
  });

  static const _tagColors = [
    Color(0xFFFF6B00), Color(0xFF11998e), Color(0xFF4776E6),
    Color(0xFFDA22FF), Color(0xFF0099F7),
  ];

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe.imageUrl.isNotEmpty ? recipe.imageUrl : fallbackImage;
    final tagColor = _tagColors[index % _tagColors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // --- IMAGE SECTION with overlay ---
              Stack(
                children: [
                  Image.network(
                    imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.network(
                      fallbackImage,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                        child: const Center(child: Icon(Icons.restaurant_rounded, size: 60, color: Color(0xFFFF6B00))),
                      ),
                    ),
                  ),
                  // Bottom gradient for text legibility
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xEE000000)],
                        ),
                      ),
                    ),
                  ),
                  // Index badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#${index + 1} Pick',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Title on image
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Text(
                      recipe.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // --- INFO SECTION ---
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (recipe.prepTime.isNotEmpty) ...[
                      _StatChip(
                        icon: Icons.soup_kitchen_outlined,
                        label: 'Prep ${recipe.prepTime}',
                        color: const Color(0xFF4776E6),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (recipe.totalTime.isNotEmpty) ...[
                      _StatChip(
                        icon: Icons.timer_outlined,
                        label: recipe.totalTime,
                        color: const Color(0xFF11998e),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (recipe.servings.isNotEmpty)
                      _StatChip(
                        icon: Icons.people_outline,
                        label: recipe.servings,
                        color: const Color(0xFFFF6B00),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tagColor, tagColor.withValues(alpha: 0.7)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Cook Now',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops!',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Try Again', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400&q=80',
            height: 160,
            width: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.kitchen_outlined, size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            'Your pantry is empty!',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Add ingredients to your pantry and get personalized AI recipe recommendations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
