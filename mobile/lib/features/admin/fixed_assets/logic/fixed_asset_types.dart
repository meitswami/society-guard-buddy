import '../../audit/logic/js_compat.dart';

/// Port of `src/lib/fixedAssetTypes.ts` (pure Dart).

const List<String> fixedAssetSourceTypes = [
  'builder_handover',
  'finance_transaction',
  'manual'
];
const List<String> fixedAssetStatuses = [
  'active',
  'under_repair',
  'disposed',
  'written_off',
  'placeholder'
];

class FixedAsset {
  const FixedAsset({
    required this.id,
    required this.societyId,
    required this.assetName,
    this.description,
    required this.majorHead,
    this.subHead,
    this.expenseGroupId,
    required this.sourceType,
    this.financeEntryId,
    this.expenseId,
    this.acquisitionDate,
    this.billValue,
    this.vendorName,
    this.vendorContact,
    this.assetTag,
    this.serialNumber,
    this.location,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.warrantyPeriodMonths,
    this.amcStartDate,
    this.amcEndDate,
    this.amcPeriodMonths,
    this.amcVendor,
    required this.status,
    this.disposalDate,
    this.disposalValue,
    this.disposalNotes,
    this.billAttachmentUrl,
    this.templateKey,
    this.notes,
    this.createdBy,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String societyId;
  final String assetName;
  final String? description;
  final String majorHead;
  final String? subHead;
  final String? expenseGroupId;
  final String sourceType;
  final String? financeEntryId;
  final String? expenseId;
  final String? acquisitionDate;
  final double? billValue;
  final String? vendorName;
  final String? vendorContact;
  final String? assetTag;
  final String? serialNumber;
  final String? location;
  final String? warrantyStartDate;
  final String? warrantyEndDate;
  final int? warrantyPeriodMonths;
  final String? amcStartDate;
  final String? amcEndDate;
  final int? amcPeriodMonths;
  final String? amcVendor;
  final String status;
  final String? disposalDate;
  final double? disposalValue;
  final String? disposalNotes;
  final String? billAttachmentUrl;
  final String? templateKey;
  final String? notes;
  final String? createdBy;
  final String createdAt;
  final String updatedAt;

  static double? _num(Object? v) => v == null ? null : jsNumber(v);
  static int? _int(Object? v) => v == null ? null : jsNumber(v).truncate();
  static String? _s(Object? v) => v?.toString();

  factory FixedAsset.fromJson(Map<String, dynamic> j) => FixedAsset(
        id: (j['id'] ?? '').toString(),
        societyId: (j['society_id'] ?? '').toString(),
        assetName: (j['asset_name'] ?? '').toString(),
        description: _s(j['description']),
        majorHead: (j['major_head'] ?? 'FIXED ASSETS').toString(),
        subHead: _s(j['sub_head']),
        expenseGroupId: _s(j['expense_group_id']),
        sourceType: (j['source_type'] ?? 'manual').toString(),
        financeEntryId: _s(j['finance_entry_id']),
        expenseId: _s(j['expense_id']),
        acquisitionDate: _s(j['acquisition_date']),
        billValue: _num(j['bill_value']),
        vendorName: _s(j['vendor_name']),
        vendorContact: _s(j['vendor_contact']),
        assetTag: _s(j['asset_tag']),
        serialNumber: _s(j['serial_number']),
        location: _s(j['location']),
        warrantyStartDate: _s(j['warranty_start_date']),
        warrantyEndDate: _s(j['warranty_end_date']),
        warrantyPeriodMonths: _int(j['warranty_period_months']),
        amcStartDate: _s(j['amc_start_date']),
        amcEndDate: _s(j['amc_end_date']),
        amcPeriodMonths: _int(j['amc_period_months']),
        amcVendor: _s(j['amc_vendor']),
        status: (j['status'] ?? 'active').toString(),
        disposalDate: _s(j['disposal_date']),
        disposalValue: _num(j['disposal_value']),
        disposalNotes: _s(j['disposal_notes']),
        billAttachmentUrl: _s(j['bill_attachment_url']),
        templateKey: _s(j['template_key']),
        notes: _s(j['notes']),
        createdBy: _s(j['created_by']),
        createdAt: (j['created_at'] ?? '').toString(),
        updatedAt: (j['updated_at'] ?? '').toString(),
      );
}

class StandardAssetTemplate {
  const StandardAssetTemplate({
    required this.templateKey,
    required this.assetName,
    required this.subHead,
    required this.description,
    required this.locationHint,
    this.defaultWarrantyMonths,
    this.defaultAmcMonths,
  });

  final String templateKey;
  final String assetName;
  final String subHead;
  final String description;
  final String locationHint;
  final int? defaultWarrantyMonths;
  final int? defaultAmcMonths;
}

/// Standard assets commonly found in Indian residential societies (stored in English like the web).
const List<StandardAssetTemplate> standardSocietyAssetTemplates = [
  StandardAssetTemplate(
      templateKey: 'garden_landscaping',
      assetName: 'Garden & Landscaping',
      subHead: 'Garden & Landscaping',
      description:
          'Lawn, plants, irrigation, garden furniture and landscaping from builder handover.',
      locationHint: 'Common garden / podium',
      defaultWarrantyMonths: 12),
  StandardAssetTemplate(
      templateKey: 'gym_equipment',
      assetName: 'Gymnasium Equipment',
      subHead: 'Gym Equipment',
      description:
          'Treadmills, weights, cycles and other fitness equipment in society gym.',
      locationHint: 'Society gym / clubhouse',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'children_play_area',
      assetName: "Children's Play Area",
      subHead: 'Play Area Equipment',
      description:
          'Swings, slides, see-saw and safety flooring in children play zone.',
      locationHint: 'Kids play area',
      defaultWarrantyMonths: 24),
  StandardAssetTemplate(
      templateKey: 'dg_set',
      assetName: 'Diesel Generator (DG Set)',
      subHead: 'DG Set',
      description: 'Backup power generator with AMF panel and fuel tank.',
      locationHint: 'DG room / basement',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'elevator_lift',
      assetName: 'Elevator / Lift',
      subHead: 'Lift',
      description: 'Passenger lifts with machine room / MRL equipment.',
      locationHint: 'Lift lobby / shaft',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'fire_fighting',
      assetName: 'Fire Fighting Equipment',
      subHead: 'Fire Fighting',
      description:
          'Hydrants, extinguishers, hose reels, sprinkler and alarm panel.',
      locationHint: 'All floors / pump room',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'borewell',
      assetName: 'Borewell / Water Boring',
      subHead: 'Borewell',
      description: 'Borewell, submersible pump and related piping.',
      locationHint: 'Pump room / underground',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'water_softener',
      assetName: 'Water Softener',
      subHead: 'Water Softener',
      description:
          'Water softening plant / RO pre-treatment for society supply.',
      locationHint: 'Pump room / STP area',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'swimming_pool',
      assetName: 'Swimming Pool Equipment',
      subHead: 'Swimming Pool',
      description: 'Filtration plant, pumps and pool accessories.',
      locationHint: 'Swimming pool plant room',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'cctv_security',
      assetName: 'CCTV & Security Systems',
      subHead: 'CCTV',
      description: 'Cameras, NVR/DVR, access control and monitoring equipment.',
      locationHint: 'Gate, lobby, parking, perimeter',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'solar_panel',
      assetName: 'Solar Panel System',
      subHead: 'Solar',
      description: 'Rooftop solar PV panels, inverters and net-metering setup.',
      locationHint: 'Terrace / rooftop',
      defaultWarrantyMonths: 60,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'stp_wtp',
      assetName: 'STP / WTP Plant',
      subHead: 'STP / WTP',
      description: 'Sewage treatment or water treatment plant machinery.',
      locationHint: 'STP / WTP room',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'common_lighting',
      assetName: 'Common Area Lighting',
      subHead: 'Common Lighting',
      description:
          'LED fixtures, poles and drivers for lobbies, parking and pathways.',
      locationHint: 'Common areas',
      defaultWarrantyMonths: 24),
  StandardAssetTemplate(
      templateKey: 'intercom_pa',
      assetName: 'Intercom / PA System',
      subHead: 'Intercom',
      description: 'Flat intercom, lobby panel and public address system.',
      locationHint: 'Lobby / guard room',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'boom_barrier',
      assetName: 'Parking Boom Barrier',
      subHead: 'Boom Barrier',
      description:
          'Vehicle entry/exit boom barrier with RFID or manual control.',
      locationHint: 'Main gate / parking entry',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
  StandardAssetTemplate(
      templateKey: 'rainwater_harvesting',
      assetName: 'Rainwater Harvesting System',
      subHead: 'Rainwater Harvesting',
      description: 'Collection pits, filters and recharge structures.',
      locationHint: 'Terrace / recharge pits',
      defaultWarrantyMonths: 24),
  StandardAssetTemplate(
      templateKey: 'compound_gate',
      assetName: 'Compound Wall & Main Gate',
      subHead: 'Compound & Gate',
      description: 'Perimeter wall, main gate structure and automation.',
      locationHint: 'Society perimeter',
      defaultWarrantyMonths: 24),
  StandardAssetTemplate(
      templateKey: 'electrical_panel',
      assetName: 'HT/LT Electrical Panel',
      subHead: 'Electrical Panel',
      description: 'Main LT panel, transformers and distribution boards.',
      locationHint: 'Electrical room',
      defaultWarrantyMonths: 12,
      defaultAmcMonths: 12),
];

const Map<String, String> fixedAssetStatusLabels = {
  'active': 'Active',
  'under_repair': 'Under repair',
  'disposed': 'Disposed',
  'written_off': 'Written off',
  'placeholder': 'Not yet acquired',
};

const Map<String, String> _statusLabelsHi = {
  'active': 'सक्रिय',
  'under_repair': 'मरम्मत में',
  'disposed': 'निपटाया गया',
  'written_off': 'बट्टे खाते में',
  'placeholder': 'अभी प्राप्त नहीं',
};

const Map<String, String> fixedAssetSourceLabels = {
  'builder_handover': 'Builder handover',
  'finance_transaction': 'Finance payment',
  'manual': 'Manual entry',
};

const Map<String, String> _sourceLabelsHi = {
  'builder_handover': 'बिल्डर हस्तांतरण',
  'finance_transaction': 'वित्त भुगतान',
  'manual': 'मैन्युअल प्रविष्टि',
};

String fixedAssetStatusLabel(String status, {bool hi = false}) =>
    (hi ? _statusLabelsHi[status] : fixedAssetStatusLabels[status]) ?? status;

String fixedAssetSourceLabel(String source, {bool hi = false}) =>
    (hi ? _sourceLabelsHi[source] : fixedAssetSourceLabels[source]) ?? source;

DateTime? _ymdLocal(String? iso, {int hour = 12}) {
  if (iso == null || iso.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return null;
  final y = int.parse(m.group(1)!),
      mo = int.parse(m.group(2)!),
      d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d, hour);
}

/// `computeEndDateFromMonths` — JS `setMonth` overflow semantics, ISO (UTC) date of local noon.
String? computeEndDateFromMonths(String? startIso, int? months) {
  if (startIso == null || startIso.isEmpty || months == null || months <= 0)
    return null;
  final d = _ymdLocal(startIso);
  if (d == null) return null;
  final end = DateTime(d.year, d.month + months, d.day, 12);
  return ymdOfDate(end.toUtc());
}

/// Whole days from today (local noon) until [iso] (ceil), `null` when not a date.
int? daysUntilDate(String? iso, {DateTime? now}) {
  final target = _ymdLocal(iso);
  if (target == null) return null;
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day, 12);
  return (target.difference(today).inMilliseconds / (1000 * 60 * 60 * 24))
      .ceil();
}

bool isWarrantyExpiringSoon(FixedAsset a,
    {int withinDays = 60, DateTime? now}) {
  final d = daysUntilDate(a.warrantyEndDate, now: now);
  return d != null && d >= 0 && d <= withinDays;
}

bool isAmcExpiringSoon(FixedAsset a, {int withinDays = 60, DateTime? now}) {
  final d = daysUntilDate(a.amcEndDate, now: now);
  return d != null && d >= 0 && d <= withinDays;
}

bool isWarrantyExpired(FixedAsset a, {DateTime? now}) {
  final d = daysUntilDate(a.warrantyEndDate, now: now);
  return d != null && d < 0;
}

bool isAmcExpired(FixedAsset a, {DateTime? now}) {
  final d = daysUntilDate(a.amcEndDate, now: now);
  return d != null && d < 0;
}

/// Seed rows for templates whose key is not yet in the register (`seedStandardAssetTemplates`).
List<Map<String, Object?>> templateSeedRows(
        String societyId, String createdBy, Set<String> existingKeys) =>
    [
      for (final t in standardSocietyAssetTemplates)
        if (!existingKeys.contains(t.templateKey))
          {
            'society_id': societyId,
            'asset_name': t.assetName,
            'description': t.description,
            'major_head': 'FIXED ASSETS',
            'sub_head': t.subHead,
            'source_type': 'builder_handover',
            'status': 'placeholder',
            'location': t.locationHint,
            'template_key': t.templateKey,
            'warranty_period_months': t.defaultWarrantyMonths,
            'amc_period_months': t.defaultAmcMonths,
            'created_by': createdBy,
          },
    ];

final RegExp _assetGroupPattern = RegExp(
    r'asset|equipment|lift|dg|softener|softner|gym|garden|cctv|fire|boring|play',
    caseSensitive: false);

/// `fetchExpenseGroupsForFixedAssets` filter.
bool isFixedAssetExpenseGroup({required String name, String? majorHead}) =>
    (majorHead ?? '').trim() == 'FIXED ASSETS' ||
    _assetGroupPattern.hasMatch(name);

/* ─── Report (fixedAssetReport.ts) ─── */

class FixedAssetReportSummary {
  const FixedAssetReportSummary({
    required this.totalAssets,
    required this.activeCount,
    required this.placeholderCount,
    required this.totalBillValue,
    required this.warrantyExpiringSoon,
    required this.amcExpiringSoon,
    required this.warrantyExpired,
    required this.amcExpired,
    required this.bySubHead,
    required this.bySource,
  });

  final int totalAssets;
  final int activeCount;
  final int placeholderCount;
  final double totalBillValue;
  final int warrantyExpiringSoon;
  final int amcExpiringSoon;
  final int warrantyExpired;
  final int amcExpired;
  final List<({String subHead, int count, double value})> bySubHead;

  /// `source` is the English label (web); `key` the raw source_type.
  final List<({String source, String key, int count, double value})> bySource;
}

FixedAssetReportSummary computeFixedAssetReport(List<FixedAsset> assets,
    {DateTime? now}) {
  final active =
      assets.where((a) => a.status != 'disposed' && a.status != 'written_off');
  final bySub = <String, ({int count, double value})>{};
  final bySrc = <String, ({String key, int count, double value})>{};
  var total = 0.0;
  var wSoon = 0, aSoon = 0, wExp = 0, aExp = 0;
  for (final a in active) {
    final val = a.billValue ?? 0;
    total += val;
    final sub = (a.subHead ?? '').trim().isNotEmpty
        ? a.subHead!.trim()
        : 'Uncategorized';
    final s = bySub[sub] ?? (count: 0, value: 0.0);
    bySub[sub] = (count: s.count + 1, value: s.value + val);
    final src = fixedAssetSourceLabels[a.sourceType] ?? a.sourceType;
    final r = bySrc[src] ?? (key: a.sourceType, count: 0, value: 0.0);
    bySrc[src] = (key: r.key, count: r.count + 1, value: r.value + val);
    if (isWarrantyExpiringSoon(a, now: now)) wSoon++;
    if (isAmcExpiringSoon(a, now: now)) aSoon++;
    if (isWarrantyExpired(a, now: now)) wExp++;
    if (isAmcExpired(a, now: now)) aExp++;
  }
  return FixedAssetReportSummary(
    totalAssets: assets.length,
    activeCount: assets
        .where((a) => a.status == 'active' || a.status == 'under_repair')
        .length,
    placeholderCount: assets.where((a) => a.status == 'placeholder').length,
    totalBillValue: total,
    warrantyExpiringSoon: wSoon,
    amcExpiringSoon: aSoon,
    warrantyExpired: wExp,
    amcExpired: aExp,
    bySubHead: stableSorted(
      [
        for (final e in bySub.entries)
          (subHead: e.key, count: e.value.count, value: e.value.value)
      ],
      (a, b) {
        final c = numDesc(a.value, b.value);
        return c != 0 ? c : jsLocaleCompare(a.subHead, b.subHead);
      },
    ),
    bySource: stableSorted(
      [
        for (final e in bySrc.entries)
          (
            source: e.key,
            key: e.value.key,
            count: e.value.count,
            value: e.value.value
          )
      ],
      (a, b) => numDesc(a.value, b.value),
    ),
  );
}

const List<String> fixedAssetRegisterHeaders = [
  'Asset name',
  'Sub-head',
  'Status',
  'Source',
  'Acquisition date',
  'Bill value (₹)',
  'Vendor',
  'Location',
  'Warranty end',
  'AMC end',
  'AMC vendor',
  'Description',
];

List<List<String>> fixedAssetRegisterRows(List<FixedAsset> assets) => [
      for (final a in assets)
        [
          a.assetName,
          a.subHead ?? '',
          fixedAssetStatusLabels[a.status] ?? a.status,
          fixedAssetSourceLabels[a.sourceType] ?? a.sourceType,
          (a.acquisitionDate ?? '').isNotEmpty
              ? fmtIsoDateToDisplay(a.acquisitionDate)
              : '',
          a.billValue != null ? jsNumStr(a.billValue!) : '',
          a.vendorName ?? '',
          a.location ?? '',
          (a.warrantyEndDate ?? '').isNotEmpty
              ? fmtIsoDateToDisplay(a.warrantyEndDate)
              : '',
          (a.amcEndDate ?? '').isNotEmpty
              ? fmtIsoDateToDisplay(a.amcEndDate)
              : '',
          a.amcVendor ?? '',
          a.description ?? '',
        ],
    ];

/// Register search haystack (name, sub-head, vendor, location, tag, serial, description).
bool fixedAssetMatches(FixedAsset a,
    {String query = '', String status = '', String subHead = ''}) {
  if (status.isNotEmpty && a.status != status) return false;
  if (subHead.isNotEmpty && a.subHead != subHead) return false;
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = [
    a.assetName,
    a.subHead,
    a.vendorName,
    a.location,
    a.assetTag,
    a.serialNumber,
    a.description
  ].where((s) => s != null && s.isNotEmpty).join(' ').toLowerCase();
  return hay.contains(q);
}
