import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/meeting_repository.dart';
import '../logic/meeting_logic.dart';
import '../models/meeting_models.dart';
import '../widgets/gov_widgets.dart';
import '../widgets/session_audio_player.dart';
import 'meeting_print.dart';
import 'meeting_sheets.dart';
import 'meetings_page.dart';

enum _SaveStatus { idle, saving, saved, error }

/// Meeting notice & record (detail card of web `MeetingManager`).
/// Admins edit with 1 s auto-save; residents read, suggest and propose agenda items.
class MeetingDetailPage extends StatefulWidget {
  const MeetingDetailPage({super.key, required this.viewer, required this.repo, required this.initial});

  final MeetingViewer viewer;
  final MeetingRepository repo;
  final MeetingRow initial;

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> {
  late MeetingRow _m = widget.initial;
  MeetingDetail _d = const MeetingDetail();
  List<MemberPick> _members = const [];
  List<FlatWithMembers> _flats = const [];
  bool _loading = true;

  // Notice drafts (admin).
  final _title = TextEditingController();
  final _purpose = TextEditingController();
  final _location = TextEditingController();
  final _executives = TextEditingController();
  final _discussion = TextEditingController();
  final _minutes = TextEditingController();
  String _date = '';
  String _time = '';
  MeetingKind _kind = MeetingKind.other;
  final Map<String, TextEditingController> _decisionDrafts = {};

  Timer? _metaTimer;
  Timer? _decisionTimer;
  Timer? _savedReset;
  _SaveStatus _status = _SaveStatus.idle;
  DateTime? _lastSavedAt;

  // Inputs.
  final _agendaDraft = TextEditingController();
  final _suggestionDraft = TextEditingController();
  final _residentAgendaDraft = TextEditingController();
  final _guestName = TextEditingController();
  String? _memberToAdd;
  final Set<String> _selection = {};
  bool _notifyWhatsapp = false;
  bool _notifyEmail = false;
  bool _busy = false;

  // Recording / dictation.
  AudioRecorder? _recorder;
  bool _recording = false;
  String? _recordPath;
  final SpeechToText _speech = SpeechToText();
  bool _dictating = false;

  bool get _isResident => widget.viewer.isResident;
  bool get _hi => context.lang == AppLang.hi;
  bool get _sessionUnlocked => isSessionDayOrPast(_m.meetingAt);
  String get _adminName => widget.viewer.adminName;

  @override
  void initState() {
    super.initState();
    _hydrate();
    for (final c in [_title, _purpose, _location, _executives, _discussion, _minutes]) {
      c.addListener(_scheduleMetaFlush);
    }
    _loadAll();
  }

  @override
  void dispose() {
    final pendingMeta = _metaTimer?.isActive ?? false;
    final pendingDecisions = _decisionTimer?.isActive ?? false;
    _metaTimer?.cancel();
    _decisionTimer?.cancel();
    _savedReset?.cancel();
    if (!_isResident) {
      // Persist anything typed in the last second before leaving.
      if (pendingDecisions) unawaited(_flushDecisions(silent: true));
      if (pendingMeta) unawaited(_flushMeeting(silent: true));
    }
    if (_recording) unawaited(_stopRecording(fromDispose: true));
    if (_dictating) unawaited(_speech.stop());
    Future<void>.delayed(const Duration(seconds: 2), () {
      for (final c in [
        _title, _purpose, _location, _executives, _discussion, _minutes,
        _agendaDraft, _suggestionDraft, _residentAgendaDraft, _guestName,
        ..._decisionDrafts.values,
      ]) {
        c.dispose();
      }
    });
    super.dispose();
  }

  void _hydrate() {
    _title.text = _m.title;
    _purpose.text = _m.description ?? '';
    _location.text = _m.location ?? '';
    _executives.text = _m.executivesPresent ?? '';
    _discussion.text = _m.discussionNotes ?? '';
    _minutes.text = _m.minutesSummary ?? '';
    _date = toDateInput(_m.meetingAt);
    _time = toTimeInput(_m.meetingAt);
    _kind = _m.meetingKind;
  }

  Future<void> _loadAll() async {
    try {
      await Future.wait([
        _loadDetail(),
        if (!_isResident)
          () async {
            final r = await Future.wait([widget.repo.loadMembers(), widget.repo.loadFlatsWithMembers()]);
            if (!mounted) return;
            setState(() {
              _members = r[0] as List<MemberPick>;
              _flats = r[1] as List<FlatWithMembers>;
            });
          }(),
      ]);
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetail() async {
    final d = await widget.repo.loadDetail(_m.id);
    if (!mounted) return;
    setState(() {
      _d = d;
      final ids = d.decisions.map((x) => x.id).toSet();
      for (final id in _decisionDrafts.keys.where((k) => !ids.contains(k)).toList()) {
        _decisionDrafts.remove(id)?.dispose();
      }
      for (final dec in d.decisions) {
        if (!_decisionDrafts.containsKey(dec.id)) {
          final c = TextEditingController(text: dec.decisionText);
          c.addListener(_scheduleDecisionFlush);
          _decisionDrafts[dec.id] = c;
        }
      }
      _selection.retainWhere((id) => d.attendees.any((a) => a.id == id));
    });
  }

  Future<void> _reloadMeeting() async {
    final row = await widget.repo.loadMeeting(_m.id);
    if (row != null && mounted) setState(() => _m = row);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  // ---------------------------------------------------------------- auto-save

  void _scheduleMetaFlush() {
    if (_isResident) return;
    _metaTimer?.cancel();
    _metaTimer = Timer(const Duration(seconds: 1), () => _flushMeeting());
  }

  void _scheduleDecisionFlush() {
    if (_isResident || !_sessionUnlocked) return;
    _decisionTimer?.cancel();
    _decisionTimer = Timer(const Duration(seconds: 1), () => _flushDecisions());
  }

  void _setStatus(_SaveStatus s) {
    if (!mounted) return;
    setState(() {
      _status = s;
      if (s == _SaveStatus.saved) _lastSavedAt = DateTime.now();
    });
    if (s == _SaveStatus.saved) {
      _savedReset?.cancel();
      _savedReset = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && _status == _SaveStatus.saved) setState(() => _status = _SaveStatus.idle);
      });
    }
  }

  /// Web `flushMeetingDraftsToServer`.
  Future<bool> _flushMeeting({bool manual = false, bool quiet = false, bool silent = false}) async {
    if (_isResident) return false;
    final server = _m;
    final patch = <String, dynamic>{};
    final mt = _title.text.trim().isEmpty ? 'Meeting' : _title.text.trim();
    if (mt != server.title.trim()) patch['title'] = mt;
    if (normText(_purpose.text) != normText(server.description)) patch['description'] = normText(_purpose.text);
    final at = combineDateAndTimeToIso(_date, _time);
    if (!sameInstant(at, server.meetingAt)) patch['meeting_at'] = at;
    if (normText(_location.text) != normText(server.location)) patch['location'] = normText(_location.text);
    if (_kind != server.meetingKind) patch['meeting_kind'] = _kind.value;
    if (_sessionUnlocked) {
      if (normText(_discussion.text) != normText(server.discussionNotes)) patch['discussion_notes'] = normText(_discussion.text);
      if (normText(_minutes.text) != normText(server.minutesSummary)) patch['minutes_summary'] = normText(_minutes.text);
      if (normText(_executives.text) != normText(server.executivesPresent)) {
        patch['executives_present'] = normText(_executives.text);
      }
    }
    if (patch.isEmpty) {
      if (manual && mounted) GovToast.info(context, context.tr('Nothing new to save', 'सहेजने को कुछ नया नहीं'));
      return false;
    }
    if (!silent) _setStatus(_SaveStatus.saving);
    try {
      await widget.repo.patchMeeting(server.id, patch);
    } catch (e) {
      if (!silent) {
        _setStatus(_SaveStatus.error);
        if (mounted) GovToast.error(context, GovBackend.errorText(e));
      }
      return false;
    }
    if (silent) return true;
    _setStatus(_SaveStatus.saved);
    await _reloadMeeting();
    if (manual && !quiet && mounted) GovToast.ok(context, context.tr('Saved', 'सहेजा गया'));
    return true;
  }

  /// Web `flushDecisionDraftsToServer`.
  Future<void> _flushDecisions({bool silent = false}) async {
    if (_isResident || !_sessionUnlocked) return;
    final pending = _d.decisions.where((d) {
      final draft = _decisionDrafts[d.id]?.text;
      return draft != null && draft != d.decisionText;
    }).toList();
    if (pending.isEmpty) return;
    if (!silent) _setStatus(_SaveStatus.saving);
    for (final d in pending) {
      try {
        await widget.repo.updateDecision(d.id, _decisionDrafts[d.id]!.text);
      } catch (e) {
        if (!silent) {
          if (mounted) GovToast.error(context, GovBackend.errorText(e));
          _setStatus(_SaveStatus.error);
        }
        return;
      }
    }
    if (silent) return;
    _setStatus(_SaveStatus.saved);
    await _loadDetail();
  }

  Future<void> _saveNow() async {
    _metaTimer?.cancel();
    _decisionTimer?.cancel();
    await _flushDecisions();
    await _flushMeeting(manual: true);
  }

  Future<void> _persist(Map<String, dynamic> patch) async {
    try {
      await widget.repo.patchMeeting(_m.id, patch);
      await _reloadMeeting();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  // ---------------------------------------------------------------- notice

  Future<void> _onStatusChange(String? v) async {
    if (v == null || v == _m.status) return;
    final ok = await govConfirm(
      context,
      title: context.tr('Change meeting status?', 'बैठक की स्थिति बदलें?'),
      message: context.tr('Set status to “$v”.', 'स्थिति “${meetingStatusLabel(v, hi: true)}” करें।'),
      confirmLabel: context.tr('Update', 'अद्यतन करें'),
    );
    if (ok) await _persist({'status': v});
  }

  Future<void> _unpublish() async {
    final ok = await govConfirm(
      context,
      title: context.tr('Unpublish meeting?', 'बैठक अप्रकाशित करें?'),
      message: context.tr('Residents may no longer see this as published until you publish again.',
          'दोबारा प्रकाशित करने तक निवासी इसे प्रकाशित रूप में नहीं देख सकेंगे।'),
      confirmLabel: context.tr('Unpublish', 'अप्रकाशित करें'),
    );
    if (ok) await _persist({'published': false});
  }

  Future<void> _publishNotice() async {
    final ok = await govConfirm(
      context,
      title: context.tr('Publish meeting notice to all residents?', 'बैठक सूचना सभी निवासियों को प्रकाशित करें?'),
      message: context.tr(
          'Marks the meeting published and sends an in-app notification (and push where configured) with date, time, venue, and purpose.',
          'बैठक प्रकाशित चिह्नित होगी और तिथि, समय, स्थान व उद्देश्य सहित इन-ऐप सूचना (और पुश) भेजी जाएगी।'),
      confirmLabel: context.tr('Publish & notify', 'प्रकाशित करें व सूचित करें'),
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      _metaTimer?.cancel();
      await _flushMeeting(manual: true, quiet: true);
      await _persist({'published': true});
      final title = 'Meeting notice: ${_title.text.isNotEmpty ? _title.text : (_m.title.isNotEmpty ? _m.title : 'Meeting')}';
      final when = Fmt.dateTimeFull(combineDateAndTimeToIso(_date, _time));
      final body = meetingPublishNoticeBody(
        purpose: _purpose.text.isNotEmpty ? _purpose.text : (_m.description ?? ''),
        when: when,
        location: _location.text,
      );
      await GovBackend.notifyResidentsOfMeeting(
        societyId: widget.viewer.societyId,
        createdBy: _adminName,
        title: title,
        body: body,
        whatsapp: _notifyWhatsapp,
        email: _notifyEmail,
      );
      if (mounted) GovToast.ok(context, context.tr('Notice published and sent to residents', 'सूचना प्रकाशित हुई और निवासियों को भेजी गई'));
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await govConfirm(
      context,
      title: context.tr('Delete meeting?', 'बैठक हटाएँ?'),
      message: context.tr('Removes attendees, decisions, documents, and signatures.', 'उपस्थित, निर्णय, दस्तावेज़ और हस्ताक्षर हट जाएँगे।'),
      confirmLabel: context.tr('Delete', 'हटाएँ'),
      destructive: true,
    );
    if (!ok) return;
    try {
      _metaTimer?.cancel();
      _decisionTimer?.cancel();
      await widget.repo.deleteMeeting(_m.id);
      if (!mounted) return;
      GovToast.ok(context, context.tr('Deleted', 'हटाया गया'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  Future<void> _print() => MeetingPrint.printDetail(
        title: (!_isResident ? _title.text.trim() : _m.title).isEmpty ? _m.title : (!_isResident ? _title.text.trim() : _m.title),
        meetingAt: !_isResident ? combineDateAndTimeToIso(_date, _time) : _m.meetingAt,
        location: !_isResident ? _location.text : (_m.location ?? ''),
        kind: !_isResident ? _kind : _m.meetingKind,
        status: _m.status,
        published: _m.published,
        executives: !_isResident ? _executives.text : (_m.executivesPresent ?? ''),
        discussion: !_isResident ? _discussion.text : (_m.discussionNotes ?? ''),
        minutes: !_isResident ? _minutes.text : (_m.minutesSummary ?? ''),
        decisions: ([..._d.decisions]..sort((a, b) => a.sortOrder - b.sortOrder))
            .map((d) => !_isResident ? (_decisionDrafts[d.id]?.text ?? d.decisionText) : d.decisionText)
            .toList(),
        attendees: _d.attendees,
      );

  // ---------------------------------------------------------------- agenda

  Future<void> _addAgenda() async {
    final text = _agendaDraft.text.trim();
    if (text.isEmpty) return;
    await _guard(() async {
      await widget.repo.insertAgendaItems([
        {'meeting_id': _m.id, 'title': text, 'sort_order': _d.agendaItems.length, 'source': 'admin', 'status': 'accepted'},
      ]);
      _agendaDraft.clear();
      await _loadDetail();
    });
  }

  Future<void> _setAgendaStatus(String id, String status) =>
      _guard(() async {
        await widget.repo.setAgendaStatus(id, status);
        await _loadDetail();
      });

  Future<void> _removeAgenda(String id) async {
    final ok = await govConfirm(
      context,
      title: context.tr('Remove agenda item?', 'कार्यसूची विषय हटाएँ?'),
      message: context.tr('This removes the item from the meeting agenda.', 'यह विषय बैठक की कार्यसूची से हटेगा।'),
      confirmLabel: context.tr('Remove', 'हटाएँ'),
      destructive: true,
    );
    if (!ok) return;
    await _guard(() async {
      await widget.repo.deleteAgendaItem(id);
      await _loadDetail();
    });
  }

  String get _residentName => widget.viewer.residentName.trim().isEmpty ? 'Resident' : widget.viewer.residentName.trim();

  Future<void> _submitSuggestion() async {
    final text = _suggestionDraft.text.trim();
    if (text.isEmpty) return;
    await _guard(() async {
      await widget.repo.addSuggestion({
        'meeting_id': _m.id,
        'member_id': widget.viewer.residentMemberId,
        'author_name': _residentName,
        'flat_number': widget.viewer.residentFlatNumber.isEmpty ? null : widget.viewer.residentFlatNumber,
        'suggestion_text': text,
      });
      _suggestionDraft.clear();
      if (mounted) GovToast.ok(context, context.tr('Suggestion submitted', 'सुझाव भेजा गया'));
      await _loadDetail();
    });
  }

  Future<void> _submitResidentAgenda() async {
    final text = _residentAgendaDraft.text.trim();
    if (text.isEmpty) return;
    await _guard(() async {
      await widget.repo.insertAgendaItems([
        {
          'meeting_id': _m.id,
          'title': text,
          'sort_order': _d.agendaItems.length,
          'source': 'resident',
          'status': 'proposed',
          'proposed_by_member_id': widget.viewer.residentMemberId,
          'proposed_by_name': _residentName,
          'proposed_by_flat': widget.viewer.residentFlatNumber.isEmpty ? null : widget.viewer.residentFlatNumber,
        },
      ]);
      _residentAgendaDraft.clear();
      if (mounted) {
        GovToast.ok(context, context.tr('Agenda issue proposed for committee review', 'विषय समिति की समीक्षा हेतु प्रस्तावित'));
      }
      await _loadDetail();
    });
  }

  // ---------------------------------------------------------------- attendance

  Map<String?, bool> get _presentByMember => {for (final a in _d.attendees) a.memberId: a.isPresent};

  Future<void> _setFlatPresence(FlatWithMembers flat, bool present) async {
    if (flat.members.isEmpty) {
      GovToast.info(context, context.tr('No members on this flat yet — add residents first.', 'इस फ्लैट पर अभी कोई सदस्य नहीं — पहले निवासी जोड़ें।'));
      return;
    }
    final ok = await govConfirm(
      context,
      title: present ? context.tr('Mark flat present?', 'फ्लैट उपस्थित चिह्नित करें?') : context.tr('Remove flat from attendance?', 'फ्लैट को उपस्थिति से हटाएँ?'),
      message: present
          ? context.tr('Add everyone in flat ${flat.flatNumber} to the attendance list as present.',
              'फ्लैट ${flat.flatNumber} के सभी सदस्यों को उपस्थित के रूप में जोड़ें।')
          : context.tr('Remove all members of flat ${flat.flatNumber} from this meeting’s attendance list.',
              'फ्लैट ${flat.flatNumber} के सभी सदस्यों को इस बैठक की उपस्थिति सूची से हटाएँ।'),
      confirmLabel: present ? context.tr('Mark present', 'उपस्थित चिह्नित करें') : context.tr('Remove', 'हटाएँ'),
    );
    if (!ok) return;
    await _guard(() async {
      for (final m in flat.members) {
        final existing = _d.attendees.where((a) => a.memberId == m.id).firstOrNull;
        if (present) {
          if (existing != null) {
            await widget.repo.updateAttendee(existing.id, {'is_present': true, 'flat_number': flat.flatNumber});
          } else {
            await widget.repo.insertAttendees([
              {
                'meeting_id': _m.id,
                'member_id': m.id,
                'display_name': m.name,
                'flat_number': flat.flatNumber,
                'attendee_role': 'member',
                'is_present': true,
              },
            ]);
          }
        } else if (existing != null) {
          await widget.repo.deleteAttendee(existing.id);
        }
      }
      if (mounted) {
        if (present) {
          GovToast.ok(context, context.tr('Marked ${flat.flatNumber} present', '${flat.flatNumber} उपस्थित चिह्नित'));
        } else {
          GovToast.info(context, context.tr('Cleared ${flat.flatNumber} from attendance', '${flat.flatNumber} उपस्थिति से हटाया'));
        }
      }
    });
    await _loadDetail();
  }

  Future<void> _addMember() async {
    final m = _members.where((x) => x.id == _memberToAdd).firstOrNull;
    if (m == null) return;
    if (_d.attendees.any((a) => a.memberId == m.id)) {
      GovToast.info(context, context.tr('Already on the list', 'पहले से सूची में'));
      return;
    }
    await _guard(() async {
      await widget.repo.insertAttendees([
        {'meeting_id': _m.id, 'member_id': m.id, 'display_name': m.name, 'flat_number': m.flatNumber, 'attendee_role': 'member', 'is_present': true},
      ]);
      setState(() => _memberToAdd = null);
      await _loadDetail();
    });
  }

  Future<void> _tablePick() async {
    final ids = await showMemberPickerSheet(
      context,
      members: _members,
      onListMemberIds: _d.attendees.map((a) => a.memberId).whereType<String>().toSet(),
    );
    if (ids == null || !mounted) return;
    final toAdd = ids.where((id) => !_d.attendees.any((a) => a.memberId == id)).toList();
    if (toAdd.isEmpty) {
      GovToast.info(context, context.tr('Select members not already on the list', 'जो सूची में नहीं हैं उन्हें चुनें'));
      return;
    }
    await _guard(() async {
      await widget.repo.insertAttendees([
        for (final id in toAdd)
          () {
            final m = _members.firstWhere((x) => x.id == id);
            return {
              'meeting_id': _m.id,
              'member_id': m.id,
              'display_name': m.name,
              'flat_number': m.flatNumber,
              'attendee_role': 'member',
              'is_present': true,
            };
          }(),
      ]);
      if (mounted) GovToast.ok(context, context.tr('Added ${toAdd.length} attendee(s)', '${toAdd.length} उपस्थित जोड़े'));
      await _loadDetail();
    });
  }

  Future<void> _addGuest() async {
    final name = _guestName.text.trim();
    if (name.isEmpty) return;
    await _guard(() async {
      await widget.repo.insertAttendees([
        {
          'meeting_id': _m.id,
          'member_id': null,
          'display_name': name,
          'guest_name': name,
          'flat_number': null,
          'attendee_role': 'guest',
          'is_present': true,
        },
      ]);
      _guestName.clear();
      await _loadDetail();
    });
  }

  Future<void> _addAdmin() => _guard(() async {
        await widget.repo.insertAttendees([
          {'meeting_id': _m.id, 'member_id': null, 'display_name': _adminName, 'attendee_role': 'admin', 'is_present': true},
        ]);
        await _loadDetail();
      });

  Future<void> _togglePresent(AttendeeRow a) async {
    final ok = await govConfirm(
      context,
      title: a.isPresent ? context.tr('Mark absent?', 'अनुपस्थित चिह्नित करें?') : context.tr('Mark present?', 'उपस्थित चिह्नित करें?'),
      message: context.tr('Update attendance for ${a.displayName}.', '${a.displayName} की उपस्थिति अद्यतन करें।'),
      confirmLabel: context.tr('Update', 'अद्यतन करें'),
    );
    if (!ok) return;
    await _guard(() async {
      await widget.repo.updateAttendee(a.id, {'is_present': !a.isPresent});
      await _loadDetail();
    });
  }

  Future<void> _removeAttendee(AttendeeRow a) async {
    final ok = await govConfirm(
      context,
      title: context.tr('Remove attendee?', 'उपस्थित हटाएँ?'),
      message: context.tr('Remove “${a.displayName}” from this meeting’s attendance list.',
          '“${a.displayName}” को इस बैठक की उपस्थिति सूची से हटाएँ।'),
      confirmLabel: context.tr('Remove', 'हटाएँ'),
      destructive: true,
    );
    if (!ok) return;
    await _guard(() async {
      await widget.repo.deleteAttendee(a.id);
      _selection.remove(a.id);
      await _loadDetail();
    });
  }

  Future<void> _bulk(String mode) async {
    if (_selection.isEmpty) {
      GovToast.info(context, context.tr('Select at least one attendee', 'कम-से-कम एक उपस्थित चुनें'));
      return;
    }
    final n = _selection.length;
    final (title, msg, label, destructive) = switch (mode) {
      'present' => (
          context.tr('Mark selected present?', 'चयनित को उपस्थित करें?'),
          context.tr('Set $n attendee(s) as present.', '$n उपस्थित को उपस्थित चिह्नित करें।'),
          context.tr('Update', 'अद्यतन करें'),
          false,
        ),
      'absent' => (
          context.tr('Mark selected absent?', 'चयनित को अनुपस्थित करें?'),
          context.tr('Set $n attendee(s) as absent (they stay on the list).', '$n को अनुपस्थित चिह्नित करें (सूची में रहेंगे)।'),
          context.tr('Update', 'अद्यतन करें'),
          false,
        ),
      _ => (
          context.tr('Remove selected attendees?', 'चयनित उपस्थित हटाएँ?'),
          context.tr('Permanently remove $n row(s) from this meeting. Signatures on documents may become orphaned.',
              'इस बैठक से $n पंक्तियाँ स्थायी रूप से हटेंगी। दस्तावेज़ों के हस्ताक्षर अनाथ हो सकते हैं।'),
          context.tr('Remove', 'हटाएँ'),
          true,
        ),
    };
    final ok = await govConfirm(context, title: title, message: msg, confirmLabel: label, destructive: destructive);
    if (!ok) return;
    await _guard(() async {
      for (final id in _selection.toList()) {
        if (mode == 'remove') {
          await widget.repo.deleteAttendee(id);
        } else {
          await widget.repo.updateAttendee(id, {'is_present': mode == 'present'});
        }
      }
      if (mounted) {
        GovToast.ok(context, mode == 'remove' ? context.tr('Removed', 'हटाया गया') : context.tr('Attendance updated', 'उपस्थिति अद्यतन'));
      }
      setState(_selection.clear);
      await _loadDetail();
    });
  }

  // ---------------------------------------------------------------- decisions

  Future<void> _addDecision() => _guard(() async {
        await widget.repo.addDecision(_m.id, _d.decisions.length);
        await _loadDetail();
      });

  Future<void> _removeDecision(String id) async {
    final ok = await govConfirm(
      context,
      title: context.tr('Delete decision?', 'निर्णय हटाएँ?'),
      message: context.tr('This removes one decision line from the meeting record.', 'यह बैठक अभिलेख से एक निर्णय पंक्ति हटाएगा।'),
      confirmLabel: context.tr('Delete', 'हटाएँ'),
      destructive: true,
    );
    if (!ok) return;
    await _guard(() async {
      await widget.repo.deleteDecision(id);
      await _loadDetail();
    });
  }

  // ---------------------------------------------------------------- documents

  Future<void> _uploadFiles(List<({String name, Uint8List bytes})> files) async {
    final allowed = files.where((f) => isAllowedMeetingAttachment(mimeType: mimeFromFileName(f.name), fileName: f.name)).toList();
    if (allowed.isEmpty) {
      GovToast.error(context, context.tr('Only images and PDF files are supported.', 'केवल चित्र और PDF फ़ाइलें समर्थित हैं।'));
      return;
    }
    if (allowed.length < files.length) {
      final skipped = files.length - allowed.length;
      GovToast.info(context, context.tr('$skipped file(s) skipped (not image or PDF).', '$skipped फ़ाइल छोड़ी गईं (चित्र या PDF नहीं)।'));
    }
    setState(() => _busy = true);
    var next = nextMeetingDocOrder(_d.documents.map((d) => d.sortOrder));
    var uploaded = 0;
    for (final f in allowed) {
      final mime = mimeFromFileName(f.name);
      final url = await widget.repo.upload(meetingId: _m.id, kind: 'docs', bytes: f.bytes, fileName: f.name, contentType: mime);
      if (url == null) {
        if (mounted) GovToast.error(context, context.tr('Upload failed: ${f.name}', 'अपलोड विफल: ${f.name}'));
        continue;
      }
      try {
        final title = stripExtension(f.name);
        await widget.repo.insertDocument({
          'meeting_id': _m.id,
          'title': title.isEmpty ? 'Attachment' : title,
          'file_url': url,
          'file_name': f.name,
          'mime_type': mime,
          'sort_order': next++,
        });
        uploaded += 1;
      } catch (e) {
        if (mounted) GovToast.error(context, '${f.name}: ${GovBackend.errorText(e)}');
      }
    }
    if (mounted) setState(() => _busy = false);
    if (uploaded > 0 && mounted) {
      GovToast.ok(context, uploaded == 1 ? context.tr('File attached', 'फ़ाइल संलग्न') : context.tr('$uploaded files attached', '$uploaded फ़ाइलें संलग्न'));
      await _loadDetail();
    }
  }

  Future<void> _browseFiles() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: meetingDocExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (res == null || !mounted) return;
    await _uploadFiles([
      for (final f in res.files)
        if (f.bytes != null) (name: f.name, bytes: f.bytes!),
    ]);
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera);
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    final name = x.name.contains('.') ? x.name : '${x.name}.jpg';
    await _uploadFiles([(name: name, bytes: bytes)]);
  }

  Future<void> _moveDoc(String id, bool up) async {
    final reordered = moveMeetingDoc(_d.documents, id, up: up, key: (d) => d.order);
    if (reordered == null) return;
    await _guard(() async {
      await Future.wait([for (final (i, d) in reordered.indexed) widget.repo.setDocumentOrder(d.id, i)]);
      await _loadDetail();
    });
  }

  // ---------------------------------------------------------------- audio

  Future<void> _uploadAudioFile() async {
    if ((_m.audioRecordingUrl ?? '').isNotEmpty) {
      final ok = await govConfirm(
        context,
        title: context.tr('Replace session audio?', 'सत्र ऑडियो बदलें?'),
        message: context.tr('This meeting already has a recording. Uploading will replace it with the new file.',
            'इस बैठक की रिकॉर्डिंग पहले से है। अपलोड करने पर नई फ़ाइल से बदल जाएगी।'),
        confirmLabel: context.tr('Replace', 'बदलें'),
      );
      if (!ok) return;
    }
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'webm', 'amr', 'flac', '3gp', 'mp4', 'mov', 'mkv'],
      withData: true,
    );
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null || !mounted) return;
    setState(() => _busy = true);
    final url = await widget.repo.upload(
      meetingId: _m.id,
      kind: 'audio',
      bytes: f.bytes!,
      fileName: f.name,
      contentType: mimeFromFileName(f.name),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (url == null) {
      GovToast.error(context, context.tr('Upload failed', 'अपलोड विफल'));
      return;
    }
    await _persist({'audio_recording_url': url});
    if (mounted) GovToast.ok(context, context.tr('Recording saved to this meeting', 'रिकॉर्डिंग इस बैठक में सहेजी गई'));
  }

  Future<void> _startRecording() async {
    final rec = _recorder ??= AudioRecorder();
    try {
      if (!await rec.hasPermission()) {
        if (mounted) GovToast.error(context, context.tr('Could not access microphone', 'माइक्रोफ़ोन तक पहुँच नहीं'));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/session-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1), path: path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordPath = path;
      });
      GovToast.info(context, context.tr('Recording… tap Stop when the meeting ends.', 'रिकॉर्डिंग… बैठक समाप्त होने पर रोकें दबाएँ।'));
    } catch (_) {
      if (mounted) GovToast.error(context, context.tr('Could not access microphone', 'माइक्रोफ़ोन तक पहुँच नहीं'));
    }
  }

  Future<void> _stopRecording({bool fromDispose = false}) async {
    final rec = _recorder;
    if (rec == null) return;
    String? path;
    try {
      path = await rec.stop();
    } catch (_) {}
    path ??= _recordPath;
    if (!fromDispose && mounted) setState(() => _recording = false);
    _recording = false;
    final file = path == null ? null : File(path);
    if (file == null || !file.existsSync() || file.lengthSync() < 200) {
      if (!fromDispose && mounted) GovToast.info(context, context.tr('Recording too short', 'रिकॉर्डिंग बहुत छोटी'));
      unawaited(rec.dispose());
      _recorder = null;
      return;
    }
    final bytes = await file.readAsBytes();
    final url = await widget.repo.upload(
      meetingId: _m.id,
      kind: 'audio',
      bytes: bytes,
      fileName: 'session-${DateTime.now().millisecondsSinceEpoch}.m4a',
      contentType: 'audio/mp4',
    );
    unawaited(rec.dispose());
    _recorder = null;
    if (url == null) {
      if (!fromDispose && mounted) GovToast.error(context, context.tr('Upload failed', 'अपलोड विफल'));
      return;
    }
    if (fromDispose) {
      try {
        await widget.repo.patchMeeting(_m.id, {'audio_recording_url': url});
      } catch (_) {}
      return;
    }
    await _persist({'audio_recording_url': url});
    if (mounted) GovToast.ok(context, context.tr('Session recording saved', 'सत्र रिकॉर्डिंग सहेजी गई'));
  }

  Future<void> _toggleDictation() async {
    if (_dictating) {
      await _speech.stop();
      if (mounted) setState(() => _dictating = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _dictating = false);
      },
      onError: (_) {
        if (mounted) setState(() => _dictating = false);
      },
    );
    if (!ok) {
      if (mounted) {
        GovToast.error(context, context.tr('Speech recognition not supported on this device.', 'इस उपकरण पर वाक् पहचान समर्थित नहीं।'));
      }
      return;
    }
    if (!mounted) return;
    final hi = _hi;
    await _speech.listen(
      onResult: (r) {
        if (!r.finalResult || r.recognizedWords.isEmpty) return;
        _minutes.text = '${_minutes.text}${r.recognizedWords} ';
      },
      listenOptions: SpeechListenOptions(
        localeId: hi ? 'hi_IN' : 'en_IN',
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 8),
      ),
    );
    if (!mounted) return;
    setState(() => _dictating = true);
    GovToast.info(context, context.tr('Dictating into minutes… tap again to stop.', 'कार्यवृत्त में बोलकर लिखा जा रहा है… रोकने के लिए फिर दबाएँ।'));
  }

  // ---------------------------------------------------------------- minutes publish

  Future<void> _publishMinutes() async {
    final ok = await govConfirm(
      context,
      title: context.tr('Publish minutes to all residents?', 'कार्यवृत्त सभी निवासियों को प्रकाशित करें?'),
      message: context.tr(
          'Saves discussion & minutes, marks the meeting published, sends an in-app notification, and triggers push where configured.',
          'चर्चा व कार्यवृत्त सहेजे जाएँगे, बैठक प्रकाशित होगी, इन-ऐप सूचना और पुश भेजी जाएगी।'),
      confirmLabel: context.tr('Publish', 'प्रकाशित करें'),
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      _metaTimer?.cancel();
      _decisionTimer?.cancel();
      await _flushDecisions();
      await _flushMeeting(manual: true, quiet: true);
      await _persist({'published': true});
      final title = 'Minutes: ${_title.text.isNotEmpty ? _title.text : (_m.title.isNotEmpty ? _m.title : 'Meeting')}';
      await GovBackend.notifyResidentsOfMeeting(
        societyId: widget.viewer.societyId,
        createdBy: _adminName,
        title: title,
        body: meetingMinutesNoticeBody(_minutes.text),
        whatsapp: _notifyWhatsapp,
        email: _notifyEmail,
      );
      if (mounted) {
        GovToast.ok(context, context.tr('Published and sent to all residents (in-app + push where configured).',
            'प्रकाशित और सभी निवासियों को भेजा गया (इन-ऐप + पुश)।'));
      }
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- signatures

  Future<void> _sign(MeetingDocRow doc, AttendeeRow att) async {
    final cap = await showSignatureSheet(context, documentTitle: doc.title, attendeeName: att.displayName);
    if (cap == null || !mounted) return;
    final existing = _d.signatures.where((s) => s.meetingDocumentId == doc.id && s.meetingAttendeeId == att.id).firstOrNull;
    final ok = await govConfirm(
      context,
      title: existing != null ? context.tr('Overwrite signature?', 'हस्ताक्षर बदलें?') : context.tr('Save signature?', 'हस्ताक्षर सहेजें?'),
      message: existing != null
          ? context.tr('This attendee already signed this document. Saving replaces the previous image.',
              'इस उपस्थित ने पहले ही हस्ताक्षर किए हैं। सहेजने पर पिछला चित्र बदल जाएगा।')
          : context.tr('Store this signature on the document for the selected attendee.', 'चयनित उपस्थित के लिए यह हस्ताक्षर दस्तावेज़ पर सहेजें।'),
      confirmLabel: context.tr('Save', 'सहेजें'),
    );
    if (!ok) return;
    final url = await widget.repo.upload(
      meetingId: _m.id,
      kind: 'signatures',
      bytes: Uint8List.fromList(cap.png),
      fileName: '${att.id}.png',
      contentType: 'image/png',
    );
    if (!mounted) return;
    if (url == null) {
      GovToast.error(context, context.tr('Upload failed', 'अपलोड विफल'));
      return;
    }
    final label = cap.signerLabel.trim().isEmpty ? null : cap.signerLabel.trim();
    try {
      if (existing != null) {
        await widget.repo.updateSignature(existing.id, {
          'signature_image_url': url,
          'signer_label': label,
          'signed_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await widget.repo.insertSignature({
          'meeting_document_id': doc.id,
          'meeting_attendee_id': att.id,
          'signature_image_url': url,
          'signer_label': label,
        });
      }
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
    if (mounted) GovToast.ok(context, context.tr('Signature saved', 'हस्ताक्षर सहेजा गया'));
    await _loadDetail();
  }

  // ================================================================= UI

  Widget _label(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 13, color: context.tokens.mutedForeground),
            const SizedBox(width: 4),
            Expanded(child: Text(text, style: AppText.fieldLabel(context))),
          ],
        ),
      );

  Widget _readBox(String text) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTokens.tint(context.tokens.muted, 0.6), borderRadius: BorderRadius.circular(6)),
        child: Text(text.isEmpty ? '—' : text, style: AppText.body(context)),
      );

  Widget _autosaveBox() {
    final t = context.tokens;
    String? line;
    Color? color;
    switch (_status) {
      case _SaveStatus.saving:
        line = context.tr('Saving…', 'सहेजा जा रहा है…');
        color = t.warning;
      case _SaveStatus.error:
        line = context.tr('Save failed — check connection', 'सहेजना विफल — कनेक्शन जाँचें');
        color = t.destructive;
      case _SaveStatus.saved:
        if (_lastSavedAt != null) {
          line = '${context.tr('Last saved', 'अंतिम बार सहेजा')} ${Fmt.dateTimeFull(_lastSavedAt)}';
          color = t.success;
        }
      case _SaveStatus.idle:
        if (_lastSavedAt != null) line = '${context.tr('Last saved', 'अंतिम बार सहेजा')} ${Fmt.dateTimeFull(_lastSavedAt)}';
    }
    return TintBox(
      color: t.primary,
      border: 0.25,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: context.tr('Auto-save', 'स्वतः सहेजें'), style: TextStyle(fontWeight: FontWeight.w600, color: t.foreground)),
                    TextSpan(
                      text: context.tr(
                          ' — notice fields (title, purpose, schedule, venue) save about 1 second after you stop typing. Published notices remain editable.',
                          ' — सूचना फ़ील्ड (शीर्षक, उद्देश्य, समय, स्थान) टाइप रुकने के लगभग 1 सेकंड बाद सहेजे जाते हैं। प्रकाशित सूचनाएँ संपादन योग्य रहती हैं।'),
                    ),
                    if (!_sessionUnlocked)
                      TextSpan(
                        text: context.tr(
                            '\nSession tools (attendance, minutes, recording, decisions) unlock on the meeting day.',
                            '\nसत्र उपकरण (उपस्थिति, कार्यवृत्त, रिकॉर्डिंग, निर्णय) बैठक के दिन खुलते हैं।'),
                        style: TextStyle(color: t.warning),
                      ),
                  ]),
                  style: AppText.caption(context).copyWith(fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              MiniButton(label: context.tr('Save now', 'अभी सहेजें'), variant: MiniVariant.secondary, onPressed: _saveNow),
            ],
          ),
          if (line != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(line, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color ?? t.mutedForeground)),
            ),
        ],
      ),
    );
  }

  Widget _noticeSection() {
    final t = context.tokens;
    if (_isResident) {
      return SectionBox(
        title: context.tr('Meeting notice', 'बैठक सूचना'),
        background: AppTokens.tint(t.muted, 0.2),
        children: [
          Text(_m.title, style: AppText.bodyMedium(context)),
          if ((_m.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_m.description!, style: AppText.body(context)),
          ],
          const SizedBox(height: 6),
          _whenWhere(),
        ],
      );
    }
    return SectionBox(
      title: context.tr('Meeting notice', 'बैठक सूचना'),
      background: AppTokens.tint(t.muted, 0.2),
      children: [
        AppDropdown<MeetingKind>(
          label: context.tr('Meeting type', 'बैठक प्रकार'),
          items: MeetingKind.values,
          value: _kind,
          labelOf: (k) => k.label(_hi),
          onChanged: (v) {
            setState(() => _kind = v ?? MeetingKind.other);
            _scheduleMetaFlush();
          },
        ),
        const SizedBox(height: 8),
        AppTextField(controller: _title, hint: context.tr('Title', 'शीर्षक'), caps: false),
        const SizedBox(height: 8),
        AppTextField(
          controller: _purpose,
          label: context.tr('Purpose', 'उद्देश्य'),
          hint: context.tr('Purpose of the meeting', 'बैठक का उद्देश्य'),
          maxLines: 4,
          minLines: 3,
          caps: false,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GovDateField(
                value: _date,
                clearable: false,
                onChanged: (v) {
                  setState(() => _date = v);
                  _scheduleMetaFlush();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GovTimeField(
                value: _time,
                onChanged: (v) {
                  setState(() => _time = v);
                  _scheduleMetaFlush();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppTextField(controller: _location, hint: context.tr('Venue', 'स्थान'), caps: false),
      ],
    );
  }

  Widget _whenWhere() {
    final t = context.tokens;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Icon(Icons.calendar_today_outlined, size: 12, color: t.mutedForeground),
        Text(Fmt.dateTimeFull(_m.meetingAt), style: AppText.caption(context).copyWith(fontSize: 11)),
        if ((_m.location ?? '').isNotEmpty) ...[
          Icon(Icons.place_outlined, size: 12, color: t.mutedForeground),
          Text(_m.location!, style: AppText.caption(context).copyWith(fontSize: 11)),
        ],
      ],
    );
  }

  Widget _agendaSection() {
    final t = context.tokens;
    return SectionBox(
      title: context.tr('Agenda issues', 'कार्यसूची के विषय'),
      children: [
        if (_d.agendaItems.isEmpty) Text(context.tr('No agenda items yet.', 'अभी कोई विषय नहीं।'), style: AppText.caption(context)),
        for (final (i, item) in _d.agendaItems.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 18, child: Text('${i + 1}.', style: AppText.tiny(context))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppText.body(context).copyWith(
                          decoration: item.status == 'rejected' ? TextDecoration.lineThrough : null,
                          color: item.status == 'rejected' ? t.mutedForeground : null,
                        ),
                      ),
                      Text(
                        item.source == 'resident'
                            ? '${context.tr('Proposed by', 'प्रस्तावक')} ${item.proposedByName ?? context.tr('resident', 'निवासी')}${(item.proposedByFlat ?? '').isNotEmpty ? ' · ${item.proposedByFlat}' : ''} · ${agendaStatusLabel(item.status, hi: _hi)}'
                            : '${context.tr('Committee', 'समिति')} · ${agendaStatusLabel(item.status, hi: _hi)}',
                        style: AppText.tiny(context),
                      ),
                    ],
                  ),
                ),
                if (!_isResident)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (item.status == 'proposed') ...[
                        MiniButton(label: context.tr('Accept', 'स्वीकारें'), fontSize: 10, onPressed: () => _setAgendaStatus(item.id, 'accepted')),
                        const SizedBox(height: 2),
                        MiniButton(
                          label: context.tr('Reject', 'अस्वीकारें'),
                          fontSize: 10,
                          variant: MiniVariant.ghost,
                          onPressed: () => _setAgendaStatus(item.id, 'rejected'),
                        ),
                      ],
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeAgenda(item.id),
                        icon: Icon(Icons.delete_outline, size: 16, color: t.destructive),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (!_isResident)
          Row(
            children: [
              Expanded(child: AppTextField(controller: _agendaDraft, hint: context.tr('Add agenda issue', 'विषय जोड़ें'), caps: false)),
              const SizedBox(width: 8),
              MiniButton(label: context.tr('Add', 'जोड़ें'), icon: Icons.add, variant: MiniVariant.secondary, onPressed: _addAgenda),
            ],
          ),
        if (_isResident) ...[
          Divider(color: t.border),
          Text(context.tr('Propose an issue for the agenda', 'कार्यसूची हेतु विषय प्रस्तावित करें'), style: AppText.tiny(context)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _residentAgendaDraft,
                  hint: context.tr('Issue you want included', 'जो विषय आप शामिल कराना चाहते हैं'),
                  caps: false,
                ),
              ),
              const SizedBox(width: 8),
              MiniButton(label: context.tr('Submit', 'भेजें'), variant: MiniVariant.secondary, onPressed: _submitResidentAgenda),
            ],
          ),
        ],
      ],
    );
  }

  Widget _documentsSection() {
    final t = context.tokens;
    return SectionBox(
      title: context.tr('Documents (PDF / images)', 'दस्तावेज़ (PDF / चित्र)'),
      icon: Icons.description_outlined,
      dashed: true,
      children: [
        if (!_isResident) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MiniButton(label: context.tr('Browse files', 'फ़ाइलें चुनें'), icon: Icons.attach_file, variant: MiniVariant.primary, busy: _busy, onPressed: _browseFiles),
              MiniButton(label: context.tr('Take photo', 'फ़ोटो लें'), icon: Icons.photo_camera_outlined, variant: MiniVariant.secondary, onPressed: _busy ? null : _takePhoto),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_d.documents.isEmpty) Text(context.tr('No attachments.', 'कोई संलग्नक नहीं।'), style: AppText.caption(context)),
        for (final (i, doc) in _d.documents.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => ExportKit.openUrl(doc.fileUrl),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: doc.title,
                          style: TextStyle(color: t.primary, decoration: TextDecoration.underline, decorationColor: t.primary),
                        ),
                        if ((doc.fileName ?? '').toLowerCase().endsWith('.pdf'))
                          TextSpan(text: ' (PDF)', style: AppText.tiny(context)),
                      ]),
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!_isResident) ...[
                  IconPillButton(icon: Icons.keyboard_arrow_up, onPressed: i == 0 ? null : () => _moveDoc(doc.id, true)),
                  const SizedBox(width: 4),
                  IconPillButton(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: i == _d.documents.length - 1 ? null : () => _moveDoc(doc.id, false),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _publishBox() {
    final t = context.tokens;
    return TintBox(
      color: t.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 16, color: t.foreground),
              const SizedBox(width: 4),
              Expanded(
                child: Text(context.tr('Bring to notice of residents', 'निवासियों के संज्ञान में लाएँ'), style: AppText.bodyMedium(context)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _m.published
                ? context.tr('Published — residents can open this notice. You may edit and re-notify if details change.',
                    'प्रकाशित — निवासी यह सूचना खोल सकते हैं। विवरण बदलें तो संपादित कर फिर सूचित करें।')
                : context.tr('Not yet published. Residents will not see this meeting until you publish.',
                    'अभी प्रकाशित नहीं। प्रकाशित करने तक निवासी यह बैठक नहीं देखेंगे।'),
            style: AppText.tiny(context).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 6),
          CheckRow(
            value: _notifyWhatsapp,
            onChanged: (v) => setState(() => _notifyWhatsapp = v),
            label: context.tr('Also WhatsApp directory contacts', 'निर्देशिका संपर्कों को व्हाट्सऐप भी करें'),
          ),
          CheckRow(
            value: _notifyEmail,
            onChanged: (v) => setState(() => _notifyEmail = v),
            label: context.tr('Also email directory contacts', 'निर्देशिका संपर्कों को ईमेल भी करें'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: _m.published ? context.tr('Re-notify residents', 'निवासियों को फिर सूचित करें') : context.tr('Publish & notify', 'प्रकाशित करें व सूचित करें'),
                icon: Icons.send_outlined,
                expand: false,
                loading: _busy,
                onPressed: _publishNotice,
              ),
              if (_m.published)
                AppButton.secondary(label: context.tr('Unpublish', 'अप्रकाशित करें'), expand: false, onPressed: _unpublish),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionsSection() {
    final t = context.tokens;
    return SectionBox(
      title: context.tr('Suggestions from residents', 'निवासियों के सुझाव'),
      children: [
        if (_d.suggestions.isEmpty) Text(context.tr('No suggestions yet.', 'अभी कोई सुझाव नहीं।'), style: AppText.caption(context)),
        for (final s in _d.suggestions)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.6), borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.suggestionText, style: AppText.body(context)),
                const SizedBox(height: 4),
                Text(
                  '${s.authorName}${(s.flatNumber ?? '').isNotEmpty ? ' · ${s.flatNumber}' : ''} · ${Fmt.dateTimeFull(s.createdAt)}',
                  style: AppText.tiny(context),
                ),
              ],
            ),
          ),
        if (_isResident) ...[
          Divider(color: t.border),
          Text(context.tr('Your suggestion', 'आपका सुझाव'), style: AppText.tiny(context)),
          const SizedBox(height: 4),
          AppTextField(
            controller: _suggestionDraft,
            hint: context.tr('Share a suggestion for the committee…', 'समिति के लिए सुझाव दें…'),
            maxLines: 3,
            minLines: 2,
            caps: false,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: MiniButton(label: context.tr('Submit suggestion', 'सुझाव भेजें'), variant: MiniVariant.secondary, onPressed: _submitSuggestion),
          ),
        ],
      ],
    );
  }

  Widget _flatsGrid() {
    final t = context.tokens;
    final present = _presentByMember;
    return SectionBox(
      title: context.tr('Flats — tap Present to record everyone in that flat', 'फ्लैट — पूरे फ्लैट को दर्ज करने हेतु उपस्थित दबाएँ'),
      icon: Icons.apartment_outlined,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.25,
            ),
            itemCount: _flats.length,
            itemBuilder: (_, i) {
              final f = _flats[i];
              final on = isFlatMarkedPresent(f.members.map((m) => m.id).toList(), present);
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: on ? AppTokens.tint(t.success, 0.05) : t.card,
                  border: Border.all(color: on ? AppTokens.tint(t.success, 0.5) : t.border),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(f.flatNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        MiniButton(
                          label: on ? context.tr('Present ✓', 'उपस्थित ✓') : context.tr('Present', 'उपस्थित'),
                          fontSize: 10,
                          variant: on ? MiniVariant.primary : MiniVariant.outline,
                          onPressed: f.members.isEmpty ? null : () => _setFlatPresence(f, !on),
                        ),
                      ],
                    ),
                    if ((f.ownerName ?? '').isNotEmpty)
                      Text('${context.tr('Owner', 'स्वामी')}: ${f.ownerName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.tiny(context)),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          for (final m in f.members) Text('· ${m.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.tiny(context)),
                          if (f.members.isEmpty)
                            Text(context.tr('No members', 'कोई सदस्य नहीं'), style: AppText.tiny(context).copyWith(fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _attendanceSection() {
    final t = context.tokens;
    final photoById = {for (final m in _members) m.id: m.photo};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context.tr('Attendance list (flat + guests)', 'उपस्थिति सूची (फ्लैट + अतिथि)'), Icons.groups_outlined),
        if (!_isResident && _d.attendees.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTokens.tint(t.muted, 0.3),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(color: t.border),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.tr('${_selection.length} selected', '${_selection.length} चयनित'), style: AppText.caption(context)),
                MiniButton(
                  label: context.tr('Select all', 'सभी चुनें'),
                  fontSize: 11,
                  onPressed: () => setState(() => _selection.addAll(_d.attendees.map((a) => a.id))),
                ),
                MiniButton(label: context.tr('Clear', 'साफ़'), fontSize: 11, onPressed: _selection.isEmpty ? null : () => setState(_selection.clear)),
                MiniButton(label: context.tr('Mark present', 'उपस्थित'), fontSize: 11, variant: MiniVariant.secondary, onPressed: _selection.isEmpty ? null : () => _bulk('present')),
                MiniButton(label: context.tr('Mark absent', 'अनुपस्थित'), fontSize: 11, variant: MiniVariant.secondary, onPressed: _selection.isEmpty ? null : () => _bulk('absent')),
                MiniButton(label: context.tr('Remove selected', 'चयनित हटाएँ'), fontSize: 11, variant: MiniVariant.destructive, onPressed: _selection.isEmpty ? null : () => _bulk('remove')),
              ],
            ),
          ),
        if (!_isResident) ...[
          Row(
            children: [
              Expanded(
                child: AppDropdown<String>(
                  items: _members.map((m) => m.id).toList(),
                  value: _memberToAdd,
                  hint: context.tr('Add one member…', 'एक सदस्य जोड़ें…'),
                  labelOf: (id) {
                    final m = _members.firstWhere((x) => x.id == id);
                    return '${m.name} · ${m.flatNumber}';
                  },
                  onChanged: (v) => setState(() => _memberToAdd = v),
                ),
              ),
              const SizedBox(width: 6),
              MiniButton(label: context.tr('Add', 'जोड़ें'), variant: MiniVariant.secondary, onPressed: _addMember),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MiniButton(label: context.tr('Table pick', 'तालिका से चुनें'), icon: Icons.table_rows_outlined, onPressed: _tablePick),
              MiniButton(label: '${context.tr('Add', 'जोड़ें')} $_adminName', onPressed: _addAdmin),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _guestName, hint: context.tr('Guest name', 'अतिथि का नाम'), caps: false)),
              const SizedBox(width: 6),
              MiniButton(label: context.tr('Guest', 'अतिथि'), variant: MiniVariant.secondary, onPressed: _addGuest),
            ],
          ),
          const SizedBox(height: 6),
        ],
        for (final a in _d.attendees)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                if (!_isResident)
                  SizedBox(
                    width: 32,
                    child: Checkbox(
                      value: _selection.contains(a.id),
                      visualDensity: VisualDensity.compact,
                      onChanged: (_) => setState(() => _selection.contains(a.id) ? _selection.remove(a.id) : _selection.add(a.id)),
                    ),
                  ),
                PersonAvatar(name: a.displayName, photo: a.memberId == null ? null : photoById[a.memberId], size: AvatarSize.xs),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: a.displayName),
                      if ((a.flatNumber ?? '').isNotEmpty) TextSpan(text: ' · ${a.flatNumber}', style: TextStyle(color: t.mutedForeground)),
                      TextSpan(text: '  (${a.attendeeRole})', style: AppText.tiny(context)),
                    ]),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isResident) ...[
                  IconButton(
                    tooltip: context.tr('Toggle present', 'उपस्थिति बदलें'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _togglePresent(a),
                    icon: Icon(a.isPresent ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: a.isPresent ? t.success : t.mutedForeground),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeAttendee(a),
                    icon: Icon(Icons.delete_outline, size: 18, color: t.destructive),
                  ),
                ] else if (a.isPresent)
                  Icon(Icons.check_circle, size: 16, color: t.success),
              ],
            ),
          ),
      ],
    );
  }

  Widget _signaturesSection() {
    final t = context.tokens;
    final present = _d.attendees.where((a) => a.isPresent).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context.tr('Document signatures', 'दस्तावेज़ हस्ताक्षर'), Icons.draw_outlined),
        if (_d.documents.isEmpty)
          Text(context.tr('Attach documents in the notice section above, then collect signatures here.',
              'ऊपर सूचना भाग में दस्तावेज़ संलग्न करें, फिर यहाँ हस्ताक्षर लें।'), style: AppText.caption(context)),
        for (final doc in _d.documents)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => ExportKit.openUrl(doc.fileUrl),
                  child: Text(doc.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.primary, decoration: TextDecoration.underline, decorationColor: t.primary)),
                ),
                const SizedBox(height: 6),
                for (final att in present)
                  Builder(builder: (_) {
                    final sig = _d.signatures.where((s) => s.meetingDocumentId == doc.id && s.meetingAttendeeId == att.id).firstOrNull;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.6), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          Expanded(child: Text(att.displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                          if (sig != null)
                            LinkText(context.tr('Signed', 'हस्ताक्षरित'), onTap: () => ExportKit.openUrl(sig.signatureImageUrl))
                          else if (!_isResident)
                            MiniButton(label: context.tr('Sign', 'हस्ताक्षर'), icon: Icons.draw_outlined, fontSize: 10, onPressed: () => _sign(doc, att))
                          else
                            Text('—', style: AppText.caption(context)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _sessionSections() {
    final t = context.tokens;
    return [
      if (!_isResident) ...[
        SectionBox(
          title: context.tr('Executive members present', 'उपस्थित कार्यकारिणी सदस्य'),
          children: [
            AppTextField(
              controller: _executives,
              hint: context.tr('One name & role per line, e.g.\nPresident — R. Mehta\nTreasurer — S. Khan',
                  'प्रति पंक्ति एक नाम व पद, जैसे\nअध्यक्ष — आर. मेहता\nकोषाध्यक्ष — एस. खान'),
              maxLines: 5,
              minLines: 4,
              caps: false,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _flatsGrid(),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: context.tr('Status', 'स्थिति'),
          items: {...meetingStatuses, _m.status}.toList(),
          value: _m.status,
          labelOf: (s) => meetingStatusLabel(s, hi: _hi),
          onChanged: _onStatusChange,
        ),
        const SizedBox(height: 12),
      ],
      if (_isResident && (_m.executivesPresent ?? '').isNotEmpty) ...[
        Text(context.tr('Executive members recorded', 'दर्ज कार्यकारिणी सदस्य'), style: AppText.caption(context)),
        const SizedBox(height: 4),
        _readBox(_m.executivesPresent!),
        const SizedBox(height: 12),
      ],
      _label(context.tr('Discussion & conversation', 'चर्चा एवं वार्तालाप'), Icons.campaign_outlined),
      if (_isResident)
        _readBox(_m.discussionNotes ?? '')
      else
        AppTextField(
          controller: _discussion,
          hint: context.tr('Notes from the floor, questions, debate…', 'सदन की टिप्पणियाँ, प्रश्न, बहस…'),
          maxLines: 6,
          minLines: 4,
          caps: false,
        ),
      const SizedBox(height: 12),
      _label(context.tr('Minutes & summary', 'कार्यवृत्त एवं सारांश'), Icons.description_outlined),
      if (_isResident)
        _readBox(_m.minutesSummary ?? '')
      else ...[
        AppTextField(
          controller: _minutes,
          hint: context.tr('Type conclusions here, or use Dictate (mic) below.', 'निष्कर्ष यहाँ लिखें, या नीचे बोलकर लिखें (माइक) का उपयोग करें।'),
          maxLines: 8,
          minLines: 5,
          caps: false,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: MiniButton(
            label: _dictating ? context.tr('Stop dictation', 'बोलना रोकें') : context.tr('Dictate into minutes', 'कार्यवृत्त में बोलकर लिखें'),
            icon: _dictating ? Icons.mic_off_outlined : Icons.mic_none,
            variant: _dictating ? MiniVariant.primary : MiniVariant.outline,
            onPressed: _toggleDictation,
          ),
        ),
      ],
      const SizedBox(height: 12),
      _label(context.tr('Session audio', 'सत्र ऑडियो'), Icons.mic_none),
      if ((_m.audioRecordingUrl ?? '').isNotEmpty)
        SessionAudioPlayer(url: _m.audioRecordingUrl!)
      else
        Text(context.tr('No recording yet.', 'अभी कोई रिकॉर्डिंग नहीं।'), style: AppText.caption(context)),
      if (!_isResident) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!_recording)
              MiniButton(label: context.tr('Record session (mic)', 'सत्र रिकॉर्ड करें (माइक)'), icon: Icons.radio_button_checked, variant: MiniVariant.primary, onPressed: _startRecording)
            else
              MiniButton(label: context.tr('Stop & upload', 'रोकें व अपलोड करें'), icon: Icons.stop, variant: MiniVariant.destructive, onPressed: () => _stopRecording()),
            MiniButton(label: context.tr('Or upload audio file', 'या ऑडियो फ़ाइल अपलोड करें'), icon: Icons.upload_file, busy: _busy, onPressed: _uploadAudioFile),
          ],
        ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _label(context.tr('Decisions', 'निर्णय'), Icons.gavel)),
          if (!_isResident) MiniButton(label: context.tr('Add', 'जोड़ें'), icon: Icons.add, onPressed: _addDecision),
        ],
      ),
      for (final (i, d) in _d.decisions.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, child: Padding(padding: const EdgeInsets.only(top: 10), child: Text('${i + 1}.', style: AppText.tiny(context)))),
              Expanded(
                child: _isResident
                    ? Text(d.decisionText, style: AppText.body(context))
                    : AppTextField(
                        controller: _decisionDrafts[d.id],
                        hint: context.tr('Decision text — auto-saves after you pause typing', 'निर्णय पाठ — टाइप रुकने पर स्वतः सहेजा जाता है'),
                        maxLines: 4,
                        minLines: 2,
                        caps: false,
                      ),
              ),
              if (!_isResident)
                IconButton(onPressed: () => _removeDecision(d.id), icon: Icon(Icons.delete_outline, size: 18, color: t.destructive)),
            ],
          ),
        ),
      const SizedBox(height: 12),
      _attendanceSection(),
      const SizedBox(height: 12),
      _signaturesSection(),
      if (!_isResident) ...[
        const SizedBox(height: 12),
        TintBox(
          color: t.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('Publish minutes to all members', 'कार्यवृत्त सभी सदस्यों को प्रकाशित करें'), style: AppText.bodyMedium(context)),
              const SizedBox(height: 2),
              Text(context.tr('After the session, save notes and notify everyone that minutes are available.',
                  'सत्र के बाद टिप्पणियाँ सहेजें और सबको सूचित करें कि कार्यवृत्त उपलब्ध है।'), style: AppText.tiny(context).copyWith(fontSize: 11)),
              const SizedBox(height: 8),
              AppButton(label: context.tr('Publish minutes & notify all', 'कार्यवृत्त प्रकाशित करें व सबको सूचित करें'), icon: Icons.send_outlined, loading: _busy, onPressed: _publishMinutes),
            ],
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isResident ? context.tr('Meeting notice', 'बैठक सूचना') : context.tr('Meeting notice & record', 'बैठक सूचना व अभिलेख')),
        actions: [
          IconButton(tooltip: context.tr('Print open meeting', 'खुली बैठक प्रिंट करें'), onPressed: _print, icon: const Icon(Icons.print_outlined)),
          if (!_isResident)
            IconButton(tooltip: context.tr('Delete', 'हटाएँ'), onPressed: _delete, icon: Icon(Icons.delete_outline, color: t.destructive)),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : PageContainer(
              onRefresh: () async {
                await _reloadMeeting();
                await _loadDetail();
              },
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TinyTag(_m.meetingKind.label(_hi), filled: false, uppercase: false),
                    Text('ID ${_m.id.length > 8 ? _m.id.substring(0, 8) : _m.id}…', style: AppText.tiny(context)),
                    if (_m.published) TinyTag(context.tr('Published', 'प्रकाशित'), color: t.primary),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isResident) ...[_autosaveBox(), const SizedBox(height: 12)],
                _noticeSection(),
                const SizedBox(height: 12),
                _agendaSection(),
                const SizedBox(height: 12),
                _documentsSection(),
                if (!_isResident) ...[const SizedBox(height: 12), _publishBox()],
                const SizedBox(height: 12),
                _suggestionsSection(),
                const SizedBox(height: 12),
                if (!_sessionUnlocked)
                  SectionBox(
                    dashed: true,
                    children: [
                      Text(
                        context.tr(
                            'Attendance, discussion, minutes, recording, decisions, and signatures unlock on the day of the meeting (${Fmt.dateTimeFull(_m.meetingAt)}).',
                            'उपस्थिति, चर्चा, कार्यवृत्त, रिकॉर्डिंग, निर्णय और हस्ताक्षर बैठक के दिन (${Fmt.dateTimeFull(_m.meetingAt)}) खुलते हैं।'),
                        style: AppText.caption(context),
                      ),
                    ],
                  )
                else
                  ..._sessionSections(),
              ],
            ),
    );
  }
}
