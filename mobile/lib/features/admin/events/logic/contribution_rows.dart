import '../data/events_models.dart';
import 'flat_options.dart';
import 'js_compat.dart';
import 'split_math.dart';

/// Port of `EventManager.buildContributionRows` and the receipt label helpers
/// (`EventManager.contribLabel`, `EventFoodReconciliation.contribReceiptLabel`,
/// `financeLedgerDisplay.eventContribRefLabel`).

/// `receipt_basis`.
enum ReceiptBasis { flat, nonFlat }

/// Flat-wise collection mode (`split_mode` values in brackets).
enum FlatCollectMode {
  /// `same_per_flat`
  samePerFlat('same_per_flat'),

  /// `individual`
  individual('individual'),

  /// `headcount`
  headcount('headcount'),

  /// `lump_equal`
  lumpEqual('lump_equal');

  const FlatCollectMode(this.db);

  final String db;
}

/// Validation failures (mapped to UI strings by the screen).
enum ContributionError {
  /// 'Enter payer name or description (outsider or collective receipt)'
  nonFlatLabelRequired,

  /// 'Enter receipt amount'
  receiptAmountRequired,

  /// 'Select at least one flat'
  selectFlat,

  /// 'Enter amount for at least one flat'
  individualAmountRequired,

  /// 'Enter total amount to distribute by adults & kids'
  headcountTotalRequired,

  /// 'No headcount units — add members (age/relation) per flat in Residents'
  noHeadcountUnits,

  /// 'Enter lump sum total to split equally across flats'
  lumpTotalRequired,

  /// 'Enter amount per flat'
  perFlatAmountRequired,

  /// 'Select at least one flat for same-amount receipt'
  sameAmountSelectFlat,
}

class ContributionBuildResult {
  const ContributionBuildResult.ok(this.rows) : error = null;
  const ContributionBuildResult.fail(this.error) : rows = const [];

  final List<Map<String, dynamic>> rows;
  final ContributionError? error;
}

/// Flats a receipt applies to: the selection, else every eligible (occupied / all) flat.
List<String> contributionTargetFlats(List<String> selectedFlats, List<FlatLite> targetFlats) {
  if (selectedFlats.isNotEmpty) return selectedFlats;
  return [for (final f in targetFlats) f.flatNumber];
}

final RegExp _outsiderRe = RegExp('outsider|sponsor|vendor|guest', caseSensitive: false);

/// Whether a "without flat" label names an outsider (sponsor / vendor / guest).
bool isOutsiderLabel(String label) => _outsiderRe.hasMatch(label) || label.toLowerCase().contains('outsider');

/// Builds the `event_contributions` insert rows exactly like the web form.
ContributionBuildResult buildContributionRows({
  required String eventId,
  required String? screenshotUrl,
  required String verifiedAt,
  required String verifiedBy,
  required String batchId,
  required ReceiptBasis basis,
  required FlatCollectMode mode,
  required List<String> selectedFlats,
  required List<String> targetFlatNumbers,
  required String paymentMethod,
  required String amountText,
  required Map<String, String> perFlatAmounts,
  required String headcountTotalText,
  required String lumpTotalText,
  required String nonFlatLabel,
  required String adultWeightText,
  required String childWeightText,
  required List<FlatLite> flats,
  required List<FlatMemberRow> members,
  required Map<String, String> primaryByFlatId,
}) {
  final base = <String, dynamic>{
    'event_id': eventId,
    'payment_method': paymentMethod,
    'screenshot_url': screenshotUrl,
    'verified_by': verifiedBy,
    'verified_at': verifiedAt,
    'batch_id': batchId,
  };

  if (basis == ReceiptBasis.nonFlat) {
    final amount = jsNumber(amountText);
    final label = nonFlatLabel.trim();
    if (label.isEmpty) return const ContributionBuildResult.fail(ContributionError.nonFlatLabelRequired);
    if (!jsPositive(amount)) return const ContributionBuildResult.fail(ContributionError.receiptAmountRequired);
    final outsider = isOutsiderLabel(label);
    return ContributionBuildResult.ok([
      {
        ...base,
        'receipt_basis': 'non_flat',
        'contributor_type': outsider ? 'outsider' : 'flat_owner',
        'outsider_name': outsider ? label : null,
        'batch_label': label,
        'flat_number': null,
        'flat_id': null,
        'resident_name': label,
        'amount': amount,
        'split_mode': 'non_flat',
        'adult_count': null,
        'kid_count': null,
      },
    ]);
  }

  if (targetFlatNumbers.isEmpty) return const ContributionBuildResult.fail(ContributionError.selectFlat);

  final flatRowBase = <String, dynamic>{
    ...base,
    'receipt_basis': 'flat',
    'contributor_type': 'flat_owner',
    'outsider_name': null,
    'batch_label': null,
  };

  final index = MemberIndex(members);
  FlatLite? flatOf(String fn) {
    for (final f in flats) {
      if (f.flatNumber == fn) return f;
    }
    return null;
  }

  Map<String, dynamic> row(String flatNumber, double amount, String splitMode, int adults, int kids) {
    final flat = flatOf(flatNumber);
    return {
      ...flatRowBase,
      'flat_number': flatNumber,
      'flat_id': flat?.id,
      'resident_name': residentLabelForFlatRow(flat?.id, flat?.ownerName, primaryByFlatId),
      'amount': amount,
      'split_mode': splitMode,
      'adult_count': adults,
      'kid_count': kids,
    };
  }

  FlatHeadcount defaultHc(String fn) => index.headcount(fn, flatOf(fn)?.id, 1, 0.5);

  switch (mode) {
    case FlatCollectMode.individual:
      final entries = <MapEntry<String, double>>[
        for (final fn in targetFlatNumbers) MapEntry(fn, jsNumber(_orZero(perFlatAmounts[fn]))),
      ].where((e) => jsPositive(e.value)).toList();
      if (entries.isEmpty) return const ContributionBuildResult.fail(ContributionError.individualAmountRequired);
      return ContributionBuildResult.ok([
        for (final e in entries)
          () {
            final hc = defaultHc(e.key);
            return row(e.key, e.value, 'individual', hc.adults, hc.kids);
          }(),
      ]);

    case FlatCollectMode.headcount:
      final total = jsNumber(headcountTotalText);
      if (!jsPositive(total)) return const ContributionBuildResult.fail(ContributionError.headcountTotalRequired);
      final preview = headcountPreview(
        targetFlatNumbers: targetFlatNumbers,
        flats: flats,
        index: index,
        adultWeightText: adultWeightText,
        childWeightText: childWeightText,
        totalText: headcountTotalText,
      );
      if (preview.rows.fold<double>(0, (s, r) => s + r.units) <= 0) {
        return const ContributionBuildResult.fail(ContributionError.noHeadcountUnits);
      }
      return ContributionBuildResult.ok([
        for (final a in preview.amounts) row(a.flatNumber, a.amount, 'headcount', a.adults, a.kids),
      ]);

    case FlatCollectMode.lumpEqual:
      final total = jsNumber(lumpTotalText);
      if (!jsPositive(total)) return const ContributionBuildResult.fail(ContributionError.lumpTotalRequired);
      final share = round2(total / targetFlatNumbers.length);
      var allocated = 0.0;
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < targetFlatNumbers.length; i++) {
        final fn = targetFlatNumbers[i];
        final isLast = i == targetFlatNumbers.length - 1;
        final amount = isLast ? round2(total - allocated) : share;
        allocated += amount;
        final hc = defaultHc(fn);
        rows.add(row(fn, amount, 'lump_equal', hc.adults, hc.kids));
      }
      return ContributionBuildResult.ok(rows);

    case FlatCollectMode.samePerFlat:
      final amount = jsNumber(amountText);
      if (!jsPositive(amount)) return const ContributionBuildResult.fail(ContributionError.perFlatAmountRequired);
      final targets = selectedFlats.isNotEmpty ? selectedFlats : const <String>[];
      if (targets.isEmpty) return const ContributionBuildResult.fail(ContributionError.sameAmountSelectFlat);
      return ContributionBuildResult.ok([
        for (final fn in targets)
          () {
            final hc = defaultHc(fn);
            return row(fn, amount, 'same_per_flat', hc.adults, hc.kids);
          }(),
      ]);
  }
}

String _orZero(String? v) => (v == null || v.isEmpty) ? '0' : v;

class HeadcountPreview {
  const HeadcountPreview({required this.rows, required this.amounts, required this.adult, required this.child});

  final List<FlatHeadcount> rows;
  final List<HeadcountAmount> amounts;
  final double adult;
  final double child;
}

/// `EventManager.headcountPreview` (weights default to 1 / 0.5 when blank or zero).
HeadcountPreview headcountPreview({
  required List<String> targetFlatNumbers,
  required List<FlatLite> flats,
  required MemberIndex index,
  required String adultWeightText,
  required String childWeightText,
  required String totalText,
}) {
  final adult = jsNumberOr(adultWeightText, 1);
  final child = jsNumberOr(childWeightText, 0.5);
  final byNumber = <String, FlatLite>{};
  for (final f in flats) {
    byNumber.putIfAbsent(f.flatNumber, () => f);
  }
  final rows = [
    for (final fn in targetFlatNumbers) index.headcount(fn, byNumber[fn]?.id, adult, child),
  ];
  final total = jsNumberOr(totalText, 0);
  final amounts = total > 0 ? computeHeadcountAmounts(total, rows) : const <HeadcountAmount>[];
  return HeadcountPreview(rows: rows, amounts: amounts, adult: adult, child: child);
}

/// Words used in receipt labels (English defaults = web text; the UI passes translations).
class ContribLabelWords {
  const ContribLabelWords({
    this.flat = 'Flat',
    this.noFlat = 'No flat',
    this.receipt = 'Receipt',
    this.headcount = 'headcount',
    this.lump = 'lump ÷',
    this.individual = 'individual',
    this.receiptNoFlat = 'Receipt (no flat)',
  });

  final String flat;
  final String noFlat;
  final String receipt;
  final String headcount;
  final String lump;
  final String individual;
  final String receiptNoFlat;
}

String _label(EventContribution c, ContribLabelWords w, {required bool tagIndividual}) {
  if (c.receiptBasis == 'non_flat' || !c.hasFlat) {
    return '${w.noFlat} · ${_firstText([c.batchLabel, c.outsiderName, c.residentName]) ?? w.receipt}';
  }
  final parts = ['${w.flat} ${c.flatNumber}'];
  if ((c.residentName ?? '').isNotEmpty) parts.add(c.residentName!);
  if (c.adultCount != null || c.kidCount != null) parts.add('${c.adultCount ?? 0}A/${c.kidCount ?? 0}K');
  if (c.splitMode == 'headcount') parts.add(w.headcount);
  if (c.splitMode == 'lump_equal') parts.add(w.lump);
  if (tagIndividual && c.splitMode == 'individual') parts.add(w.individual);
  return parts.join(' · ');
}

/// `EventManager.contribLabel`.
String contributionLabel(EventContribution c, [ContribLabelWords w = const ContribLabelWords()]) => _label(c, w, tagIndividual: false);

/// `EventFoodReconciliation.contribReceiptLabel` (adds the `individual` tag).
String contributionReceiptLabel(EventContribution c, [ContribLabelWords w = const ContribLabelWords()]) =>
    _label(c, w, tagIndividual: true);

/// `financeLedgerDisplay.eventContribRefLabel` (Finance → receipts reference list).
String eventContribRefLabel(EventContribution c, [ContribLabelWords w = const ContribLabelWords()]) {
  if (c.receiptBasis == 'non_flat' || !c.hasFlat) {
    return _firstText([c.batchLabel, c.outsiderName, c.residentName]) ?? w.receiptNoFlat;
  }
  final parts = ['${w.flat} ${c.flatNumber}'];
  if ((c.residentName ?? '').isNotEmpty) parts.add(c.residentName!);
  if (c.splitMode == 'headcount') parts.add(w.headcount);
  return parts.join(' · ');
}

String? _firstText(List<String?> values) {
  for (final v in values) {
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}
