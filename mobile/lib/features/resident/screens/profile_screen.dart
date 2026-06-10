import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../models/session_models.dart';
import '../../../providers/session_provider.dart';
import '../../shared/widgets/biometric_settings_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);
    final r = session.resident;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: brand.primaryLight,
          child: Text(
            r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: brand.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(r.name, style: theme.textTheme.headlineSmall),
        Text('Flat ${r.flatNumber} · ${session.societyName}'),
        Text(r.phone),
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
                title: const Text('Log out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                ],
              ),
            );
            if (ok == true) {
              await ref.read(sessionProvider.notifier).logout();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
