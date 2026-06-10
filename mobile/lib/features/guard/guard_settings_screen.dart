import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../shared/widgets/biometric_settings_tile.dart';

class GuardSettingsScreen extends ConsumerWidget {
  const GuardSettingsScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);
    final g = session.guard;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: brand.primaryLight,
          child: Text(
            g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: brand.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(g.name, style: theme.textTheme.headlineSmall),
        Text('Guard · ${session.societyName}'),
        const SizedBox(height: 16),
        Card(child: BiometricSettingsTile(session: session)),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: brand.primary,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('End shift & log out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                ],
              ),
            );
            if (ok == true) {
              await ref.read(sessionProvider.notifier).logout(guardShiftId: session.shiftId);
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('End shift'),
        ),
      ],
    );
  }
}
