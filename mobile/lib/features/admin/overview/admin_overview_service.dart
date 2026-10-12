import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/formatters.dart';
import '../../../core/supabase/db.dart';

/// Data for the admin home (web `AdminDashboard` `loadStats`, `loadKycPending`,
/// monthly collection + expense breakdown modals).
class AdminOverviewStats {
  const AdminOverviewStats({
    this.visitors = 0,
    this.visitorsGuest = 0,
    this.visitorsService = 0,
    this.guards = 0,
    this.flats = 0,
    this.members = 0,
    this.vehicles = 0,
    this.vehiclesCars = 0,
    this.vehiclesTwoWheelers = 0,
    this.blacklist = 0,
    this.meetingsHeld = 0,
    this.maintenanceCollected = 0,
    this.expenseTotal = 0,
  });

  final int visitors;
  final int visitorsGuest;
  final int visitorsService;
  final int guards;
  final int flats;
  final int members;
  final int vehicles;
  final int vehiclesCars;
  final int vehiclesTwoWheelers;
  final int blacklist;
  final int meetingsHeld;
  final double maintenanceCollected;
  final double expenseTotal;
}

class KycPendingGuard {
  const KycPendingGuard({required this.id, required this.name, required this.guardId});

  final String id;
  final String name;
  final String guardId;
}

class MonthTotal {
  const MonthTotal(this.month, this.total, this.count);

  final String month; // yyyy-MM or 'Unknown'
  final double total;
  final int count;
}

class ExpenseBucket {
  const ExpenseBucket({required this.key, required this.label, required this.isEventFood, required this.total, required this.count, required this.months});

  final String key;
  final String label;
  final bool isEventFood;
  final double total;
  final int count;
  final List<MonthTotal> months;
}

/// Chart-of-accounts major heads (web `SOCIETY_PAYMENT_MAJOR_HEADS`).
const kSocietyPaymentMajorHeads = [
  'SALARY & WAGES',
  'OPERATION & MAINTENANCE',
  'FIXED ASSETS',
  'LEGAL & PROFESSIONAL FEES',
  'SOCIETY CORPUS FUND',
  'CORPUS FUND (LEGAL)',
  'FIXED DEPOSIT',
  'BANK',
  'CASH',
  'MISCELLANEOUS',
];

/// Web `inferMajorHeadFromGroupName`.
String inferMajorHeadFromGroupName(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return 'MISCELLANEOUS';
  bool m(String re) => RegExp(re).hasMatch(n);
  if (m(r'corpus.*legal|legal.*corpus')) return 'CORPUS FUND (LEGAL)';
  if (m(r'corpus|society fund')) return 'SOCIETY CORPUS FUND';
  if (m(r'fixed deposit|\bfd\b')) return 'FIXED DEPOSIT';
  if (m(r'^bank\b|bank account')) return 'BANK';
  if (m(r'^cash\b|petty cash')) return 'CASH';
  if (m(r'legal|professional|audit|advocate|lawyer')) return 'LEGAL & PROFESSIONAL FEES';
  if (m(r'fixed asset|furniture|chair|equipment|machine|softner|softener|installation|asset')) return 'FIXED ASSETS';
  if (m(r'salary|wage|security|guard|sweeper|cleaning|garden|housekeeping|house keeping|labour|labor')) return 'SALARY & WAGES';
  if (m(r'electric|water|wifi|cctv|dg set|diesel|printing|maintenance|repair|insurance|lift|amc|utility')) {
    return 'OPERATION & MAINTENANCE';
  }
  return 'MISCELLANEOUS';
}

/// Web `resolveGroupMajorHead`.
String resolveGroupMajorHead(String name, String? majorHead) {
  final stored = majorHead?.trim();
  if (stored != null && kSocietyPaymentMajorHeads.contains(stored)) return stored;
  return inferMajorHeadFromGroupName(name);
}

/// Web `extractMonthFromTitle`: "Maintenance February 2026" → `2026-02`.
String? extractMonthFromTitle(String title, {DateTime? now}) {
  // Same key order as the web object literal (first match wins).
  const names = {
    'jan': '01', 'january': '01', 'feb': '02', 'february': '02', 'mar': '03', 'march': '03',
    'apr': '04', 'april': '04', 'may': '05', 'jun': '06', 'june': '06',
    'jul': '07', 'july': '07', 'aug': '08', 'august': '08', 'sep': '09', 'september': '09',
    'oct': '10', 'october': '10', 'nov': '11', 'november': '11', 'dec': '12', 'december': '12',
  };
  final lower = title.toLowerCase();
  for (final e in names.entries) {
    if (lower.contains(e.key)) {
      final y4 = RegExp(r'20\d{2}').firstMatch(lower);
      if (y4 != null) return '${y4.group(0)}-${e.value}';
      final y2 = RegExp(r'\b(\d{2})\b').firstMatch(lower);
      if (y2 != null) return '20${y2.group(1)}-${e.value}';
      return '${(now ?? DateTime.now()).year}-${e.value}';
    }
  }
  return null;
}

/// `2026-02` → `Feb 2026`.
String formatMonthLabel(String ym) {
  final parts = ym.split('-');
  if (ym.length < 7 || parts.length < 2) return ym;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final idx = int.tryParse(parts[1]) ?? 0;
  return '${idx >= 1 && idx <= 12 ? months[idx - 1] : parts[1]} ${parts[0]}';
}

class AdminOverviewService {
  Future<int> _count(PostgrestFilterBuilder<dynamic> q) async {
    final res = await q.count(CountOption.exact);
    return res.count;
  }

  Future<AdminOverviewStats> loadStats(String sid) async {
    if (!dbReady) return const AdminOverviewStats();
    final counts = await Future.wait([
      _count(db.from('visitors').select('id').eq('society_id', sid)),
      _count(db.from('visitors').select('id').eq('society_id', sid).eq('category', 'visitor')),
      _count(db.from('visitors').select('id').eq('society_id', sid).eq('category', 'service')),
      _count(db.from('guards').select('id').eq('society_id', sid)),
      _count(db.from('flats').select('id').eq('society_id', sid)),
      _count(db.from('resident_vehicles').select('id').eq('society_id', sid)),
      _count(db.from('resident_vehicles').select('id').eq('society_id', sid).eq('vehicle_type', 'car')),
      _count(db.from('resident_vehicles').select('id').eq('society_id', sid).inFilter('vehicle_type', ['bike', 'cycle', 'activa'])),
      _count(db.from('blacklist').select('id').eq('society_id', sid)),
      _count(db.from('meetings').select('id').eq('society_id', sid)),
    ]);

    final flatIds = rowsOf(await db.from('flats').select('id').eq('society_id', sid)).map((r) => r['id'] as String).toList();
    final results = await Future.wait<Object?>([
      flatIds.isEmpty ? Future.value(0) : _count(db.from('members').select('id').inFilter('flat_id', flatIds)),
      db.from('maintenance_charges').select('id').eq('society_id', sid),
      db
          .from('finance_entries')
          .select('id, total_amount, destination')
          .eq('society_id', sid)
          .eq('payment_status', 'verified')
          .inFilter('destination', ['current_month_maintenance', 'corpus']),
      db.from('expense_groups').select('id').eq('society_id', sid),
    ]);
    final members = results[0] as int;
    final chargeIds = rowsOf(results[1]).map((r) => r['id'] as String).toList();
    final ledger = rowsOf(results[2]);
    final groupIds = rowsOf(results[3]).map((r) => r['id'] as String).toList();

    final pays = chargeIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : rowsOf(await db
            .from('maintenance_payments')
            .select('amount, finance_entry_id')
            .inFilter('charge_id', chargeIds)
            .eq('payment_status', 'verified'));
    final expenses = groupIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : rowsOf(await db.from('expenses').select('total_amount').inFilter('group_id', groupIds).eq('record_status', 'active'));

    var collected = 0.0;
    final linked = <String>{};
    for (final p in pays) {
      collected += asDouble(p['amount']);
      final fid = p['finance_entry_id'];
      if (fid is String && fid.isNotEmpty) linked.add(fid);
    }
    for (final le in ledger) {
      if (!linked.contains(le['id'])) collected += asDouble(le['total_amount']);
    }
    var expenseTotal = 0.0;
    for (final e in expenses) {
      expenseTotal += asDouble(e['total_amount']);
    }

    return AdminOverviewStats(
      visitors: counts[0],
      visitorsGuest: counts[1],
      visitorsService: counts[2],
      guards: counts[3],
      flats: counts[4],
      members: members,
      vehicles: counts[5],
      vehiclesCars: counts[6],
      vehiclesTwoWheelers: counts[7],
      blacklist: counts[8],
      meetingsHeld: counts[9],
      maintenanceCollected: collected,
      expenseTotal: expenseTotal,
    );
  }

  /// Guards whose police verification is still pending past `kyc_alert_days` (default 7).
  Future<List<KycPendingGuard>> loadKycPending(String sid) async {
    if (!dbReady) return const [];
    final rows = rowsOf(await db
        .from('guards')
        .select('id, name, guard_id, kyc_alert_days, created_at')
        .eq('police_verification', 'pending')
        .eq('society_id', sid));
    final now = DateTime.now();
    return [
      for (final g in rows)
        if (() {
          final created = DateTime.tryParse('${g['created_at']}');
          if (created == null) return false;
          final days = now.difference(created).inMilliseconds / (1000 * 60 * 60 * 24);
          final alertDays = asInt(g['kyc_alert_days']);
          return days >= (alertDays == 0 ? 7 : alertDays);
        }())
          KycPendingGuard(id: '${g['id']}', name: '${g['name']}', guardId: '${g['guard_id']}'),
    ];
  }

  /// Verified collection grouped by month (web "Total Collection — Monthly" modal).
  Future<List<MonthTotal>> loadCollectionByMonth(String sid) async {
    if (!dbReady) return const [];
    final monthMap = <String, (double, int)>{};
    void add(String month, double amount) {
      final cur = monthMap[month] ?? (0.0, 0);
      monthMap[month] = (cur.$1 + amount, cur.$2 + 1);
    }

    final charges = rowsOf(await db.from('maintenance_charges').select('id, title').eq('society_id', sid));
    final titleById = {for (final c in charges) c['id'] as String: '${c['title'] ?? ''}'};
    final linked = <String>{};
    if (charges.isNotEmpty) {
      final pays = rowsOf(await db
          .from('maintenance_payments')
          .select('amount, due_date, finance_entry_id, charge_id')
          .inFilter('charge_id', titleById.keys.toList())
          .eq('payment_status', 'verified'));
      for (final p in pays) {
        final titleMonth = extractMonthFromTitle(titleById[p['charge_id']] ?? '');
        final dateStr = '${p['due_date'] ?? ''}';
        final month = titleMonth ?? (dateStr.length >= 7 ? dateStr.substring(0, 7) : 'Unknown');
        add(month, asDouble(p['amount']));
        final fid = p['finance_entry_id'];
        if (fid is String && fid.isNotEmpty) linked.add(fid);
      }
    }
    final ledger = rowsOf(await db
        .from('finance_entries')
        .select('id, total_amount, entry_month, created_at')
        .eq('society_id', sid)
        .eq('payment_status', 'verified')
        .inFilter('destination', ['current_month_maintenance', 'corpus']));
    for (final le in ledger) {
      if (linked.contains(le['id'])) continue;
      final created = '${le['created_at'] ?? ''}';
      final month = (le['entry_month'] as String?)?.isNotEmpty == true
          ? le['entry_month'] as String
          : (created.length >= 7 ? created.substring(0, 7) : 'Unknown');
      add(month, asDouble(le['total_amount']));
    }
    final keys = monthMap.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) MonthTotal(k, monthMap[k]!.$1, monthMap[k]!.$2)];
  }

  /// Active expenses by category, each with a monthly breakdown (web "Total expenses" modal).
  Future<List<ExpenseBucket>> loadExpenseBuckets(String sid) async {
    if (!dbReady) return const [];
    final groups = rowsOf(await db.from('expense_groups').select('id, name, major_head, group_kind').eq('society_id', sid));
    if (groups.isEmpty) return const [];
    final byId = {for (final g in groups) g['id'] as String: g};
    final expenses = rowsOf(await db
        .from('expenses')
        .select('total_amount, expense_date, expense_category, group_id')
        .inFilter('group_id', byId.keys.toList())
        .eq('record_status', 'active'));

    final acc = <String, ({String label, bool food, double total, int count, Map<String, (double, int)> months})>{};
    for (final e in expenses) {
      final amount = asDouble(e['total_amount']);
      final dateStr = '${e['expense_date'] ?? ''}';
      final month = dateStr.length >= 7 ? dateStr.substring(0, 7) : 'Unknown';
      final isFood = '${e['expense_category'] ?? ''}' == 'food';
      final String key;
      final String label;
      if (isFood) {
        key = 'event_food';
        label = 'Event food expenses';
      } else {
        final g = byId[e['group_id']];
        final major = resolveGroupMajorHead('${g?['name'] ?? 'MISCELLANEOUS'}', g?['major_head'] as String?);
        key = 'payment:$major';
        label = major;
      }
      final cur = acc[key] ?? (label: label, food: isFood, total: 0.0, count: 0, months: <String, (double, int)>{});
      final m = cur.months[month] ?? (0.0, 0);
      cur.months[month] = (m.$1 + amount, m.$2 + 1);
      acc[key] = (label: cur.label, food: cur.food, total: cur.total + amount, count: cur.count + 1, months: cur.months);
    }
    final buckets = [
      for (final e in acc.entries)
        ExpenseBucket(
          key: e.key,
          label: e.value.label,
          isEventFood: e.value.food,
          total: e.value.total,
          count: e.value.count,
          months: (e.value.months.keys.toList()..sort((a, b) => b.compareTo(a)))
              .map((k) => MonthTotal(k, e.value.months[k]!.$1, e.value.months[k]!.$2))
              .toList(),
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return buckets;
  }
}
