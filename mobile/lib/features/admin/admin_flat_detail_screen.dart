import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/admin_flat_service.dart';
import '../../services/admin_resident_service.dart';
import '../../utils/password_generator.dart';

class AdminFlatDetailScreen extends StatefulWidget {
  const AdminFlatDetailScreen({
    super.key,
    required this.session,
    required this.flatId,
    required this.flatNumber,
  });

  final SessionAdmin session;
  final String flatId;
  final String flatNumber;

  @override
  State<AdminFlatDetailScreen> createState() => _AdminFlatDetailScreenState();
}

class _AdminFlatDetailScreenState extends State<AdminFlatDetailScreen>
    with SingleTickerProviderStateMixin {
  final _flatService = AdminFlatService();
  final _residentService = AdminResidentService();

  late TabController _tabs;
  Map<String, dynamic>? _flat;
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _logins = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final flat = await _flatService.fetchFlat(widget.flatId);
    final members = await _flatService.fetchMembers(widget.flatId);
    final logins = await _flatService.fetchResidentUsers(widget.flatId);
    if (!mounted) return;
    setState(() {
      _flat = flat;
      _members = members;
      _logins = logins;
      _loading = false;
    });
  }

  Future<void> _editFlat() async {
    final f = _flat;
    if (f == null) return;

    final flatCtrl = TextEditingController(text: f['flat_number'] as String?);
    final wingCtrl = TextEditingController(text: f['wing'] as String? ?? '');
    final floorCtrl = TextEditingController(text: f['floor'] as String? ?? '');
    final ownerCtrl = TextEditingController(text: f['owner_name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: f['owner_phone'] as String? ?? '');
    final intercomCtrl = TextEditingController(text: f['intercom'] as String? ?? '');
    var occupied = f['is_occupied'] as bool? ?? true;
    var ownerLives = f['owner_lives_here'] as bool? ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Edit flat'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: flatCtrl,
                  decoration: const InputDecoration(labelText: 'Flat number *'),
                ),
                TextField(controller: wingCtrl, decoration: const InputDecoration(labelText: 'Wing')),
                TextField(controller: floorCtrl, decoration: const InputDecoration(labelText: 'Floor')),
                TextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner')),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Owner phone'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(controller: intercomCtrl, decoration: const InputDecoration(labelText: 'Intercom')),
                SwitchListTile(
                  title: const Text('Occupied'),
                  value: occupied,
                  onChanged: (v) => setDlg(() => occupied = v),
                ),
                SwitchListTile(
                  title: const Text('Owner lives here'),
                  value: ownerLives,
                  onChanged: (v) => setDlg(() => ownerLives = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true || flatCtrl.text.trim().isEmpty) {
      _disposeCtrls([flatCtrl, wingCtrl, floorCtrl, ownerCtrl, phoneCtrl, intercomCtrl]);
      return;
    }

    try {
      await _flatService.upsertFlat(
        societyId: widget.session.societyId,
        id: widget.flatId,
        flatNumber: flatCtrl.text,
        wing: wingCtrl.text,
        floor: floorCtrl.text,
        ownerName: ownerCtrl.text,
        ownerPhone: phoneCtrl.text,
        intercom: intercomCtrl.text,
        isOccupied: occupied,
        ownerLivesHere: ownerLives,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flat updated')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      _disposeCtrls([flatCtrl, wingCtrl, floorCtrl, ownerCtrl, phoneCtrl, intercomCtrl]);
    }
  }

  Future<void> _deleteFlat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete flat?'),
        content: const Text('Resident logins must be removed first. Members will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _flatService.deleteFlat(widget.flatId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flat deleted')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addMember() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    var isPrimary = _members.isEmpty;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Add household member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextField(controller: relationCtrl, decoration: const InputDecoration(labelText: 'Relation')),
              SwitchListTile(
                title: const Text('Primary member'),
                value: isPrimary,
                onChanged: (v) => setDlg(() => isPrimary = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (ok != true || nameCtrl.text.trim().isEmpty) {
      _disposeCtrls([nameCtrl, phoneCtrl, relationCtrl]);
      return;
    }

    try {
      await _flatService.addMember(
        flatId: widget.flatId,
        name: nameCtrl.text,
        phone: phoneCtrl.text,
        relation: relationCtrl.text,
        isPrimary: isPrimary,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      _disposeCtrls([nameCtrl, phoneCtrl, relationCtrl]);
    }
  }

  Future<void> _addLogin() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pwdCtrl = TextEditingController(text: generateFlatPassword());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add resident login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone *'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: pwdCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (ok != true || nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      _disposeCtrls([nameCtrl, phoneCtrl, pwdCtrl]);
      return;
    }

    try {
      await _residentService.addResident(
        flatId: widget.flatId,
        flatNumber: widget.flatNumber,
        name: nameCtrl.text,
        phone: phoneCtrl.text,
        password: pwdCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login created')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      _disposeCtrls([nameCtrl, phoneCtrl, pwdCtrl]);
    }
  }

  void _disposeCtrls(List<TextEditingController> ctrls) {
    for (final c in ctrls) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Flat ${widget.flatNumber}'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editFlat),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteFlat),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: brand.primary,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Members'),
            Tab(text: 'Logins'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _DetailsTab(flat: _flat),
                _MembersTab(
                  members: _members,
                  onAdd: _addMember,
                  onDelete: (id) async {
                    await _flatService.deleteMember(id);
                    await _load();
                  },
                ),
                _LoginsTab(
                  logins: _logins,
                  onAdd: _addLogin,
                  onDelete: (id) async {
                    await _residentService.deleteResident(id);
                    await _load();
                  },
                ),
              ],
            ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          if (_tabs.index == 1) {
            return FloatingActionButton.extended(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add),
              label: const Text('Member'),
            );
          }
          if (_tabs.index == 2) {
            return FloatingActionButton.extended(
              onPressed: _addLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.flat});

  final Map<String, dynamic>? flat;

  @override
  Widget build(BuildContext context) {
    if (flat == null) {
      return const Center(child: Text('Flat not found'));
    }

    final rows = <String, String?>{
      'Flat number': flat!['flat_number'] as String?,
      'Wing': flat!['wing'] as String?,
      'Floor': flat!['floor'] as String?,
      'Type': flat!['flat_type'] as String?,
      'Owner': flat!['owner_name'] as String?,
      'Owner phone': flat!['owner_phone'] as String?,
      'Intercom': flat!['intercom'] as String?,
      'Occupied': (flat!['is_occupied'] as bool? ?? false) ? 'Yes' : 'No',
      'Owner lives here': (flat!['owner_lives_here'] as bool? ?? false) ? 'Yes' : 'No',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: rows.entries
          .where((e) => e.value != null && e.value!.isNotEmpty)
          .map(
            (e) => Card(
              child: ListTile(
                title: Text(e.key, style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted)),
                subtitle: Text(e.value!, style: const TextStyle(fontSize: 16)),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.members,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> members;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No household members', style: TextStyle(color: KutumbikaColors.textMuted)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add member')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final m = members[index];
        final primary = m['is_primary'] as bool? ?? false;
        return Card(
          child: ListTile(
            leading: Icon(primary ? Icons.star : Icons.person_outline),
            title: Text(m['name'] as String? ?? ''),
            subtitle: Text(
              [
                if (m['relation'] != null) m['relation'] as String,
                if (m['phone'] != null) m['phone'] as String,
              ].join(' · '),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(m['id'] as String),
            ),
          ),
        );
      },
    );
  }
}

class _LoginsTab extends StatelessWidget {
  const _LoginsTab({
    required this.logins,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> logins;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (logins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No resident app logins', style: TextStyle(color: KutumbikaColors.textMuted)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add login')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logins.length,
      itemBuilder: (context, index) {
        final r = logins[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.phone_android),
            title: Text(r['name'] as String? ?? ''),
            subtitle: Text(r['phone'] as String? ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(r['id'] as String),
            ),
          ),
        );
      },
    );
  }
}
