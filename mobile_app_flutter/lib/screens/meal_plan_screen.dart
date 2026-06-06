import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final _api = ApiService();
  List<_DayPlan> _plan = [];
  bool _loading = true;
  String? _error;

  static const _dayColors = [
    Color(0xFFE04A18), Color(0xFF28A860), Color(0xFF2878D0),
    Color(0xFFD07820), Color(0xFF8040C0), Color(0xFF188090),
    Color(0xFFC84060),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await _api.getMealPlan();
    if (!mounted) return;
    if (result['success'] == true) {
      final planData = result['data']['plan'] as List? ?? [];
      setState(() {
        _plan = planData.map((d) => _DayPlan(
          day:    d['day'] ?? '',
          lunch:  d['lunch']  != null ? Recipe.fromJson(d['lunch'])  : null,
          dinner: d['dinner'] != null ? Recipe.fromJson(d['dinner']) : null,
        )).toList();
        _loading = false;
      });
    } else {
      setState(() { _error = result['message']; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            flexibleSpace: FlexibleSpaceBar(
              title: Text('7-Day Meal Plan',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
              background: Stack(fit: StackFit.expand, children: [
                Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF2A3A6E), Color(0xFF1A2E4E)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                )),
                const Positioned(top: 20, right: 20,
                    child: Text('📅', style: TextStyle(fontSize: 60, color: Colors.white24))),
              ]),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
            ],
          ),

          if (_loading)
            SliverFillRemaining(child: _SkeletonPlan())
          else if (_error != null)
            SliverFillRemaining(child: _ErrorView(message: _error!, onRetry: _load))
          else if (_plan.isEmpty)
            SliverFillRemaining(child: _EmptyPantryState())
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [cs.primary.withValues(alpha: 0.12), cs.primary.withValues(alpha: 0.05)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.auto_awesome_rounded, color: cs.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'AI generated this plan based on your pantry and dietary preferences.',
                      style: GoogleFonts.poppins(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _DayCard(
                  plan:  _plan[i],
                  color: _dayColors[i % _dayColors.length],
                  onTapRecipe: (r) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r))),
                ),
                childCount: _plan.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }
}

class _DayPlan {
  final String  day;
  final Recipe? lunch;
  final Recipe? dinner;
  const _DayPlan({required this.day, this.lunch, this.dinner});
}

// ── Day card ─────────────────────────────────────────────────────────────────
class _DayCard extends StatelessWidget {
  final _DayPlan plan;
  final Color color;
  final void Function(Recipe) onTapRecipe;
  const _DayCard({required this.plan, required this.color, required this.onTapRecipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Day header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)], begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Text(plan.day, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            if (plan.lunch != null || plan.dinner != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('2 meals', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11)),
              ),
          ]),
        ),
        // Meals
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _MealRow(label: '🌤 Lunch',  recipe: plan.lunch,  color: color, onTap: plan.lunch  != null ? () => onTapRecipe(plan.lunch!)  : null),
            const SizedBox(height: 10),
            _MealRow(label: '🌙 Dinner', recipe: plan.dinner, color: color, onTap: plan.dinner != null ? () => onTapRecipe(plan.dinner!) : null),
          ]),
        ),
      ]),
    );
  }
}

class _MealRow extends StatelessWidget {
  final String label;
  final Recipe? recipe;
  final Color color;
  final VoidCallback? onTap;
  const _MealRow({required this.label, required this.recipe, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (recipe == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurfaceVariant)),
          const Spacer(),
          Text('No recipe available', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400])),
        ]),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
          ]),
          const SizedBox(width: 10),
          Expanded(child: Text(recipe!.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          if (recipe!.totalTime.isNotEmpty)
            Text(recipe!.totalTime, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
        ]),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class _SkeletonPlan extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(20),
    itemCount: 7,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 130,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    ),
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
      const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')),
    ]),
  ));
}

class _EmptyPantryState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('📅', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 20),
      Text('Pantry is empty', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Add ingredients to your pantry so the AI can build a meal plan for you.',
          textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
    ]),
  ));
}
