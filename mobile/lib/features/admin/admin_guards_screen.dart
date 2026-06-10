import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/admin_guard_service.dart';

class AdminGuardsScreen extends StatefulWidget {
  const AdminGuardsScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminGuardsScreen> createState() => _AdminGuardsScreenState();
}

class _AdminGuardsScreenState extends State<AdminGuardsScreen> {
  final _service = AdminGuardService();
  List<Map<String, dynamic>> _guards = const [];
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
    if (!Env.isConfigured) {
      setState(() => _loading = false);
      return;
    }

    final rows = await SupabaseBootstrap.client
        .from('guards')
        .select('id, guard_id, name, phone, auth_mode')
        .eq('society_id', widget.session.societyId)
        .order('name');

    if (!mounted) return;
    setState(() {
      _guards = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _guards;
    return _guards.where((g) {
      return (g['name'] as String? ?? '').toLowerCase().contains(q) ||
          (g['guard_id'] as String? ?? '').toLowerCase().contains(q) ||
          (g['phone'] as String? ?? '').contains(q);
    }).toList();
  }

  Future<void> _addGuard() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    var authMode = 'password';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add guard'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'Guard ID *')),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'password', label: Text('Password')),
                    ButtonSegment(value: 'otp', label: Text('OTP')),
                  ],
                  selected: {authMode},
                  onSelectionChanged: (s) => setDialog(() => authMode = s.first),
                ),
                if (authMode == 'password')
                  TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password *'), obscureText: true),
                if (authMode == 'otp')
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *'), keyboardType: TextInputType.phone),
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
    try {
      await _service.addGuard(
        societyId: widget.session.societyId,
        guardId: idCtrl.text,
        name: nameCtrl.text,
        authMode: authMode,
        password: passCtrl.text,
        phone: phoneCtrl.text,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editGuard(Map<String, dynamic> g) async {
    final nameCtrl = TextEditingController(text: g['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: g['phone']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${g['guard_id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;
    await _service.updateGuard(
      id: g['id'] as String,
      societyId: widget.session.societyId,
      name: nameCtrl.text,
      phone: phoneCtrl.text,
    );
    await _load();
  }

  Future<void> _resetPassword(Map<String, dynamic> g) async {
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'New password'), obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.resetPassword(id: g['id'] as String, societyId: widget.session.societyId, password: passCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteGuard(Map<String, dynamic> g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete guard?'),
        content: Text('Remove ${g['name']} (${g['guard_id']})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteGuard(widget.session.societyId, g['id'] as String);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Guards')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGuard,
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
                hintText: 'Search guard ID, name, phone…',
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
                              Center(child: Text('No guards', style: TextStyle(color: KutumbikaColors.textMuted))),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final g = _filtered[index];
                              return ListTile(
                                title: Text(g['name']?.toString() ?? ''),
                                subtitle: Text('ID ${g['guard_id']} · ${g['auth_mode']}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'edit':
                                        _editGuard(g);
                                      case 'password':
                                        _resetPassword(g);
                                      case 'delete':
                                        _deleteGuard(g);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'password', child: Text('Reset password')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
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
