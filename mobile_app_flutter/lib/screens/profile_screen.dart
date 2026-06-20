import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../utils/theme_notifier.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  UserProfile _profile = UserProfile();
  bool _loading = true;
  bool _saving = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.getProfile();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      final profile = UserProfile.fromJson(data['profile'] ?? {});
      // top-level name takes precedence if profile.name is empty
      if (profile.name.isEmpty && (data['name'] as String? ?? '').isNotEmpty) {
        profile.name = data['name'] as String;
      }
      setState(() {
        _profile = profile;
        _nameCtrl.text = _profile.name;
        _email = data['email'] as String?;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    _profile.name = _nameCtrl.text.trim();
    setState(() => _saving = true);
    final result = await _api.updateProfile(_profile.toJson());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true
          ? 'Profile saved!'
          : (result['message'] ?? 'Failed to save profile')),
      backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
    ));
  }

  void _addToList(List<String> list, String hint) async {
    final ctrl = TextEditingController();
    final val = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add $hint', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (val != null && val.isNotEmpty && !list.contains(val)) {
      setState(() => list.add(val));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('My Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Account card ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Signed in as', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                        if (_email != null)
                          Text(_email!, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                        hintText: 'e.g. Mohamed',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Allergies',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red,
                  items: _profile.allergies,
                  hint: 'e.g. peanuts, gluten',
                  onAdd: () => _addToList(_profile.allergies, 'Allergy'),
                  onRemove: (i) => setState(() => _profile.allergies.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Diets',
                  icon: Icons.eco_rounded,
                  color: Colors.green,
                  items: _profile.diet,
                  hint: 'e.g. vegan, keto',
                  onAdd: () => _addToList(_profile.diet, 'Diet'),
                  onRemove: (i) => setState(() => _profile.diet.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Medical Conditions',
                  icon: Icons.local_hospital_rounded,
                  color: Colors.blue,
                  items: _profile.medicalConditions,
                  hint: 'e.g. diabetes, hypertension',
                  onAdd: () => _addToList(_profile.medicalConditions, 'Condition'),
                  onRemove: (i) => setState(() => _profile.medicalConditions.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Disliked Ingredients',
                  icon: Icons.thumb_down_outlined,
                  color: Colors.orange,
                  items: _profile.dislikes,
                  hint: 'e.g. cilantro, olives',
                  onAdd: () => _addToList(_profile.dislikes, 'Disliked ingredient'),
                  onRemove: (i) => setState(() => _profile.dislikes.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Disliked Cuisines',
                  icon: Icons.no_meals_rounded,
                  color: Colors.purple,
                  items: _profile.dislikedCuisines,
                  hint: 'e.g. spicy, Indian',
                  onAdd: () => _addToList(_profile.dislikedCuisines, 'Disliked cuisine'),
                  onRemove: (i) => setState(() => _profile.dislikedCuisines.removeAt(i)),
                ),
                const SizedBox(height: 16),
                // ── Dark Mode ────────────────────────────────
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeNotifier.instance,
                  builder: (_, mode, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: mode == ThemeMode.dark ? Colors.indigo : Colors.amber[700],
                      ),
                      title: Text('Dark Mode', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(mode == ThemeMode.dark ? 'On' : 'Off',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                      value: mode == ThemeMode.dark,
                      activeThumbColor: Colors.indigo,
                      onChanged: (_) => ThemeNotifier.instance.toggle(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String hint;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _Section({
    required this.title, required this.icon, required this.color,
    required this.items, required this.hint,
    required this.onAdd, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 14, color: color),
                const SizedBox(width: 2),
                Text('Add', style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: items.asMap().entries.map((e) => Chip(
              label: Text(e.value, style: GoogleFonts.poppins(fontSize: 12)),
              deleteIcon: const Icon(Icons.close_rounded, size: 14),
              onDeleted: () => onRemove(e.key),
              backgroundColor: color.withValues(alpha: 0.08),
              side: BorderSide(color: color.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )).toList(),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text('None added yet. Tap Add to get started.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
        ],
      ]),
    );
  }
}
