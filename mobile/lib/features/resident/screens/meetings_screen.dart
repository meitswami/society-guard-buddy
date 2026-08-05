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
  final Map<String, List<MeetingAgendaItem>> _agendaByMeeting = {};
  final Map<String, List<MeetingSuggestion>> _suggestionsByMeeting = {};
  final _suggestionCtrl = TextEditingController();
  final _agendaCtrl = TextEditingController();
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _suggestionCtrl.dispose();
    _agendaCtrl.dispose();
    super.dispose();
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

  Future<void> _ensureDetail(String meetingId) async {
    if (_agendaByMeeting.containsKey(meetingId) && _suggestionsByMeeting.containsKey(meetingId)) return;
    final agenda = await _service.fetchAgenda(meetingId);
    final suggestions = await _service.fetchSuggestions(meetingId);
    if (!mounted) return;
    setState(() {
      _agendaByMeeting[meetingId] = agenda;
      _suggestionsByMeeting[meetingId] = suggestions;
    });
  }

  String _formatWhen(String iso) {
    try {
      return DateFormat('EEE, d MMM yyyy · h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  bool _sessionUnlocked(SocietyMeeting m) {
    try {
      final day = DateUtils.dateOnly(DateTime.parse(m.meetingAt).toLocal());
      final today = DateUtils.dateOnly(DateTime.now());
      return !day.isAfter(today);
    } catch (_) {
      return false;
    }
  }

  Future<void> _submitSuggestion(String meetingId) async {
    final text = _suggestionCtrl.text.trim();
    if (text.isEmpty) return;
    await _service.addSuggestion(
      meetingId: meetingId,
      authorName: widget.session.resident.name,
      flatNumber: widget.session.resident.flatNumber,
      memberId: null,
      text: text,
    );
    _suggestionCtrl.clear();
    final suggestions = await _service.fetchSuggestions(meetingId);
    if (!mounted) return;
    setState(() => _suggestionsByMeeting[meetingId] = suggestions);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggestion submitted')));
  }

  Future<void> _submitAgenda(String meetingId) async {
    final text = _agendaCtrl.text.trim();
    if (text.isEmpty) return;
    await _service.proposeAgendaItem(
      meetingId: meetingId,
      title: text,
      proposedByName: widget.session.resident.name,
      proposedByFlat: widget.session.resident.flatNumber,
      memberId: null,
    );
    _agendaCtrl.clear();
    final agenda = await _service.fetchAgenda(meetingId);
    if (!mounted) return;
    setState(() => _agendaByMeeting[meetingId] = agenda);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agenda issue proposed')));
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
                        final unlocked = _sessionUnlocked(m);
                        return Card(
                          child: ExpansionTile(
                            leading: Icon(Icons.event, color: brand.primary),
                            title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(_formatWhen(m.meetingAt)),
                            onExpansionChanged: (open) {
                              if (open) {
                                setState(() => _expandedId = m.id);
                                _suggestionCtrl.clear();
                                _agendaCtrl.clear();
                                void _ensureDetail(m.id);
                              } else if (_expandedId == m.id) {
                                setState(() => _expandedId = null);
                              }
                            },
                            children: [
                              if (m.description != null && m.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Purpose', style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary)),
                                      const SizedBox(height: 4),
                                      Text(m.description!),
                                    ],
                                  ),
                                ),
                              if (m.location != null && m.location!.isNotEmpty)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_outlined, size: 20),
                                  title: Text(m.location!),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Agenda', style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary)),
                                    const SizedBox(height: 4),
                                    ...(_agendaByMeeting[m.id] ?? const []).map(
                                      (a) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text('• ${a.title}${a.status == 'proposed' ? ' (proposed)' : ''}'),
                                      ),
                                    ),
                                    if ((_agendaByMeeting[m.id] ?? const []).isEmpty)
                                      const Text('No agenda items yet', style: TextStyle(color: KutumbikaColors.textMuted, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _expandedId == m.id ? _agendaCtrl : null,
                                      decoration: const InputDecoration(
                                        labelText: 'Propose agenda issue',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _expandedId == m.id ? () => _submitAgenda(m.id) : null,
                                        child: const Text('Submit issue'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Suggestions', style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary)),
                                    const SizedBox(height: 4),
                                    ...(_suggestionsByMeeting[m.id] ?? const []).map(
                                      (s) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Text('${s.suggestionText}\n— ${s.authorName}', style: const TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                    TextField(
                                      controller: _expandedId == m.id ? _suggestionCtrl : null,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Your suggestion',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _expandedId == m.id ? () => _submitSuggestion(m.id) : null,
                                        child: const Text('Submit suggestion'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (unlocked && m.minutesSummary != null && m.minutesSummary!.isNotEmpty)
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
                              if (!unlocked)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Text(
                                    'Attendance, minutes, and session records unlock on the meeting day.',
                                    style: TextStyle(color: KutumbikaColors.textMuted, fontSize: 12),
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
