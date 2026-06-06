import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final _api = ApiService();
  final _inputController = TextEditingController();
  List<String> _ingredients = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.getPantry();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _ingredients = List<String>.from(result['data']['ingredients'] ?? []);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _addIngredients() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final newItems = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    setState(() {
      for (final item in newItems) {
        final lower = item.toLowerCase();
        if (!_ingredients.any((i) => i.toLowerCase() == lower)) {
          _ingredients.add(item);
        }
      }
    });
    _inputController.clear();
  }

  void _remove(String item) => setState(() => _ingredients.remove(item));

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await _api.savePantry(_ingredients);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? 'Pantry saved!' : result['message']),
      backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('My Pantry', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
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
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Add input
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add Ingredients', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Separate multiple items with commas', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onSubmitted: (_) => _addIngredients(),
                          decoration: InputDecoration(
                            hintText: 'e.g. chicken, rice, tomatoes',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                            filled: true, fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addIngredients,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Icon(Icons.add_rounded),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Text('Pantry Items', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${_ingredients.length}', style: GoogleFonts.poppins(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: _ingredients.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.kitchen_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('Your pantry is empty.\nAdd some ingredients above!',
                              textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[500])),
                        ]))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _ingredients.map((item) => Chip(
                            label: Text(item, style: GoogleFonts.poppins(fontSize: 13)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            onDeleted: () => _remove(item),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          )).toList(),
                        ),
                ),
              ]),
            ),
    );
  }
}
