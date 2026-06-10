import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/flat_member.dart';
import '../../../models/session_models.dart';
import '../../../services/member_service.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final _service = MemberService();
  List<FlatMember> _members = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final members = await _service.fetchForFlat(widget.session.resident.flatId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _addMember() async {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ageCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add family member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: relationCtrl,
                decoration: const InputDecoration(labelText: 'Relation'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: ageCtrl,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    final ageText = ageCtrl.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);

    try {
      await _service.addMember(
        flatId: widget.session.resident.flatId,
        name: name,
        relation: relationCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        age: age,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member added')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add member: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Family members')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMember,
        backgroundColor: brand.primary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _members.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No members yet', style: TextStyle(color: KutumbikaColors.textMuted))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final subtitle = [
                          if (m.relation != null && m.relation!.isNotEmpty) m.relation,
                          if (m.phone != null && m.phone!.isNotEmpty) m.phone,
                          if (m.age != null) 'Age ${m.age}',
                        ].join(' · ');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: brand.primary.withValues(alpha: 0.12),
                            child: Icon(Icons.person, color: brand.primary),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(m.name)),
                              if (m.isPrimary)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: brand.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Primary',
                                    style: TextStyle(fontSize: 11, color: brand.primary),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                        );
                      },
                    ),
            ),
    );
  }
}
