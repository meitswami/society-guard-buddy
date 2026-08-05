import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/admin_resident_service.dart';
import '../../utils/member_photo.dart';
import '../../utils/phone_utils.dart';

class AdminResidentsScreen extends StatefulWidget {
  const AdminResidentsScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminResidentsScreen> createState() => _AdminResidentsScreenState();
}

class _AdminResidentsScreenState extends State<AdminResidentsScreen> {
  final _service = AdminResidentService();
  List<Map<String, dynamic>> _residents = const [];
  List<Map<String, dynamic>> _flats = const [];
  Map<String, String> _photoByPhone = const {};
  Map<String, String> _photoByFlatName = const {};
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

    _flats = await _service.fetchFlats(widget.session.societyId);
    final flatIds = _flats.map((f) => f['id'] as String).toList();

    if (flatIds.isEmpty) {
      setState(() {
        _residents = const [];
        _loading = false;
      });
      return;
    }

    final rows = await SupabaseBootstrap.client
        .from('resident_users')
        .select('id, name, phone, flat_number, flat_id')
        .inFilter('flat_id', flatIds)
        .order('flat_number');

    final photoByPhone = <String, String>{};
    final photoByFlatName = <String, String>{};
    final memRows = await SupabaseBootstrap.client
        .from('members')
        .select('flat_id, name, phone, photo')
        .inFilter('flat_id', flatIds);
    for (final m in (memRows as List).cast<Map<String, dynamic>>()) {
      final photo = (m['photo'] as String?)?.trim();
      if (photo == null || photo.isEmpty) continue;
      final phone = m['phone'] as String?;
      if (phone != null && phone.trim().isNotEmpty) {
        photoByPhone[normalizeLoginPhone(phone)] = photo;
      }
      final name = (m['name'] as String?)?.trim().toLowerCase();
      final flatId = m['flat_id'] as String?;
      if (name != null && name.isNotEmpty && flatId != null) {
        photoByFlatName['$flatId|$name'] = photo;
      }
    }

    if (!mounted) return;
    setState(() {
      _residents = (rows as List).cast<Map<String, dynamic>>();
      _photoByPhone = photoByPhone;
      _photoByFlatName = photoByFlatName;
      _loading = false;
    });
  }

  String? _photoForResident(Map<String, dynamic> r) {
    final phone = r['phone'] as String?;
    if (phone != null && phone.trim().isNotEmpty) {
      final byPhone = _photoByPhone[normalizeLoginPhone(phone)];
      if (byPhone != null) return byPhone;
    }
    final flatId = r['flat_id'] as String?;
    final name = (r['name'] as String?)?.trim().toLowerCase();
    if (flatId != null && name != null && name.isNotEmpty) {
      return _photoByFlatName['$flatId|$name'];
    }
    return null;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _residents;
    return _residents.where((r) {
      return (r['name'] as String? ?? '').toLowerCase().contains(q) ||
          (r['phone'] as String? ?? '').contains(q) ||
          (r['flat_number'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addResident() async {
    if (_flats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No flats in this society')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var flatId = _flats.first['id'] as String;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add resident login'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: flatId,
                  decoration: const InputDecoration(labelText: 'Flat'),
                  items: _flats
                      .map((f) => DropdownMenuItem(
                            value: f['id'] as String,
                            child: Text(f['flat_number']?.toString() ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => flatId = v);
                  },
                ),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *'), keyboardType: TextInputType.phone),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password (optional — shared flat password if empty)'),
                  obscureText: true,
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
    final flat = _flats.firstWhere((f) => f['id'] == flatId);
    try {
      await _service.addResident(
        flatId: flatId,
        flatNumber: flat['flat_number'] as String,
        name: nameCtrl.text,
        phone: phoneCtrl.text,
        password: passCtrl.text.isEmpty ? null : passCtrl.text,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editResident(Map<String, dynamic> r) async {
    final nameCtrl = TextEditingController(text: r['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: r['phone']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${r['flat_number']}'),
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
    try {
      await _service.updateResident(id: r['id'] as String, name: nameCtrl.text, phone: phoneCtrl.text);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> r) async {
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
      await _service.resetPassword(id: r['id'] as String, password: passCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset — resident must change on next login')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteResident(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete resident login?'),
        content: Text('Remove ${r['name']} from flat ${r['flat_number']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteResident(r['id'] as String);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Residents')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addResident,
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
                              Center(child: Text('No residents', style: TextStyle(color: KutumbikaColors.textMuted))),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final r = _filtered[index];
                              return ListTile(
                                leading: memberPhotoAvatar(
                                  name: r['name']?.toString() ?? '',
                                  photo: _photoForResident(r),
                                  backgroundColor: brand.primary.withValues(alpha: 0.12),
                                  foregroundColor: brand.primary,
                                  radius: 22,
                                ),
                                title: Text(r['name']?.toString() ?? ''),
                                subtitle: Text('Flat ${r['flat_number']} · ${r['phone']}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'edit':
                                        _editResident(r);
                                      case 'password':
                                        _resetPassword(r);
                                      case 'delete':
                                        _deleteResident(r);
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
