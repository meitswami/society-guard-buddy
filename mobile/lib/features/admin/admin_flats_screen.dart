import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/admin_flat_service.dart';
import '../../utils/member_photo.dart';
import 'admin_flat_detail_screen.dart';
import 'admin_flat_generator_screen.dart';

class AdminFlatsScreen extends StatefulWidget {
  const AdminFlatsScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminFlatsScreen> createState() => _AdminFlatsScreenState();
}

class _AdminFlatsScreenState extends State<AdminFlatsScreen> {
  final _service = AdminFlatService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _flats = const [];
  Map<String, String> _ownerPhotoByFlatId = const {};
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
    final flats = await _service.fetchFlats(widget.session.societyId);
    final photoByFlat = <String, String>{};
    if (Env.isConfigured && flats.isNotEmpty) {
      final flatIds = flats.map((f) => f['id'] as String).toList();
      final rows = await SupabaseBootstrap.client
          .from('members')
          .select('flat_id, photo')
          .eq('is_primary', true)
          .inFilter('flat_id', flatIds);
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final photo = (row['photo'] as String?)?.trim();
        final flatId = row['flat_id'] as String?;
        if (flatId != null && photo != null && photo.isNotEmpty) {
          photoByFlat[flatId] = photo;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _flats = flats;
      _ownerPhotoByFlatId = photoByFlat;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _flats;
    return _flats.where((f) {
      final num = (f['flat_number'] as String? ?? '').toLowerCase();
      final wing = (f['wing'] as String? ?? '').toLowerCase();
      final owner = (f['owner_name'] as String? ?? '').toLowerCase();
      return num.contains(q) || wing.contains(q) || owner.contains(q);
    }).toList();
  }

  Future<void> _addFlat() async {
    final flatCtrl = TextEditingController();
    final wingCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add flat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: flatCtrl,
                decoration: const InputDecoration(labelText: 'Flat number *'),
                textCapitalization: TextCapitalization.characters,
              ),
              TextField(
                controller: wingCtrl,
                decoration: const InputDecoration(labelText: 'Wing / block'),
              ),
              TextField(
                controller: floorCtrl,
                decoration: const InputDecoration(labelText: 'Floor'),
              ),
              TextField(
                controller: ownerCtrl,
                decoration: const InputDecoration(labelText: 'Owner name'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Owner phone'),
                keyboardType: TextInputType.phone,
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

    if (ok != true || flatCtrl.text.trim().isEmpty) {
      flatCtrl.dispose();
      wingCtrl.dispose();
      floorCtrl.dispose();
      ownerCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }

    try {
      await _service.upsertFlat(
        societyId: widget.session.societyId,
        flatNumber: flatCtrl.text,
        wing: wingCtrl.text,
        floor: floorCtrl.text,
        ownerName: ownerCtrl.text,
        ownerPhone: phoneCtrl.text,
        isOccupied: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flat added')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      flatCtrl.dispose();
      wingCtrl.dispose();
      floorCtrl.dispose();
      ownerCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flats & members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: 'Generate from layout',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminFlatGeneratorScreen(session: widget.session),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search flat, wing, owner…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    color: brand.primary,
                    child: _filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No flats yet',
                                  style: TextStyle(color: KutumbikaColors.textMuted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final f = _filtered[index];
                              final wing = f['wing'] as String?;
                              final floor = f['floor'] as String?;
                              final meta = [
                                if (wing != null && wing.isNotEmpty) wing,
                                if (floor != null && floor.isNotEmpty) 'Fl $floor',
                              ].join(' · ');

                              return Card(
                                child: ListTile(
                                  leading: memberPhotoAvatar(
                                    name: f['owner_name'] as String? ?? f['flat_number'] as String? ?? '?',
                                    photo: _ownerPhotoByFlatId[f['id'] as String],
                                    backgroundColor: brand.primaryLight,
                                    foregroundColor: brand.primary,
                                    radius: 22,
                                  ),
                                  title: Text('Flat ${f['flat_number']}'),
                                  subtitle: Text(
                                    [
                                      if (meta.isNotEmpty) meta,
                                      f['owner_name'] as String? ?? 'No owner set',
                                    ].join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Icon(
                                    (f['is_occupied'] as bool? ?? false)
                                        ? Icons.home
                                        : Icons.home_outlined,
                                    color: KutumbikaColors.textMuted,
                                  ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AdminFlatDetailScreen(
                                          session: widget.session,
                                          flatId: f['id'] as String,
                                          flatNumber: f['flat_number'] as String,
                                        ),
                                      ),
                                    );
                                    await _load();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlat,
        icon: const Icon(Icons.add),
        label: const Text('Add flat'),
      ),
    );
  }
}
