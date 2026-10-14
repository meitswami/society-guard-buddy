import '../../../core/format/formatters.dart';
import '../../../models/blacklist_entry.dart';
import 'gate_models.dart';

/// Pure gate logic ported from the web guard pages (`DashboardPage`, `VisitorEntryPage`,
/// `useStore`, `entryCaps`). No Flutter / Supabase imports so it can be unit-tested.

// ---------------------------------------------------------------------------
// Dashboard (web `DashboardPage.tsx`)
// ---------------------------------------------------------------------------

/// Stat filters on the guard home (`StatFilter`).
enum DashboardFilter { all, visitor, vehicle, delivery, inside }

/// Furthest the date arrows go back (web `Math.min(dayOffset + 1, 7)`).
const int kMaxDashboardDayOffset = 7;

/// Alert when the same phone entered this many times on the selected day.
const int kRepeatVisitAlertThreshold = 3;

/// Entries listed under "Recent Entries".
const int kRecentEntriesLimit = 10;

/// `yyyy-MM-dd` of `now` minus [offset] days (web `format(subDays(new Date(), dayOffset), 'yyyy-MM-dd')`).
String dayIsoForOffset(DateTime now, int offset) =>
    Fmt.isoDate(DateTime(now.year, now.month, now.day - offset));

/// Clamp helpers for the dashboard date arrows.
int olderDayOffset(int offset) =>
    offset + 1 > kMaxDashboardDayOffset ? kMaxDashboardDayOffset : offset + 1;
int newerDayOffset(int offset) => offset - 1 < 0 ? 0 : offset - 1;

/// Visitors whose entry falls on the local calendar day [isoDay].
List<GateVisitor> visitorsOnDay(List<GateVisitor> all, String isoDay) =>
    all.where((v) => v.entryDay == isoDay).toList();

bool isDeliveryCategory(String category) =>
    category == 'delivery' || category == 'service';

class DashboardStats {
  const DashboardStats({
    required this.totalVisitors,
    required this.totalVehicles,
    required this.totalDeliveries,
    required this.currentlyInside,
  });

  final int totalVisitors;
  final int totalVehicles;
  final int totalDeliveries;
  final int currentlyInside;
}

DashboardStats dashboardStats(List<GateVisitor> day) => DashboardStats(
      totalVisitors: day.where((v) => v.category == 'visitor').length,
      totalVehicles: day.where((v) => v.hasVehicle).length,
      totalDeliveries: day.where((v) => isDeliveryCategory(v.category)).length,
      currentlyInside: day.where((v) => v.isInside).length,
    );

bool matchesDashboardFilter(GateVisitor v, DashboardFilter filter) =>
    switch (filter) {
      DashboardFilter.all => true,
      DashboardFilter.visitor => v.category == 'visitor',
      DashboardFilter.vehicle => v.hasVehicle,
      DashboardFilter.delivery => isDeliveryCategory(v.category),
      DashboardFilter.inside => v.isInside,
    };

/// Web `filteredEntries`: filter then keep the first [limit] (list is newest first).
List<GateVisitor> filterDashboardEntries(
        List<GateVisitor> day, DashboardFilter filter,
        {int limit = kRecentEntriesLimit}) =>
    day.where((v) => matchesDashboardFilter(v, filter)).take(limit).toList();

/// Tapping the active filter again clears it (web `toggleFilter`).
DashboardFilter toggleDashboardFilter(
        DashboardFilter current, DashboardFilter tapped) =>
    current == tapped ? DashboardFilter.all : tapped;

class RepeatVisitAlert {
  const RepeatVisitAlert(
      {required this.phone, required this.count, required this.name});

  final String phone;
  final int count;
  final String name;
}

/// Phones that entered [threshold]+ times on the day (web `alerts`). Order follows the
/// first appearance in [day] (newest first); the name is from the newest visit.
List<RepeatVisitAlert> repeatVisitAlerts(List<GateVisitor> day,
    {int threshold = kRepeatVisitAlertThreshold}) {
  final counts = <String, int>{};
  for (final v in day) {
    counts[v.phone] = (counts[v.phone] ?? 0) + 1;
  }
  final out = <RepeatVisitAlert>[];
  counts.forEach((phone, count) {
    if (count < threshold) return;
    GateVisitor? first;
    for (final v in day) {
      if (v.phone == phone) {
        first = v;
        break;
      }
    }
    final name = (first?.name ?? '').isEmpty ? 'Unknown' : first!.name;
    out.add(RepeatVisitAlert(phone: phone, count: count, name: name));
  });
  return out;
}

// ---------------------------------------------------------------------------
// Visitor entry (web `VisitorEntryPage.tsx`)
// ---------------------------------------------------------------------------

/// Visitor purposes: stored value → web i18n key.
const List<({String value, String key})> kVisitorPurposes = [
  (value: 'Visit', key: 'purpose.visit'),
  (value: 'Delivery', key: 'purpose.delivery'),
  (value: 'Meeting', key: 'purpose.meeting'),
  (value: 'Maintenance', key: 'purpose.maintenance'),
  (value: 'Guest', key: 'purpose.guest'),
  (value: 'Other', key: 'purpose.other'),
];

/// Document types (web `DOC_TYPES`).
const List<({String value, String en, String hi})> kDocumentTypes = [
  (value: 'aadhaar', en: 'Aadhaar', hi: 'आधार'),
  (value: 'driving_license', en: 'Driving License', hi: 'ड्राइविंग लाइसेंस'),
  (value: 'passport', en: 'Passport', hi: 'पासपोर्ट'),
  (value: 'other', en: 'Other', hi: 'अन्य'),
];

/// Keeps only digits, at most [maxLength] (web `replace(/\D/g, '')` + `maxLength`).
String digitsOnly(String input, {int? maxLength}) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  if (maxLength != null && d.length > maxLength) {
    return d.substring(0, maxLength);
  }
  return d;
}

/// Up to [max] earlier visitors with distinct phones containing [phone]; only while the
/// guard is typing (4–9 digits), like the web suggestion chips.
List<GateVisitor> phoneSuggestions(List<GateVisitor> all, String phone,
    {int max = 3}) {
  if (phone.length < 4 || phone.length >= 10) return const [];
  final seen = <String>{};
  final out = <GateVisitor>[];
  for (final v in all) {
    if (!v.phone.contains(phone) || seen.contains(v.phone)) continue;
    seen.add(v.phone);
    out.add(v);
    if (out.length >= max) break;
  }
  return out;
}

/// How many times [phone] already entered on [todayIso] (repeat-visit warning).
int visitsOnDayForPhone(List<GateVisitor> all, String phone, String todayIso) =>
    all.where((v) => v.phone == phone && v.entryDay == todayIso).length;

/// Most recent earlier visit of [phone] ([all] is newest first).
GateVisitor? previousVisitFor(List<GateVisitor> all, String phone) {
  for (final v in all) {
    if (v.phone == phone) return v;
  }
  return null;
}

/// Web `useStore.isBlacklisted(phone, vehicleNumber)`.
bool isBlacklistedIn(List<BlacklistEntry> list,
    {String? phone, String? vehicleNumber}) {
  final p = phone ?? '';
  final vn = vehicleNumber ?? '';
  return list.any((e) =>
      (p.isNotEmpty && e.phone == p) ||
      (vn.isNotEmpty && e.vehicleNumber == vn));
}

/// Form fields the previous visit pre-fills once a full phone is typed.
class VisitorPrefill {
  const VisitorPrefill(
      {required this.name,
      required this.documentType,
      required this.documentNumber,
      required this.flatNumber});

  final String name;
  final String documentType;
  final String documentNumber;
  final String flatNumber;
}

/// Web: `name: f.name || prev.name, documentType: prev.documentType,
/// documentNumber: f.documentNumber || prev.documentNumber, flatNumber: f.flatNumber || prev.flatNumber`.
VisitorPrefill prefillFromPrevious({
  required String name,
  required String documentType,
  required String documentNumber,
  required String flatNumber,
  required GateVisitor prev,
}) =>
    VisitorPrefill(
      name: name.isNotEmpty ? name : prev.name,
      documentType: prev.documentType,
      documentNumber:
          documentNumber.isNotEmpty ? documentNumber : prev.documentNumber,
      flatNumber: flatNumber.isNotEmpty ? flatNumber : prev.flatNumber,
    );

/// Placeholder phone when a pre-approved pass has no guest phone (web `'0000000000'`).
const String kPassPlaceholderPhone = '0000000000';

/// Current time as stored by the web (`new Date().toISOString()`).
String nowIsoUtc([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().toIso8601String();

/// Web `registerVisitor` payload (category `visitor`).
GateVisitor buildVisitorEntry({
  required String name,
  required String phone,
  required String flatNumber,
  required String purpose,
  required String documentType,
  required String documentNumber,
  String? documentPhoto,
  List<String> visitorPhotos = const [],
  required bool hasVehicle,
  String vehicleNumber = '',
  required String guardId,
  required String guardName,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final iso = nowIsoUtc(at);
  final vn = vehicleNumber.trim();
  return GateVisitor(
    id: 'V${at.millisecondsSinceEpoch}',
    name: name,
    phone: phone,
    documentType: documentType,
    documentNumber: documentNumber,
    documentPhoto: documentPhoto,
    visitorPhotos: visitorPhotos,
    flatNumber: flatNumber,
    purpose: purpose,
    entryTime: iso,
    guardId: guardId,
    guardName: guardName,
    category: 'visitor',
    vehicleNumber: hasVehicle && vn.isNotEmpty ? vn : null,
    vehicleEntryTime: hasVehicle && vn.isNotEmpty ? iso : null,
  );
}

/// Web `DeliveryEntryPage.handleSubmit` payload (category `delivery` / `service`).
GateVisitor buildDeliveryEntry({
  required bool isDelivery,
  required String name,
  required String phone,
  required String company,
  required String flatNumber,
  String vehicleNumber = '',
  List<String> personPhotos = const [],
  required String guardId,
  required String guardName,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final iso = nowIsoUtc(at);
  final vn = vehicleNumber.trim();
  return GateVisitor(
    id: 'D${at.millisecondsSinceEpoch}',
    name: name,
    phone: phone,
    documentType: 'other',
    documentNumber: '',
    visitorPhotos: personPhotos,
    flatNumber: flatNumber,
    purpose: deliveryPurpose(isDelivery: isDelivery, company: company),
    entryTime: iso,
    guardId: guardId,
    guardName: guardName,
    category: isDelivery ? 'delivery' : 'service',
    company: company,
    vehicleNumber: vn.isEmpty ? null : vn,
    vehicleEntryTime: vn.isEmpty ? null : iso,
  );
}

// ---------------------------------------------------------------------------
// Delivery / service (web `DeliveryEntryPage.tsx`)
// ---------------------------------------------------------------------------

const List<String> kDeliveryCompanies = [
  'Amazon',
  'Flipkart',
  'Swiggy',
  'Zomato',
  'BigBasket',
  'Blinkit',
  'Dunzo',
  'Other'
];

const List<({String value, String hi})> kServiceTypes = [
  (value: 'Housekeeping', hi: 'हाउसकीपिंग'),
  (value: 'Electrician', hi: 'इलेक्ट्रीशियन'),
  (value: 'Plumber', hi: 'प्लंबर'),
  (value: 'Carpenter', hi: 'बढ़ई'),
  (value: 'Painter', hi: 'पेंटर'),
  (value: 'AC Service', hi: 'AC सर्विस'),
  (value: 'Other', hi: 'अन्य'),
];

/// `Delivery - Amazon` / `Service - Plumber`.
String deliveryPurpose({required bool isDelivery, required String company}) =>
    isDelivery ? 'Delivery - $company' : 'Service - $company';

// ---------------------------------------------------------------------------
// Vehicles (web `VehiclePage.tsx`)
// ---------------------------------------------------------------------------

const List<({String value, String en, String hi})> kGateVehicleTypes = [
  (value: 'car', en: 'Car', hi: 'कार'),
  (value: 'bike', en: 'Bike', hi: 'बाइक'),
  (value: 'delivery', en: 'Delivery', hi: 'डिलीवरी'),
  (value: 'other', en: 'Other', hi: 'अन्य'),
];

bool vehicleMatchesSearch(GateResidentVehicle v, String search) {
  final q = search.toLowerCase();
  return v.vehicleNumber.toLowerCase().contains(q) ||
      v.flatNumber.toLowerCase().contains(q) ||
      v.residentName.toLowerCase().contains(q);
}

/// Resident name saved with a vehicle: the flat's primary member, else the flat owner.
String residentNameForFlat(GateFlat flat, List<GateMember> members) {
  for (final m in members) {
    if (m.flatId == flat.id && m.isPrimary) {
      final n = m.name.trim();
      if (n.isNotEmpty) return n;
      break;
    }
  }
  return (flat.ownerName ?? '').trim();
}

// ---------------------------------------------------------------------------
// Blacklist (web `BlacklistPage.tsx`)
// ---------------------------------------------------------------------------

bool blacklistMatchesSearch(BlacklistEntry e, String search) {
  if (search.isEmpty) return true;
  final q = search.toLowerCase();
  return (e.name != null && e.name!.toLowerCase().contains(q)) ||
      (e.phone != null && e.phone!.contains(q)) ||
      (e.vehicleNumber != null && e.vehicleNumber!.toLowerCase().contains(q)) ||
      e.reason.toLowerCase().contains(q);
}

// ---------------------------------------------------------------------------
// CAPS entry mode (web `src/lib/entryCaps.ts`)
// ---------------------------------------------------------------------------

const Set<String> kCapsExemptFields = {
  'phone',
  'password',
  'email',
  'otp',
  'amount',
  'target_amount',
  'contribution_amount',
  'screenshot_url',
  'transaction_id',
  'due_day',
  'razorpay',
};

/// Web `normalizeEntryValue(value, { field })`.
String normalizeEntryValue(String value,
    {required bool capsMode, String? field}) {
  if (!capsMode) return value;
  if (field != null && kCapsExemptFields.contains(field)) return value;
  return value.toUpperCase();
}
