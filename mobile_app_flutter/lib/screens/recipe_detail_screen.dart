import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'sous_chef_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _api = ApiService();
  bool _isFav = false;
  bool _favLoading = false;
  bool _cookMode = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _checkFav();
  }

  Future<void> _checkFav() async {
    if (widget.recipe.id.isEmpty) return;
    final fav = await _api.isFavourite(widget.recipe.id);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    if (_favLoading) return;
    setState(() { _favLoading = true; });
    final r = widget.recipe;
    if (_isFav) {
      await _api.removeFavourite(r.id);
    } else {
      await _api.addFavourite({
        'recipeId': r.id, 'recipeName': r.title, 'recipeImage': r.imageUrl,
        'prepTime': r.prepTime, 'totalTime': r.totalTime,
        'servings': r.servings, 'cuisine': r.cuisine,
      });
    }
    if (mounted) {
      setState(() { _isFav = !_isFav; _favLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isFav ? '❤️ Added to favourites' : 'Removed from favourites'),
        backgroundColor: _isFav ? Colors.red : Colors.grey[700],
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _showRatingDialog() async {
    int selectedStars = 0;
    final feedbackController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rate this Recipe', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                icon: Icon(i < selectedStars ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 36),
                onPressed: () => setS(() => selectedStars = i + 1),
              ))),
          const SizedBox(height: 12),
          TextField(controller: feedbackController, maxLines: 3,
              decoration: InputDecoration(hintText: 'Any feedback? (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: selectedStars == 0 ? null : () async {
              Navigator.pop(ctx);
              final result = await _api.rateRecipe(widget.recipe.id, selectedStars, feedbackText: feedbackController.text.trim());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result['success'] == true ? '⭐ Rating saved! Thanks.' : result['message']),
                backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
              ));
            },
            child: const Text('Submit'),
          ),
        ],
      )),
    );
  }

  Future<void> _showSubstitutionDialog(String ingredient) async {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Finding substitutes...')]),
        ));
    final result = await _api.getSubstitutions(widget.recipe.id, ingredient);
    if (!mounted) return;
    Navigator.pop(context);
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent));
      return;
    }
    final suggestions = result['data']['suggestions'] as List? ?? [];
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.6,
        builder: (_, sc) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Substitutes for "$ingredient"', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Expanded(child: ListView.separated(controller: sc, itemCount: suggestions.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final s = suggestions[i];
                return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.swap_horiz_rounded, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(s['name'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    if (s['ratio'] != null) ...[const SizedBox(width: 8), Text('(${s['ratio']})', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12))],
                  ]),
                  if (s['preparation_instructions'] != null) ...[const SizedBox(height: 4), Text(s['preparation_instructions'], style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]))],
                  if (s['culinary_impact'] != null) ...[const SizedBox(height: 4), Text(s['culinary_impact'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic))],
                ]));
              },
            )),
          ]),
        ),
      ),
    );
  }

  Future<void> _generateShoppingList() async {
    final result = await _api.generateShoppingList(widget.recipe.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? '🛒 Missing ingredients added to shopping list!' : result['message']),
      backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
    ));
  }

  // ── Cook Mode ──────────────────────────────────────────────
  void _enterCookMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    setState(() { _cookMode = true; _currentStep = 0; });
  }

  void _exitCookMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() => _cookMode = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cookMode) {
      return _CookModeView(
        recipe: widget.recipe,
        currentStep: _currentStep,
        onStepChanged: (s) => setState(() => _currentStep = s),
        onExit: _exitCookMode,
      );
    }

    final recipe = widget.recipe;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: cs.primary,
            actions: [
              // Favourite button
              _favLoading
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : IconButton(
                      icon: Icon(_isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isFav ? Colors.redAccent : Colors.white),
                      onPressed: _toggleFav,
                      tooltip: _isFav ? 'Remove from favourites' : 'Add to favourites',
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: recipe.imageUrl.isNotEmpty
                  ? Image.network(recipe.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: cs.primary,
                          child: const Icon(Icons.restaurant_rounded, size: 80, color: Colors.white54)))
                  : Container(color: cs.primary,
                      child: const Icon(Icons.restaurant_rounded, size: 80, color: Colors.white54)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recipe.title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                if (recipe.cuisine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(recipe.cuisine, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 16, children: [
                  if (recipe.prepTime.isNotEmpty) _InfoChip(Icons.timer_outlined, 'Prep: ${recipe.prepTime}'),
                  if (recipe.cookTime.isNotEmpty) _InfoChip(Icons.local_fire_department_outlined, 'Cook: ${recipe.cookTime}'),
                  if (recipe.totalTime.isNotEmpty) _InfoChip(Icons.schedule_rounded, recipe.totalTime),
                  if (recipe.servings.isNotEmpty) _InfoChip(Icons.people_outline, '${recipe.servings} servings'),
                  if (recipe.rating > 0) _InfoChip(Icons.star_rounded, '${recipe.rating.toStringAsFixed(1)} ★'),
                ]),
                const SizedBox(height: 20),

                // Action buttons
                Row(children: [
                  Expanded(child: _ActionBtn(Icons.play_circle_outline_rounded, 'Cook Mode', Colors.deepOrange, _enterCookMode)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(Icons.star_border_rounded, 'Rate', Colors.amber, _showRatingDialog)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(Icons.shopping_cart_outlined, 'Shop List', Colors.teal, _generateShoppingList)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(Icons.chat_bubble_outline_rounded, 'Ask AI', cs.primary, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SousChefScreen(recipeId: recipe.id, recipeTitle: recipe.title)));
                  })),
                ]),
                const SizedBox(height: 24),

                // Ingredients
                _SectionHeader('Ingredients', Icons.egg_outlined),
                const SizedBox(height: 12),
                ...recipe.ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(ing, style: GoogleFonts.poppins(fontSize: 14))),
                    IconButton(
                      icon: Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.grey[400]),
                      tooltip: 'Get substitutes', onPressed: () => _showSubstitutionDialog(ing),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                  ]),
                )),
                const SizedBox(height: 24),

                // Instructions
                if (recipe.instructions.isNotEmpty) ...[
                  _SectionHeader('Instructions', Icons.format_list_numbered_rounded),
                  const SizedBox(height: 12),
                  ...recipe.instructions.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.7)]), shape: BoxShape.circle),
                        child: Center(child: Text('${e.key + 1}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: GoogleFonts.poppins(fontSize: 14, height: 1.6))),
                    ]),
                  )),
                ],

                // Nutrition
                if (recipe.nutrition.isNotEmpty) ...[
                  _SectionHeader('Nutrition', Icons.monitor_heart_outlined),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                    child: Text(recipe.nutrition, style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurfaceVariant)),
                  ),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cook Mode ────────────────────────────────────────────────
class _CookModeView extends StatelessWidget {
  final Recipe recipe;
  final int currentStep;
  final void Function(int) onStepChanged;
  final VoidCallback onExit;
  const _CookModeView({required this.recipe, required this.currentStep, required this.onStepChanged, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final steps = recipe.instructions;
    if (steps.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('No instructions available', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onExit, child: const Text('Exit Cook Mode')),
        ])),
      );
    }

    final isFirst = currentStep == 0;
    final isLast  = currentStep == steps.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: onExit),
              Expanded(child: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
              Text('${currentStep + 1} / ${steps.length}',
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13)),
            ]),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / steps.length,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B2E)),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Step content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B2E), Color(0xFFFFAA44)]),
                      shape: BoxShape.circle,
                    ),
                    child: Text('${currentStep + 1}',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
                  ),
                  const SizedBox(height: 32),
                  Text(steps[currentStep],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, height: 1.7, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
          // Navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(children: [
              Expanded(
                child: AnimatedOpacity(
                  opacity: isFirst ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    onPressed: isFirst ? null : () => onStepChanged(currentStep - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLast ? onExit : () => onStepChanged(currentStep + 1),
                  icon: Icon(isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded),
                  label: Text(isLast ? 'Done!' : 'Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast ? Colors.green : const Color(0xFFFF6B2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
  ]);
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: Colors.grey[500]),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
