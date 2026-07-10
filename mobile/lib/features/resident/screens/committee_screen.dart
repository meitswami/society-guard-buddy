import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/committee_duty.dart';
import '../../../models/committee_member.dart';
import '../../../models/session_models.dart';
import '../../../services/committee_duty_service.dart';
import '../../../services/committee_service.dart';

class CommitteeScreen extends StatefulWidget {
  const CommitteeScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<CommitteeScreen> createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen> {
  final _service = CommitteeService();
  final _dutyService = CommitteeDutyService();
  List<CommitteeMember> _members = const [];
  CommitteeDutiesChart? _dutiesChart;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.fetchActive(widget.session.societyId),
      _dutyService.fetchActiveChart(widget.session.societyId),
    ]);
    if (!mounted) return;
    setState(() {
      _members = results[0] as List<CommitteeMember>;
      _dutiesChart = results[1] as CommitteeDutiesChart?;
      _loading = false;
    });
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Widget _buildDutiesChart(KutumbikaBrandTheme brand) {
    final chart = _dutiesChart;
    if (chart == null) return const SizedBox.shrink();

    final periodLabel = chart.periodTo != null
        ? '${_formatDate(chart.periodFrom)} → ${_formatDate(chart.periodTo!)}'
        : '${_formatDate(chart.periodFrom)} → Ongoing';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, size: 18, color: brand.primary),
                const SizedBox(width: 8),
                const Text('Standard Duties Chart', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Period: $periodLabel', style: const TextStyle(color: KutumbikaColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            ...chart.rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(row.dutyLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.supervisorNames.join(', '),
                        style: const TextStyle(color: KutumbikaColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    final hasDuties = _dutiesChart != null;
    final isEmpty = _members.isEmpty && !hasDuties;

    return Scaffold(
      appBar: AppBar(title: const Text('Managing committee')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No committee information listed', style: TextStyle(color: KutumbikaColors.textMuted))),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        if (hasDuties) _buildDutiesChart(brand),
                        if (_members.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, hasDuties ? 20 : 16, 16, 8),
                            child: Text(
                              'Committee members',
                              style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary),
                            ),
                          ),
                          ...List.generate(_members.length, (index) {
                            final m = _members[index];
                            final displayName = m.showRepresentative && (m.repName?.isNotEmpty ?? false)
                                ? m.repName!
                                : m.name;
                            final displayPhone = m.showRepresentative && (m.repPhone?.isNotEmpty ?? false)
                                ? m.repPhone
                                : m.phone;
                            final photo = m.showRepresentative && (m.repName?.isNotEmpty ?? false)
                                ? null
                                : m.photo;

                            return Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: brand.primary.withValues(alpha: 0.12),
                                    backgroundImage: photo != null && photo.isNotEmpty
                                        ? CachedNetworkImageProvider(photo)
                                        : null,
                                    child: photo == null || photo.isEmpty
                                        ? Icon(Icons.person, color: brand.primary)
                                        : null,
                                  ),
                                  title: Text(displayName),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.position, style: TextStyle(color: brand.primary, fontWeight: FontWeight.w500)),
                                      if (m.flatNumber != null && m.flatNumber!.isNotEmpty)
                                        Text('Flat ${m.flatNumber}'),
                                      if (displayPhone != null && displayPhone.isNotEmpty) Text(displayPhone),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                                if (index < _members.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
            ),
    );
  }
}
