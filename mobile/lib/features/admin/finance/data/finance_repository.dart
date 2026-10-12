// Finance data access — port of `src/services/finance/financeService.ts`,
// `src/services/finance/financeMutations.ts` and the queries made directly by
// MonthlyOperatingFundPanel / HeadFundReconciliation / useSocietyOpeningBalanceAnchors.
// Same tables, columns, filters, ordering, inserts, notification rows and edge functions as web.

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/db.dart';
import '../logic/finance_charge_helpers.dart';
import '../logic/finance_models.dart';
import '../logic/finance_receipt_conflicts.dart';
import '../logic/flat_sort.dart';
import '../logic/record_receipt_plan.dart';

/// Error with the message the web shows in its toast.
class FinanceException implements Exception {
  const FinanceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Best-effort readable message from Supabase / function errors.
String financeErrorMessage(Object e, [String fallback = 'Unknown error']) {
  if (e is FinanceException) return e.message;
  if (e is PostgrestException) return e.message;
  if (e is StorageException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    if (d is String && d.trim().isNotEmpty) return d.trim();
    return e.reasonPhrase ?? 'Edge function returned ${e.status}';
  }
  final s = e.toString();
  return s.isEmpty ? fallback : s;
}

class ChargeInput {
  const ChargeInput({
    required this.title,
    required this.amount,
    required this.frequency,
    required this.dueDay,
    required this.expenseGroupId,
  });

  final String title;
  final double amount;
  final String frequency;
  final int dueDay;
  final String? expenseGroupId;
}

class MonthlyBillIssueResult {
  const MonthlyBillIssueResult({
    required this.issued,
    this.flats,
    this.whatsappSent,
    this.whatsappFailed,
    this.whatsappConfigured,
    this.chargeTitle,
    this.amount,
    this.note,
  });

  final int issued;
  final int? flats;
  final int? whatsappSent;
  final int? whatsappFailed;
  final bool? whatsappConfigured;
  final String? chargeTitle;
  final double? amount;
  final String? note;
}

/// Society notification tune (web `fetchSocietyNotificationSound`).
class SocietySound {
  const SocietySound(this.soundKey, this.soundCustomUrl);

  final String soundKey;
  final String? soundCustomUrl;
}

/// Head fund reconciliation source rows.
class HeadFundGroup {
  const HeadFundGroup(
      {required this.id, required this.name, this.majorHead, this.description});

  final String id;
  final String name;
  final String? majorHead;
  final String? description;
}

class HeadFundCharge {
  const HeadFundCharge(
      {required this.id, required this.title, this.expenseGroupId});

  final String id;
  final String title;
  final String? expenseGroupId;
}

class HeadFundContribution {
  const HeadFundContribution({
    required this.id,
    required this.groupId,
    required this.flatNumber,
    this.residentName,
    required this.amount,
    required this.paymentMethod,
    this.screenshotUrl,
    required this.dueDate,
    required this.chargeTitle,
  });

  final String id;
  final String groupId;
  final String flatNumber;
  final String? residentName;
  final double amount;
  final String paymentMethod;
  final String? screenshotUrl;
  final String dueDate;
  final String chargeTitle;
}

class HeadFundExpense {
  const HeadFundExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    required this.expenseDate,
    required this.paymentMethod,
    this.billScreenshotUrl,
    this.vendorOrService,
    required this.groupName,
    this.correlated = false,
  });

  final String id;
  final String groupId;
  final String title;
  final double totalAmount;
  final String expenseDate;
  final String paymentMethod;
  final String? billScreenshotUrl;
  final String? vendorOrService;
  final String groupName;
  final bool correlated;

  HeadFundExpense asCorrelated(bool value) => HeadFundExpense(
        id: id,
        groupId: groupId,
        title: title,
        totalAmount: totalAmount,
        expenseDate: expenseDate,
        paymentMethod: paymentMethod,
        billScreenshotUrl: billScreenshotUrl,
        vendorOrService: vendorOrService,
        groupName: groupName,
        correlated: value,
      );
}

class HeadFundAdjustment {
  const HeadFundAdjustment({
    required this.id,
    required this.expenseGroupId,
    required this.amount,
    required this.sourceType,
    this.flatNumber,
    this.notes,
    this.createdAt = '',
  });

  final String id;
  final String expenseGroupId;
  final double amount;
  final String sourceType;
  final String? flatNumber;
  final String? notes;
  final String createdAt;
}

class HeadFundData {
  const HeadFundData({
    this.groups = const [],
    this.charges = const [],
    this.contributions = const [],
    this.expenses = const [],
    this.adjustments = const [],
  });

  final List<HeadFundGroup> groups;
  final List<HeadFundCharge> charges;
  final List<HeadFundContribution> contributions;
  final List<HeadFundExpense> expenses;
  final List<HeadFundAdjustment> adjustments;
}

double _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Interface so the module can be widget-tested with a fake.
abstract class FinanceRepository {
  Future<FinanceCoreData> fetchCore(String societyId, String adminName);
  Future<FinanceEventReference> fetchEventReference(String societyId);
  Future<FinanceFlatReportData> fetchFlatReport(String societyId);
  Future<List<OpeningBalanceAnchor>> fetchOpeningAnchors(String societyId);
  Future<void> saveOpeningAnchor(String societyId, OpeningBalanceAnchor anchor);
  Future<void> deleteOpeningAnchor(String id);
  Future<List<ReserveTransfer>> fetchReserveTransfers(String societyId);
  Future<void> insertReserveTransfer({
    required String societyId,
    required String entryMonth,
    required double amount,
    required String direction,
    required String? notes,
    required String adminName,
  });
  Future<HeadFundData> fetchHeadFundData(String societyId);
  Future<void> insertHeadAdjustment({
    required String societyId,
    required String groupId,
    required double amount,
    required String sourceType,
    required String flatNumber,
    required String notes,
    required String adminName,
  });

  Future<String> createExpenseGroup({
    required String societyId,
    required String name,
    required String majorHead,
    String? description,
    required String createdBy,
  });
  Future<void> updateExpenseGroup({
    required String societyId,
    required String groupId,
    required String name,
    required String? description,
    required String majorHead,
  });
  Future<void> deleteExpenseGroup(String societyId, String groupId);
  Future<void> insertCharge(
      String societyId, String adminName, ChargeInput input);
  Future<void> updateCharge(
      String societyId, String chargeId, ChargeInput input);
  Future<void> deleteCharge(String societyId, String chargeId);
  Future<void> distributePool({
    required String entryId,
    required List<AllocationInsert> allocationRows,
    required List<Map<String, dynamic>> maintenancePaymentRows,
    required int aggregateFlatCount,
    required String title,
  });
  Future<String> persistFinanceRecord(RecordReceiptPlan plan);
  Future<void> updatePaymentStatus(
      String paymentId, String status, String adminName,
      [String? reason]);
  Future<void> updatePayment(String paymentId, Map<String, dynamic> payload);
  Future<void> deletePaymentRow(
      {required String id, required String flatNumber, String? financeEntryId});
  Future<void> updateLedgerStatus(String entryId, String status);
  Future<void> updateLedger(String entryId, Map<String, dynamic> payload);
  Future<void> deleteLedger(String entryId);
  Future<void> sendMaintenanceReminders(
      String societyId, String adminName, List<String> flatNumbers);
  Future<void> upsertReminderSettings(
      String societyId, FinanceReminderSettings s);
  Future<int> invokeReminderTest(String societyId);
  Future<MonthlyBillIssueResult> invokeIssueMonthlyBill(String societyId);
  Future<void> notifyPaymentDecision({
    required String societyId,
    required String adminName,
    required String flatNumber,
    required String title,
    required String message,
  });
  Future<bool> notifyResidentsOfRecord({
    required String societyId,
    required String adminName,
    required String audience,
    required List<String> selectedFlatNumbers,
    required String title,
    required String message,
    required String notificationType,
    required String? billUrl,
  });
  Future<List<FinancePayment>> queryReceiptHeadConflicts({
    required String chargeId,
    String? paymentMethod,
    required List<({String flatNumber, String dueDate})> targets,
    List<String> monthlyMaintenanceChargeIds,
  });
  Future<String?> uploadMaintenanceReceipt(Uint8List bytes, String fileName,
      {String? contentType});
}

/// Supabase implementation (same project / RLS as the web app).
class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _c => _client ?? db;

  Future<T> _soft<T>(Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } catch (_) {
      return fallback;
    }
  }

  // ───────────────────────── reads ─────────────────────────

  @override
  Future<FinanceCoreData> fetchCore(String societyId, String adminName) async {
    if (!dbReady) return const FinanceCoreData();
    final c = _c;
    // Wave 1: independent society-scoped reads in parallel.
    final flatsF = _soft(
      () async => rowsOf(await c
          .from('flats')
          .select('flat_number, id, owner_name, is_occupied')
          .eq('society_id', societyId)
          .order('flat_number')),
      const <Map<String, dynamic>>[],
    );
    final societyF = _soft<Map<String, dynamic>?>(
      () =>
          c.from('societies').select('name').eq('id', societyId).maybeSingle(),
      null,
    );
    final reminderF = _soft<Map<String, dynamic>?>(
      () => c
          .from('finance_reminder_settings')
          .select(
              'enabled, schedule, due_day, auto_issue_enabled, auto_issue_whatsapp, auto_issue_email, reminder_whatsapp, reminder_email, bill_sound_key')
          .eq('society_id', societyId)
          .maybeSingle(),
      null,
    );
    final chargesF = _soft(
      () async => rowsOf(await c
          .from('maintenance_charges')
          .select('*')
          .eq('society_id', societyId)
          .order('created_at', ascending: false)),
      const <Map<String, dynamic>>[],
    );
    final groupsF = _soft(
      () async => rowsOf(await c
          .from('expense_groups')
          .select('id, name, major_head, description')
          .eq('society_id', societyId)
          .eq('group_kind', 'general')
          .order('name')),
      const <Map<String, dynamic>>[],
    );
    final ledgerF = c
        .from('finance_entries')
        .select(
            '*, finance_entry_counterparties(*), finance_entry_allocations(*)')
        .eq('society_id', societyId)
        .order('created_at', ascending: false)
        .limit(2500);
    final reserveF = c
        .from('reserve_fund_transfers')
        .select(
            'id, entry_month, amount, direction, payment_method, notes, created_at')
        .eq('society_id', societyId)
        .order('entry_month', ascending: false)
        .limit(500);

    final flatRows = await flatsF;
    final society = await societyF;
    final reminder = await reminderF;
    final chargeRows = await chargesF;
    final groupRows = await groupsF;
    final ledgerRows = rowsOf(await _rethrow(ledgerF));
    final reserveRows = rowsOf(await _rethrow(reserveF));

    final flats = sortFlatsByNumber<SocietyFlatRow>(
        flatRows.map(SocietyFlatRow.fromJson), (f) => f.flatNumber);
    final flatIds = flats.map((f) => f.id).toList();
    final settings = FinanceReminderSettings.fromRow(reminder);
    final ledgerEntries = ledgerRows.map(FinanceLedgerRow.fromJson).toList();
    final linkedExpenseIds = [
      for (final e in ledgerEntries)
        if (e.expenseId != null && e.expenseId!.isNotEmpty) e.expenseId!,
    ];

    // Wave 2.
    final membersF = flatIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _soft(
            () async => rowsOf(await c
                .from('members')
                .select('flat_id, name')
                .eq('is_primary', true)
                .inFilter('flat_id', flatIds)),
            const <Map<String, dynamic>>[],
          );
    final residentsF = flatIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _soft(
            () async => rowsOf(await c
                .from('resident_users')
                .select('id, name, flat_number, flat_id')
                .inFilter('flat_id', flatIds)
                .order('flat_number')),
            const <Map<String, dynamic>>[],
          );
    final categoriesF = linkedExpenseIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : c
            .from('expenses')
            .select('id, expense_category')
            .inFilter('id', linkedExpenseIds)
            .then(rowsOf);

    final charges = await _ensureCurrentMonthMaintenanceCharge(
      societyId,
      adminName,
      chargeRows.map(FinanceCharge.fromJson).toList(),
      settings.dueDay,
    );
    final chargeIds = charges.map((ch) => ch.id).toList();
    final paymentsF = chargeIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : c
            .from('maintenance_payments')
            .select('*')
            .inFilter('charge_id', chargeIds)
            .order('created_at', ascending: false)
            .limit(2500)
            .then(rowsOf);

    final members = await membersF;
    final residents = await residentsF;
    final payments = await _rethrow(paymentsF);
    final categories = await _rethrow(categoriesF);

    final primaryByFlatId = <String, String>{};
    for (final r in members) {
      final fid = r['flat_id']?.toString();
      final name = r['name']?.toString().trim() ?? '';
      if (fid != null && name.isNotEmpty) primaryByFlatId[fid] = name;
    }
    final expenseCategoryById = <String, String>{
      for (final r in categories)
        '${r['id']}': (r['expense_category'] ?? '').toString(),
    };

    return FinanceCoreData(
      flats: flats,
      primaryByFlatId: primaryByFlatId,
      societyName: society?['name']?.toString() ?? '',
      residentUsers: residents.map(FinanceResidentUser.fromJson).toList(),
      settings: settings,
      charges: charges,
      paymentExpenseGroups:
          groupRows.map(PaymentExpenseGroup.fromJson).toList(),
      payments: payments.map(FinancePayment.fromJson).toList(),
      ledgerEntries: ledgerEntries,
      expenseCategoryById: expenseCategoryById,
      reserveTransfers: reserveRows.map(ReserveTransfer.fromJson).toList(),
    );
  }

  Future<T> _rethrow<T>(Future<T> f) async {
    try {
      return await f;
    } on PostgrestException catch (e) {
      throw FinanceException(e.message);
    }
  }

  /// Web `ensureCurrentMonthMaintenanceCharge`: clone the monthly maintenance template for this month.
  Future<List<FinanceCharge>> _ensureCurrentMonthMaintenanceCharge(
    String societyId,
    String adminName,
    List<FinanceCharge> charges,
    int dueDay,
  ) async {
    final monthly = charges.where(isMonthlyMaintenanceCharge).toList();
    final hasCurrent = monthly.any((c) => isCurrentMonthChargeTitle(c.title));
    if (hasCurrent || monthly.isEmpty) return charges;
    final template = monthly.first;
    final currentTitle = buildCurrentMonthChargeTitle();
    if (charges
        .any((c) => normalizeTitle(c.title) == normalizeTitle(currentTitle))) {
      return charges;
    }
    try {
      final inserted = await _c
          .from('maintenance_charges')
          .insert([
            {
              'title': currentTitle,
              'amount': template.amount,
              'frequency': 'monthly',
              'due_day': dueDay,
              'created_by': adminName,
              'society_id': societyId,
            },
          ])
          .select('*')
          .maybeSingle();
      if (inserted == null) return charges;
      return [FinanceCharge.fromJson(inserted), ...charges];
    } catch (_) {
      return charges;
    }
  }

  @override
  Future<FinanceEventReference> fetchEventReference(String societyId) async {
    if (!dbReady) return const FinanceEventReference();
    final c = _c;
    final eventsF = c
        .from('events')
        .select('id, title')
        .eq('society_id', societyId)
        .order('event_date', ascending: false)
        .limit(100)
        .then(rowsOf);
    final groupsF = c
        .from('expense_groups')
        .select('id, name, event_id')
        .eq('society_id', societyId)
        .eq('group_kind', 'event')
        .then(rowsOf);
    final events = await _rethrow(eventsF);
    final groups = await _rethrow(groupsF);
    final eventIds = events.map((e) => e['id'].toString()).toList();
    final eventTitleById = {
      for (final e in events) e['id'].toString(): (e['title'] ?? '').toString()
    };
    final groupIds = groups.map((g) => g['id'].toString()).toList();
    final groupById = {for (final g in groups) g['id'].toString(): g};

    final contribF = eventIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : c
            .from('event_contributions')
            .select('*')
            .inFilter('event_id', eventIds)
            .order('verified_at', ascending: false)
            .limit(150)
            .then(rowsOf);
    final expF = groupIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : c
            .from('expenses')
            .select(
                'id, title, total_amount, expense_date, payment_method, bill_screenshot_url, group_id')
            .inFilter('group_id', groupIds)
            .eq('expense_category', 'food')
            .eq('record_status', 'active')
            .order('expense_date', ascending: false)
            .limit(150)
            .then(rowsOf);
    final contribs = await _rethrow(contribF);
    final exps = await _rethrow(expF);

    return FinanceEventReference(
      contributions: [
        for (final r in contribs)
          EventContribRefRow.fromJson(r,
              eventTitle: eventTitleById[r['event_id']?.toString()] ?? 'Event'),
      ],
      foodExpenses: [
        for (final r in exps)
          () {
            final g = groupById[r['group_id']?.toString()];
            final eventId = g?['event_id']?.toString();
            return EventFoodRefRow(
              id: r['id'].toString(),
              title: (r['title'] ?? '').toString(),
              totalAmount: _d(r['total_amount']),
              expenseDate: (r['expense_date'] ?? '').toString(),
              paymentMethod: (r['payment_method'] ?? '').toString(),
              billScreenshotUrl: r['bill_screenshot_url']?.toString(),
              groupName: (g?['name'] ?? 'Food group').toString(),
              eventTitle: eventId != null ? eventTitleById[eventId] : null,
            );
          }(),
      ],
    );
  }

  @override
  Future<FinanceFlatReportData> fetchFlatReport(String societyId) async {
    if (!dbReady) return const FinanceFlatReportData();
    final c = _c;
    final groups = await _rethrow(
      c
          .from('expense_groups')
          .select('id, name')
          .eq('society_id', societyId)
          .eq('group_kind', 'general')
          .then(rowsOf),
    );
    final groupIds = groups.map((g) => g['id'].toString()).toList();
    if (groupIds.isEmpty) return const FinanceFlatReportData();
    final groupNameById = {
      for (final g in groups) g['id'].toString(): (g['name'] ?? '').toString()
    };
    final expRows = await _rethrow(
      c
          .from('expenses')
          .select(
              'id, title, total_amount, expense_date, payment_method, vendor_or_service, service_kind, group_id, split_type, paid_by_flat, paid_by_flats, record_status')
          .inFilter('group_id', groupIds)
          .eq('record_status', 'active')
          .eq('expense_category', 'payment')
          .then(rowsOf),
    );
    final expIds = expRows.map((e) => e['id'].toString()).toList();
    var splits = const <Map<String, dynamic>>[];
    if (expIds.isNotEmpty) {
      splits = await _rethrow(
        c
            .from('expense_splits')
            .select(
                'id, expense_id, flat_number, amount, is_settled, settled_at')
            .inFilter('expense_id', expIds)
            .then(rowsOf),
      );
    }
    return FinanceFlatReportData(
      expenses: [
        for (final e in expRows)
          FlatReportExpense(
            id: e['id'].toString(),
            title: (e['title'] ?? '').toString(),
            totalAmount: _d(e['total_amount']),
            expenseDate: (e['expense_date'] ?? '').toString(),
            paymentMethod: (e['payment_method'] ?? '').toString(),
            groupName:
                groupNameById[e['group_id']?.toString()] ?? 'Unknown group',
          ),
      ],
      splits: [
        for (final s in splits)
          FlatReportSplit(
            id: (s['id'] ?? '').toString(),
            expenseId: (s['expense_id'] ?? '').toString(),
            flatNumber: (s['flat_number'] ?? '').toString(),
            amount: _d(s['amount']),
            isSettled: s['is_settled'] == true,
          ),
      ],
    );
  }

  @override
  Future<List<OpeningBalanceAnchor>> fetchOpeningAnchors(
      String societyId) async {
    if (!dbReady) return const [];
    return _soft(
      () async => rowsOf(await _c
              .from('finance_opening_balance_anchors')
              .select(
                  'id, as_on_date, cash_amount, bank_amount, other_amount, notes')
              .eq('society_id', societyId)
              .order('as_on_date', ascending: false))
          .map(OpeningBalanceAnchor.fromJson)
          .toList(),
      const <OpeningBalanceAnchor>[],
    );
  }

  @override
  Future<void> saveOpeningAnchor(
      String societyId, OpeningBalanceAnchor anchor) async {
    if (anchor.cashAmount == null &&
        anchor.bankAmount == null &&
        anchor.otherAmount == null) {
      throw const FinanceException(
          'Enter at least one channel amount (cash, bank, or other)');
    }
    final notes = anchor.notes?.trim() ?? '';
    await _wrap(() => _c.from('finance_opening_balance_anchors').upsert({
          'society_id': societyId,
          'as_on_date': anchor.asOnDate.length > 10
              ? anchor.asOnDate.substring(0, 10)
              : anchor.asOnDate,
          'cash_amount': anchor.cashAmount,
          'bank_amount': anchor.bankAmount,
          'other_amount': anchor.otherAmount,
          'notes': notes.isEmpty ? null : notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'society_id,as_on_date'));
  }

  @override
  Future<void> deleteOpeningAnchor(String id) => _wrap(
      () => _c.from('finance_opening_balance_anchors').delete().eq('id', id));

  @override
  Future<List<ReserveTransfer>> fetchReserveTransfers(String societyId) async {
    if (!dbReady) return const [];
    return _soft(
      () async => rowsOf(await _c
              .from('reserve_fund_transfers')
              .select('id, entry_month, amount, direction, notes, created_at')
              .eq('society_id', societyId)
              .order('created_at', ascending: false)
              .limit(200))
          .map(ReserveTransfer.fromJson)
          .toList(),
      const <ReserveTransfer>[],
    );
  }

  @override
  Future<void> insertReserveTransfer({
    required String societyId,
    required String entryMonth,
    required double amount,
    required String direction,
    required String? notes,
    required String adminName,
  }) =>
      _wrap(() => _c.from('reserve_fund_transfers').insert({
            'society_id': societyId,
            'entry_month': entryMonth,
            'amount': amount,
            'direction': direction,
            'payment_method': 'bank_transfer',
            'notes': notes,
            'created_by': adminName,
          }));

  @override
  Future<HeadFundData> fetchHeadFundData(String societyId) async {
    if (!dbReady) return const HeadFundData();
    final c = _c;
    final gRows = await _soft(
      () async => rowsOf(await c
          .from('expense_groups')
          .select('id, name, major_head, description')
          .eq('society_id', societyId)
          .eq('group_kind', 'general')
          .order('name')),
      const <Map<String, dynamic>>[],
    );
    final chRows = await _soft(
      () async => rowsOf(await c
          .from('maintenance_charges')
          .select('id, title, expense_group_id')
          .eq('society_id', societyId)),
      const <Map<String, dynamic>>[],
    );
    final groups = [
      for (final g in gRows)
        HeadFundGroup(
          id: g['id'].toString(),
          name: (g['name'] ?? '').toString(),
          majorHead: g['major_head']?.toString(),
          description: g['description']?.toString(),
        ),
    ];
    final charges = [
      for (final ch in chRows)
        HeadFundCharge(
          id: ch['id'].toString(),
          title: (ch['title'] ?? '').toString(),
          expenseGroupId: ch['expense_group_id']?.toString(),
        ),
    ];
    final linked = charges
        .where(
            (ch) => ch.expenseGroupId != null && ch.expenseGroupId!.isNotEmpty)
        .toList();
    final chargeIdToGroup = {
      for (final ch in linked) ch.id: ch.expenseGroupId!
    };
    final chargeTitleById = {for (final ch in charges) ch.id: ch.title};
    final activeGroupIds = groups.map((g) => g.id).toList();

    final mpRows = linked.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _soft(
            () async => rowsOf(await c
                .from('maintenance_payments')
                .select(
                    'id, flat_number, resident_name, amount, payment_method, screenshot_url, due_date, charge_id')
                .inFilter('charge_id', linked.map((ch) => ch.id).toList())
                .inFilter('payment_status', ['verified', 'pending'])),
            const <Map<String, dynamic>>[],
          );
    final contributions = <HeadFundContribution>[];
    for (final row in mpRows) {
      final groupId = chargeIdToGroup[row['charge_id']?.toString()];
      if (groupId == null) continue;
      contributions.add(HeadFundContribution(
        id: row['id'].toString(),
        groupId: groupId,
        flatNumber: (row['flat_number'] ?? '').toString(),
        residentName: row['resident_name']?.toString(),
        amount: _d(row['amount']),
        paymentMethod: (row['payment_method'] ?? '').toString(),
        screenshotUrl: row['screenshot_url']?.toString(),
        dueDate: (row['due_date'] ?? '').toString(),
        chargeTitle: chargeTitleById[row['charge_id']?.toString()] ?? '',
      ));
    }

    final exRows = activeGroupIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _soft(
            () async => rowsOf(await c
                .from('expenses')
                .select(
                    'id, title, total_amount, expense_date, payment_method, bill_screenshot_url, vendor_or_service, group_id, expense_groups!inner(name, society_id)')
                .eq('expense_groups.society_id', societyId)
                .eq('expense_category', 'payment')
                .eq('record_status', 'active')),
            const <Map<String, dynamic>>[],
          );
    final expenses = [
      for (final row in exRows)
        HeadFundExpense(
          id: row['id'].toString(),
          groupId: (row['group_id'] ?? '').toString(),
          title: (row['title'] ?? '').toString(),
          totalAmount: _d(row['total_amount']),
          expenseDate: (row['expense_date'] ?? '').toString(),
          paymentMethod: (row['payment_method'] ?? '').toString(),
          billScreenshotUrl: row['bill_screenshot_url']?.toString(),
          vendorOrService: row['vendor_or_service']?.toString(),
          groupName: ((row['expense_groups'] is Map
                      ? (row['expense_groups'] as Map)['name']
                      : null) ??
                  '')
              .toString(),
        ),
    ];

    final adjRows = activeGroupIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _soft(
            () async => rowsOf(await c
                .from('head_fund_adjustments')
                .select(
                    'id, expense_group_id, amount, source_type, flat_number, notes, created_at')
                .eq('society_id', societyId)
                .order('created_at', ascending: false)),
            const <Map<String, dynamic>>[],
          );
    final adjustments = [
      for (final a in adjRows)
        HeadFundAdjustment(
          id: a['id'].toString(),
          expenseGroupId: (a['expense_group_id'] ?? '').toString(),
          amount: _d(a['amount']),
          sourceType: (a['source_type'] ?? '').toString(),
          flatNumber: a['flat_number']?.toString(),
          notes: a['notes']?.toString(),
          createdAt: (a['created_at'] ?? '').toString(),
        ),
    ];
    return HeadFundData(
      groups: groups,
      charges: charges,
      contributions: contributions,
      expenses: expenses,
      adjustments: adjustments,
    );
  }

  @override
  Future<void> insertHeadAdjustment({
    required String societyId,
    required String groupId,
    required double amount,
    required String sourceType,
    required String flatNumber,
    required String notes,
    required String adminName,
  }) async {
    final flat = flatNumber.trim();
    String? flatId;
    if (flat.isNotEmpty) {
      final row = await _soft<Map<String, dynamic>?>(
        () => _c
            .from('flats')
            .select('id')
            .eq('society_id', societyId)
            .eq('flat_number', flat)
            .maybeSingle(),
        null,
      );
      flatId = row?['id']?.toString();
    }
    final n = notes.trim();
    await _wrap(() => _c.from('head_fund_adjustments').insert({
          'society_id': societyId,
          'expense_group_id': groupId,
          'amount': amount,
          'source_type': sourceType,
          'flat_number': flat.isEmpty ? null : flat,
          'flat_id': flatId,
          'notes': n.isEmpty ? null : n,
          'created_by': adminName,
        }));
  }

  // ───────────────────────── mutations ─────────────────────────

  Future<void> _wrap(Future<Object?> Function() run) async {
    try {
      await run();
    } on PostgrestException catch (e) {
      throw FinanceException(e.message);
    }
  }

  @override
  Future<String> createExpenseGroup({
    required String societyId,
    required String name,
    required String majorHead,
    String? description,
    required String createdBy,
  }) async {
    final desc = description?.trim() ?? '';
    try {
      final row = await _c
          .from('expense_groups')
          .insert({
            'society_id': societyId,
            'name': name,
            'major_head': majorHead,
            'description': desc.isEmpty ? null : desc,
            'group_kind': 'general',
            'created_by': createdBy,
          })
          .select('id')
          .single();
      return row['id'].toString();
    } on PostgrestException catch (e) {
      throw FinanceException(
          e.message.isEmpty ? 'Could not create payment sub-head' : e.message);
    }
  }

  @override
  Future<void> updateExpenseGroup({
    required String societyId,
    required String groupId,
    required String name,
    required String? description,
    required String majorHead,
  }) =>
      _wrap(() => _c
          .from('expense_groups')
          .update({
            'name': name,
            'description': description,
            'major_head': majorHead,
            'event_id': null
          })
          .eq('id', groupId)
          .eq('society_id', societyId));

  @override
  Future<void> deleteExpenseGroup(String societyId, String groupId) async {
    try {
      final expenseCount =
          await _c.from('expenses').count().eq('group_id', groupId);
      if (expenseCount > 0) {
        throw const FinanceException(
            'Remove all recorded payments in this head before deleting it.');
      }
      final chargeCount = await _c
          .from('maintenance_charges')
          .count()
          .eq('expense_group_id', groupId)
          .eq('society_id', societyId);
      if (chargeCount > 0) {
        throw const FinanceException(
            'Unlink or delete receipt types using this payment head first.');
      }
      await _c
          .from('expense_groups')
          .delete()
          .eq('id', groupId)
          .eq('society_id', societyId);
    } on PostgrestException catch (e) {
      throw FinanceException(e.message);
    }
  }

  @override
  Future<void> insertCharge(
          String societyId, String adminName, ChargeInput input) =>
      _wrap(() => _c.from('maintenance_charges').insert([
            {
              'title': input.title,
              'amount': input.amount,
              'frequency': input.frequency,
              'due_day': input.dueDay,
              'created_by': adminName,
              'society_id': societyId,
              'expense_group_id': input.expenseGroupId,
            },
          ]));

  @override
  Future<void> updateCharge(
          String societyId, String chargeId, ChargeInput input) =>
      _wrap(() => _c
          .from('maintenance_charges')
          .update({
            'title': input.title,
            'amount': input.amount,
            'frequency': input.frequency,
            'due_day': input.dueDay,
            'expense_group_id': input.expenseGroupId,
          })
          .eq('id', chargeId)
          .eq('society_id', societyId));

  @override
  Future<void> deleteCharge(String societyId, String chargeId) => _wrap(() => _c
      .from('maintenance_charges')
      .delete()
      .eq('id', chargeId)
      .eq('society_id', societyId));

  @override
  Future<void> distributePool({
    required String entryId,
    required List<AllocationInsert> allocationRows,
    required List<Map<String, dynamic>> maintenancePaymentRows,
    required int aggregateFlatCount,
    required String title,
  }) async {
    await _wrap(() => _c
        .from('finance_entry_allocations')
        .insert([for (final a in allocationRows) a.toRow(entryId)]));
    if (maintenancePaymentRows.isNotEmpty) {
      try {
        await _c.from('maintenance_payments').insert(maintenancePaymentRows);
      } on PostgrestException catch (e) {
        await _soft(
            () => _c
                .from('finance_entry_allocations')
                .delete()
                .eq('finance_entry_id', entryId),
            null);
        throw FinanceException(e.message);
      }
    }
    await _wrap(() => _c.from('finance_entries').update({
          'allocation_style': 'split_total_equally',
          'aggregate_flat_count': aggregateFlatCount,
          'distributed_at': DateTime.now().toUtc().toIso8601String(),
          'title': title,
        }).eq('id', entryId));
  }

  @override
  Future<String> persistFinanceRecord(RecordReceiptPlan plan) async {
    String entryId;
    try {
      final row = await _c
          .from('finance_entries')
          .insert(plan.entry)
          .select('id')
          .single();
      entryId = row['id'].toString();
    } on PostgrestException catch (e) {
      throw FinanceException(
          e.message.isEmpty ? 'Could not save finance entry' : e.message);
    }
    final cp = plan.counterparty;
    if (cp != null) {
      await _wrap(() => _c.from('finance_entry_counterparties').insert({
            'finance_entry_id': entryId,
            'name': cp.name,
            'relation_to_society': cp.relation,
          }));
    }
    if (plan.allocations.isNotEmpty) {
      await _wrap(() => _c
          .from('finance_entry_allocations')
          .insert([for (final a in plan.allocations) a.toRow(entryId)]));
    }
    if (plan.maintenancePayments.isNotEmpty) {
      await _wrap(() => _c.from('maintenance_payments').insert([
            for (final r in plan.maintenancePayments)
              {...r, 'finance_entry_id': entryId}
          ]));
    }
    return entryId;
  }

  @override
  Future<void> updatePaymentStatus(
      String paymentId, String status, String adminName,
      [String? reason]) {
    final reviewedAt = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> payload;
    if (status == 'verified') {
      payload = {
        'payment_status': 'verified',
        'verified_by': adminName,
        'verified_at': reviewedAt,
        'reviewed_at': reviewedAt,
        'rejection_reason': null,
      };
    } else if (status == 'rejected') {
      final r = reason?.trim() ?? '';
      payload = {
        'payment_status': 'rejected',
        'verified_by': adminName,
        'verified_at': reviewedAt,
        'reviewed_at': reviewedAt,
        'rejection_reason': r.isEmpty ? 'Rejected by admin' : r,
      };
    } else {
      payload = {
        'payment_status': 'pending',
        'verified_by': null,
        'verified_at': null,
        'reviewed_at': null,
        'rejection_reason': null,
      };
    }
    return _wrap(() =>
        _c.from('maintenance_payments').update(payload).eq('id', paymentId));
  }

  @override
  Future<void> updatePayment(String paymentId, Map<String, dynamic> payload) =>
      _wrap(() =>
          _c.from('maintenance_payments').update(payload).eq('id', paymentId));

  @override
  Future<void> deletePaymentRow(
      {required String id,
      required String flatNumber,
      String? financeEntryId}) async {
    // Web ignores errors on these steps (best-effort cleanup of the linked ledger entry).
    final c = _c;
    final feId = (financeEntryId == null || financeEntryId.isEmpty)
        ? null
        : financeEntryId;
    if (feId != null) {
      await _soft(
          () => c
              .from('finance_entry_allocations')
              .delete()
              .eq('finance_entry_id', feId)
              .eq('flat_number', flatNumber),
          null);
    }
    await _soft(
        () => c.from('maintenance_payments').delete().eq('id', id), null);
    if (feId == null) return;
    final restAllocs = await _soft(
      () async => rowsOf(await c
          .from('finance_entry_allocations')
          .select('amount')
          .eq('finance_entry_id', feId)),
      const <Map<String, dynamic>>[],
    );
    final restMps = await _soft(
      () async => rowsOf(await c
          .from('maintenance_payments')
          .select('id')
          .eq('finance_entry_id', feId)),
      const <Map<String, dynamic>>[],
    );
    final total = restAllocs.fold<double>(0, (s, a) => s + _d(a['amount']));
    final acount = restAllocs.length;
    final mpLeft = restMps.length;
    if (acount == 0 && mpLeft == 0) {
      await _soft(
          () => c.from('finance_entries').delete().eq('id', feId), null);
    } else if (acount > 0) {
      await _soft(
        () => c
            .from('finance_entries')
            .update({'total_amount': total, 'aggregate_flat_count': acount}).eq(
                'id', feId),
        null,
      );
    } else if (mpLeft > 0) {
      await _soft(
          () => c
              .from('maintenance_payments')
              .update({'finance_entry_id': null}).eq('finance_entry_id', feId),
          null);
      await _soft(
          () => c.from('finance_entries').delete().eq('id', feId), null);
    }
  }

  @override
  Future<void> updateLedgerStatus(String entryId, String status) =>
      _wrap(() => _c
          .from('finance_entries')
          .update({'payment_status': status}).eq('id', entryId));

  @override
  Future<void> updateLedger(String entryId, Map<String, dynamic> payload) =>
      _wrap(() => _c.from('finance_entries').update(payload).eq('id', entryId));

  @override
  Future<void> deleteLedger(String entryId) =>
      _wrap(() => _c.from('finance_entries').delete().eq('id', entryId));

  Future<SocietySound> fetchSocietySound(String societyId) async {
    final row = await _soft<Map<String, dynamic>?>(
      () => _c
          .from('societies')
          .select('admin_push_sound_url')
          .eq('id', societyId)
          .maybeSingle(),
      null,
    );
    final url = row?['admin_push_sound_url']?.toString().trim() ?? '';
    return url.isNotEmpty
        ? SocietySound('custom', url)
        : const SocietySound('digital', null);
  }

  Future<void> _push(Map<String, dynamic> body) async {
    try {
      await _c.functions.invoke('send-push-notification', body: body);
    } catch (_) {
      // Web: `supabase.functions.invoke` never throws — push is best-effort.
    }
  }

  /// Web `dispatchDirectoryChannels` (WhatsApp + email via directory contacts, best-effort).
  Future<void> dispatchDirectoryChannels({
    required String societyId,
    required String title,
    required String message,
    required bool whatsapp,
    required bool email,
    required String targetType,
    List<String> flatNumbers = const [],
    String? imageUrl,
  }) async {
    if (!whatsapp && !email) return;
    try {
      await _c.functions.invoke('dispatch-directory-message', body: {
        'society_id': societyId,
        'title': title,
        'message': message,
        'channels': {'whatsapp': whatsapp, 'email': email},
        'target_type': targetType,
        'target_flat_numbers': targetType == 'flat' ? flatNumbers : <String>[],
        'target_ids': <String>[],
        'image_url': imageUrl,
      });
    } catch (_) {
      // best-effort
    }
  }

  @override
  Future<void> sendMaintenanceReminders(
      String societyId, String adminName, List<String> flatNumbers) async {
    final flats = {...flatNumbers.where((f) => f.isNotEmpty)}.toList();
    if (flats.isEmpty) return;
    const title = 'Maintenance Due Reminder';
    final sound = await fetchSocietySound(societyId);
    for (final flatNumber in flats) {
      await _wrap(() => _c.from('notifications').insert([
            {
              'society_id': societyId,
              'title': title,
              'message':
                  'Dear resident of Flat $flatNumber, your maintenance payment is due. Please pay at the earliest.',
              'type': 'payment_reminder',
              'target_type': 'flat',
              'target_id': flatNumber,
              'created_by': adminName,
              'sound_key': sound.soundKey,
              'sound_custom_url': sound.soundCustomUrl,
            },
          ]));
    }
    await _push({
      'title': title,
      'message': 'Your maintenance payment is due. Please pay at the earliest.',
      'target_type': 'flat',
      'target_flat_numbers': flats,
      'target_ids': <String>[],
      'media_items': <Object>[],
      'society_id': societyId,
      'sound_key': sound.soundKey,
      'sound_custom_url': sound.soundCustomUrl ?? '',
    });
    try {
      final settings = await _c
          .from('finance_reminder_settings')
          .select('reminder_whatsapp, reminder_email')
          .eq('society_id', societyId)
          .maybeSingle();
      final wantWa = settings?['reminder_whatsapp'] == true;
      final wantEmail = settings?['reminder_email'] == true;
      if (wantWa || wantEmail) {
        await dispatchDirectoryChannels(
          societyId: societyId,
          title: title,
          message:
              'Your maintenance payment is due. Please pay at the earliest.',
          whatsapp: wantWa,
          email: wantEmail,
          targetType: 'flat',
          flatNumbers: flats,
        );
      }
    } catch (_) {
      // Directory channel reminder failed — non-fatal (web logs a warning).
    }
  }

  @override
  Future<void> upsertReminderSettings(
          String societyId, FinanceReminderSettings s) =>
      _wrap(() => _c.from('finance_reminder_settings').upsert({
            'society_id': societyId,
            'enabled': s.enabled,
            'schedule': s.schedule,
            'due_day': s.dueDay.clamp(1, 28),
            'timezone': 'Asia/Kolkata',
            'auto_issue_enabled': s.autoIssueEnabled,
            'auto_issue_whatsapp': s.autoIssueWhatsapp,
            'auto_issue_email': s.autoIssueEmail,
            'reminder_whatsapp': s.reminderWhatsapp,
            'reminder_email': s.reminderEmail,
            'bill_sound_key':
                s.billSoundKey.isEmpty ? 'melody' : s.billSoundKey,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'society_id'));

  @override
  Future<int> invokeReminderTest(String societyId) async {
    try {
      final res = await _c.functions.invoke('maintenance-reminder',
          body: {'society_id': societyId, 'force_slot': '12pm'});
      final data = res.data;
      return data is Map
          ? (num.tryParse('${data['sent'] ?? 0}') ?? 0).toInt()
          : 0;
    } on FunctionException catch (e) {
      throw FinanceException(financeErrorMessage(e, 'Unknown function error'));
    }
  }

  @override
  Future<MonthlyBillIssueResult> invokeIssueMonthlyBill(
      String societyId) async {
    try {
      final res = await _c.functions.invoke('issue-monthly-maintenance', body: {
        'society_id': societyId,
        'force': true,
        'amount': 2500,
      });
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      final results = data['results'];
      final first =
          results is List && results.isNotEmpty && results.first is Map
              ? Map<String, dynamic>.from(results.first as Map)
              : const <String, dynamic>{};
      int? i(Object? v) => v == null ? null : (num.tryParse('$v'))?.toInt();
      return MonthlyBillIssueResult(
        issued: i(data['issued']) ?? 0,
        flats: i(first['flats']),
        whatsappSent: i(first['whatsapp_sent']),
        whatsappFailed: i(first['whatsapp_failed']),
        whatsappConfigured: first['whatsapp_configured'] is bool
            ? first['whatsapp_configured'] as bool
            : null,
        chargeTitle: first['charge_title']?.toString(),
        amount: first['amount'] == null ? null : _d(first['amount']),
        note: first['skipped']?.toString(),
      );
    } on FunctionException catch (e) {
      throw FinanceException(financeErrorMessage(e, 'Unknown function error'));
    }
  }

  @override
  Future<void> notifyPaymentDecision({
    required String societyId,
    required String adminName,
    required String flatNumber,
    required String title,
    required String message,
  }) async {
    final sound = await fetchSocietySound(societyId);
    await _soft(
      () => _c.from('notifications').insert([
        {
          'society_id': societyId,
          'title': title,
          'message': message,
          'type': 'maintenance_payment_decision',
          'target_type': 'flat',
          'target_id': flatNumber,
          'created_by': adminName,
          'sound_key': sound.soundKey,
          'sound_custom_url': sound.soundCustomUrl,
        },
      ]),
      null,
    );
    await _push({
      'title': title,
      'message': message,
      'target_type': 'flat',
      'target_flat_numbers': [flatNumber],
      'target_ids': <String>[],
      'media_items': <Object>[],
      'society_id': societyId,
      'sound_key': sound.soundKey,
      'sound_custom_url': sound.soundCustomUrl ?? '',
    });
    await dispatchDirectoryChannels(
      societyId: societyId,
      title: title,
      message: message,
      whatsapp: true,
      email: true,
      targetType: 'flat',
      flatNumbers: [flatNumber],
    );
  }

  /// Web `mediaItemsFromReceiptUrl`.
  static List<Map<String, String>>? mediaItemsFromReceiptUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final u = url.split('?').first.toLowerCase();
    if (u.endsWith('.pdf')) return null;
    return [
      {'url': url, 'kind': 'image'},
    ];
  }

  @override
  Future<bool> notifyResidentsOfRecord({
    required String societyId,
    required String adminName,
    required String audience,
    required List<String> selectedFlatNumbers,
    required String title,
    required String message,
    required String notificationType,
    required String? billUrl,
  }) async {
    final media = mediaItemsFromReceiptUrl(billUrl);
    final sound = await fetchSocietySound(societyId);
    final rowBase = {
      'title': title,
      'message': message,
      'type': notificationType,
      'created_by': adminName,
      'society_id': societyId,
      'sound_key': sound.soundKey,
      'sound_custom_url': sound.soundCustomUrl,
      'media_items': media ?? const <Object>[],
    };
    try {
      if (audience == 'all') {
        await _c.from('notifications').insert([
          {...rowBase, 'target_type': 'all', 'target_id': null},
        ]);
        await _push({
          'title': title,
          'message': message,
          'target_type': 'all',
          'target_flat_numbers': <String>[],
          'target_ids': <String>[],
          'media_items': media ?? const <Object>[],
          'society_id': societyId,
          'sound_key': sound.soundKey,
          'sound_custom_url': sound.soundCustomUrl ?? '',
        });
      } else {
        final flats =
            {...selectedFlatNumbers.where((f) => f.isNotEmpty)}.toList();
        if (flats.isEmpty) return true;
        for (final flat in flats) {
          await _c.from('notifications').insert([
            {...rowBase, 'target_type': 'flat', 'target_id': flat},
          ]);
        }
        await _push({
          'title': title,
          'message': message,
          'target_type': 'flat',
          'target_flat_numbers': flats,
          'target_ids': <String>[],
          'media_items': media ?? const <Object>[],
          'society_id': societyId,
          'sound_key': sound.soundKey,
          'sound_custom_url': sound.soundCustomUrl ?? '',
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<FinancePayment>> queryReceiptHeadConflicts({
    required String chargeId,
    String? paymentMethod,
    required List<({String flatNumber, String dueDate})> targets,
    List<String> monthlyMaintenanceChargeIds = const [],
  }) async {
    final flatNumbers = {for (final t in targets) t.flatNumber}.toList();
    if (flatNumbers.isEmpty || chargeId.isEmpty || !dbReady) return const [];
    final isMonthly = monthlyMaintenanceChargeIds.contains(chargeId);
    final chargeIds =
        isMonthly ? {...monthlyMaintenanceChargeIds}.toList() : [chargeId];
    List<Map<String, dynamic>> rows;
    try {
      rows = rowsOf(await _c
          .from('maintenance_payments')
          .select(
              'id, charge_id, flat_number, amount, payment_method, due_date, payment_date, created_at, payment_status, transaction_id, notes, finance_entry_id')
          .inFilter('charge_id', chargeIds)
          .inFilter('flat_number', flatNumbers)
          .inFilter('payment_status', ['verified', 'pending']));
    } catch (_) {
      return const [];
    }
    final existing = rows.map(FinancePayment.fromJson).toList();
    if (isMonthly) {
      return findMonthlyMaintenanceMonthConflicts(existing, chargeIds, targets);
    }
    return findReceiptHeadConflicts(existing, [
      for (final t in targets)
        ReceiptHeadRecordingTarget(
            flatNumber: t.flatNumber,
            dueDate: t.dueDate,
            chargeId: chargeId,
            paymentMethod: paymentMethod),
    ]);
  }

  @override
  Future<String?> uploadMaintenanceReceipt(Uint8List bytes, String fileName,
      {String? contentType}) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.-]'), '_');
    final path = 'maintenance-receipts/${const Uuid().v4()}_$safe';
    try {
      final bucket = _c.storage.from('notification-media');
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
            cacheControl: '3600', upsert: false, contentType: contentType),
      );
      return bucket.getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}
