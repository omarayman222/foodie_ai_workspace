import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';

class PantryItem {
  String name;
  DateTime? expiryDate;
  PantryItem({required this.name, this.expiryDate});

  Map<String, dynamic> toJson() => {
    'name': name,
    'expiryDate': expiryDate?.toIso8601String(),
  };

  factory PantryItem.fromJson(dynamic j) {
    if (j is String) return PantryItem(name: j);
    return PantryItem(
      name: j['name'] ?? '',
      expiryDate: j['expiryDate'] != null ? DateTime.tryParse(j['expiryDate']) : null,
    );
  }

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get expiringSoon {
    if (expiryDate == null || isExpired) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 3;
  }
}

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final _api = ApiService();
  final _inputCtrl = TextEditingController();
  List<PantryItem> _items = [];
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.getPantry();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      final rawItems = data['items'] as List?;
      final rawIngr  = data['ingredients'] as List?;
      final source   = (rawItems != null && rawItems.isNotEmpty) ? rawItems : (rawIngr ?? []);
      setState(() {
        _items   = source.map((x) => PantryItem.fromJson(x)).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _addIngredients() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final newNames = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    setState(() {
      for (final name in newNames) {
        if (!_items.any((i) => i.name.toLowerCase() == name.toLowerCase())) {
          _items.add(PantryItem(name: name));
        }
      }
    });
    _inputCtrl.clear();
  }

  void _remove(PantryItem item) => setState(() => _items.remove(item));

  Future<void> _pickExpiry(PantryItem item) async {
    final now   = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: 'Pick expiry date for "${item.name}"',
    );
    if (picked != null) setState(() => item.expiryDate = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await _api.savePantry(_items.map((i) => i.toJson()).toList());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? '✅ Pantry saved!' : result['message'] ?? 'Error'),
      backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
    ));
  }

  // Summary badges
  int get _expiredCount      => _items.where((i) => i.isExpired).length;
  int get _expiringSoonCount => _items.where((i) => i.expiringSoon).length;

  Future<void> _restockExpired() async {
    final names = _items.where((i) => i.isExpired).map((i) => i.name).toList();
    if (names.isEmpty) return;
    final result = await _api.addToShoppingList(names);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true
          ? '${names.length} expired item(s) added to shopping list!'
          : result['message'] ?? 'Failed'),
      backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Pantry', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
          ? _SkeletonPantry()
          : RefreshIndicator(
              onRefresh: _load,
              color: cs.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Add box ─────────────────────────────────
                  _AddBox(ctrl: _inputCtrl, onAdd: _addIngredients),
                  const SizedBox(height: 16),

                  // ── Warning badges ───────────────────────────
                  if (_expiredCount > 0 || _expiringSoonCount > 0)
                    _WarningBanner(
                      expired: _expiredCount,
                      expiringSoon: _expiringSoonCount,
                      onRestock: _expiredCount > 0 ? _restockExpired : null,
                    ),

                  // ── Header row ───────────────────────────────
                  const SizedBox(height: 16),
                  Row(children: [
                    Text('Pantry Items', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('${_items.length}', style: GoogleFonts.poppins(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Items ────────────────────────────────────
                  if (_items.isEmpty)
                    _EmptyState()
                  else
                    ..._items.map((item) => _ItemTile(
                      item: item,
                      onRemove: () => _remove(item),
                      onPickExpiry: () => _pickExpiry(item),
                    )),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ── Add box ─────────────────────────────────────────────────────────────────
class _AddBox extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onAdd;
  const _AddBox({required this.ctrl, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add Ingredients', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Separate multiple items with commas', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: ctrl,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: 'e.g. chicken, rice, tomatoes',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            child: const Icon(Icons.add_rounded),
          ),
        ]),
      ]),
    );
  }
}

// ── Warning banner ──────────────────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  final int expired;
  final int expiringSoon;
  final VoidCallback? onRestock;
  const _WarningBanner({required this.expired, required this.expiringSoon, this.onRestock});

  @override
  Widget build(BuildContext context) {
    final isError = expired > 0;
    final accent = isError ? Colors.redAccent : Colors.amber[700]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: isError ? Colors.red.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? Colors.red.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.warning_amber_rounded : Icons.access_time_rounded,
            color: accent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          [
            if (expired > 0) '$expired item${expired > 1 ? 's' : ''} expired',
            if (expiringSoon > 0) '$expiringSoon expiring within 3 days',
          ].join(' · '),
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
        )),
        if (onRestock != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRestock,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Restock', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

// ── Item tile ────────────────────────────────────────────────────────────────
class _ItemTile extends StatelessWidget {
  final PantryItem item;
  final VoidCallback onRemove;
  final VoidCallback onPickExpiry;
  const _ItemTile({required this.item, required this.onRemove, required this.onPickExpiry});

  Color get _statusColor {
    if (item.isExpired)    return Colors.redAccent;
    if (item.expiringSoon) return Colors.amber[700]!;
    if (item.expiryDate != null) return Colors.green;
    return Colors.grey[300]!;
  }

  String get _expiryLabel {
    if (item.expiryDate == null) return 'Tap to add expiry';
    if (item.isExpired)          return 'Expired!';
    final days = item.expiryDate!.difference(DateTime.now()).inDays;
    if (days == 0) return 'Expires today!';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.isExpired ? Colors.red.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
        leading: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
        ),
        title: Text(item.name,
            style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600,
              decoration: item.isExpired ? TextDecoration.lineThrough : null,
              color: item.isExpired ? Colors.grey : null,
            )),
        subtitle: GestureDetector(
          onTap: onPickExpiry,
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, size: 11, color: _statusColor),
            const SizedBox(width: 4),
            Text(_expiryLabel,
                style: GoogleFonts.poppins(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w500)),
          ]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(Icons.edit_calendar_rounded, size: 18, color: cs.primary), onPressed: onPickExpiry, tooltip: 'Set expiry'),
          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent), onPressed: onRemove, tooltip: 'Remove'),
        ]),
      ),
    );
  }
}

// ── Skeleton ────────────────────────────────────────────────────────────────
class _SkeletonPantry extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 8,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 64,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

// ── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.kitchen_outlined, size: 64, color: Colors.grey),
      const SizedBox(height: 12),
      Text('Your pantry is empty.\nAdd some ingredients above!',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.grey[500])),
    ])),
  );
}
