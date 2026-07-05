import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/blacklist_entry.dart';
import '../../models/session_models.dart';
import '../../services/blacklist_service.dart';

class GuardBlacklistScreen extends StatefulWidget {
  const GuardBlacklistScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardBlacklistScreen> createState() => _GuardBlacklistScreenState();
}

class _GuardBlacklistScreenState extends State<GuardBlacklistScreen> {
  final _service = BlacklistService();
  List<BlacklistEntry> _entries = const [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

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
    final rows = await _service.fetchAll(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _loading = false;
    });
  }

  List<BlacklistEntry> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) {
      return (e.name?.toLowerCase().contains(q) ?? false) ||
          (e.phone?.contains(q) ?? false) ||
          (e.vehicleNumber?.toLowerCase().contains(q) ?? false) ||
          e.reason.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addEntry() async {
    var type = 'visitor';
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add to blacklist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'visitor', label: Text('Visitor')),
                    ButtonSegment(value: 'vehicle', label: Text('Vehicle')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setDialog(() => type = s.first),
                ),
                const SizedBox(height: 12),
                if (type == 'visitor') ...[
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone *'),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                ] else
                  TextField(
                    controller: vehicleCtrl,
                    decoration: const InputDecoration(labelText: 'Vehicle number *'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason *'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required')));
      return;
    }
    if (type == 'visitor' && phoneCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone is required')));
      return;
    }
    if (type == 'vehicle' && vehicleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle number is required')));
      return;
    }

    try {
      await _service.addEntry(
        societyId: widget.session.societyId,
        type: type,
        reason: reason,
        addedBy: widget.session.guard.name,
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        vehicleNumber: vehicleCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _remove(BlacklistEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from blacklist?'),
        content: Text(entry.name ?? entry.phone ?? entry.vehicleNumber ?? entry.id),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.removeEntry(widget.session.societyId, entry.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Blacklist')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        backgroundColor: brand.primary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search blacklist…',
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
                              Center(child: Text('No blacklist entries', style: TextStyle(color: KutumbikaColors.textMuted))),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final e = _filtered[index];
                              final subtitle = [
                                if (e.phone != null) e.phone,
                                if (e.vehicleNumber != null) e.vehicleNumber,
                                e.reason,
                              ].whereType<String>().join(' · ');
                              return ListTile(
                                leading: Icon(
                                  e.type == 'vehicle' ? Icons.directions_car : Icons.person_off,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                title: Text(e.name ?? e.vehicleNumber ?? e.phone ?? 'Flagged'),
                                subtitle: Text(subtitle),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _remove(e),
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
