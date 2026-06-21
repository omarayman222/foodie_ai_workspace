import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Data model ─────────────────────────────────────────────────────────────
class _Recipe {
  final String name;
  final String cuisine;
  final List<String> categories;
  final int cookMinutes;
  final String emoji;

  const _Recipe({
    required this.name,
    required this.cuisine,
    required this.categories,
    required this.cookMinutes,
    required this.emoji,
  });

  String get cookLabel {
    if (cookMinutes < 60) return '$cookMinutes min';
    final h = cookMinutes ~/ 60;
    final m = cookMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ── Sample recipes ─────────────────────────────────────────────────────────
const _kRecipes = [
  _Recipe(name: 'Koshari', cuisine: 'Egyptian', categories: ['Vegetarian', 'Comfort Food', 'Sour'], cookMinutes: 45, emoji: '🍲'),
  _Recipe(name: 'Feteer Meshaltet', cuisine: 'Egyptian', categories: ['Sweet', 'Comfort Food'], cookMinutes: 60, emoji: '🥐'),
  _Recipe(name: 'Ful Medames', cuisine: 'Egyptian', categories: ['Vegetarian', 'Healthy'], cookMinutes: 30, emoji: '🫘'),
  _Recipe(name: 'Margherita Pizza', cuisine: 'Italian', categories: ['Vegetarian', 'Comfort Food'], cookMinutes: 30, emoji: '🍕'),
  _Recipe(name: 'Pasta Carbonara', cuisine: 'Italian', categories: ['Comfort Food', 'Quick Cook'], cookMinutes: 25, emoji: '🍝'),
  _Recipe(name: 'Tiramisu', cuisine: 'Italian', categories: ['Sweet'], cookMinutes: 20, emoji: '🍰'),
  _Recipe(name: 'Tacos al Pastor', cuisine: 'Mexican', categories: ['Spicy'], cookMinutes: 25, emoji: '🌮'),
  _Recipe(name: 'Guacamole', cuisine: 'Mexican', categories: ['Vegetarian', 'Healthy', 'Quick Cook', 'Side Item'], cookMinutes: 10, emoji: '🥑'),
  _Recipe(name: 'Enchiladas Verdes', cuisine: 'Mexican', categories: ['Spicy', 'Comfort Food'], cookMinutes: 40, emoji: '🫔'),
  _Recipe(name: 'Sushi Roll', cuisine: 'Japanese', categories: ['Healthy', 'Quick Cook'], cookMinutes: 20, emoji: '🍣'),
  _Recipe(name: 'Ramen', cuisine: 'Japanese', categories: ['Comfort Food', 'Spicy'], cookMinutes: 40, emoji: '🍜'),
  _Recipe(name: 'Butter Chicken', cuisine: 'Indian', categories: ['Spicy', 'Comfort Food'], cookMinutes: 45, emoji: '🍛'),
  _Recipe(name: 'Dal Makhani', cuisine: 'Indian', categories: ['Vegetarian', 'Comfort Food'], cookMinutes: 60, emoji: '🫘'),
  _Recipe(name: 'Mango Lassi', cuisine: 'Indian', categories: ['Sweet', 'Quick Cook'], cookMinutes: 5, emoji: '🥭'),
  _Recipe(name: 'BBQ Burger', cuisine: 'American', categories: ['Comfort Food', 'Quick Cook'], cookMinutes: 20, emoji: '🍔'),
  _Recipe(name: 'Caesar Salad', cuisine: 'American', categories: ['Healthy', 'Quick Cook'], cookMinutes: 15, emoji: '🥗'),
  _Recipe(name: 'Mac and Cheese', cuisine: 'American', categories: ['Comfort Food'], cookMinutes: 30, emoji: '🧀'),
  _Recipe(name: 'Greek Salad', cuisine: 'Mediterranean', categories: ['Vegetarian', 'Healthy', 'Quick Cook', 'Side Item'], cookMinutes: 10, emoji: '🥗'),
  _Recipe(name: 'Hummus & Pita', cuisine: 'Mediterranean', categories: ['Vegetarian', 'Healthy', 'Side Item'], cookMinutes: 10, emoji: '🫓'),
  _Recipe(name: 'Kung Pao Chicken', cuisine: 'Chinese', categories: ['Spicy', 'Quick Cook'], cookMinutes: 25, emoji: '🥡'),
  _Recipe(name: 'Vegetable Spring Rolls', cuisine: 'Chinese', categories: ['Vegetarian', 'Side Item', 'Quick Cook'], cookMinutes: 20, emoji: '🥟'),
  _Recipe(name: 'Dim Sum', cuisine: 'Chinese', categories: ['Side Item'], cookMinutes: 35, emoji: '🥟'),
  _Recipe(name: 'Croissant', cuisine: 'French', categories: ['Sweet'], cookMinutes: 90, emoji: '🥐'),
  _Recipe(name: 'French Onion Soup', cuisine: 'French', categories: ['Comfort Food', 'Sour'], cookMinutes: 55, emoji: '🍲'),
  _Recipe(name: 'Pad Thai', cuisine: 'Thai', categories: ['Spicy', 'Quick Cook'], cookMinutes: 20, emoji: '🍝'),
  _Recipe(name: 'Mango Sticky Rice', cuisine: 'Thai', categories: ['Sweet'], cookMinutes: 30, emoji: '🍚'),
  _Recipe(name: 'Tom Yum Soup', cuisine: 'Thai', categories: ['Spicy', 'Sour', 'Healthy'], cookMinutes: 25, emoji: '🍜'),
];

// ── Color maps ──────────────────────────────────────────────────────────────
const _kCuisineColors = {
  'Egyptian':      Color(0xFFC41E3A),
  'Italian':       Color(0xFF009246),
  'Mexican':       Color(0xFF006847),
  'Japanese':      Color(0xFFBC002D),
  'Indian':        Color(0xFFFF7B00),
  'American':      Color(0xFF3C3B6E),
  'Mediterranean': Color(0xFF0F72C5),
  'Chinese':       Color(0xFFDE2910),
  'French':        Color(0xFF0055A4),
  'Thai':          Color(0xFF2D882D),
};

const _kCuisineEmoji = {
  'Egyptian': '🇪🇬', 'Italian': '🇮🇹', 'Mexican': '🇲🇽',
  'Japanese': '🇯🇵', 'Indian': '🇮🇳', 'American': '🇺🇸',
  'Mediterranean': '🌊', 'Chinese': '🇨🇳', 'French': '🇫🇷', 'Thai': '🇹🇭',
};

const _kCategoryColors = {
  'Healthy':      Color(0xFF3D9A40),
  'Sweet':        Color(0xFFD44D8C),
  'Sour':         Color(0xFFBBA000),
  'Spicy':        Color(0xFFD4421E),
  'Side Item':    Color(0xFF8D6E63),
  'Quick Cook':   Color(0xFFE07B00),
  'Comfort Food': Color(0xFFB85C00),
  'Vegetarian':   Color(0xFF2E7D32),
};

const _kCategoryEmoji = {
  'Healthy': '🥗', 'Sweet': '🍰', 'Sour': '🍋', 'Spicy': '🌶️',
  'Side Item': '🍞', 'Quick Cook': '⚡', 'Comfort Food': '🍲', 'Vegetarian': '🥦',
};

Color _cuisineColor(String c) => _kCuisineColors[c] ?? const Color(0xFF666666);
Color _categoryColor(String c) => _kCategoryColors[c] ?? const Color(0xFF888888);

// ── Screen ─────────────────────────────────────────────────────────────────
class RecipeFilterScreen extends StatefulWidget {
  const RecipeFilterScreen({super.key});

  @override
  State<RecipeFilterScreen> createState() => _RecipeFilterScreenState();
}

class _RecipeFilterScreenState extends State<RecipeFilterScreen> {
  final Set<String> _cuisines    = {};
  final Set<String> _categories  = {};

  static const _kAllCuisines   = ['Egyptian','Italian','Mexican','Japanese','Indian','American','Mediterranean','Chinese','French','Thai'];
  static const _kAllCategories = ['Healthy','Sweet','Sour','Spicy','Side Item','Quick Cook','Comfort Food','Vegetarian'];

  // Cuisine: OR within group. Category: AND within group. Both groups: AND between.
  List<_Recipe> get _results {
    return _kRecipes.where((r) {
      if (_cuisines.isNotEmpty && !_cuisines.contains(r.cuisine)) return false;
      for (final cat in _categories) {
        if (!r.categories.contains(cat)) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasFilters => _cuisines.isNotEmpty || _categories.isNotEmpty;

  void _toggleCuisine(String c) => setState(() => _cuisines.contains(c) ? _cuisines.remove(c) : _cuisines.add(c));
  void _toggleCategory(String c) => setState(() => _categories.contains(c) ? _categories.remove(c) : _categories.add(c));
  void _clearAll() => setState(() { _cuisines.clear(); _categories.clear(); });

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3F0),
      body: Column(
        children: [
          _TopBar(
            count: results.length,
            total: _kRecipes.length,
            hasFilters: _hasFilters,
            onClear: _clearAll,
          ),
          _FilterPanel(
            allCuisines:    _kAllCuisines,
            allCategories:  _kAllCategories,
            selectedCuisines:   _cuisines,
            selectedCategories: _categories,
            onCuisine:  _toggleCuisine,
            onCategory: _toggleCategory,
          ),
          Expanded(
            child: results.isEmpty
                ? _EmptyState(hasFilters: _hasFilters)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: results.length,
                    itemBuilder: (_, i) => _RecipeCard(recipe: results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int count;
  final int total;
  final bool hasFilters;
  final VoidCallback onClear;

  const _TopBar({required this.count, required this.total, required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filter Recipes',
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1E1208))),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        key: ValueKey(count),
                        hasFilters ? '$count of $total match' : '$total recipes',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF9A8E84)),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: hasFilters ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: TextButton.icon(
                  onPressed: hasFilters ? onClear : null,
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: Text('Clear all', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD4622A),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFD4622A)),
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

// ── Filter panel ────────────────────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  final List<String> allCuisines;
  final List<String> allCategories;
  final Set<String> selectedCuisines;
  final Set<String> selectedCategories;
  final void Function(String) onCuisine;
  final void Function(String) onCategory;

  const _FilterPanel({
    required this.allCuisines,
    required this.allCategories,
    required this.selectedCuisines,
    required this.selectedCategories,
    required this.onCuisine,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFEDE0D0)),
          // Cuisine row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(children: [
              const Icon(Icons.public_rounded, size: 14, color: Color(0xFF9A8E84)),
              const SizedBox(width: 6),
              Text('Cuisine', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF9A8E84), letterSpacing: 0.5)),
            ]),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              scrollDirection: Axis.horizontal,
              children: allCuisines.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: c,
                  emoji: _kCuisineEmoji[c] ?? '',
                  selected: selectedCuisines.contains(c),
                  color: _cuisineColor(c),
                  onTap: () => onCuisine(c),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Category row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: Row(children: [
              const Icon(Icons.label_outline_rounded, size: 14, color: Color(0xFF9A8E84)),
              const SizedBox(width: 6),
              Text('Category', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF9A8E84), letterSpacing: 0.5)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allCategories.map((c) => _Chip(
                label: c,
                emoji: _kCategoryEmoji[c] ?? '',
                selected: selectedCategories.contains(c),
                color: _categoryColor(c),
                onTap: () => onCategory(c),
              )).toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDE0D0)),
        ],
      ),
    );
  }
}

// ── Single filter chip ──────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : const Color(0xFFDDD5CC), width: 1.2),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF4A3F35),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded, size: 12, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Recipe card ─────────────────────────────────────────────────────────────
class _RecipeCard extends StatelessWidget {
  final _Recipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cColor = _cuisineColor(recipe.cuisine);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left emoji panel
          Container(
            width: 74,
            height: 90,
            decoration: BoxDecoration(
              color: cColor.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            ),
            child: Center(
              child: Text(recipe.emoji, style: const TextStyle(fontSize: 34)),
            ),
          ),
          // Right content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.name,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E1208), height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _Tag(recipe.cuisine, cColor, filled: true),
                      ...recipe.categories.map((c) => _Tag(c, _categoryColor(c))),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(children: [
                    Icon(Icons.timer_outlined, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(
                      recipe.cookLabel,
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag pill ────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _Tag(this.label, this.color, {this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFD4622A).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Text('🍽️', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
            Text(
              'No recipes found',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1E1208)),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'No recipes match all your selected filters.\nTry removing some to see more results.'
                  : 'No recipes available.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF9A8E84), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
