import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/events/data/events_models.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/contribution_rows.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/flat_options.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/split_math.dart';

/// `EventManager.buildContributionRows` parity.
void main() {
  const flats = [
    FlatLite(id: 'f1', flatNumber: '101', ownerName: 'Owner One', isOccupied: true),
    FlatLite(id: 'f2', flatNumber: '102', ownerName: 'Owner Two', isOccupied: true),
    FlatLite(id: 'f3', flatNumber: '103', ownerName: null, isOccupied: false),
  ];
  const members = [
    FlatMemberRow(flatId: 'f1', name: 'Ravi', age: 40),
    FlatMemberRow(flatId: 'f1', name: 'Kid', age: 8),
    FlatMemberRow(flatId: 'f2', name: 'Asha', age: 35),
    FlatMemberRow(flatId: 'f2', name: 'Raj', age: 36),
  ];
  const primary = {'f1': 'Ravi Kumar'};

  ContributionBuildResult build({
    ReceiptBasis basis = ReceiptBasis.flat,
    FlatCollectMode mode = FlatCollectMode.samePerFlat,
    List<String> selected = const [],
    String amount = '',
    Map<String, String> perFlat = const {},
    String headcountTotal = '',
    String lumpTotal = '',
    String label = '',
    String adultWeight = '1',
    String childWeight = '0.5',
  }) {
    final eligible = flats.where((f) => f.isOccupied == true).toList();
    return buildContributionRows(
      eventId: 'e1',
      screenshotUrl: 'https://x/y.png',
      verifiedAt: '2026-10-12T10:00:00.000Z',
      verifiedBy: 'Admin',
      batchId: 'b1',
      basis: basis,
      mode: mode,
      selectedFlats: selected,
      targetFlatNumbers: contributionTargetFlats(selected, eligible),
      paymentMethod: 'upi',
      amountText: amount,
      perFlatAmounts: perFlat,
      headcountTotalText: headcountTotal,
      lumpTotalText: lumpTotal,
      nonFlatLabel: label,
      adultWeightText: adultWeight,
      childWeightText: childWeight,
      flats: flats,
      members: members,
      primaryByFlatId: primary,
    );
  }

  group('without flat', () {
    test('outsider sponsor row', () {
      final r = build(basis: ReceiptBasis.nonFlat, label: ' ABC Sponsor ', amount: '5000');
      expect(r.error, isNull);
      final row = r.rows.single;
      expect(row['receipt_basis'], 'non_flat');
      expect(row['contributor_type'], 'outsider');
      expect(row['outsider_name'], 'ABC Sponsor');
      expect(row['batch_label'], 'ABC Sponsor');
      expect(row['resident_name'], 'ABC Sponsor');
      expect(row['flat_number'], isNull);
      expect(row['flat_id'], isNull);
      expect(row['amount'], 5000);
      expect(row['split_mode'], 'non_flat');
      expect(row['adult_count'], isNull);
      expect(row['batch_id'], 'b1');
      expect(row['payment_method'], 'upi');
      expect(row['screenshot_url'], 'https://x/y.png');
      expect(row['verified_by'], 'Admin');
      expect(row['event_id'], 'e1');
    });

    test('collective receipt is not an outsider', () {
      final row = build(basis: ReceiptBasis.nonFlat, label: 'Collective collection', amount: '1200').rows.single;
      expect(row['contributor_type'], 'flat_owner');
      expect(row['outsider_name'], isNull);
    });

    test('validations', () {
      expect(build(basis: ReceiptBasis.nonFlat, amount: '10').error, ContributionError.nonFlatLabelRequired);
      expect(build(basis: ReceiptBasis.nonFlat, label: 'Guest').error, ContributionError.receiptAmountRequired);
      expect(build(basis: ReceiptBasis.nonFlat, label: 'Guest', amount: '-5').error, ContributionError.receiptAmountRequired);
    });
  });

  group('flat-wise', () {
    test('same amount per selected flat', () {
      final r = build(selected: const ['102', '101'], amount: '500');
      expect(r.rows.map((e) => e['flat_number']).toList(), ['102', '101']);
      expect(r.rows.every((e) => e['amount'] == 500 && e['split_mode'] == 'same_per_flat'), isTrue);
      expect(r.rows[1]['resident_name'], 'Ravi Kumar');
      expect(r.rows[0]['resident_name'], 'Owner Two');
      expect(r.rows[1]['adult_count'], 1);
      expect(r.rows[1]['kid_count'], 1);
      expect(r.rows[0]['receipt_basis'], 'flat');
      expect(r.rows[0]['contributor_type'], 'flat_owner');
      expect(r.rows[0]['batch_label'], isNull);
    });

    test('same amount requires a selection and an amount', () {
      expect(build(amount: '500').error, ContributionError.sameAmountSelectFlat);
      expect(build(selected: const ['101']).error, ContributionError.perFlatAmountRequired);
    });

    test('individual amounts skip blank / invalid entries', () {
      final r = build(mode: FlatCollectMode.individual, perFlat: const {'101': '750', '102': 'abc'});
      expect(r.rows.single['flat_number'], '101');
      expect(r.rows.single['amount'], 750);
      expect(r.rows.single['split_mode'], 'individual');
      expect(build(mode: FlatCollectMode.individual).error, ContributionError.individualAmountRequired);
    });

    test('headcount distribution over eligible flats when nothing is selected', () {
      final r = build(mode: FlatCollectMode.headcount, headcountTotal: '1000');
      // 101: 1 adult + 1 kid = 1.5 units, 102: 2 adults = 2 units.
      expect(r.rows.map((e) => e['flat_number']).toList(), ['101', '102']);
      expect(r.rows.map((e) => e['amount']).toList(), [428.57, 571.43]);
      expect(r.rows.map((e) => '${e['adult_count']}/${e['kid_count']}').toList(), ['1/1', '2/0']);
      expect(r.rows.every((e) => e['split_mode'] == 'headcount'), isTrue);
      expect(build(mode: FlatCollectMode.headcount).error, ContributionError.headcountTotalRequired);
    });

    test('headcount with zero weights reports no units', () {
      final r = build(
        mode: FlatCollectMode.headcount,
        headcountTotal: '1000',
        selected: const ['103'],
        adultWeight: '-1',
        childWeight: '0',
      );
      expect(r.error, ContributionError.noHeadcountUnits);
    });

    test('lump sum split equally', () {
      final r = build(mode: FlatCollectMode.lumpEqual, lumpTotal: '1000', selected: const ['101', '102', '103']);
      expect(r.rows.map((e) => e['amount']).toList(), [333.33, 333.33, 333.34]);
      expect(r.rows.every((e) => e['split_mode'] == 'lump_equal'), isTrue);
      expect(r.rows[2]['flat_id'], 'f3');
      expect(r.rows[2]['resident_name'], isNull);
      expect(build(mode: FlatCollectMode.lumpEqual).error, ContributionError.lumpTotalRequired);
    });

    test('no eligible flat at all', () {
      final r = buildContributionRows(
        eventId: 'e1',
        screenshotUrl: null,
        verifiedAt: 'now',
        verifiedBy: 'Admin',
        batchId: 'b',
        basis: ReceiptBasis.flat,
        mode: FlatCollectMode.lumpEqual,
        selectedFlats: const [],
        targetFlatNumbers: const [],
        paymentMethod: 'cash',
        amountText: '',
        perFlatAmounts: const {},
        headcountTotalText: '',
        lumpTotalText: '100',
        nonFlatLabel: '',
        adultWeightText: '1',
        childWeightText: '0.5',
        flats: const [],
        members: const [],
        primaryByFlatId: const {},
      );
      expect(r.error, ContributionError.selectFlat);
    });
  });

  group('labels', () {
    EventContribution c({
      String? flat,
      String? basis = 'flat',
      String? resident,
      int? adults,
      int? kids,
      String? mode,
      String? batch,
      String? outsider,
    }) =>
        EventContribution(
          id: 'c1',
          eventId: 'e1',
          amount: 500,
          paymentMethod: 'cash',
          flatNumber: flat,
          receiptBasis: basis,
          residentName: resident,
          adultCount: adults,
          kidCount: kids,
          splitMode: mode,
          batchLabel: batch,
          outsiderName: outsider,
        );

    test('EventManager label', () {
      expect(contributionLabel(c(flat: '101', resident: 'Ravi', adults: 2, kids: 1, mode: 'headcount')),
          'Flat 101 · Ravi · 2A/1K · headcount');
      expect(contributionLabel(c(flat: '101', mode: 'lump_equal', kids: 1)), 'Flat 101 · 0A/1K · lump ÷');
      expect(contributionLabel(c(flat: '101', mode: 'individual')), 'Flat 101');
      expect(contributionLabel(c(basis: 'non_flat', batch: 'ABC Sponsor')), 'No flat · ABC Sponsor');
      expect(contributionLabel(c(flat: '', basis: 'flat')), 'No flat · Receipt');
    });

    test('reconciliation label tags individual receipts', () {
      expect(contributionReceiptLabel(c(flat: '101', mode: 'individual', adults: 1, kids: 0)), 'Flat 101 · 1A/0K · individual');
      expect(contributionReceiptLabel(c(basis: 'non_flat', outsider: 'Guest')), 'No flat · Guest');
    });

    test('finance reference label (financeChargeUtils.test.ts case)', () {
      expect(eventContribRefLabel(c(flat: 'A-101', resident: 'Ravi', mode: 'headcount')), 'Flat A-101 · Ravi · headcount');
      expect(eventContribRefLabel(c(basis: 'non_flat')), 'Receipt (no flat)');
    });
  });
}
