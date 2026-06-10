import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../services/society_service.dart';
import '../home/resident_home_screen.dart';

/// Society-first gate — port of `SocietyLoginGate.tsx` (resident preview for now).
class SocietyGateScreen extends StatefulWidget {
  const SocietyGateScreen({super.key});

  @override
  State<SocietyGateScreen> createState() => _SocietyGateScreenState();
}

class _SocietyGateScreenState extends State<SocietyGateScreen> {
  final _service = SocietyService();
  List<SocietyRow> _societies = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _service.fetchActiveSocieties();
    if (!mounted) return;
    setState(() {
      _societies = rows;
      _loading = false;
    });
  }

  void _openPreview(SocietyRow society) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResidentHomeScreen(
          residentName: 'Rohan',
          societyName: society.name,
          societyId: society.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kutumbika'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your society',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Env.isConfigured
                  ? 'Choose a society to continue. Login screens come next.'
                  : 'Supabase not configured — showing themed preview with demo data.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: KutumbikaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: KutumbikaColors.primary),
                ),
              )
            else if (_societies.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No societies loaded.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _openPreview(
                          const SocietyRow(id: 'demo', name: 'Green Valley Apartments'),
                        ),
                        child: const Text('Open theme preview'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _societies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final society = _societies[index];
                    return Card(
                      child: ListTile(
                        title: Text(society.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openPreview(society),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
