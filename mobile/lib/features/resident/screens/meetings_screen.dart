import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/meeting.dart';
import '../../../models/session_models.dart';
import '../../../services/meeting_service.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _service = MeetingService();
  List<SocietyMeeting> _meetings = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchPublished(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _meetings = rows;
      _loading = false;
    });
  }

  String _formatWhen(String iso) {
    try {
      return DateFormat('EEE, d MMM yyyy · h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _meetings.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No published meetings', style: TextStyle(color: KutumbikaColors.textMuted))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _meetings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = _meetings[index];
                        return Card(
                          child: ExpansionTile(
                            leading: Icon(Icons.event, color: brand.primary),
                            title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(_formatWhen(m.meetingAt)),
                            children: [
                              if (m.location != null && m.location!.isNotEmpty)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_outlined, size: 20),
                                  title: Text(m.location!),
                                ),
                              if (m.description != null && m.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Text(m.description!),
                                ),
                              if (m.minutesSummary != null && m.minutesSummary!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Minutes', style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary)),
                                      const SizedBox(height: 4),
                                      Text(m.minutesSummary!),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
