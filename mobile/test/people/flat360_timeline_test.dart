import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/people/flat360/flat360_models.dart';
import 'package:kutumbika_mobile/features/admin/people/flat360/flat360_service.dart';
import 'package:kutumbika_mobile/features/admin/people/flat360/flat360_timeline.dart';

void main() {
  // Port of src/lib/flat360Timeline.test.ts
  group('mergeFlat360Timeline', () {
    const items = [
      Flat360TimelineItem(
          id: 'a',
          kind: Flat360TimelineKind.payment,
          at: '2026-01-01T00:00:00Z',
          title: 'Older'),
      Flat360TimelineItem(
          id: 'b',
          kind: Flat360TimelineKind.notification,
          at: '2026-06-01T00:00:00Z',
          title: 'Newer'),
      Flat360TimelineItem(
          id: 'c',
          kind: Flat360TimelineKind.ticket,
          at: '2026-03-01T00:00:00Z',
          title: 'Middle'),
    ];

    test('sorts newest first and respects limit', () {
      final r = mergeFlat360Timeline(items, 2);
      expect(r.timeline.map((t) => t.id).toList(), ['b', 'c']);
      expect(r.hasMore, isTrue);
    });

    test('reports no more when within limit', () {
      final r = mergeFlat360Timeline(items, 5);
      expect(r.timeline, hasLength(3));
      expect(r.hasMore, isFalse);
    });

    test('date-only values are UTC midnight like JavaScript', () {
      final r = mergeFlat360Timeline(const [
        Flat360TimelineItem(
            id: 'd',
            kind: Flat360TimelineKind.payment,
            at: '2026-03-01',
            title: 'Date only'),
        Flat360TimelineItem(
            id: 'e',
            kind: Flat360TimelineKind.payment,
            at: '2026-02-28T23:59:59Z',
            title: 'Before'),
      ], 10);
      expect(r.timeline.first.id, 'd');
    });
  });

  test('timelineKindLabel', () {
    expect(timelineKindLabel(Flat360TimelineKind.payment), 'Payment');
    expect(timelineKindLabel(Flat360TimelineKind.notification), 'Notice');
    expect(timelineKindLabel(Flat360TimelineKind.ticket), 'Feedback');
    expect(timelineKindLabel(Flat360TimelineKind.meeting), 'Meeting');
    expect(timelineKindLabel(Flat360TimelineKind.eventContribution), 'Event');
    expect(timelineKindLabel(Flat360TimelineKind.visitor), 'Visitor');
  });

  test('subMonthsClamped clamps like date-fns', () {
    expect(subMonthsClamped(DateTime(2024, 2, 29), 12), DateTime(2023, 2, 28));
    expect(subMonthsClamped(DateTime(2026, 3, 31), 1), DateTime(2026, 2, 28));
    expect(subMonthsClamped(DateTime(2026, 1, 15, 10, 30), 12),
        DateTime(2025, 1, 15, 10, 30));
  });

  test('notificationVisibleToResident', () {
    const r = Flat360ResidentContext(id: 'u1', name: 'Asha');
    bool v(String? type, String? id) => notificationVisibleToResident(
        targetType: type, targetId: id, resident: r, flatNumber: '101');
    expect(v('all', null), isTrue);
    expect(v('flat', '101'), isTrue);
    expect(v('flat', '102, 101'), isTrue);
    expect(v('flat', '102'), isFalse);
    expect(v('user', 'u1'), isTrue);
    expect(v('user', 'Asha'), isTrue);
    expect(v('user', 'x, Asha'), isTrue);
    expect(v('user', 'u2'), isFalse);
    expect(v('general', ''), isFalse);
  });

  test('admin flat filter keeps empty targets and other target types', () {
    expect(
        notificationVisibleForFlatAdmin(
            targetType: 'all', targetId: null, flatNumber: '101'),
        isTrue);
    expect(
        notificationVisibleForFlatAdmin(
            targetType: 'flat', targetId: '', flatNumber: '101'),
        isTrue);
    expect(
        notificationVisibleForFlatAdmin(
            targetType: 'flat', targetId: '101', flatNumber: '101'),
        isTrue);
    expect(
        notificationVisibleForFlatAdmin(
            targetType: 'flat', targetId: '102,101', flatNumber: '101'),
        isTrue);
    expect(
        notificationVisibleForFlatAdmin(
            targetType: 'flat', targetId: '102', flatNumber: '101'),
        isFalse);
  });

  test('paymentStatusLabel / method label', () {
    expect(paymentStatusLabel('VERIFIED'), 'Verified');
    expect(paymentStatusLabel('pending'), 'Pending');
    expect(paymentStatusLabel('rejected'), 'Rejected');
    expect(paymentStatusLabel('partial'), 'partial');
    expect(paymentMethodLabel(null), 'cash');
    expect(paymentMethodLabel('bank_transfer'), 'bank transfer');
  });

  group('assembleFlat360Profile', () {
    const params = Flat360FetchParams(
        societyId: 's1',
        flatId: 'f1',
        flatNumber: '101',
        includeVisitors: true);

    test('summary and timeline', () {
      final p = assembleFlat360Profile(
        params: params,
        flat: {
          'id': 'f1',
          'flat_number': '101',
          'owner_name': 'Ravi',
          'floor': '1st Floor',
          'wing': 'A',
          'is_occupied': null
        },
        members: [
          {
            'id': 'm1',
            'name': 'Ravi',
            'phone': '9999999999',
            'relation': 'owner',
            'is_primary': true
          },
          {
            'id': 'm2',
            'name': 'Sita',
            'phone': null,
            'relation': null,
            'is_primary': false
          },
        ],
        payments: [
          {
            'id': 'p1',
            'amount': '1500',
            'payment_status': 'verified',
            'payment_method': 'upi',
            'payment_date': '2026-05-01',
            'created_at': '2026-05-01T08:00:00Z',
            'charge_id': 'c1'
          },
          {
            'id': 'p2',
            'amount': 500,
            'payment_status': 'pending',
            'payment_method': null,
            'payment_date': null,
            'created_at': '2026-06-01T08:00:00Z',
            'charge_id': 'zz'
          },
          {
            'id': 'p3',
            'amount': 250.5,
            'payment_status': 'Pending',
            'created_at': '2026-06-02T08:00:00Z'
          },
        ],
        charges: [
          {'id': 'c1', 'title': 'May maintenance'},
        ],
        tickets: [
          {
            'id': 't1',
            'ticket_number': 7,
            'message': 'Leak',
            'status': 'pending',
            'created_at': '2026-04-01T00:00:00Z'
          },
          {
            'id': 't2',
            'ticket_number': 8,
            'message': 'Done',
            'status': 'resolved',
            'created_at': '2026-04-02T00:00:00Z'
          },
        ],
        parking: [
          {
            'id': 'k1',
            'space_number': 'P-1',
            'space_type': null,
            'floor_level': 'B1',
            'allocated_vehicle_number': 'MH01'
          },
        ],
        attendees: [
          {
            'id': 'a1',
            'meeting_id': 'mt1',
            'is_present': true,
            'created_at': '2026-02-01T00:00:00Z',
            'meetings': {
              'id': 'mt1',
              'title': 'AGM',
              'meeting_at': '2026-02-02T10:00:00Z',
              'meeting_kind': 'agm'
            }
          },
          {
            'id': 'a2',
            'meeting_id': 'mt2',
            'is_present': false,
            'created_at': '2026-03-01T00:00:00Z',
            'meetings': {'id': 'mt2', 'title': null, 'meeting_at': null}
          },
          {
            'id': 'a3',
            'meeting_id': 'mt2',
            'is_present': true,
            'created_at': '2026-03-01T00:00:00Z',
            'meetings': null
          },
        ],
        notifications: [
          {
            'id': 'n1',
            'title': 'Water cut',
            'message': 'x' * 200,
            'type': null,
            'target_type': 'all',
            'target_id': null,
            'created_at': '2026-06-03T00:00:00Z'
          },
          {
            'id': 'n2',
            'title': 'Other flat',
            'message': '',
            'type': 'general',
            'target_type': 'flat',
            'target_id': '102',
            'created_at': '2026-06-04T00:00:00Z'
          },
        ],
        contributions: [
          {
            'id': 'e1',
            'amount': 100,
            'created_at': '2026-01-10T00:00:00Z',
            'verified_at': '2026-01-11T00:00:00Z',
            'events': {'title': 'Diwali'}
          },
          {
            'id': 'e2',
            'amount': 50,
            'created_at': '2026-01-09T00:00:00Z',
            'verified_at': null,
            'events': null
          },
        ],
        visitors: [
          {
            'id': 'v1',
            'name': 'Courier',
            'purpose': 'Delivery',
            'category': 'delivery',
            'entry_time': '2026-06-05T09:00:00Z',
            'created_at': '2026-06-05T09:00:00Z'
          },
        ],
      );

      expect(p.flatNumber, '101');
      expect(p.ownerName, 'Ravi');
      expect(p.isOccupied, isTrue);
      expect(p.members.map((m) => m.relation).toList(), ['owner', 'member']);
      expect(p.parking.single.spaceType, 'car');
      expect(p.summary.verifiedPaid12m, 1500);
      expect(p.summary.pendingCount, 2);
      expect(p.summary.pendingAmount, 750.5);
      expect(p.summary.openTickets, 1);
      expect(p.summary.parkingSlots, 1);
      expect(p.summary.meetingsAttended, 2);
      expect(p.summary.meetingsTotal, 2);
      expect(p.summary.attendancePct, 100);

      final ids = p.timeline.map((t) => t.id).toList();
      expect(ids.first, 'vis-v1');
      expect(ids, isNot(contains('notif-n2')));
      expect(ids, isNot(contains('meet-a3')));
      final pay1 = p.timeline.firstWhere((t) => t.id == 'pay-p1');
      expect(pay1.title, 'May maintenance');
      expect(pay1.detail, 'Verified · upi');
      expect(pay1.at, '2026-05-01');
      final pay2 = p.timeline.firstWhere((t) => t.id == 'pay-p2');
      expect(pay2.title, 'Maintenance');
      expect(pay2.detail, 'Pending · cash');
      final n1 = p.timeline.firstWhere((t) => t.id == 'notif-n1');
      expect(n1.detail!.length, 120);
      expect(n1.status, 'general');
      final m2 = p.timeline.firstWhere((t) => t.id == 'meet-a2');
      expect(m2.title, 'Society meeting');
      expect(m2.detail, 'Absent');
      expect(m2.status, 'other');
      expect(p.timeline.firstWhere((t) => t.id == 'evc-e1').title,
          'Contribution: Diwali');
      expect(p.timeline.firstWhere((t) => t.id == 'evc-e2').detail, 'Recorded');
      expect(p.timeline.firstWhere((t) => t.id == 'vis-v1').detail,
          'delivery · Delivery');
    });

    test('resident context filters notifications', () {
      final p = assembleFlat360Profile(
        params: const Flat360FetchParams(
          societyId: 's1',
          flatId: 'f1',
          flatNumber: '101',
          residentContext: Flat360ResidentContext(id: 'u1', name: 'Asha'),
        ),
        flat: null,
        notifications: [
          {
            'id': 'n1',
            'title': 'A',
            'target_type': 'user',
            'target_id': 'u1',
            'created_at': '2026-06-03T00:00:00Z'
          },
          {
            'id': 'n2',
            'title': 'B',
            'target_type': 'flat',
            'target_id': '',
            'created_at': '2026-06-04T00:00:00Z'
          },
        ],
      );
      expect(p.timeline.map((t) => t.id).toList(), ['notif-n1']);
      expect(p.summary.attendancePct, 0);
      expect(p.isOccupied, isTrue);
    });
  });
}
