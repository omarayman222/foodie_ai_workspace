import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
        'recipeId':    r.id,
        'recipeName':  r.title,
        'recipeImage': r.imageUrl,
        'prepTime':    r.prepTime,
        'cookTime':    r.cookTime,
        'totalTime':   r.totalTime,
        'servings':    r.servings,
        'cuisine':     r.cuisine,
        'rating':      r.rating,
        'nutrition':   r.nutrition,
        'ingredients': r.ingredients,
        'directions':  r.instructions.join('\n'),
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
    final result = await _api.generateShoppingList(
      widget.recipe.id,
      ingredients: widget.recipe.ingredients,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true
          ? (result['data']?['message'] ?? '🛒 Missing ingredients added to shopping list!')
          : (result['message'] ?? 'Failed to generate list')),
      backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
    ));
  }

  // ── Cook Mode ──────────────────────────────────────────────
  void _enterCookMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    setState(() => _cookMode = true);
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

// ── Cook Mode with Voice + Arabic translation ─────────────────
class _CookModeView extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback onExit;
  const _CookModeView({required this.recipe, required this.onExit});

  @override
  State<_CookModeView> createState() => _CookModeViewState();
}

class _CookModeViewState extends State<_CookModeView> {
  final FlutterTts _tts = FlutterTts();
  final _api = ApiService();

  int _currentStep = 0;
  bool _voiceEnabled = true;
  bool _isSpeaking = false;

  // Language: 'en' or 'ar'
  String _lang = 'en';
  List<String>? _arabicSteps;   // null = not yet fetched
  bool _translating = false;
  String? _translateError;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // Non-blocking: speak() interrupts current audio instead of queuing
    await _tts.awaitSpeakCompletion(false);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() { if (mounted) setState(() => _isSpeaking = true); });
    _tts.setCompletionHandler(() { if (mounted) setState(() => _isSpeaking = false); });
    _tts.setCancelHandler(() { if (mounted) setState(() => _isSpeaking = false); });

    _speakStep(_currentStep);
  }

  List<String> get _activeSteps =>
      (_lang == 'ar' && _arabicSteps != null) ? _arabicSteps! : widget.recipe.instructions;

  Future<void> _speakStep(int step, {bool afterSwitch = false}) async {
    if (!_voiceEnabled) return;
    final steps = _activeSteps;
    if (steps.isEmpty || step >= steps.length) return;

    // Stop any ongoing speech and give the engine time to settle.
    // Language switches need a longer pause; normal step navigation needs a short one.
    await _tts.stop();
    await Future.delayed(Duration(milliseconds: afterSwitch ? 300 : 150));
    if (!mounted) return;

    final text = steps[step];
    if (_lang == 'ar') {
      final prefix = step == 0 ? 'بدأنا. الخطوة الأولى. ' : 'الخطوة ${step + 1}. ';
      await _tts.speak('$prefix$text');
    } else {
      final prefix = step == 0 ? 'Starting ${widget.recipe.title}. Step 1. ' : 'Step ${step + 1}. ';
      await _tts.speak('$prefix$text');
    }
  }

  Future<void> _stopSpeaking() => _tts.stop();

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _speakStep(step);
  }

  void _toggleVoice() {
    setState(() => _voiceEnabled = !_voiceEnabled);
    if (!_voiceEnabled) {
      _stopSpeaking();
    } else {
      _speakStep(_currentStep);
    }
  }

  Future<void> _switchLanguage(String lang) async {
    if (lang == _lang) return;

    if (lang == 'ar') {
      if (_arabicSteps == null) {
        setState(() { _translating = true; _translateError = null; });
        final result = await _api.translateSteps(
          widget.recipe.instructions,
          targetLang: 'Egyptian Arabic dialect (عامية مصرية)',
        );
        if (!mounted) return;
        if (result['success'] == true) {
          final List<dynamic> raw = result['data']['translations'];
          setState(() {
            _arabicSteps = raw.cast<String>();
            _translating = false;
          });
        } else {
          setState(() {
            _translateError = result['message'];
            _translating = false;
          });
          return;
        }
      }
      // ar-EG for Egyptian Arabic; fall back to ar-SA then plain ar
      final egResult = await _tts.setLanguage('ar-EG');
      if (egResult == 0) {
        final saResult = await _tts.setLanguage('ar-SA');
        if (saResult == 0) await _tts.setLanguage('ar');
      }
      await _tts.setSpeechRate(0.75); // 1.5× normal (0.5 default)
    } else {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
    }

    setState(() => _lang = lang);

    // Use addPostFrameCallback so the widget has fully rebuilt with the new
    // language before we fire speak — this guarantees _activeSteps returns
    // the correct list and the toggle feels instant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speakStep(_currentStep, afterSwitch: true);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _activeSteps;
    final isAr   = _lang == 'ar';

    if (widget.recipe.instructions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('No instructions available', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: widget.onExit, child: const Text('Exit Cook Mode')),
        ])),
      );
    }

    final isFirst = _currentStep == 0;
    final isLast  = _currentStep == steps.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(children: [

          // ── Top bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () { _stopSpeaking(); widget.onExit(); },
              ),
              Expanded(
                child: Text(widget.recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),

              // Language toggle EN | AR
              _LangToggle(current: _lang, onSelect: _switchLanguage, loading: _translating),

              const SizedBox(width: 4),

              // Replay
              IconButton(
                tooltip: isAr ? 'إعادة القراءة' : 'Replay step',
                icon: Icon(Icons.replay_rounded,
                    color: (_voiceEnabled && _isSpeaking) ? const Color(0xFFFF6B2E) : Colors.white54),
                onPressed: _voiceEnabled ? () => _speakStep(_currentStep) : null,
              ),

              // Mute toggle
              IconButton(
                tooltip: _voiceEnabled ? (isAr ? 'كتم الصوت' : 'Mute') : (isAr ? 'تشغيل الصوت' : 'Unmute'),
                icon: Icon(
                  _voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _voiceEnabled ? Colors.white : Colors.white30,
                ),
                onPressed: _toggleVoice,
              ),

              Text('${_currentStep + 1} / ${steps.length}',
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13)),
            ]),
          ),

          // ── Translation error banner ──────────────────────────
          if (_translateError != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_translateError ?? 'Translation failed.', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12))),
                GestureDetector(onTap: () => setState(() => _translateError = null), child: const Icon(Icons.close, color: Colors.redAccent, size: 16)),
              ]),
            ),

          // ── Progress bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / steps.length,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B2E)),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Step content ──────────────────────────────────────
          Expanded(
            child: _translating
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(color: Color(0xFFFF6B2E)),
                    const SizedBox(height: 16),
                    Text('جاري الترجمة…', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14)),
                    Text('Translating to Arabic…', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                  ]))
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Badge — glows orange while speaking
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isSpeaking
                                  ? [const Color(0xFFFF6B2E), const Color(0xFFFFAA44)]
                                  : [Colors.white24, Colors.white12],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${_currentStep + 1}',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
                        ),

                        // Speaking indicator
                        const SizedBox(height: 12),
                        AnimatedOpacity(
                          opacity: (_voiceEnabled && _isSpeaking) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.graphic_eq_rounded, color: Color(0xFFFF6B2E), size: 16),
                            const SizedBox(width: 4),
                            Text(isAr ? 'جاري القراءة…' : 'Speaking…',
                                style: GoogleFonts.poppins(color: const Color(0xFFFF6B2E), fontSize: 12)),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        // Step text — RTL for Arabic
                        Directionality(
                          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                          child: Text(
                            steps[_currentStep],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 18, height: 1.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
          ),

          // ── Navigation ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(children: [
              Expanded(
                child: AnimatedOpacity(
                  opacity: isFirst ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    onPressed: isFirst ? null : () => _goToStep(_currentStep - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(isAr ? 'السابق' : 'Back'),
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
                  onPressed: isLast
                      ? () { _stopSpeaking(); widget.onExit(); }
                      : () => _goToStep(_currentStep + 1),
                  icon: Icon(isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded),
                  label: Text(isLast ? (isAr ? 'انتهى!' : 'Done!') : (isAr ? 'التالي' : 'Next')),
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

// ── Language toggle chip ──────────────────────────────────────
class _LangToggle extends StatelessWidget {
  final String current;
  final Future<void> Function(String) onSelect;
  final bool loading;
  const _LangToggle({required this.current, required this.onSelect, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: loading
          ? const SizedBox(
              width: 60, height: 28,
              child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B2E)))),
            )
          : Row(mainAxisSize: MainAxisSize.min, children: [
              _LangChip(label: 'EN', active: current == 'en', onTap: () => onSelect('en')),
              _LangChip(label: 'AR', active: current == 'ar', onTap: () => onSelect('ar')),
            ]),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFF6B2E) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.white54,
          )),
    ),
  );
}

// ── Shared small widgets ──────────────────────────────────────
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
