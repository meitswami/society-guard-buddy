import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import 'admin_broadcast_screen.dart';
import 'admin_finance_screen.dart';
import 'admin_polls_hub_screen.dart';
import 'admin_flats_screen.dart';
import 'admin_guards_screen.dart';
import 'admin_residents_screen.dart';
import '../shared/widgets/biometric_settings_tile.dart';
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  int _residents = 0;
  int _guards = 0;
  int _visitorsToday = 0;
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
    final sid = widget.session.societyId;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final flats = await SupabaseBootstrap.client
        .from('flats')
        .select('id')
        .eq('society_id', sid);
    final flatIds = (flats as List).map((f) => f['id']).toList();

    int residents = 0;
    if (flatIds.isNotEmpty) {
      final ru = await SupabaseBootstrap.client
          .from('resident_users')
          .select('id')
          .inFilter('flat_id', flatIds);
      residents = (ru as List).length;
    }

    final guards = await SupabaseBootstrap.client
        .from('guards')
        .select('id')
        .eq('society_id', sid);

    final visitors = await SupabaseBootstrap.client
        .from('visitors')
        .select('id')
        .eq('society_id', sid)
        .gte('entry_time', '${today}T00:00:00');

    if (!mounted) return;
    setState(() {
      _residents = residents;
      _guards = (guards as List).length;
      _visitorsToday = (visitors as List).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);
    final p = widget.session.admin.permissions;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final modules = <_Module>[
      if (p.residentsRw) _Module('Residents', Icons.people),
      if (p.residentsRw) _Module('Flats', Icons.apartment),
      if (p.guardsRw) _Module('Guards', Icons.shield),
      if (p.finance) _Module('Finance', Icons.account_balance_wallet),
      if (p.events) _Module('Events', Icons.event),
      if (p.meetings) _Module('Meetings', Icons.groups),
      if (p.polls) _Module('Polls', Icons.how_to_vote),
      if (p.notifications) _Module('Notifications', Icons.campaign),
      if (p.visitor) _Module('Visitors', Icons.badge),
      if (p.report) _Module('Reports', Icons.bar_chart),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      color: brand.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome, ${widget.session.admin.name}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Residents', value: '$_residents'),
              _Stat(label: 'Guards', value: '$_guards'),
              _Stat(label: 'Visitors today', value: '$_visitorsToday'),
            ],
          ),
          const SizedBox(height: 24),
          Text('Modules', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...modules.map(
            (m) => Card(
              child: ListTile(
                leading: Icon(m.icon, color: brand.primary),
                title: Text(m.title),
                subtitle: const Text('Full UI on web — mobile summary'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (m.title == 'Notifications' && p.notifications) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminBroadcastScreen(session: widget.session),
                      ),
                    );
                    return;
                  }
                  if (m.title == 'Residents' && p.residentsRw) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminResidentsScreen(session: widget.session),
                      ),
                    );
                    return;
                  }
                  if (m.title == 'Flats' && p.residentsRw) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminFlatsScreen(session: widget.session),
                      ),
                    );
                    return;
                  }
                  if (m.title == 'Guards' && p.guardsRw) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminGuardsScreen(session: widget.session),
                      ),
                    );
                    return;
                  }
                  if (m.title == 'Polls' && p.polls) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminPollsHubScreen(session: widget.session),
                      ),
                    );
                    return;
                  }
                  if (m.title == 'Finance' && p.finance) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminFinanceScreen(session: widget.session),
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${m.title} — use web for full management')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: BiometricSettingsTile(
              session: widget.session,
              quickLoginEnabled: p.biometric,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Permission-gated tabs match web AdminDashboard. Detailed finance, reports, and settings remain on web for now.',
            style: theme.textTheme.bodySmall?.copyWith(color: KutumbikaColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Module {
  const _Module(this.title, this.icon);
  final String title;
  final IconData icon;
}
