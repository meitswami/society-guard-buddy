import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/db.dart';
import '../../../models/session_models.dart';
import '../data/alert_sounds.dart';
import '../data/committee_roster.dart';
import '../data/member_rules.dart';
import '../data/resident_models.dart';
import '../data/resident_repository.dart';

/// Approval requests of the flat with realtime refresh and the new-request beep
/// (web `loadRequests` + `resident-approvals` channel + `notificationSound`).
class ResidentApprovalsController extends ChangeNotifier {
  ResidentApprovalsController({required this.session, required this.sounds, this.repo = const ResidentRepository()});

  final SessionResident session;
  final ResidentAlertSounds sounds;
  final ResidentRepository repo;

  List<ApprovalRequestRow> requests = const [];
  bool loading = true;
  bool failed = false;
  int _prevPending = 0;
  RealtimeChannel? _channel;
  bool _disposed = false;

  List<ApprovalRequestRow> get pending => requests.where((r) => r.isPending).toList();
  List<ApprovalRequestRow> get history => requests.where((r) => !r.isPending).toList();
  int get pendingCount => requests.where((r) => r.isPending).length;

  Future<void> load() async {
    try {
      final data = await repo.fetchApprovals(session.resident.flatId);
      if (_disposed) return;
      final newPending = data.where((r) => r.isPending).length;
      if (newPending > _prevPending) unawaited(sounds.playApprovalChime());
      _prevPending = newPending;
      requests = data;
      failed = false;
    } catch (_) {
      if (_disposed) return;
      failed = requests.isEmpty;
    }
    loading = false;
    notifyListeners();
  }

  /// Web listens to INSERTs; updates are included so a flatmate's answer on another
  /// phone clears the pending card here too.
  void subscribe() {
    if (!dbReady || _channel != null) return;
    _channel = db
        .channel('resident-approvals-${session.resident.flatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'approval_requests',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'flat_id', value: session.resident.flatId),
          callback: (_) => load(),
        )
        .subscribe();
  }

  Future<void> respond(String id, String status) async {
    await repo.respondApproval(id: id, flatId: session.resident.flatId, status: status);
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    final ch = _channel;
    if (ch != null) unawaited(db.removeChannel(ch));
    super.dispose();
  }
}

/// Household data shared by the Family and Profile tabs and the shell
/// (web `myMembers`, `flatmates`, `committeeRoster`, `residentSelfIdUploadEnabled`).
class ResidentHousehold extends ChangeNotifier {
  ResidentHousehold({required this.session, this.repo = const ResidentRepository()});

  final SessionResident session;
  final ResidentRepository repo;

  List<HouseholdMember> members = const [];
  List<FlatmateLogin> flatmates = const [];
  List<CommitteeRosterRow> roster = const [];
  bool selfIdUploadEnabled = false;
  bool loading = true;
  bool failed = false;
  bool _disposed = false;

  String get _flatId => session.resident.flatId;

  /// Member row whose phone matches the login phone (web `myMemberRecord`).
  HouseholdMember? get myMember {
    final mine = digitsOnly(session.resident.phone);
    if (mine.isEmpty) return null;
    for (final m in members) {
      if ((m.phone ?? '').isNotEmpty && digitsOnly(m.phone!) == mine) return m;
    }
    return null;
  }

  FlatmateLogin? get selfLogin {
    for (final f in flatmates) {
      if (f.id == session.resident.id) return f;
    }
    return null;
  }

  bool onCommittee(HouseholdMember m) =>
      isMemberOnCommitteeRoster(id: m.id, name: m.name, phone: m.phone, flatId: _flatId, roster: roster);

  Future<void> loadAll() async {
    await Future.wait([loadMembers(), loadFlatmates(), loadRoster(), _loadSelfIdFlag()]);
    loading = false;
    _notify();
  }

  Future<void> loadMembers() async {
    try {
      members = await repo.fetchMembers(_flatId);
      failed = false;
    } catch (_) {
      failed = members.isEmpty;
    }
    _notify();
  }

  Future<void> loadFlatmates() async {
    try {
      flatmates = await repo.fetchFlatmates(_flatId);
    } catch (_) {}
    _notify();
  }

  Future<void> loadRoster() async {
    try {
      roster = await repo.fetchCommitteeRoster(session.societyId);
    } catch (_) {}
    _notify();
  }

  Future<void> _loadSelfIdFlag() async {
    try {
      selfIdUploadEnabled = await repo.fetchSelfIdUploadEnabled(session.societyId);
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
