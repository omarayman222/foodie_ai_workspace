import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';
import 'recipes_screen.dart';
import 'pantry_screen.dart';
import 'sous_chef_screen.dart';
import 'shopping_list_screen.dart';
import 'profile_screen.dart';
import 'favourites_screen.dart';
import 'meal_plan_screen.dart';
import 'recipe_detail_screen.dart';
import 'recipe_filter_screen.dart';

// ── Palette ────────────────────────────────────────────────────────────────
class _C {
  static const card    = Color(0xFFFFFFFF);
  static const border  = Color(0xFFEDE0D0);
  static const textPri = Color(0xFF1E1208);
  static const textSec = Color(0xFF7A6E62);

  static const hTop  = Color(0xFFD42A00);
  static const hMid  = Color(0xFFFF6B2E);
  static const hBot  = Color(0xFFFFB340);

  static const recipes = Color(0xFFE04A28);
  static const pantry  = Color(0xFF28A860);
  static const chef    = Color(0xFF2878D0);
  static const shop    = Color(0xFFD07820);
  static const profile = Color(0xFF8040C0);
}

// ── Floating orb painter ───────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  final double t; // 0..1 repeating
  _OrbPainter(this.t);

  static final _orbs = [
    _Orb(0.12, 0.22, 110, Color(0x28FF6B2E), 0.18, 0.05),
    _Orb(0.75, 0.55, 90,  Color(0x2228A860), 0.22, 0.12),
    _Orb(0.45, 0.80, 130, Color(0x222878D0), 0.14, 0.08),
    _Orb(0.85, 0.10, 80,  Color(0x30FF9A00), 0.26, 0.03),
    _Orb(0.30, 0.45, 100, Color(0x228040C0), 0.20, 0.16),
    _Orb(0.60, 0.25, 70,  Color(0x30E04A28), 0.16, 0.20),
    _Orb(0.10, 0.70, 120, Color(0x22FFB340), 0.24, 0.09),
    _Orb(0.90, 0.85, 95,  Color(0x2028A860), 0.18, 0.14),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final o in _orbs) {
      final phase = (t + o.phase) % 1.0;
      final dx = math.sin(phase * math.pi * 2) * 0.04 * size.width;
      final baseX = o.cx * size.width + dx;
      final baseY = o.cy * size.height - phase * size.height * o.speed;
      final y = ((baseY % size.height) + size.height) % size.height;

      final opacity = math.sin(phase * math.pi).clamp(0.2, 1.0);
      final paint = Paint()
        ..color = o.color.withValues(alpha: o.color.a * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(Offset(baseX, y), o.r, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

class _Orb {
  final double cx, cy, r, speed, phase;
  final Color color;
  const _Orb(this.cx, this.cy, this.r, this.color, this.speed, this.phase);
}

// ── Live animated background ───────────────────────────────────────────────
class _LiveBg extends StatefulWidget {
  final Widget child;
  const _LiveBg({required this.child});

  @override
  State<_LiveBg> createState() => _LiveBgState();
}

class _LiveBgState extends State<_LiveBg> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        // Background gradient shifts slightly over time
        final hue1 = 25.0 + math.sin(t * math.pi * 2) * 10;
        final hue2 = 330.0 + math.sin(t * math.pi * 2 + 1.2) * 15;
        final bg1 = HSLColor.fromAHSL(1, hue1, 1.0, 0.96).toColor();
        final bg2 = HSLColor.fromAHSL(1, hue1 + 10, 0.9, 0.94).toColor();
        final bg3 = HSLColor.fromAHSL(1, hue2, 0.6, 0.96).toColor();

        return Stack(
          children: [
            // Shifting gradient base
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [bg1, bg2, bg3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Floating orbs
            CustomPaint(
              painter: _OrbPainter(t),
              child: const SizedBox.expand(),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

// ── Home screen ────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  List<Recipe> _picks = [];
  bool _picksLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPicks();
  }

  Future<void> _loadPicks() async {
    setState(() => _picksLoading = true);
    final result = await _api.getRecommendations();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      final list = data['recipes'] ?? data['top_recipes'] ?? [];
      setState(() {
        _picks = (list as List).map((r) => Recipe.fromJson(r)).toList();
        _picksLoading = false;
      });
    } else {
      setState(() => _picksLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final features = [
      _Feature(Icons.restaurant_menu_rounded, '🍽️', 'Recipes',
          'Personalized meal ideas based on what\'s in your pantry.',
          _C.recipes, const RecipesScreen()),
      _Feature(Icons.kitchen_rounded, '🥦', 'Pantry',
          'Track ingredients so the AI can suggest perfect meals.',
          _C.pantry, const PantryScreen()),
      _Feature(Icons.chat_bubble_outline_rounded, '🤖', 'Sous Chef',
          'Ask anything — techniques, substitutions, cooking tips.',
          _C.chef, const SousChefScreen()),
      _Feature(Icons.shopping_cart_outlined, '🛒', 'Shopping List',
          'Build smart grocery lists straight from your recipes.',
          _C.shop, const ShoppingListScreen()),
      _Feature(Icons.manage_accounts_outlined, '👤', 'My Profile',
          'Set allergies, diets and dislikes for safer results.',
          _C.profile, const ProfileScreen()),
      _Feature(Icons.favorite_rounded, '❤️', 'Favourites',
          'All the recipes you\'ve saved — ready to cook anytime.',
          const Color(0xFFD04060), const FavouritesScreen()),
      _Feature(Icons.calendar_month_rounded, '📅', 'Meal Plan',
          'AI-generated 7-day plan based on your pantry.',
          const Color(0xFF2060B0), const MealPlanScreen()),
      _Feature(Icons.tune_rounded, '🔍', 'Filter Recipes',
          'Browse and filter recipes by cuisine, diet, and category.',
          const Color(0xFFD4622A), const RecipeFilterScreen()),
    ];

    return Scaffold(
      body: _LiveBg(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                  greeting: _greeting(),
                  onLogout: () => _logout(context)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                child: _StatsRow(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 10),
                child: _SectionLabel('Explore Features'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FeatureCard(feature: features[i]),
                  ),
                  childCount: features.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: _TipCard(),
              ),
            ),
            // ── Today's Picks ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
                child: Row(children: [
                  _SectionLabel("Today's Picks"),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RecipesScreen())),
                    child: Text('See all',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _C.hMid,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 230,
                child: _picksLoading
                    ? _PicksSkeleton()
                    : _picks.isEmpty
                        ? _PicksEmpty()
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                            itemCount: _picks.length,
                            itemBuilder: (ctx, i) => _PickCard(
                              recipe: _picks[i],
                              index: i,
                              onTap: () => Navigator.push(ctx,
                                  MaterialPageRoute(
                                      builder: (_) => RecipeDetailScreen(recipe: _picks[i]))),
                            ),
                          ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────
class _Header extends StatefulWidget {
  final String greeting;
  final VoidCallback onLogout;
  const _Header({required this.greeting, required this.onLogout});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final p = _pulse.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(_C.hTop, const Color(0xFFBB1A00), p)!,
                Color.lerp(_C.hMid, const Color(0xFFFF5520), p)!,
                Color.lerp(_C.hBot, const Color(0xFFFFCC44), p)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(36)),
            boxShadow: [
              BoxShadow(
                color: _C.hMid.withValues(alpha: 0.4 + p * 0.15),
                blurRadius: 24 + p * 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            // Blobs
            Positioned(top: -30, right: -30,
                child: _Blob(140, Colors.white.withValues(alpha: 0.10 + p * 0.06))),
            Positioned(top: 50, right: 70,
                child: _Blob(60, Colors.white.withValues(alpha: 0.08))),
            Positioned(bottom: -25, left: -25,
                child: _Blob(110, Colors.black.withValues(alpha: 0.07))),
            Positioned(bottom: 15, left: 90,
                child: _Blob(45, Colors.white.withValues(alpha: 0.06))),
            Positioned(top: 20, left: 130,
                child: _Blob(35, Colors.white.withValues(alpha: 0.05 + p * 0.05))),

            // Content
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 14, 30),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.30)),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🍴',
                                      style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 5),
                                  Text('Foodie AI',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ]),
                          ),
                          const SizedBox(height: 18),
                          Text(widget.greeting,
                              style: GoogleFonts.poppins(
                                  color:
                                      Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13)),
                          const SizedBox(height: 3),
                          Text("What's cooking\ntoday?",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15)),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('✨ AI-powered cooking assistant',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                    // Avatar + logout
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _HoverIconButton(
                          icon: Icons.logout_rounded,
                          onTap: widget.onLogout,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.50),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.15),
                                  blurRadius: 12)
                            ],
                          ),
                          child: const Center(
                              child: Text('👨‍🍳',
                                  style: TextStyle(fontSize: 26))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ── Hover icon button ──────────────────────────────────────────────────────
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HoverIconButton({required this.icon, required this.onTap});

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.30)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon,
              color: Colors.white.withValues(alpha: _hovered ? 1.0 : 0.7),
              size: 18),
        ),
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatChip('🍳', '1,090', 'Recipes',
          [const Color(0xFFFF6B2E), const Color(0xFFFF9A5C)]),
      const SizedBox(width: 10),
      _StatChip('🤖', 'AI', 'Powered',
          [const Color(0xFF4A90D9), const Color(0xFF6AAFE8)]),
      const SizedBox(width: 10),
      _StatChip('❤️', '100%', 'Personal',
          [const Color(0xFFAA40C0), const Color(0xFFCC70E0)]),
    ]);
  }
}

class _StatChip extends StatefulWidget {
  final String emoji, value, label;
  final List<Color> grad;
  const _StatChip(this.emoji, this.value, this.label, this.grad);

  @override
  State<_StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<_StatChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -4.0 : 0.0, 0.0, 1.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: widget.grad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: widget.grad[0]
                      .withValues(alpha: _hovered ? 0.55 : 0.30),
                  blurRadius: _hovered ? 18 : 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(widget.value,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            Text(widget.label,
                style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_C.hTop, _C.hBot],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 9),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.textPri)),
      ]);
}

// ── Feature model ──────────────────────────────────────────────────────────
class _Feature {
  final IconData icon;
  final String emoji, title, description;
  final Color color;
  final Widget screen;
  const _Feature(this.icon, this.emoji, this.title, this.description,
      this.color, this.screen);
}

// ── Feature card with hover ────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  List<Color> get _grad {
    final c = widget.feature.color;
    return [
      Color.lerp(c, Colors.white, 0.10)!,
      Color.lerp(c, Colors.black, 0.20)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => widget.feature.screen)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 90,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -4.0 : 0.0, 0.0, 1.0),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _hovered
                    ? widget.feature.color.withValues(alpha: 0.5)
                    : _C.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: widget.feature.color
                    .withValues(alpha: _hovered ? 0.28 : 0.10),
                blurRadius: _hovered ? 24 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Vivid left panel
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _hovered ? 100 : 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: _grad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: Stack(children: [
                    Positioned(
                      right: -8, bottom: -8,
                      child: Opacity(
                        opacity: _hovered ? 0.45 : 0.28,
                        child: Text(widget.feature.emoji,
                            style: const TextStyle(fontSize: 58)),
                      ),
                    ),
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(_hovered ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: _hovered ? 0.35 : 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.6)),
                        ),
                        child: Icon(widget.feature.icon,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ]),
                ),
              ),

              // Text
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.feature.title,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.textPri)),
                      const SizedBox(height: 4),
                      Text(widget.feature.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: _C.textSec,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),

              // Arrow button
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _grad),
                    shape: BoxShape.circle,
                    boxShadow: _hovered
                        ? [
                            BoxShadow(
                                color: widget.feature.color
                                    .withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ]
                        : [
                            BoxShadow(
                                color: widget.feature.color
                                    .withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                  ),
                  child: AnimatedRotation(
                    turns: _hovered ? 0.02 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.arrow_forward_rounded,
                        size: 15, color: Colors.white),
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

// ── Tip card ───────────────────────────────────────────────────────────────
class _TipCard extends StatefulWidget {
  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  bool _hovered = false;

  static const _tips = [
    'Add a pinch of sugar to tomato sauce to cut acidity.',
    'Let meat rest 5 min after cooking for juicier results.',
    'Cold butter makes flakier pastry — keep it chilled!',
    'Salt pasta water like the sea for perfect flavor.',
    'Roast spices in a dry pan to unlock deeper aromas.',
    'A splash of pasta water helps sauce cling to noodles.',
    'Deglaze the pan after searing for a quick pan sauce.',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _hovered
                  ? const Color(0xFFFF9040)
                  : const Color(0xFFFFD0A0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE07020)
                  .withValues(alpha: _hovered ? 0.22 : 0.10),
              blurRadius: _hovered ? 20 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('💡', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Chef's Tip of the Day",
                    style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFFBF5010),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
                const SizedBox(height: 5),
                Text(tip,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _C.textPri,
                        height: 1.5)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Today's Picks — skeleton ───────────────────────────────────────────────
class _PicksSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: 155,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

// ── Today's Picks — empty ─────────────────────────────────────────────────
class _PicksEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.kitchen_outlined, size: 40, color: Colors.grey),
        const SizedBox(height: 8),
        Text('Add pantry items to get picks',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
      ]),
    );
  }
}

// ── Today's Picks — single card ───────────────────────────────────────────
class _PickCard extends StatefulWidget {
  final Recipe recipe;
  final int index;
  final VoidCallback onTap;
  const _PickCard({required this.recipe, required this.index, required this.onTap});

  @override
  State<_PickCard> createState() => _PickCardState();
}

class _PickCardState extends State<_PickCard> {
  bool _hovered = false;

  static const _gradients = [
    [Color(0xFFE04A18), Color(0xFFFF8C50)],
    [Color(0xFF28A860), Color(0xFF6AD490)],
    [Color(0xFF2878D0), Color(0xFF70AAEE)],
    [Color(0xFFD07820), Color(0xFFEEAA50)],
    [Color(0xFF8040C0), Color(0xFFB080E0)],
  ];

  static const _fallbacks = [
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&q=80',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&q=80',
    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400&q=80',
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80',
    'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=400&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    final grad = _gradients[widget.index % _gradients.length];
    final img = widget.recipe.imageUrl.isNotEmpty
        ? widget.recipe.imageUrl
        : _fallbacks[widget.index % _fallbacks.length];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 155,
          margin: const EdgeInsets.only(right: 12),
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -5.0 : 0.0, 0.0, 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: grad[0].withValues(alpha: _hovered ? 0.35 : 0.15),
                blurRadius: _hovered ? 18 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image area
                Stack(
                  children: [
                    Image.network(
                      img,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: grad,
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                        ),
                        child: Center(
                          child: Text(
                            ['🍽️', '🥗', '🍜', '🍕', '🥘'][widget.index % 5],
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, grad[0].withValues(alpha: 0.85)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Rank badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: grad),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: grad[0].withValues(alpha: 0.4), blurRadius: 6)],
                        ),
                        child: Text('#${widget.index + 1}',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                // Info area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textPri,
                              height: 1.3),
                        ),
                        Row(children: [
                          if (widget.recipe.totalTime.isNotEmpty) ...[
                            Icon(Icons.timer_outlined, size: 11, color: grad[0]),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.recipe.totalTime,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: _C.textSec),
                              ),
                            ),
                          ] else
                            Expanded(
                              child: Text('Tap to cook',
                                  style: GoogleFonts.poppins(fontSize: 10, color: _C.textSec)),
                            ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: grad),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded,
                                size: 10, color: Colors.white),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
