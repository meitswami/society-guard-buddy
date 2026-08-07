import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/session_models.dart';
import '../../../utils/member_photo.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<Map<String, dynamic>> _flats = const [];
  Map<String, List<Map<String, dynamic>>> _membersByFlat = const {};
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
    final flatRows = await SupabaseBootstrap.client
        .from('flats')
        .select('id, flat_number, block_name, owner_name')
        .eq('society_id', widget.session.societyId)
        .order('flat_number');
    final flats = (flatRows as List).cast<Map<String, dynamic>>();
    final flatIds = flats.map((f) => f['id'] as String).toList();

    final byFlat = <String, List<Map<String, dynamic>>>{};
    if (flatIds.isNotEmpty) {
      final memRows = await SupabaseBootstrap.client
          .from('members')
          .select('id, flat_id, name, phone, whatsapp_phone, email, relation, photo, is_primary')
          .inFilter('flat_id', flatIds)
          .order('is_primary', ascending: false)
          .order('name');
      for (final row in (memRows as List).cast<Map<String, dynamic>>()) {
        final fid = row['flat_id'] as String?;
        if (fid == null) continue;
        (byFlat[fid] ??= []).add(row);
      }
    }

    if (!mounted) return;
    setState(() {
      _flats = flats;
      _membersByFlat = byFlat;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredFlats {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _flats;
    return _flats.where((f) {
      final members = _membersByFlat[f['id']] ?? const [];
      final memberHay = members
          .map((m) => [m['name'], m['phone'], m['whatsapp_phone'], m['email'], m['relation']].whereType<String>().join(' '))
          .join(' ')
          .toLowerCase();
      final hay = [
        f['flat_number'],
        f['block_name'],
        f['owner_name'],
        memberHay,
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _nameHits(String flatId) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return (_membersByFlat[flatId] ?? const []).where((m) {
      final hay = [m['name'], m['phone'], m['whatsapp_phone'], m['email'], m['relation']].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    final flats = _filteredFlats;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
          child: RefreshIndicator(
            onRefresh: _load,
            child: flats.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('No flats found', style: TextStyle(color: KutumbikaColors.textMuted))),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: flats.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final f = flats[index];
                      final flatId = f['id'] as String;
                      final members = _membersByFlat[flatId] ?? const [];
                      final hits = _nameHits(flatId);
                      final block = f['block_name'] as String?;
                      return ExpansionTile(
                        leading: Icon(Icons.home_outlined, color: brand.primary),
                        title: Text(f['flat_number']?.toString() ?? ''),
                        subtitle: Text(
                          [
                            if (block != null && block.isNotEmpty) block,
                            if ((f['owner_name'] as String?)?.isNotEmpty ?? false) f['owner_name'],
                            '${members.length} members',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
                        ),
                        children: [
                          if (hits.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: hits
                                    .map(
                                      (m) => Chip(
                                        avatar: memberPhotoAvatar(
                                          name: m['name'] as String? ?? '',
                                          photo: m['photo'] as String?,
                                          backgroundColor: brand.primary.withValues(alpha: 0.12),
                                          foregroundColor: brand.primary,
                                          radius: 12,
                                        ),
                                        label: Text(m['name'] as String? ?? ''),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (members.isEmpty)
                            const ListTile(
                              dense: true,
                              title: Text('No members listed', style: TextStyle(color: KutumbikaColors.textMuted)),
                            )
                          else
                            ...members.map((m) {
                              final name = m['name'] as String? ?? '';
                              return ListTile(
                                dense: true,
                                leading: memberPhotoAvatar(
                                  name: name,
                                  photo: m['photo'] as String?,
                                  backgroundColor: brand.primary.withValues(alpha: 0.12),
                                  foregroundColor: brand.primary,
                                  radius: 18,
                                ),
                                title: Text(name),
                                subtitle: Text(
                                  [
                                    if (m['is_primary'] == true) 'Primary',
                                    if (m['relation'] != null) m['relation'] as String,
                                    if (m['phone'] != null) m['phone'] as String,
                                    if (m['whatsapp_phone'] != null) 'WA ${m['whatsapp_phone']}',
                                    if (m['email'] != null) m['email'] as String,
                                  ].join(' · '),
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
