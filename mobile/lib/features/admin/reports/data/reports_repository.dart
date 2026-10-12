import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/db.dart';
import '../logic/finance_period_report.dart';
import '../logic/flat_report.dart';
import '../logic/flat_sort.dart';
import '../logic/js_compat.dart';
import '../logic/report_aggregations.dart';
import 'report_models.dart';

/// Finance data the Reports page needs — same queries as the web
/// `fetchSocietyFinanceCore` (`services/finance/financeService.ts`).
class ReportFinanceData {
  const ReportFinanceData({
    this.societyName = '',
    this.flats = const [],
    this.primaryByFlatId = const {},
    this.charges = const [],
    this.payments = const [],
    this.ledgerEntries = const [],
    this.expenseCategoryById = const {},
    this.reserveTransfers = const [],
  });

  static const empty = ReportFinanceData();

  final String societyName;
  final List<ReportFlat> flats;
  final Map<String, String> primaryByFlatId;
  final List<ReportCharge> charges;
  final List<FinancePeriodPayment> payments;

  /// All ledger rows (incl. allocations) — use [societyLedgerEntries] for period maths.
  final List<FinancePeriodLedgerEntry> ledgerEntries;
  final Map<String, String> expenseCategoryById;
  final List<FinancePeriodReserveTransfer> reserveTransfers;

  /// Ledger without event food / contribution rows (web `useSocietyFinanceData`).
  List<FinancePeriodLedgerEntry> get societyLedgerEntries => filterSocietyLedgerEntries(ledgerEntries, expenseCategoryById);
}

/// `fetchFinanceFlatReport` result.
class FlatReportSource {
  const FlatReportSource({this.expenses = const [], this.splits = const []});

  final List<FlatReportExpense> expenses;
  final List<FlatReportSplit> splits;
}

/// Society notification tune (`fetchSocietyNotificationSound`).
class SocietyNotificationSound {
  const SocietyNotificationSound({required this.soundKey, this.soundCustomUrl});

  final String soundKey;
  final String? soundCustomUrl;
}

/// Data access for Reports + Logs (plain Dart, like the web services).
abstract final class ReportsRepository {
  static const _uuid = Uuid();

  // ─── Finance core ─────────────────────────────────────────────────────────

  static Future<ReportFinanceData> loadFinanceCore(String societyId) async {
    if (!dbReady || societyId.isEmpty) return ReportFinanceData.empty;
    final results = await Future.wait<Object?>([
      db.from('flats').select('flat_number, id, owner_name, is_occupied').eq('society_id', societyId).order('flat_number', ascending: true),
      db.from('societies').select('name').eq('id', societyId).maybeSingle(),
      db.from('maintenance_charges').select('*').eq('society_id', societyId).order('created_at', ascending: false),
      db
          .from('finance_entries')
          .select('*, finance_entry_counterparties(*), finance_entry_allocations(*)')
          .eq('society_id', societyId)
          .order('created_at', ascending: false)
          .limit(2500),
      db
          .from('reserve_fund_transfers')
          .select('id, entry_month, amount, direction, payment_method, notes, created_at')
          .eq('society_id', societyId)
          .order('entry_month', ascending: false)
          .limit(500),
    ]);

    final flats = sortFlatsByNumber(rowsOf(results[0]).map(ReportFlat.fromJson), (f) => f.flatNumber);
    final societyRow = results[1];
    final societyName = societyRow is Map ? (societyRow['name'] ?? '').toString() : '';
    final charges = rowsOf(results[2]).map(ReportCharge.fromJson).toList();
    final ledgerRaw = rowsOf(results[3]);
    final ledgerEntries = ledgerRaw.map(FinancePeriodLedgerEntry.fromJson).toList();
    final reserveTransfers = rowsOf(results[4]).map(FinancePeriodReserveTransfer.fromJson).toList();

    final flatIds = [for (final f in flats) f.id];
    final chargeIds = [for (final c in charges) c.id];
    final linkedExpenseIds = [
      for (final e in ledgerEntries)
        if (e.expenseId != null && e.expenseId!.isNotEmpty) e.expenseId!,
    ];

    final wave2 = await Future.wait<Object?>([
      flatIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : db.from('members').select('flat_id, name').eq('is_primary', true).inFilter('flat_id', flatIds),
      chargeIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : db
              .from('maintenance_payments')
              .select('*')
              .inFilter('charge_id', chargeIds)
              .order('created_at', ascending: false)
              .limit(2500),
      linkedExpenseIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : db.from('expenses').select('id, expense_category').inFilter('id', linkedExpenseIds.toSet().toList()),
    ]);

    final primaryByFlatId = <String, String>{};
    for (final row in rowsOf(wave2[0])) {
      final fid = row['flat_id']?.toString();
      final name = row['name']?.toString().trim() ?? '';
      if (fid != null && fid.isNotEmpty && name.isNotEmpty) primaryByFlatId[fid] = name;
    }
    final payments = rowsOf(wave2[1]).map(FinancePeriodPayment.fromJson).toList();
    final expenseCategoryById = <String, String>{
      for (final row in rowsOf(wave2[2])) row['id'].toString(): (row['expense_category'] ?? '').toString(),
    };

    return ReportFinanceData(
      societyName: societyName,
      flats: flats,
      primaryByFlatId: primaryByFlatId,
      charges: charges,
      payments: payments,
      ledgerEntries: ledgerEntries,
      expenseCategoryById: expenseCategoryById,
      reserveTransfers: reserveTransfers,
    );
  }

  /// `useSocietyOpeningBalanceAnchors` — errors resolve to an empty list like the web.
  static Future<List<FinanceOpeningBalanceAnchor>> loadOpeningAnchors(String societyId) async {
    if (!dbReady || societyId.isEmpty) return const [];
    try {
      final data = await db
          .from('finance_opening_balance_anchors')
          .select('id, as_on_date, cash_amount, bank_amount, other_amount, notes')
          .eq('society_id', societyId)
          .order('as_on_date', ascending: false);
      return rowsOf(data).map(FinanceOpeningBalanceAnchor.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── Module aggregations (`fetchReportModuleAggregations`) ───────────────

  static Future<ReportModuleAggregations> loadModuleAggregations(
    String societyId,
    String periodFrom,
    String periodTo,
  ) async {
    if (!dbReady || societyId.isEmpty || periodFrom.compareTo(periodTo) > 0) return ReportModuleAggregations.empty;
    final from = '${periodFrom}T00:00:00';
    final to = '${periodTo}T23:59:59';

    final ids = await Future.wait<Object?>([
      db.from('maintenance_charges').select('id').eq('society_id', societyId),
      db.from('donation_campaigns').select('id').eq('society_id', societyId),
      db.from('expense_groups').select('id').eq('society_id', societyId).eq('group_kind', 'general'),
    ]);
    List<String> idList(Object? d) => [for (final r in rowsOf(d)) r['id'].toString()];
    final chargeIds = idList(ids[0]);
    final campIds = idList(ids[1]);
    final groupIds = idList(ids[2]);

    final res = await Future.wait<Object?>([
      chargeIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : db
              .from('maintenance_payments')
              .select('payment_status, amount, finance_entry_id')
              .inFilter('charge_id', chargeIds)
              .gte('due_date', periodFrom)
              .lte('due_date', periodTo),
      campIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : db
              .from('donation_payments')
              .select('amount, verified_at')
              .inFilter('campaign_id', campIds)
              .gte('created_at', from)
              .lte('created_at', to),
      groupIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : db
              .from('expenses')
              .select('id')
              .inFilter('group_id', groupIds)
              .eq('record_status', 'active')
              .eq('expense_category', 'payment')
              .gte('expense_date', periodFrom)
              .lte('expense_date', periodTo),
    ]);

    final mp = rowsOf(res[0]);
    final maintenanceStatuses = bucketByKey<Map<String, dynamic>>(
      mp,
      (p) => (p['payment_status'] ?? 'pending').toString(),
      (p) => jsAmount(p['amount']),
    );
    var linkedCount = 0, unlinkedCount = 0;
    var linkedTotal = 0.0, unlinkedTotal = 0.0;
    for (final p in mp) {
      final amt = jsAmount(p['amount']);
      if (jsTruthy(p['finance_entry_id'])) {
        linkedCount++;
        linkedTotal += amt;
      } else {
        unlinkedCount++;
        unlinkedTotal += amt;
      }
    }

    final donationStatuses = bucketByKey<Map<String, dynamic>>(
      rowsOf(res[1]),
      (p) => jsTruthy(p['verified_at']) ? 'verified' : 'pending',
      (p) => jsAmount(p['amount']),
    );

    final expIds = idList(res[2]);
    var splitStatuses = const <StatusBucket>[];
    if (expIds.isNotEmpty) {
      final splits = await db.from('expense_splits').select('amount, is_settled').inFilter('expense_id', expIds);
      splitStatuses = bucketByKey<Map<String, dynamic>>(
        rowsOf(splits),
        (s) => s['is_settled'] == true ? 'settled' : 'pending',
        (s) => jsAmount(s['amount']),
      );
    }

    return ReportModuleAggregations(
      maintenanceStatuses: maintenanceStatuses,
      maintenanceLinkSummary: mp.isEmpty
          ? null
          : MaintenanceLinkSummary(
              linkedCount: linkedCount,
              linkedTotal: linkedTotal,
              unlinkedCount: unlinkedCount,
              unlinkedTotal: unlinkedTotal,
            ),
      donationStatuses: donationStatuses,
      splitStatuses: splitStatuses,
    );
  }

  // ─── Flat-wise report (`fetchFinanceFlatReport`) ──────────────────────────

  static Future<FlatReportSource> loadFlatReportSource(String societyId) async {
    if (!dbReady || societyId.isEmpty) return const FlatReportSource();
    final groupRows = rowsOf(
      await db.from('expense_groups').select('id, name').eq('society_id', societyId).eq('group_kind', 'general'),
    );
    if (groupRows.isEmpty) return const FlatReportSource();
    final groupNameById = {for (final g in groupRows) g['id'].toString(): (g['name'] ?? '').toString()};
    final expenseRows = rowsOf(
      await db
          .from('expenses')
          .select(
            'id, title, total_amount, expense_date, payment_method, vendor_or_service, service_kind, group_id, split_type, paid_by_flat, paid_by_flats, record_status',
          )
          .inFilter('group_id', groupNameById.keys.toList())
          .eq('record_status', 'active')
          .eq('expense_category', 'payment'),
    );
    final expIds = [for (final e in expenseRows) e['id'].toString()];
    var splits = const <FlatReportSplit>[];
    if (expIds.isNotEmpty) {
      final splitRows = await db
          .from('expense_splits')
          .select('id, expense_id, flat_number, amount, is_settled, settled_at')
          .inFilter('expense_id', expIds);
      splits = rowsOf(splitRows).map(FlatReportSplit.fromJson).toList();
    }
    final expenses = [
      for (final e in expenseRows)
        FlatReportExpense.fromJson(e, groupName: groupNameById[e['group_id']?.toString()] ?? 'Unknown group'),
    ];
    return FlatReportSource(expenses: expenses, splits: splits);
  }

  // ─── Gate data ────────────────────────────────────────────────────────────

  /// Guard shifts with `login_time` in the month (same bounds as the web).
  static Future<List<ReportShiftRow>> loadShifts(String societyId, String monthFrom, String monthTo) async {
    if (!dbReady || societyId.isEmpty) return const [];
    final data = await db
        .from('guard_shifts')
        .select('*')
        .eq('society_id', societyId)
        .gte('login_time', '${monthFrom}T00:00:00')
        .lte('login_time', '${monthTo}T23:59:59')
        .order('login_time', ascending: true);
    return rowsOf(data).map(ReportShiftRow.fromJson).toList();
  }

  /// Visitors whose `entry_time` ISO string starts with `yyyy-MM` — the web filters
  /// `entryTime.startsWith(reportMonth)` on the UTC timestamp, so the bounds are UTC.
  static Future<List<ReportVisitor>> loadVisitorsForMonth(String societyId, String ym) async {
    if (!dbReady || societyId.isEmpty) return const [];
    final parts = ym.split('-');
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    final start = DateTime.utc(y, m);
    final end = DateTime.utc(y, m + 1);
    return _loadVisitorsBetween(societyId, start, end);
  }

  /// Visitors whose `entry_time` starts with `yyyy-MM-dd` (UTC day, like the web Logs filter).
  static Future<List<ReportVisitor>> loadVisitorsForDay(String societyId, String ymd) async {
    if (!dbReady || societyId.isEmpty) return const [];
    final d = DateTime.tryParse(ymd);
    if (d == null) return const [];
    final start = DateTime.utc(d.year, d.month, d.day);
    final end = DateTime.utc(d.year, d.month, d.day + 1);
    return _loadVisitorsBetween(societyId, start, end);
  }

  static Future<List<ReportVisitor>> _loadVisitorsBetween(String societyId, DateTime start, DateTime end) async {
    final out = <ReportVisitor>[];
    const page = 1000;
    for (var offset = 0;; offset += page) {
      final data = await db
          .from('visitors')
          .select(ReportVisitor.selectColumns)
          .eq('society_id', societyId)
          .gte('entry_time', start.toIso8601String())
          .lt('entry_time', end.toIso8601String())
          .order('entry_time', ascending: false)
          .range(offset, offset + page - 1);
      final rows = rowsOf(data);
      out.addAll(rows.map(ReportVisitor.fromJson));
      if (rows.length < page) break;
    }
    return out;
  }

  /// Web store `markExit`: sets `exit_time` (and `vehicle_exit_time` for vehicles).
  static Future<String> markVisitorExit(String societyId, ReportVisitor visitor) async {
    final now = DateTime.now().toUtc().toIso8601String();
    var q = db.from('visitors').update({
      'exit_time': now,
      'vehicle_exit_time': visitor.hasVehicle ? now : null,
    }).eq('id', visitor.id);
    if (societyId.isNotEmpty) q = q.eq('society_id', societyId);
    await q;
    return now;
  }

  // ─── Period report → members (`financeMutations.ts`) ─────────────────────

  static Future<String?> latestPeriodReportBatch(String societyId) async {
    if (!dbReady || societyId.isEmpty) return null;
    final data = await db
        .from('notifications')
        .select('delivery_batch_id')
        .eq('society_id', societyId)
        .eq('type', 'finance_period_report')
        .not('delivery_batch_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(1);
    final rows = rowsOf(data);
    if (rows.isEmpty) return null;
    final id = rows.first['delivery_batch_id']?.toString();
    return (id == null || id.isEmpty) ? null : id;
  }

  static Future<SocietyNotificationSound> societyNotificationSound(String societyId) async {
    if (societyId.isEmpty) return const SocietyNotificationSound(soundKey: 'digital');
    try {
      final data = await db.from('societies').select('admin_push_sound_url').eq('id', societyId).maybeSingle();
      final url = data?['admin_push_sound_url']?.toString().trim() ?? '';
      if (url.isNotEmpty) return SocietyNotificationSound(soundKey: 'custom', soundCustomUrl: url);
    } catch (_) {}
    return const SocietyNotificationSound(soundKey: 'digital');
  }

  /// `uploadFinancePeriodReportPdf` → public URL (null on failure).
  static Future<String?> uploadFinancePeriodReportPdf(String societyId, String batchId, Uint8List pdf) async {
    final path = 'finance-reports/$societyId/$batchId.pdf';
    try {
      await db.storage.from('notification-media').uploadBinary(
            path,
            pdf,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true, contentType: 'application/pdf'),
          );
      return db.storage.from('notification-media').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// `sendFinancePeriodReportToMembers` — returns the delivery batch id.
  static Future<String> sendPeriodReportToMembers({
    required String societyId,
    required String adminName,
    required String periodLabel,
    required String summaryMessage,
    required Uint8List pdfBytes,
    required List<String> flatNumbers,
    required bool sendPush,
  }) async {
    final flats = <String>{for (final f in flatNumbers) if (f.isNotEmpty) f}.toList();
    if (flats.isEmpty) throw StateError('No flats to notify');

    final batchId = _uuid.v4();
    final pdfUrl = await uploadFinancePeriodReportPdf(societyId, batchId, pdfBytes);
    if (pdfUrl == null) throw StateError('Could not upload period report PDF');

    final title = 'Finance report · $periodLabel';
    final message = '$summaryMessage Open Alerts for details. PDF: $pdfUrl';
    final sound = await societyNotificationSound(societyId);

    final rows = [
      for (final flat in flats)
        {
          'title': title,
          'message': message,
          'type': 'finance_period_report',
          'target_type': 'flat',
          'target_id': flat,
          'society_id': societyId,
          'created_by': adminName,
          'sound_key': sound.soundKey,
          'sound_custom_url': sound.soundCustomUrl,
          'delivery_batch_id': batchId,
          'is_read': false,
        },
    ];
    await db.from('notifications').insert(rows);

    if (sendPush) {
      try {
        await invokeFunction('send-push-notification', {
          'title': title,
          'message': summaryMessage,
          'target_type': 'flat',
          'target_flat_numbers': flats,
          'target_ids': <String>[],
          'media_items': <Object>[],
          'society_id': societyId,
          'sound_key': sound.soundKey,
          'sound_custom_url': sound.soundCustomUrl ?? '',
        });
      } catch (_) {
        // Web logs and continues when push fails.
      }
    }
    return batchId;
  }

  /// `recallFinancePeriodReportNotifications` — removes the batch rows + stored PDF.
  static Future<List<String>> recallPeriodReport(String societyId, String batchId) async {
    final batchRows = rowsOf(await db
        .from('notifications')
        .select('target_id')
        .eq('delivery_batch_id', batchId)
        .eq('society_id', societyId)
        .eq('type', 'finance_period_report'));
    final targetIds = <String>{
      for (final r in batchRows)
        if ((r['target_id'] ?? '').toString().isNotEmpty) r['target_id'].toString(),
    }.toList();
    await db
        .from('notifications')
        .delete()
        .eq('delivery_batch_id', batchId)
        .eq('society_id', societyId)
        .eq('type', 'finance_period_report');
    try {
      await db.storage.from('notification-media').remove(['finance-reports/$societyId/$batchId.pdf']);
    } catch (_) {}
    return targetIds;
  }
}
