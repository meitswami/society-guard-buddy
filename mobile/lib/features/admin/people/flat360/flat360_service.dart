import '../../../../core/format/formatters.dart';
import '../../../../core/supabase/db.dart';
import 'flat360_models.dart';
import 'flat360_timeline.dart';

/// Port of web `src/services/flat360/flat360Service.ts` (`fetchFlat360Profile`).
class Flat360Service {
  static const defaultMonthsBack = 12;
  static const maxTimelineItems = 500;

  /// `flats.flat_number` for a flat id (the sheet is opened with just the id).
  Future<String?> flatNumberFor(String flatId) async {
    if (!dbReady) return null;
    final row = await db.from('flats').select('flat_number').eq('id', flatId).maybeSingle();
    return row?['flat_number']?.toString();
  }

  Future<Flat360Profile> fetch(Flat360FetchParams params) async {
    final societyId = params.societyId;
    final flatId = params.flatId;
    final flatNumber = params.flatNumber;
    final cutoff = flat360CutoffIso(params.monthsBack);

    if (!dbReady) {
      return assembleFlat360Profile(params: params, flat: null);
    }

    // Like supabase-js, a failing secondary query yields no rows instead of failing the panel.
    Future<List<Map<String, dynamic>>> safe(Future<Object?> Function() q) async {
      try {
        return rowsOf(await q());
      } catch (_) {
        return const [];
      }
    }

    Map<String, dynamic>? flat;
    Object? flatError;
    final flatTask = () async {
      try {
        flat = await db
            .from('flats')
            .select('id, flat_number, owner_name, floor, wing, is_occupied')
            .eq('id', flatId)
            .maybeSingle();
      } catch (e) {
        flatError = e;
      }
    }();

    final results = await Future.wait<List<Map<String, dynamic>>>([
      safe(() => db
          .from('members')
          .select('id, name, phone, relation, is_primary')
          .eq('flat_id', flatId)
          .order('is_primary', ascending: false)
          .order('name')),
      safe(() => db
          .from('maintenance_payments')
          .select(
            'id, amount, payment_status, payment_method, payment_date, created_at, due_date, transaction_id, notes, charge_id',
          )
          .or('flat_id.eq.$flatId,flat_number.eq.$flatNumber')
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(100)),
      safe(() => db.from('maintenance_charges').select('id, title').eq('society_id', societyId)),
      safe(() => db
          .from('support_tickets')
          .select('id, ticket_number, message, status, created_at')
          .eq('society_id', societyId)
          .eq('flat_number', flatNumber)
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(30)),
      safe(() => db
          .from('parking_spaces')
          .select('id, space_number, space_type, floor_level, allocated_vehicle_number')
          .eq('society_id', societyId)
          .or('allocated_flat_id.eq.$flatId,allocated_flat_number.eq.$flatNumber')),
      safe(() => db
          .from('meeting_attendees')
          .select(
            'id, meeting_id, is_present, display_name, created_at, meetings!inner(id, title, meeting_at, published, society_id, meeting_kind)',
          )
          .eq('flat_number', flatNumber)
          .eq('meetings.society_id', societyId)
          .gte('meetings.meeting_at', cutoff)
          .order('created_at', ascending: false)
          .limit(40)),
      safe(() => db
          .from('notifications')
          .select('id, title, message, type, target_type, target_id, created_at')
          .eq('society_id', societyId)
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(80)),
      safe(() => db
          .from('event_contributions')
          .select('id, amount, payment_method, created_at, verified_at, events!inner(id, title, society_id)')
          .eq('events.society_id', societyId)
          .or('flat_id.eq.$flatId,flat_number.eq.$flatNumber')
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(30)),
      if (params.includeVisitors)
        safe(() => db
            .from('visitors')
            .select('id, name, purpose, category, entry_time, created_at')
            .eq('society_id', societyId)
            .eq('flat_number', flatNumber)
            .gte('created_at', cutoff)
            .order('created_at', ascending: false)
            .limit(20))
      else
        Future.value(const <Map<String, dynamic>>[]),
    ]);

    // The flat lookup is the only query whose failure surfaces as an error (web `throw flatRes.error`).
    await flatTask;
    if (flatError != null) throw flatError!;

    return assembleFlat360Profile(
      params: params,
      flat: flat,
      members: results[0],
      payments: results[1],
      charges: results[2],
      tickets: results[3],
      parking: results[4],
      attendees: results[5],
      notifications: results[6],
      contributions: results[7],
      visitors: results[8],
    );
  }
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Pure assembly of the 360° profile from raw rows (same rules as the web service).
Flat360Profile assembleFlat360Profile({
  required Flat360FetchParams params,
  required Map<String, dynamic>? flat,
  List<Map<String, dynamic>> members = const [],
  List<Map<String, dynamic>> payments = const [],
  List<Map<String, dynamic>> charges = const [],
  List<Map<String, dynamic>> tickets = const [],
  List<Map<String, dynamic>> parking = const [],
  List<Map<String, dynamic>> attendees = const [],
  List<Map<String, dynamic>> notifications = const [],
  List<Map<String, dynamic>> contributions = const [],
  List<Map<String, dynamic>> visitors = const [],
}) {
  final flatNumber = params.flatNumber;
  final chargeTitleById = <String, String>{
    for (final c in charges) '${c['id']}': (c['title'] ?? 'Maintenance').toString(),
  };

  final memberList = [
    for (final m in members)
      Flat360Member(
        id: '${m['id']}',
        name: '${m['name']}',
        phone: _str(m['phone']),
        relation: (m['relation'] ?? 'member').toString(),
        isPrimary: m['is_primary'] == true,
      ),
  ];

  final parkingList = [
    for (final p in parking)
      Flat360ParkingSlot(
        id: '${p['id']}',
        spaceNumber: '${p['space_number']}',
        spaceType: (p['space_type'] ?? 'car').toString(),
        floorLevel: _str(p['floor_level']),
        vehicleNumber: _str(p['allocated_vehicle_number']),
      ),
  ];

  var verifiedPaid12m = 0.0;
  var pendingCount = 0;
  var pendingAmount = 0.0;
  for (final p in payments) {
    final amt = asDouble(p['amount']);
    final status = (p['payment_status'] ?? '').toString().toLowerCase();
    if (status == 'verified') verifiedPaid12m += amt;
    if (status == 'pending') {
      pendingCount += 1;
      pendingAmount += amt;
    }
  }

  final openTickets = tickets.where((t) => '${t['status']}'.toLowerCase() == 'pending').length;

  final meetingsAttended = attendees.where((a) => a['is_present'] == true).length;
  final meetingsTotal = attendees.map((a) => '${a['meeting_id']}').toSet().length;
  final attendancePct = meetingsTotal > 0 ? ((meetingsAttended / meetingsTotal) * 100).round() : 0;

  final summary = Flat360Summary(
    verifiedPaid12m: verifiedPaid12m,
    pendingCount: pendingCount,
    pendingAmount: pendingAmount,
    openTickets: openTickets,
    parkingSlots: parkingList.length,
    meetingsAttended: meetingsAttended,
    meetingsTotal: meetingsTotal,
    attendancePct: attendancePct,
  );

  final items = <Flat360TimelineItem>[];

  for (final p in payments) {
    final chargeTitle = chargeTitleById['${p['charge_id']}'] ?? 'Maintenance';
    final status = '${p['payment_status']}';
    items.add(Flat360TimelineItem(
      id: 'pay-${p['id']}',
      kind: Flat360TimelineKind.payment,
      at: '${_str(p['payment_date']) ?? p['created_at']}',
      title: chargeTitle,
      detail: '${paymentStatusLabel(status)} · ${paymentMethodLabel(_str(p['payment_method']))}',
      status: status,
      amount: asDouble(p['amount']),
    ));
  }

  final residentCtx = params.residentContext;
  for (final row in notifications) {
    final targetType = _str(row['target_type']);
    final targetId = _str(row['target_id']);
    if (residentCtx != null) {
      final visible = notificationVisibleToResident(
        targetType: targetType,
        targetId: targetId,
        resident: residentCtx,
        flatNumber: flatNumber,
      );
      if (!visible) continue;
    } else if (!notificationVisibleForFlatAdmin(targetType: targetType, targetId: targetId, flatNumber: flatNumber)) {
      continue;
    }
    items.add(Flat360TimelineItem(
      id: 'notif-${row['id']}',
      kind: Flat360TimelineKind.notification,
      at: '${row['created_at']}',
      title: '${row['title']}',
      detail: jsSlice((row['message'] ?? '').toString(), 120),
      status: (row['type'] ?? 'general').toString(),
    ));
  }

  for (final t in tickets) {
    items.add(Flat360TimelineItem(
      id: 'ticket-${t['id']}',
      kind: Flat360TimelineKind.ticket,
      at: '${t['created_at']}',
      title: 'Ticket #${t['ticket_number']}',
      detail: jsSlice((t['message'] ?? '').toString(), 120),
      status: '${t['status']}',
    ));
  }

  for (final a in attendees) {
    final meeting = a['meetings'];
    if (meeting is! Map || meeting['id'] == null) continue;
    items.add(Flat360TimelineItem(
      id: 'meet-${a['id']}',
      kind: Flat360TimelineKind.meeting,
      at: '${_str(meeting['meeting_at']) ?? a['created_at']}',
      title: (meeting['title'] ?? 'Society meeting').toString(),
      detail: a['is_present'] == true ? 'Present' : 'Absent',
      status: (meeting['meeting_kind'] ?? 'other').toString(),
    ));
  }

  for (final c in contributions) {
    final event = c['events'];
    final title = event is Map ? _str(event['title']) : null;
    items.add(Flat360TimelineItem(
      id: 'evc-${c['id']}',
      kind: Flat360TimelineKind.eventContribution,
      at: '${c['created_at']}',
      title: title != null ? 'Contribution: $title' : 'Event contribution',
      detail: _str(c['verified_at']) != null ? 'Verified' : 'Recorded',
      amount: asDouble(c['amount']),
    ));
  }

  for (final v in visitors) {
    items.add(Flat360TimelineItem(
      id: 'vis-${v['id']}',
      kind: Flat360TimelineKind.visitor,
      at: '${_str(v['entry_time']) ?? v['created_at']}',
      title: (v['name'] ?? 'Visitor').toString(),
      detail: [_str(v['category']), _str(v['purpose'])].whereType<String>().join(' · '),
    ));
  }

  final merged = mergeFlat360Timeline(items, Flat360Service.maxTimelineItems);

  return Flat360Profile(
    flatId: params.flatId,
    flatNumber: _str(flat?['flat_number']) ?? flatNumber,
    ownerName: _str(flat?['owner_name']),
    floor: _str(flat?['floor']),
    wing: _str(flat?['wing']),
    isOccupied: flat?['is_occupied'] != false,
    members: memberList,
    parking: parkingList,
    summary: summary,
    timeline: merged.timeline,
  );
}
