import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/gate/data/gate_logic.dart';
import 'package:kutumbika_mobile/features/gate/data/gate_models.dart';
import 'package:kutumbika_mobile/models/blacklist_entry.dart';

GateVisitor v(
  String id, {
  String phone = '9876543210',
  String name = 'Ravi',
  String flat = '101',
  String category = 'visitor',
  required DateTime at,
  bool exited = false,
  String? vehicle,
  String docType = 'aadhaar',
  String doc = '',
}) =>
    GateVisitor(
      id: id,
      name: name,
      phone: phone,
      flatNumber: flat,
      purpose: 'Visit',
      category: category,
      entryTime: at.toUtc().toIso8601String(),
      exitTime: exited
          ? at.add(const Duration(hours: 1)).toUtc().toIso8601String()
          : null,
      vehicleNumber: vehicle,
      documentType: docType,
      documentNumber: doc,
    );

void main() {
  final today = DateTime(2026, 10, 12, 10);
  final yesterday = DateTime(2026, 10, 11, 18);

  group('dashboard day', () {
    test('day iso for offsets and arrow clamping', () {
      expect(dayIsoForOffset(today, 0), '2026-10-12');
      expect(dayIsoForOffset(today, 1), '2026-10-11');
      expect(dayIsoForOffset(DateTime(2026, 3, 1), 1), '2026-02-28');
      expect(olderDayOffset(0), 1);
      expect(olderDayOffset(7), 7);
      expect(newerDayOffset(0), 0);
      expect(newerDayOffset(3), 2);
    });

    test('local calendar day is used (early-morning entries stay on their day)',
        () {
      final early = v('e', at: DateTime(2026, 10, 12, 1, 30));
      expect(early.entryDay, '2026-10-12');
      expect(visitorsOnDay([early], '2026-10-12'), hasLength(1));
    });

    test('stats count visitors, vehicles, deliveries/services and inside', () {
      final day = [
        v('1', at: today, vehicle: 'MH01AB1234'),
        v('2', at: today, category: 'delivery', exited: true),
        v('3', at: today, category: 'service'),
        v('4', at: today, exited: true),
      ];
      final s = dashboardStats(day);
      expect(s.totalVisitors, 2);
      expect(s.totalVehicles, 1);
      expect(s.totalDeliveries, 2);
      expect(s.currentlyInside, 2);
    });

    test('filters and the 10-entry limit; toggling the active filter clears it',
        () {
      final day = [
        for (var i = 0; i < 12; i++) v('$i', at: today, exited: i.isEven)
      ];
      expect(filterDashboardEntries(day, DashboardFilter.all), hasLength(10));
      expect(filterDashboardEntries(day, DashboardFilter.inside), hasLength(6));
      expect(filterDashboardEntries(day, DashboardFilter.vehicle), isEmpty);
      expect(toggleDashboardFilter(DashboardFilter.all, DashboardFilter.inside),
          DashboardFilter.inside);
      expect(
          toggleDashboardFilter(DashboardFilter.inside, DashboardFilter.inside),
          DashboardFilter.all);
    });

    test('alerts for phones entering 3+ times, newest name, first-seen order',
        () {
      final day = [
        v('a', phone: '1111111111', name: 'Newest', at: today),
        v('b', phone: '2222222222', at: today),
        v('c', phone: '1111111111', name: 'Old', at: today),
        v('d', phone: '1111111111', at: today),
        v('e', phone: '2222222222', at: today),
      ];
      final alerts = repeatVisitAlerts(day);
      expect(alerts, hasLength(1));
      expect(alerts.single.phone, '1111111111');
      expect(alerts.single.count, 3);
      expect(alerts.single.name, 'Newest');
    });
  });

  group('visitor entry', () {
    final all = [
      v('1',
          phone: '9876543210',
          name: 'Ravi',
          flat: '604',
          at: today,
          docType: 'passport',
          doc: 'P123'),
      v('2', phone: '9876543210', name: 'Ravi K', at: yesterday),
      v('3', phone: '9876000000', name: 'Asha', at: yesterday),
      v('4', phone: '1234987600', name: 'Om', at: yesterday),
      v('5', phone: '5559876111', name: 'Zed', at: yesterday),
    ];

    test('suggestions: 4–9 digits, distinct phones, max 3', () {
      expect(phoneSuggestions(all, '987'), isEmpty);
      expect(phoneSuggestions(all, '9876543210'), isEmpty);
      final s = phoneSuggestions(all, '9876');
      expect(s.map((e) => e.phone), ['9876543210', '9876000000', '1234987600']);
    });

    test('repeat visits today and previous-visit prefill rules', () {
      expect(visitsOnDayForPhone(all, '9876543210', '2026-10-12'), 1);
      expect(visitsOnDayForPhone(all, '9876000000', '2026-10-12'), 0);
      final prev = previousVisitFor(all, '9876543210')!;
      expect(prev.id, '1');
      final p = prefillFromPrevious(
          name: '',
          documentType: 'aadhaar',
          documentNumber: 'MINE',
          flatNumber: '',
          prev: prev);
      expect(p.name, 'Ravi');
      expect(p.documentType, 'passport');
      expect(p.documentNumber, 'MINE');
      expect(p.flatNumber, '604');
    });

    test('blacklist matches phone or vehicle', () {
      const list = [
        BlacklistEntry(
            id: '1',
            type: 'visitor',
            reason: 'r',
            addedAt: '',
            addedBy: 'g',
            phone: '9999999999'),
        BlacklistEntry(
            id: '2',
            type: 'vehicle',
            reason: 'r',
            addedAt: '',
            addedBy: 'g',
            vehicleNumber: 'MH01X1'),
      ];
      expect(isBlacklistedIn(list, phone: '9999999999'), isTrue);
      expect(isBlacklistedIn(list, vehicleNumber: 'MH01X1'), isTrue);
      expect(isBlacklistedIn(list, phone: '8888888888'), isFalse);
      expect(isBlacklistedIn(list), isFalse);
      expect(blacklistMatchesSearch(list.first, '9999'), isTrue);
      expect(blacklistMatchesSearch(list.last, 'mh01'), isTrue);
      expect(blacklistMatchesSearch(list.last, 'zzz'), isFalse);
    });

    test('visitor entry payload: vehicle only when toggled, insert row nulls',
        () {
      final e = buildVisitorEntry(
        name: 'Ravi',
        phone: '9876543210',
        flatNumber: '604',
        purpose: 'Guest',
        documentType: 'aadhaar',
        documentNumber: '',
        hasVehicle: false,
        vehicleNumber: 'MH01',
        guardId: 'G001',
        guardName: 'Ram',
        now: today,
      );
      expect(e.vehicleNumber, isNull);
      expect(e.category, 'visitor');
      final row = e.toInsertRow('soc');
      expect(row['society_id'], 'soc');
      expect(row['document_number'], isNull);
      expect(row['vehicle_entry_time'], isNull);
      expect(row['entry_time'], endsWith('Z'));

      final withVehicle = buildVisitorEntry(
        name: 'Ravi',
        phone: '1',
        flatNumber: '1',
        purpose: 'Visit',
        documentType: 'other',
        documentNumber: 'X',
        hasVehicle: true,
        vehicleNumber: 'MH01',
        guardId: 'G',
        guardName: 'N',
        now: today,
      );
      expect(withVehicle.vehicleNumber, 'MH01');
      expect(withVehicle.vehicleEntryTime, withVehicle.entryTime);
    });

    test('delivery / service payload', () {
      final d = buildDeliveryEntry(
        isDelivery: true,
        name: 'Boy',
        phone: '1',
        company: 'Amazon',
        flatNumber: '1',
        guardId: 'G',
        guardName: 'N',
        now: today,
      );
      expect(d.purpose, 'Delivery - Amazon');
      expect(d.category, 'delivery');
      expect(d.documentType, 'other');
      expect(d.vehicleNumber, isNull);
      final s = buildDeliveryEntry(
        isDelivery: false,
        name: 'P',
        phone: '1',
        company: 'Plumber',
        flatNumber: '1',
        vehicleNumber: 'UP1',
        guardId: 'G',
        guardName: 'N',
        now: today,
      );
      expect(s.purpose, 'Service - Plumber');
      expect(s.category, 'service');
      expect(s.vehicleEntryTime, isNotNull);
    });

    test('digits only and CAPS entry normalisation', () {
      expect(digitsOnly('98-765 43210x', maxLength: 10), '9876543210');
      expect(
          normalizeEntryValue('ravi', capsMode: true, field: 'name'), 'RAVI');
      expect(
          normalizeEntryValue('ravi', capsMode: false, field: 'name'), 'ravi');
      expect(normalizeEntryValue('abc', capsMode: true, field: 'otp'), 'abc');
    });
  });

  group('vehicles', () {
    test('resident name: primary member, else owner', () {
      const flat = GateFlat(id: 'f1', flatNumber: '101', ownerName: ' Owner ');
      const members = [
        GateMember(id: 'm1', flatId: 'f1', name: 'Kid'),
        GateMember(id: 'm2', flatId: 'f1', name: 'Primary', isPrimary: true),
      ];
      expect(residentNameForFlat(flat, members), 'Primary');
      expect(residentNameForFlat(flat, const []), 'Owner');
      expect(
          residentNameForFlat(
              const GateFlat(id: 'x', flatNumber: '2'), const []),
          '');
    });

    test('search by number, flat or resident', () {
      const veh = GateResidentVehicle(
          id: '1',
          flatNumber: 'A-101',
          residentName: 'Meena',
          vehicleNumber: 'MH02AB1234');
      expect(vehicleMatchesSearch(veh, 'ab12'), isTrue);
      expect(vehicleMatchesSearch(veh, 'a-1'), isTrue);
      expect(vehicleMatchesSearch(veh, 'meen'), isTrue);
      expect(vehicleMatchesSearch(veh, 'zz'), isFalse);
    });
  });
}
