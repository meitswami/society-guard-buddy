import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../providers/branding_provider.dart';
import '../../services/society_service.dart';
import '../home/resident_home_screen.dart';
import '../shared/widgets/branded_background.dart';
import '../shared/widgets/branding_logo.dart';

/// Society-first gate — port of `SocietyLoginGate.tsx` (resident preview for now).
class SocietyGateScreen extends ConsumerStatefulWidget {
  const SocietyGateScreen({super.key});

  @override
  ConsumerState<SocietyGateScreen> createState() => _SocietyGateScreenState();
}

class _SocietyGateScreenState extends ConsumerState<SocietyGateScreen> {
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
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      body: BrandedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandingLogo(size: 52, borderRadius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brand.appName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: brand.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            brand.tagline,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: KutumbikaColors.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref.read(platformBrandingProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh branding',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
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
                      child: CircularProgressIndicator(),
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
                              const SocietyRow(
                                id: 'demo',
                                name: 'Green Valley Apartments',
                              ),
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
                            leading: society.logoUrl != null && society.logoUrl!.isNotEmpty
                                ? BrandingLogo(
                                    size: 40,
                                    borderRadius: 10,
                                    imageUrl: society.logoUrl,
                                  )
                                : Icon(Icons.apartment_rounded, color: brand.primary),
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
        ),
      ),
    );
  }
}
