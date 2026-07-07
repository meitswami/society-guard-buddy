import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/session_models.dart';
import 'committee_screen.dart';
import 'family_members_screen.dart';
import 'feedback_screen.dart';
import 'meetings_screen.dart';
import 'polls_screen.dart';
import 'society_documents_screen.dart';
import 'vehicles_screen.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({
    super.key,
    required this.session,
    required this.onSelect,
  });

  final SessionResident session;
  final ValueChanged<int> onSelect;

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    final items = [
      _MenuItem(
        Icons.family_restroom_outlined,
        'Family members',
        'View & add',
        () => _openScreen(context, FamilyMembersScreen(session: session)),
      ),
      _MenuItem(
        Icons.directions_car_outlined,
        'Vehicles',
        'Register vehicles',
        () => _openScreen(context, VehiclesScreen(session: session)),
      ),
      _MenuItem(
        Icons.how_to_vote_outlined,
        'Polls & elections',
        'Vote on polls',
        () => _openScreen(context, PollsScreen(session: session)),
      ),
      _MenuItem(
        Icons.groups_outlined,
        'Meetings',
        'Published minutes',
        () => _openScreen(context, MeetingsScreen(session: session)),
      ),
      _MenuItem(
        Icons.folder_copy_outlined,
        'Society documents',
        'Bylaws & notices',
        () => _openScreen(context, SocietyDocumentsScreen(session: session)),
      ),
      _MenuItem(
        Icons.account_balance_outlined,
        'Maintenance payments',
        'Submit & track',
        () => onSelect(6),
      ),
      _MenuItem(
        Icons.feedback_outlined,
        'Complaints & feedback',
        'Send to support',
        () => _openScreen(context, FeedbackScreen(session: session)),
      ),
      _MenuItem(
        Icons.landscape_outlined,
        'Committee',
        'Managing committee',
        () => _openScreen(context, CommitteeScreen(session: session)),
      ),
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
            onTap: () {
              if (item.onTap != null) {
                item.onTap!();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.title} — ${item.subtitle}')),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: brand.primary),
                  const Spacer(),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: KutumbikaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}
