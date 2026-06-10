import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/visitor_service.dart';

class GuardDashboardScreen extends StatefulWidget {
  const GuardDashboardScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();
}

class _GuardDashboardScreenState extends State<GuardDashboardScreen> {
  final _service = VisitorService();
  List<VisitorEntry> _visitors = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchToday(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _visitors = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);

    final visitors = _visitors.where((v) => v.category == 'visitor').length;
    final deliveries = _visitors
        .where((v) => v.category == 'delivery' || v.category == 'service')
        .length;
    final inside = _visitors.where((v) => v.isInside).length;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      color: brand.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Today\'s gate activity',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCard(label: 'Visitors', value: '$visitors', color: brand.primary),
              const SizedBox(width: 8),
              _StatCard(label: 'Deliveries', value: '$deliveries', color: KutumbikaColors.announcementBlue),
              const SizedBox(width: 8),
              _StatCard(label: 'Inside', value: '$inside', color: KutumbikaColors.success),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent entries', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._visitors.take(10).map(
                (v) => Card(
                  child: ListTile(
                    title: Text(v.name),
                    subtitle: Text('Flat ${v.flatNumber} · ${v.category}'),
                    trailing: v.isInside
                        ? const Icon(Icons.door_front_door, color: KutumbikaColors.success)
                        : const Icon(Icons.logout),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
