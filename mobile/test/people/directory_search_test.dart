import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/shared/directory/directory_models.dart';
import 'package:kutumbika_mobile/features/shared/directory/directory_search.dart';

void main() {
  final flats = [
    PeopleFlat.fromJson({
      'id': 'f1',
      'flat_number': '101',
      'owner_name': 'Ravi Kumar',
      'owner_phone': '9811111111',
      'wing': 'A',
      'floor': '1st Floor'
    }),
    PeopleFlat.fromJson({
      'id': 'f2',
      'flat_number': '102',
      'owner_name': null,
      'flat_type': 'commercial'
    }),
    PeopleFlat.fromJson(
        {'id': 'f3', 'flat_number': '201', 'owner_name': 'Meena'}),
  ];
  final members = [
    PeopleMember.fromJson({
      'id': 'm1',
      'flat_id': 'f1',
      'name': 'Ravi Kumar',
      'phone': '9811111111',
      'relation': 'owner',
      'is_primary': true
    }),
    PeopleMember.fromJson({
      'id': 'm2',
      'flat_id': 'f2',
      'name': 'Anil',
      'whatsapp_phone': '9722222222',
      'email': 'anil@x.com',
      'relation': 'tenant',
      'age': 57,
      'gender': 'Male'
    }),
    PeopleMember.fromJson(
        {'id': 'm3', 'flat_id': 'f3', 'name': 'Lakshmi', 'relation': 'maid'}),
  ];
  final vehicles = [
    PeopleVehicle.fromJson({
      'id': 'v1',
      'flat_number': '201',
      'resident_name': 'Meena',
      'vehicle_number': 'MH12AB1234',
      'vehicle_type': 'car'
    }),
  ];
  final byFlat = membersByFlatId(members);
  final byNumber = vehiclesByFlatNumber(vehicles);

  List<String> dir(String q) => filterDirectoryFlats(
          flats: flats,
          membersByFlat: byFlat,
          vehiclesByFlat: byNumber,
          query: q)
      .map((f) => f.flatNumber)
      .toList();
  List<String> res(String q) => filterResidentDirectoryFlats(
          flats: flats,
          membersByFlat: byFlat,
          vehiclesByFlat: byNumber,
          query: q)
      .map((f) => f.flatNumber)
      .toList();

  test('model defaults like the web store', () {
    expect(flats[1].flatType, 'commercial');
    expect(flats[0].flatType, 'residential');
    expect(flats[0].isOccupied, isTrue);
    expect(members[2].relation, 'maid');
    expect(
        PeopleMember.fromJson(
            {'id': 'x', 'flat_id': 'f', 'name': 'N', 'age': 0}).age,
        isNull);
    expect(
        PeopleMember.fromJson({'id': 'x', 'flat_id': 'f', 'name': 'N'})
            .relation,
        'owner');
    expect(members[1].group, 'tenant');
    expect(
        PeopleMember.fromJson({
          'id': 'x',
          'flat_id': 'f',
          'name': 'N',
          'relation': 'tenant',
          'household_group': 'owner'
        }).group,
        'owner');
  });

  test('guard/admin directory search covers members, vehicles and flat fields',
      () {
    expect(dir(''), ['101', '102', '201']);
    expect(dir('ravi'), ['101']);
    expect(dir('97222'), ['102']);
    expect(dir('ANIL@X'), ['102']);
    expect(dir('commercial'), ['102']);
    expect(dir('mh12'), ['201']);
    expect(dir('1st floor'), ['101']);
    expect(dir('57'), ['102']);
    expect(dir('male'), ['102']);
  });

  test('resident directory search ignores WhatsApp / email / flat type', () {
    expect(res('97222'), isEmpty);
    expect(res('anil@'), isEmpty);
    expect(res('commercial'), isEmpty);
    expect(res('anil'), ['102']);
    expect(res('maid'), ['201']);
  });

  test('name hits', () {
    expect(directoryNameHits(byFlat['f2']!, 'anil@').map((m) => m.id), ['m2']);
    expect(residentNameHits(byFlat['f2']!, 'anil@'), isEmpty);
    expect(directoryNameHits(byFlat['f2']!, '  '), isEmpty);
  });

  test('visitor directory groups by phone', () {
    final visitors = [
      DirectoryVisitor.fromJson({
        'id': '1',
        'name': 'Old Name',
        'phone': '900',
        'flat_number': '101',
        'entry_time': '2026-01-01T10:00:00Z'
      }),
      DirectoryVisitor.fromJson({
        'id': '2',
        'name': 'New Name',
        'phone': '900',
        'flat_number': '102',
        'entry_time': '2026-03-01T10:00:00Z',
        'vehicle_number': 'KA01'
      }),
      DirectoryVisitor.fromJson({
        'id': '3',
        'name': 'Other',
        'phone': '800',
        'flat_number': '201',
        'entry_time': '2026-02-01T10:00:00Z',
        'visitor_photos': ['', 'data:image/png;base64,AA==']
      }),
    ];
    final entries = buildVisitorDirectory(visitors);
    expect(entries.map((e) => e.latest.id).toList(), ['2', '3']);
    expect(entries.first.totalVisits, 2);
    expect(entries.first.firstVisit, '2026-01-01T10:00:00Z');
    expect(entries[1].latest.visitorPhotos.length, 1);
    expect(
        filterVisitorDirectory(entries, 'ka01').map((e) => e.latest.id), ['2']);
    expect(
        filterVisitorDirectory(entries, '80').map((e) => e.latest.id), ['3']);
    expect(
        filterVisitorDirectory(entries, '201').map((e) => e.latest.id), ['3']);
    expect(filterVisitorDirectory(entries, 'old'), isEmpty);
  });

  test('compareFlatNumbers is numeric', () {
    final list = ['1001', '102', '101', 'A-10', 'A-9', '99'];
    list.sort(compareFlatNumbers);
    expect(list, ['99', '101', '102', '1001', 'A-9', 'A-10']);
  });
}
