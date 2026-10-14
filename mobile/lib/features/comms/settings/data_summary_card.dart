import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/settings_repository.dart';

/// Settings → Data summary (web: flats, members, vehicles, visitors, blacklist stat cards).
class DataSummaryCard extends StatefulWidget {
  const DataSummaryCard({super.key, required this.societyId});

  final String societyId;

  @override
  State<DataSummaryCard> createState() => _DataSummaryCardState();
}

class _DataSummaryCardState extends State<DataSummaryCard> {
  SocietyDataSummary? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d =
          await const SettingsRepository().loadDataSummary(widget.societyId);
      if (mounted) setState(() => _data = d);
    } catch (_) {
      if (mounted) setState(() => _data = const SocietyDataSummary());
    }
  }

  Widget _card(BuildContext context, String key, int? value) =>
      DescriptiveStatCard(
        compact: true,
        title: context.ct('comms.metric.$key.title'),
        description: context.ct('comms.metric.$key.desc'),
        howCalculated: context.ct('comms.metric.$key.how'),
        value: value == null ? '…' : Fmt.number(value),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(context.t('settings.dataSummary'),
              icon: Icons.shield_outlined,
              padding: const EdgeInsets.only(bottom: 12)),
          StatGrid(
            spacing: 8,
            children: [
              _card(context, 'flats', d?.flats),
              _card(context, 'members', d?.members),
              _card(context, 'vehicles', d?.vehicles),
              _card(context, 'visitors', d?.visitors),
            ],
          ),
          const SizedBox(height: 8),
          _card(context, 'blacklist', d?.blacklist),
        ],
      ),
    );
  }
}
