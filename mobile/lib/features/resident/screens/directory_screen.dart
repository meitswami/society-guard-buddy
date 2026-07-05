import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/session_models.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<Map<String, dynamic>> _flats = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() => _loading = false);
      return;
    }
    final rows = await SupabaseBootstrap.client
        .from('flats')
        .select('id, flat_number, block_name')
        .eq('society_id', widget.session.societyId)
        .order('flat_number');
    if (!mounted) return;
    setState(() {
      _flats = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _flats.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final f = _flats[index];
        final block = f['block_name'] as String?;
        return ListTile(
          title: Text(f['flat_number']?.toString() ?? ''),
          subtitle: block != null && block.isNotEmpty ? Text(block) : null,
          trailing: const Icon(Icons.chevron_right, color: KutumbikaColors.textMuted),
        );
      },
    );
  }
}
