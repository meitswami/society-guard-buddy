import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/quick_entry_service.dart';
import '../../services/visitor_entry_service.dart';
import '../../services/visitor_service.dart';

class GuardQuickEntryScreen extends StatefulWidget {
  const GuardQuickEntryScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardQuickEntryScreen> createState() => _GuardQuickEntryScreenState();
}

class _GuardQuickEntryScreenState extends State<GuardQuickEntryScreen> {
  final _quickService = QuickEntryService();
  final _entryService = VisitorEntryService();
  final _visitorService = VisitorService();
  final _searchCtrl = TextEditingController();

  List<QuickEntryRow> _rows = const [];
  List<VisitorEntry> _visitors = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _quickService.fetchRows(widget.session.societyId);
    final visitors = await _visitorService.fetchToday(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _visitors = visitors;
      _loading = false;
    });
  }

  List<QuickEntryRow> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.phone.contains(q) ||
          r.flatNumber.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _logIn(QuickEntryRow row) async {
    try {
      await _entryService.registerVisitor(
        societyId: widget.session.societyId,
        guardId: widget.session.guard.guardId,
        guardName: widget.session.guard.name,
        name: row.name,
        phone: row.phone,
        flatNumber: row.flatNumber,
        purpose: row.purpose,
        documentType: 'other',
        category: row.category,
        company: row.company,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${row.name} logged in')));
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not log entry')));
    }
  }

  Future<void> _logOut(QuickEntryRow row) async {
    final active = _quickService.findActiveVisit(_visitors, row);
    if (active == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark exit?'),
        content: Text('Mark ${row.name} as exited?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit')),
        ],
      ),
    );
    if (ok != true) return;

    await _visitorService.markExit(active.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${row.name} exited')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick entry')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name, phone, flat…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No frequent visitors or staff yet', style: TextStyle(color: KutumbikaColors.textMuted))),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = _filtered[index];
                              final inside = _quickService.findActiveVisit(_visitors, row) != null;
                              return ListTile(
                                title: Text(row.name),
                                subtitle: Text('Flat ${row.flatNumber} · ${row.phone}${row.isStaff ? ' · Staff' : ''}'),
                                trailing: inside
                                    ? OutlinedButton(
                                        onPressed: () => _logOut(row),
                                        child: const Text('Exit'),
                                      )
                                    : FilledButton(
                                        onPressed: () => _logIn(row),
                                        style: FilledButton.styleFrom(backgroundColor: brand.primary),
                                        child: const Text('Enter'),
                                      ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
