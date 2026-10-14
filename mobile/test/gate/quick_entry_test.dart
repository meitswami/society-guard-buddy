import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/gate/data/gate_models.dart';
import 'package:kutumbika_mobile/features/gate/data/quick_entry_logic.dart';

GateVisitor visit(String id, String phone, String name, String at,
        {bool inside = false,
        List<String> photos = const [],
        String flat = '101'}) =>
    GateVisitor(
      id: id,
      name: name,
      phone: phone,
      flatNumber: flat,
      purpose: 'Visit',
      entryTime: at,
      exitTime: inside ? null : '${at}x',
      visitorPhotos: photos,
    );

void main() {
  const flats = [
    GateFlat(id: 'f1', flatNumber: '101'),
    GateFlat(id: 'f2', flatNumber: '202')
  ];

  test('staff member detection', () {
    expect(
        isQuickEntryStaffMember(const GateMember(
            id: '1', flatId: 'f1', name: 'A', relation: 'Maid')),
        isTrue);
    expect(
        isQuickEntryStaffMember(const GateMember(
            id: '1', flatId: 'f1', name: 'A', relation: 'plumber')),
        isTrue);
    expect(
        isQuickEntryStaffMember(const GateMember(
            id: '1', flatId: 'f1', name: 'A', relation: 'Son')),
        isFalse);
    expect(
        isQuickEntryStaffMember(const GateMember(
            id: '1', flatId: 'f1', name: 'A', relation: 'Others')),
        isFalse);
    expect(
        isQuickEntryStaffMember(const GateMember(
            id: '1',
            flatId: 'f1',
            name: 'A',
            relation: 'cook',
            isPrimary: true)),
        isFalse);
  });

  test('staff phone: last 10 digits or synthetic id', () {
    expect(
        quickEntryPhoneForMember(const GateMember(
            id: 'm', flatId: 'f', name: 'A', phone: '+91 98765-43210')),
        '9876543210');
    expect(
      quickEntryPhoneForMember(const GateMember(
          id: '12345678-1234-1234-1234-123456789012',
          flatId: 'f',
          name: 'A',
          phone: '123')),
      'staff-1234567812341234',
    );
    expect(isSyntheticStaffPhone('staff-1'), isTrue);
  });

  test('staff template purpose is title-cased', () {
    final t = memberToQuickVisitorTemplate(
        const GateMember(
            id: 'm',
            flatId: 'f1',
            name: 'Sita',
            relation: 'mid-servant',
            photo: 'p'),
        '101');
    expect(t.purpose, 'Mid-Servant · Registered staff');
    expect(t.category, 'service');
    expect(t.visitorPhotos, ['p']);
  });

  test('rows merge staff and frequent visitors (2+ entries), sorted by name',
      () {
    final visitors = [
      visit('1', '9000000001', 'zara', '2026-10-12T09:00:00Z', photos: ['ph']),
      visit('2', '9000000001', 'Zara old', '2026-10-11T09:00:00Z'),
      visit('3', '9000000002', 'Once', '2026-10-12T08:00:00Z'),
      visit('4', '9876543210', 'Maid visit', '2026-10-12T07:00:00Z'),
      visit('5', '9876543210', 'Maid visit', '2026-10-10T07:00:00Z'),
    ];
    const members = [
      GateMember(
          id: 'm1',
          flatId: 'f1',
          name: 'Kamla',
          relation: 'maid',
          phone: '9876543210'),
      GateMember(id: 'm2', flatId: 'zz', name: 'No flat', relation: 'cook'),
      GateMember(id: 'm3', flatId: 'f2', name: 'Owner', relation: 'owner'),
    ];
    final rows =
        buildQuickRows(visitors: visitors, members: members, flats: flats);
    expect(rows.map((r) => r.visitor.name), ['Kamla', 'zara']);
    final staff = rows.first;
    expect(staff.isStaff, isTrue);
    expect(staff.visitCount, 2);
    expect(staff.key, 'staff-m1');
    final freq = rows.last;
    expect(freq.key, 'freq-9000000001');
    expect(freq.visitCount, 2);
    expect(freq.visitor.id, '1', reason: 'latest visit is the template');
  });

  test('staff without photo takes the visitor photo', () {
    final visitors = [
      visit('1', '9876543210', 'K', '2026-10-12T09:00:00Z', photos: ['ph']),
      visit('2', '9876543210', 'K', '2026-10-11T09:00:00Z'),
    ];
    const members = [
      GateMember(
          id: 'm1',
          flatId: 'f1',
          name: 'Kamla',
          relation: 'maid',
          phone: '9876543210')
    ];
    final rows =
        buildQuickRows(visitors: visitors, members: members, flats: flats);
    expect(rows.single.visitor.visitorPhotos, ['ph']);
  });

  test('search and active visit lookup', () {
    final visitors = [
      visit('1', '9000000001', 'Ravi', '2026-10-12T09:00:00Z',
          inside: true, flat: '101'),
      visit('2', 'staff-abc', 'Kamla', '2026-10-12T08:00:00Z',
          inside: true, flat: '202'),
    ];
    const template = GateVisitor(
        id: 't',
        name: ' kamla ',
        phone: 'staff-zzz',
        flatNumber: '202',
        purpose: 'Maid',
        entryTime: '');
    expect(findActiveVisit(visitors, template)?.id, '2');
    const byPhone = GateVisitor(
        id: 't',
        name: 'x',
        phone: '9000000001',
        flatNumber: '9',
        purpose: '',
        entryTime: '');
    expect(findActiveVisit(visitors, byPhone)?.id, '1');
    expect(findActiveVisit([visit('3', '1', 'A', 'x')], byPhone), isNull);

    final rows = [
      const QuickRow(key: 'a', visitor: template, visitCount: 0, isStaff: true)
    ];
    expect(filterQuickRows(rows, ' MAID '), hasLength(1));
    expect(filterQuickRows(rows, '202'), hasLength(1));
    expect(filterQuickRows(rows, 'nope'), isEmpty);
  });

  test('quick entry copies the template', () {
    const src = GateVisitor(
        id: 's',
        name: 'A',
        phone: '1',
        flatNumber: '101',
        purpose: '',
        entryTime: '',
        category: 'service');
    final e = buildQuickEntry(
        source: src,
        guardId: 'G1',
        guardName: 'Ram',
        now: DateTime.utc(2026, 10, 12, 4));
    expect(e.purpose, 'Regular Visit');
    expect(e.category, 'service');
    expect(e.guardId, 'G1');
    expect(e.entryTime, '2026-10-12T04:00:00.000Z');
    expect(e.vehicleNumber, isNull);
  });
}
