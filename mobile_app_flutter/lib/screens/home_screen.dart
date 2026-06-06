import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'recipes_screen.dart';
import 'pantry_screen.dart';
import 'sous_chef_screen.dart';
import 'shopping_list_screen.dart';
import 'profile_screen.dart';

// ── Palette ────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFFAF7F2);
  static const card      = Color(0xFFFFFFFF);
  static const headerBg  = Color(0xFFFFF3E8);
  static const border    = Color(0xFFF0E8DC);
  static const textPri   = Color(0xFF2C2416);
  static const textSec   = Color(0xFF9A8F82);
  static const accent    = Color(0xFFC8603A);
  static const accentSoft= Color(0xFFF5E6DF);
  static const recipes   = Color(0xFFD4785A);
  static const pantry    = Color(0xFF6FA882);
  static const chef      = Color(0xFF6A8FBF);
  static const shop      = Color(0xFFBF8F5A);
  static const profile   = Color(0xFF9278BB);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      _Feature(
        icon: Icons.restaurant_menu_rounded,
        emoji: '🍽️',
        title: 'Recipes',
        subtitle: 'AI recommendations',
        description: 'Get personalized recipe ideas based on what\'s already in your pantry.',

        color: _C.recipes,
        screen: const RecipesScreen(),
      ),
      _Feature(
        icon: Icons.kitchen_rounded,
        emoji: '🥦',
        title: 'Pantry',
        subtitle: 'Manage ingredients',
        description: 'Track what you have at home so the AI can suggest the perfect meals.',

        color: _C.pantry,
        screen: const PantryScreen(),
      ),
      _Feature(
        icon: Icons.chat_bubble_outline_rounded,
        emoji: '🤖',
        title: 'Sous Chef',
        subtitle: 'AI cooking assistant',
        description: 'Ask anything about cooking — techniques, substitutes, timing, and more.',

        color: _C.chef,
        screen: const SousChefScreen(),
      ),
      _Feature(
        icon: Icons.shopping_cart_outlined,
        emoji: '🛒',
        title: 'Shopping',
        subtitle: 'Plan your groceries',
        description: 'Build a smart shopping list from recipes and never forget an ingredient.',

        color: _C.shop,
        screen: const ShoppingListScreen(),
      ),
      _Feature(
        icon: Icons.person_outline_rounded,
        emoji: '👤',
        title: 'My Profile',
        subtitle: 'Preferences & diet',
        description: 'Set your allergies, dietary needs and dislikes for safer recommendations.',

        color: _C.profile,
        screen: const ProfileScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(greeting: _greeting(), onLogout: () => _logout(context)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _QuickRow(features: features.take(3).toList()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text(
                'All Features',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _C.textSec,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _FeatureCard(feature: features[i]),
                childCount: features.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 220, // fixed height — not aspect ratio
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: _TipCard(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String greeting;
  final VoidCallback onLogout;
  const _Header({required this.greeting, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.headerBg,
        border: Border(bottom: BorderSide(color: _C.border, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _C.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: _C.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Foodie AI',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 16, color: _C.textPri)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20, color: _C.textSec),
                    tooltip: 'Logout',
                    onPressed: onLogout,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('$greeting,',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: _C.textSec, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text("What's cooking\ntoday?",
                  style: GoogleFonts.poppins(
                      fontSize: 28, fontWeight: FontWeight.w700, color: _C.textPri, height: 1.2)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _C.accentSoft, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: _C.accent),
                    const SizedBox(width: 6),
                    Text('AI-powered kitchen companion',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: _C.accent, fontWeight: FontWeight.w500)),
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

// ── Quick-access chips ─────────────────────────────────────────────────────
class _QuickRow extends StatelessWidget {
  final List<_Feature> features;
  const _QuickRow({required this.features});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: _C.textSec, letterSpacing: 0.4)),
        const SizedBox(height: 12),
        Row(
          children: features.map((f) {
            final isLast = f == features.last;
            final bg = Color.lerp(f.color, Colors.white, 0.88)!;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 10),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => f.screen)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: f.color.withValues(alpha: 0.25), width: 1),
                    ),
                    child: Column(children: [
                      Text(f.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 6),
                      Text(f.title,
                          style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: f.color)),
                    ]),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Feature card ───────────────────────────────────────────────────────────
class _Feature {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final Widget screen;
  const _Feature({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.screen,
  });
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final softBg = Color.lerp(feature.color, Colors.white, 0.82)!;
    final midBg  = Color.lerp(feature.color, Colors.white, 0.60)!;

    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => feature.screen)),
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: feature.color.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient hero with emoji ─────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [softBg, midBg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Large faint emoji watermark in background
                    Positioned(
                      right: -8, bottom: -8,
                      child: Text(feature.emoji,
                          style: const TextStyle(fontSize: 72)),
                    ),
                    // Icon badge top-left
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(feature.icon,
                            color: feature.color, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Text section ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.textPri,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feature.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: _C.textSec,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tip card ───────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  static const _tips = [
    'Add a pinch of sugar to tomato sauce to cut acidity.',
    'Let meat rest 5 minutes after cooking for juicier results.',
    'Cold butter makes flakier pastry — keep it chilled!',
    'Salt pasta water like the sea for perfect flavor.',
    'Roast spices in a dry pan to unlock deeper aromas.',
    'A splash of pasta water helps sauce cling to noodles.',
    'Deglaze the pan after searing meat for a quick sauce.',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: _C.accent.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 52,
            decoration: BoxDecoration(
              color: _C.accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Tip",
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _C.accent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 5),
                Text(tip,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _C.textPri,
                        height: 1.5,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('💡', style: TextStyle(fontSize: 26)),
        ],
      ),
    );
  }
}
