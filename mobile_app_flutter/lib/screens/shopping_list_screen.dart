import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _api = ApiService();
  final _inputController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.getShoppingList();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _items = List<Map<String, dynamic>>.from(result['data']['items'] ?? []);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _addItem() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final items = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    _inputController.clear();
    await _api.addToShoppingList(items);
    await _load();
  }

  Future<void> _removeItem(String name) async {
    await _api.removeFromShoppingList([name]);
    await _load();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final cat = item['category'] ?? 'Uncategorized';
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Shopping List', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.black54), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Add bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: (_) => _addItem(),
                      decoration: InputDecoration(
                        hintText: 'Add items (comma-separated)…',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                        filled: true, fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Icon(Icons.add_rounded),
                  ),
                ]),
              ),
              Expanded(
                child: _items.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('Your shopping list is empty.',
                            style: GoogleFonts.poppins(color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        Text('Add items above or generate one from a recipe.',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
                      ]))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: grouped.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 8),
                              child: Text(entry.key,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary)),
                            ),
                            Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                              child: Column(
                                children: entry.value.asMap().entries.map((e) {
                                  final item = e.value;
                                  final isLast = e.key == entry.value.length - 1;
                                  return Column(children: [
                                    ListTile(
                                      leading: Icon(Icons.circle_outlined, size: 20, color: Colors.grey[400]),
                                      title: Text(item['name'] ?? '', style: GoogleFonts.poppins(fontSize: 14)),
                                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                        if ((item['quantity'] ?? 1) > 1)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                            child: Text('x${item['quantity']}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                          ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300], size: 20),
                                          onPressed: () => _removeItem(item['name']),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ]),
                                    ),
                                    if (!isLast) Divider(height: 1, indent: 16, color: Colors.grey[100]),
                                  ]);
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        )).toList(),
                      ),
              ),
            ]),
    );
  }
}
