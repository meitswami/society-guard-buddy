import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import 'guard_blacklist_screen.dart';
import 'guard_delivery_screen.dart';
import 'guard_emergency_screen.dart';
import 'guard_pass_verify_screen.dart';
import 'guard_quick_entry_screen.dart';
import 'guard_settings_screen.dart';

class GuardMoreMenuScreen extends StatelessWidget {
  const GuardMoreMenuScreen({super.key, required this.session});

  final SessionGuard session;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    final items = [
      _Item(Icons.key_outlined, 'Verify pass OTP', 'Resident visitor pass', () => _open(context, GuardPassVerifyScreen(session: session))),
      _Item(Icons.flash_on_outlined, 'Quick entry', 'Frequent & staff', () => _open(context, GuardQuickEntryScreen(session: session))),
      _Item(Icons.local_shipping_outlined, 'Delivery & service', 'Couriers & staff', () => _open(context, GuardDeliveryScreen(session: session))),
      _Item(Icons.block_outlined, 'Blacklist', 'Flagged visitors', () => _open(context, GuardBlacklistScreen(session: session))),
      _Item(Icons.warning_amber_outlined, 'Emergency alert', 'Broadcast to all', () => _open(context, GuardEmergencyScreen(session: session))),
      _Item(Icons.settings_outlined, 'Settings', 'Biometric lock & shift', () => _open(context, GuardSettingsScreen(session: session))),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: brand.primary),
                  const Spacer(),
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(item.subtitle, style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Item {
  const _Item(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
