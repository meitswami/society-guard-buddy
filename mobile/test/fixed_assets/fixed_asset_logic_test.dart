import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/fixed_assets/export/fixed_asset_export.dart';
import 'package:kutumbika_mobile/features/admin/fixed_assets/export/society_letterhead.dart';
import 'package:kutumbika_mobile/features/admin/fixed_assets/logic/fixed_asset_types.dart';

FixedAsset asset({
  String id = 'a1',
  String name = 'Lift',
  String? subHead = 'Lift',
  String status = 'active',
  String source = 'manual',
  double? bill,
  String? warrantyEnd,
  String? amcEnd,
  String? vendor,
  String? tag,
}) =>
    FixedAsset(
      id: id,
      societyId: 's1',
      assetName: name,
      majorHead: 'FIXED ASSETS',
      subHead: subHead,
      sourceType: source,
      status: status,
      billValue: bill,
      warrantyEndDate: warrantyEnd,
      amcEndDate: amcEnd,
      vendorName: vendor,
      assetTag: tag,
    );

void main() {
  final now = DateTime(2026, 10, 12, 9);

  group('computeEndDateFromMonths', () {
    test('adds months like JS setMonth (with overflow)', () {
      expect(computeEndDateFromMonths('2026-01-15', 12), '2027-01-15');
      expect(computeEndDateFromMonths('2024-01-31', 1), '2024-03-02');
      expect(computeEndDateFromMonths('2026-03-01', 60), '2031-03-01');
    });
    test('null for missing / non-positive input', () {
      expect(computeEndDateFromMonths(null, 12), isNull);
      expect(computeEndDateFromMonths('', 12), isNull);
      expect(computeEndDateFromMonths('2026-01-01', 0), isNull);
      expect(computeEndDateFromMonths('2026-01-01', null), isNull);
      expect(computeEndDateFromMonths('bad', 3), isNull);
    });
  });

  group('expiry helpers', () {
    test('daysUntilDate', () {
      expect(daysUntilDate('2026-10-12', now: now), 0);
      expect(daysUntilDate('2026-10-13', now: now), 1);
      expect(daysUntilDate('2026-10-11', now: now), -1);
      expect(daysUntilDate(null, now: now), isNull);
    });
    test('warranty / AMC soon and expired', () {
      final a = asset(warrantyEnd: '2026-12-01', amcEnd: '2026-10-01');
      expect(isWarrantyExpiringSoon(a, now: now), isTrue);
      expect(isWarrantyExpired(a, now: now), isFalse);
      expect(isAmcExpired(a, now: now), isTrue);
      expect(isAmcExpiringSoon(a, now: now), isFalse);
      expect(isWarrantyExpiringSoon(asset(warrantyEnd: '2027-02-01'), now: now),
          isFalse);
    });
  });

  test('computeFixedAssetReport', () {
    final s = computeFixedAssetReport([
      asset(id: '1', subHead: 'Lift', bill: 500000, warrantyEnd: '2026-11-01'),
      asset(
          id: '2',
          subHead: 'Gym Equipment',
          bill: 200000,
          source: 'finance_transaction',
          status: 'under_repair'),
      asset(
          id: '3',
          subHead: '  ',
          status: 'placeholder',
          source: 'builder_handover'),
      asset(id: '4', subHead: 'Lift', bill: 99999, status: 'disposed'),
    ], now: now);
    expect(s.totalAssets, 4);
    expect(s.activeCount, 2);
    expect(s.placeholderCount, 1);
    expect(s.totalBillValue, 700000);
    expect(s.warrantyExpiringSoon, 1);
    expect(s.bySubHead.map((r) => r.subHead),
        ['Lift', 'Gym Equipment', 'Uncategorized']);
    expect(s.bySource.first.source, 'Manual entry');
    expect(s.bySource.map((r) => r.key),
        ['manual', 'finance_transaction', 'builder_handover']);
  });

  test('register rows / headers match the web export', () {
    final rows = fixedAssetRegisterRows([
      asset(
          bill: 1500.5,
          status: 'placeholder',
          source: 'builder_handover',
          warrantyEnd: '2027-01-31')
    ]);
    expect(fixedAssetRegisterHeaders.length, 12);
    expect(rows.single[2], 'Not yet acquired');
    expect(rows.single[3], 'Builder handover');
    expect(rows.single[5], '1500.5');
    expect(rows.single[8], '31/01/2027');
  });

  test('labels (en / hi)', () {
    expect(fixedAssetStatusLabel('written_off'), 'Written off');
    expect(fixedAssetStatusLabel('active', hi: true), 'सक्रिय');
    expect(fixedAssetSourceLabel('unknown'), 'unknown');
  });

  test('search + filters', () {
    final a = asset(
        name: 'DG Set', subHead: 'DG Set', vendor: 'Kirloskar', tag: 'AST-9');
    expect(fixedAssetMatches(a, query: 'kirlo'), isTrue);
    expect(fixedAssetMatches(a, query: 'ast-9'), isTrue);
    expect(fixedAssetMatches(a, query: 'lift'), isFalse);
    expect(fixedAssetMatches(a, status: 'placeholder'), isFalse);
    expect(fixedAssetMatches(a, subHead: 'DG Set'), isTrue);
  });

  test('template seeding skips existing keys', () {
    final rows = templateSeedRows('s1', 'Admin', {'dg_set', 'elevator_lift'});
    expect(standardSocietyAssetTemplates.length, 18);
    expect(rows.length, 16);
    expect(rows.first['status'], 'placeholder');
    expect(rows.first['source_type'], 'builder_handover');
    expect(rows.any((r) => r['template_key'] == 'dg_set'), isFalse);
    final garden =
        rows.firstWhere((r) => r['template_key'] == 'garden_landscaping');
    expect(garden['amc_period_months'], isNull);
    expect(garden['warranty_period_months'], 12);
  });

  test('expense group filter', () {
    expect(isFixedAssetExpenseGroup(name: 'Lift repairs'), isTrue);
    expect(
        isFixedAssetExpenseGroup(
            name: 'Electricity', majorHead: 'FIXED ASSETS'),
        isTrue);
    expect(
        isFixedAssetExpenseGroup(name: 'Electricity', majorHead: 'UTILITIES'),
        isFalse);
  });

  test('moneyInr', () {
    expect(moneyInr(1234567.891), '₹12,34,567.89');
    expect(moneyInr(0), '₹0');
  });

  testWidgets('PDF builds in plain and auto letterhead modes', (tester) async {
    final assets = [
      asset(bill: 1000),
      asset(id: 'b', name: 'हिंदी नाम', bill: null)
    ];
    final plain = await tester.runAsync(() => buildFixedAssetPdf(
        societyName: 'Test',
        assets: assets,
        letterhead: null,
        pdfMode: 'plain',
        now: now));
    expect(plain, isNotNull);
    expect(plain!.length, greaterThan(1000));
    final lh = SocietyLetterhead(
        name: 'Green Park',
        address: 'Sector 5',
        city: 'Pune',
        contactPhone: '9999999999',
        letterheadMode: 'auto');
    final auto = await tester.runAsync(() => buildFixedAssetPdf(
        societyName: 'Green Park',
        assets: assets,
        letterhead: lh,
        pdfMode: 'letterhead',
        now: now));
    expect(auto!.length, greaterThan(1000));
  });
}
