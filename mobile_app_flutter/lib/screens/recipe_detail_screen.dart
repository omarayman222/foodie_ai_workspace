import 'package:flutter/material.dart';
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

  Future<void> _showRatingDialog() async {
    int selectedStars = 0;
    final feedbackController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rate this Recipe', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(i < selectedStars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber, size: 36),
              onPressed: () => setS(() => selectedStars = i + 1),
            )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: feedbackController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any feedback? (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: selectedStars == 0 ? null : () async {
              Navigator.pop(ctx);
              final result = await _api.rateRecipe(
                widget.recipe.id, selectedStars,
                feedbackText: feedbackController.text.trim(),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result['success'] == true ? 'Rating saved! Thanks for your feedback.' : result['message']),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(), SizedBox(width: 16),
          Text('Finding substitutes...'),
        ]),
      ),
    );

    final result = await _api.getSubstitutions(widget.recipe.id, ingredient);
    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final data = result['data'];
    final suggestions = data['suggestions'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, sc) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Substitutes for "$ingredient"', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                controller: sc,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final s = suggestions[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.swap_horiz_rounded, color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        Text(s['name'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        if (s['ratio'] != null) Text('(${s['ratio']})', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                      ]),
                      if (s['preparation_instructions'] != null) ...[
                        const SizedBox(height: 4),
                        Text(s['preparation_instructions'], style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
                      ],
                      if (s['culinary_impact'] != null) ...[
                        const SizedBox(height: 4),
                        Text(s['culinary_impact'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                      ],
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _generateShoppingList() async {
    final result = await _api.generateShoppingList(widget.recipe.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? 'Missing ingredients added to your shopping list!' : result['message']),
      backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: recipe.imageUrl.isNotEmpty
                  ? Image.network(recipe.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: theme.colorScheme.primary,
                        child: const Icon(Icons.restaurant_rounded, size: 80, color: Colors.white54)))
                  : Container(color: theme.colorScheme.primary,
                      child: const Icon(Icons.restaurant_rounded, size: 80, color: Colors.white54)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recipe.title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // Time + servings row
                Wrap(spacing: 16, children: [
                  if (recipe.prepTime.isNotEmpty) _InfoChip(Icons.timer_outlined, 'Prep: ${recipe.prepTime}'),
                  if (recipe.cookTime.isNotEmpty) _InfoChip(Icons.local_fire_department_outlined, 'Cook: ${recipe.cookTime}'),
                  if (recipe.totalTime.isNotEmpty) _InfoChip(Icons.schedule_rounded, recipe.totalTime),
                  if (recipe.servings.isNotEmpty) _InfoChip(Icons.people_outline, '${recipe.servings} servings'),
                ]),
                const SizedBox(height: 20),

                // Action buttons
                Row(children: [
                  Expanded(child: _ActionBtn(Icons.star_border_rounded, 'Rate', Colors.amber, _showRatingDialog)),
                  const SizedBox(width: 10),
                  Expanded(child: _ActionBtn(Icons.shopping_cart_outlined, 'Shopping List', Colors.teal, _generateShoppingList)),
                  const SizedBox(width: 10),
                  Expanded(child: _ActionBtn(Icons.chat_bubble_outline_rounded, 'Cook AI', theme.colorScheme.primary, () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SousChefScreen(recipeId: recipe.id, recipeTitle: recipe.title),
                    ));
                  })),
                ]),
                const SizedBox(height: 24),

                // Ingredients
                Text('Ingredients', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...recipe.ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(ing, style: GoogleFonts.poppins(fontSize: 14))),
                    IconButton(
                      icon: Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.grey[400]),
                      tooltip: 'Get substitutes',
                      onPressed: () => _showSubstitutionDialog(ing),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                )),
                const SizedBox(height: 24),

                // Instructions
                if (recipe.instructions.isNotEmpty) ...[
                  Text('Instructions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...recipe.instructions.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                        child: Center(child: Text('${e.key + 1}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: GoogleFonts.poppins(fontSize: 14, height: 1.5))),
                    ]),
                  )),
                ],

                // Nutrition
                if (recipe.nutrition.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Nutrition', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                    child: Text(recipe.nutrition, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
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
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
