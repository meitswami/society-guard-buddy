import '../../../../core/supabase/db.dart';
import '../logic/expense_heads.dart';
import '../logic/finance_dates.dart';
import '../logic/js_compat.dart';
import 'events_models.dart';
import 'events_repository.dart';
import 'query_helpers.dart';

/// Which slice of `ExpenseSplitter` is shown (web props `foodOnly` / `paymentOnly`).
enum SplitterMode {
  /// Neither flag: "Event & function expenses".
  general,

  /// `foodOnly` — Events & food → Food expenses.
  food,

  /// `paymentOnly` — Finance → Record payment.
  payment,
}

class SplitterData {
  const SplitterData({
    required this.flats,
    required this.events,
    required this.groups,
    required this.expenses,
    required this.splits,
  });

  final SocietyFlatsData flats;
  final List<EventRow> events;
  final List<ExpenseGroup> groups;
  final List<ExpenseRow> expenses;
  final List<ExpenseSplit> splits;

  static const empty = SplitterData(flats: SocietyFlatsData.empty, events: [], groups: [], expenses: [], splits: []);
}

/// One allocation line for the finance ledger (`finance_entry_allocations`).
class LedgerAllocation {
  const LedgerAllocation(this.flatNumber, this.amount);

  final String flatNumber;
  final double amount;
}

/// Queries of `ExpenseSplitter`, `FoodExpenseEditModal` and `groupExpenseFinanceLedger.ts`.
class ExpenseRepository {
  const ExpenseRepository();

  static const _events = EventsRepository();

  Future<SplitterData> loadSplitter(String societyId, SplitterMode mode) async {
    if (!dbReady || societyId.isEmpty) return SplitterData.empty;
    final flats = await _events.loadFlats(societyId, withMembers: true);

    var events = const <EventRow>[];
    if (mode == SplitterMode.food) {
      final ev = rowsOf(
        await db
            .from('events')
            .select('id, title, event_date')
            .eq('society_id', societyId)
            .orderDesc('event_date')
            .limit(80),
      );
      events = ev.map(EventRow.fromJson).toList();
    }

    var groupQuery = db.from('expense_groups').select().eq('society_id', societyId);
    if (mode == SplitterMode.food) {
      groupQuery = groupQuery.eq('group_kind', 'event');
    } else if (mode == SplitterMode.payment) {
      groupQuery = groupQuery.eq('group_kind', 'general');
    }
    var groups = rowsOf(await groupQuery.orderDesc('created_at')).map(ExpenseGroup.fromJson).toList();

    if (mode == SplitterMode.food) {
      final foodGroupIds = rowsOf(
        await db.from('expenses').select('group_id').eq('expense_category', 'food').eq('record_status', 'active'),
      );
      final extraIds = <String>[];
      for (final r in foodGroupIds) {
        final id = r['group_id']?.toString();
        if (id != null && id.isNotEmpty && !extraIds.contains(id)) extraIds.add(id);
      }
      final known = {for (final g in groups) g.id};
      final missing = [for (final id in extraIds) if (!known.contains(id)) id];
      if (missing.isNotEmpty) {
        final extra = rowsOf(await db.from('expense_groups').select().inFilter('id', missing).eq('society_id', societyId));
        if (extra.isNotEmpty) groups = [...groups, ...extra.map(ExpenseGroup.fromJson)];
      }
    }

    final groupIds = [for (final g in groups) g.id];
    if (groupIds.isEmpty) {
      return SplitterData(flats: flats, events: events, groups: groups, expenses: const [], splits: const []);
    }
    var expQuery = db.from('expenses').select().inFilter('group_id', groupIds);
    if (mode == SplitterMode.food) {
      expQuery = expQuery.eq('expense_category', 'food');
    } else if (mode == SplitterMode.payment) {
      expQuery = expQuery.eq('expense_category', 'payment');
    }
    final expenses = rowsOf(await expQuery.orderDesc('created_at')).map(ExpenseRow.fromJson).toList();
    final expIds = [for (final e in expenses) e.id];
    if (expIds.isEmpty) {
      return SplitterData(flats: flats, events: events, groups: groups, expenses: expenses, splits: const []);
    }
    final splits = rowsOf(await db.from('expense_splits').select().inFilter('expense_id', expIds))
        .map(ExpenseSplit.fromJson)
        .toList();
    return SplitterData(flats: flats, events: events, groups: groups, expenses: expenses, splits: splits);
  }

  // ------------------------------------------------------------------ groups

  Future<void> insertGroup(Map<String, dynamic> row) async {
    await db.from('expense_groups').insert([row]);
  }

  Future<void> updateGroup(String id, String societyId, Map<String, dynamic> payload) async {
    await db.from('expense_groups').update(payload).eq('id', id).eq('society_id', societyId);
  }

  Future<void> deleteGroup(String id, String societyId) async {
    await db.from('expense_groups').delete().eq('id', id).eq('society_id', societyId);
  }

  // ---------------------------------------------------------------- expenses

  /// Duplicate detection: same title + amount + expense_date in the group.
  Future<bool> duplicateExists({
    required String groupId,
    required String title,
    required double total,
    required String expenseDate,
  }) async {
    final rows = rowsOf(
      await db
          .from('expenses')
          .select('id')
          .eq('group_id', groupId)
          .eq('title', title)
          .eq('total_amount', total)
          .eq('expense_date', expenseDate)
          .limit(1),
    );
    return rows.isNotEmpty;
  }

  /// Inserts one expense and returns its id.
  Future<String> insertExpense(Map<String, dynamic> row) async {
    final data = await db.from('expenses').insert([row]).select('id').single();
    return '${data['id']}';
  }

  Future<void> insertSplits(List<Map<String, dynamic>> rows) async {
    await db.from('expense_splits').insert(rows);
  }

  Future<void> deleteExpense(String id) async {
    await db.from('expenses').delete().eq('id', id);
  }

  Future<void> deleteSplitsOf(String expenseId) async {
    await db.from('expense_splits').delete().eq('expense_id', expenseId);
  }

  Future<void> settleSplit(String splitId) async {
    await db
        .from('expense_splits')
        .update({'is_settled': true, 'settled_at': DateTime.now().toUtc().toIso8601String()}).eq('id', splitId);
  }

  Future<void> updateSplitAmount(String splitId, double amount) async {
    await db.from('expense_splits').update({'amount': amount}).eq('id', splitId);
  }

  Future<void> updateExpense(String id, Map<String, dynamic> payload) async {
    await db.from('expenses').update(payload).eq('id', id);
  }

  Future<List<LedgerAllocation>> splitAllocationsOf(String expenseId) async {
    final rows = rowsOf(await db.from('expense_splits').select('flat_number, amount').eq('expense_id', expenseId));
    return [for (final s in rows) LedgerAllocation('${s['flat_number']}', jsNumber(s['amount']))];
  }

  Future<ExpenseRow?> getExpense(String id) async {
    final data = await db.from('expenses').select().eq('id', id).maybeSingle();
    return data == null ? null : ExpenseRow.fromJson(data);
  }

  Future<List<ExpenseSplit>> splitsOf(String expenseId) async {
    final rows = rowsOf(await db.from('expense_splits').select('id, amount').eq('expense_id', expenseId));
    return [for (final r in rows) ExpenseSplit(id: '${r['id']}', expenseId: expenseId, flatNumber: '', amount: jsNumber(r['amount']))];
  }

  // ------------------------------------------------------------------ ledger

  static String _allocationStyleForAmounts(List<double> amounts) {
    if (amounts.isEmpty) return 'none';
    final first = amounts.first;
    final allEq = amounts.every((a) => (a - first).abs() < 0.005);
    return allEq ? 'split_total_equally' : 'none';
  }

  /// `insertFinanceLedgerForGroupExpense` — mirrors Finance "outsider only" + `separate_entry`.
  /// Returns an error message or null.
  Future<String?> insertFinanceLedgerForGroupExpense({
    required String societyId,
    required String adminName,
    required String groupName,
    required String expenseId,
    required String title,
    required double total,
    required String expenseDate,
    required String paymentMethod,
    required String? screenshotUrl,
    required String? notes,
    required String? vendorOrService,
    required List<LedgerAllocation> allocationSplits,
    required List<({String id, String flatNumber})> flats,
    required String counterpartyName,
    required String? counterpartyRelation,
    required String expenseCategory,
    String? eventTitle,
  }) async {
    final transactionDate = expenseDate.length > 10 ? expenseDate.substring(0, 10) : expenseDate;
    final entryMonth = entryMonthFromExpenseDate(transactionDate);
    final amounts = [for (final s in allocationSplits) s.amount];
    final sum = round2(amounts.fold<double>(0, (a, b) => a + b));
    if ((sum - total).abs() > 0.02) return 'Split amounts do not match expense total for ledger';
    final allocationStyle = _allocationStyleForAmounts(amounts);
    final t = buildGroupExpenseLedgerTitle(
      expenseCategory: expenseCategory,
      groupName: groupName,
      expenseTitle: title,
      eventTitle: eventTitle,
    );
    final ledgerNotes = joinNoteLines([
      t.detailNote,
      (notes?.trim().isNotEmpty ?? false) ? notes!.trim() : null,
      (vendorOrService?.trim().isNotEmpty ?? false) ? 'Vendor: ${vendorOrService!.trim()}' : null,
    ]);

    String entryId;
    try {
      final fe = await db
          .from('finance_entries')
          .insert({
            'society_id': societyId,
            'record_mode': 'outsider_only',
            'destination': 'separate_entry',
            'allocation_style': allocationStyle,
            'include_vacant': false,
            'entry_month': entryMonth,
            'transaction_date': transactionDate,
            'total_amount': total,
            'aggregate_flat_count': allocationSplits.length,
            'charge_id': null,
            'title': t.ledgerTitle,
            'notes': ledgerNotes,
            'screenshot_url': screenshotUrl,
            'transaction_id': null,
            'payment_method': paymentMethod,
            'payment_status': 'verified',
            'created_by': adminName,
            'expense_id': expenseId,
          })
          .select('id')
          .single();
      entryId = '${fe['id']}';
    } catch (e) {
      final msg = supabaseErrorMessage(e);
      return msg.isEmpty ? 'Could not create finance ledger entry' : msg;
    }

    try {
      await db.from('finance_entry_counterparties').insert({
        'finance_entry_id': entryId,
        'name': _cap500(counterpartyName),
        'relation_to_society': counterpartyRelation == null ? null : _cap500(counterpartyRelation),
      });
    } catch (e) {
      await _quietDeleteEntry(entryId);
      return supabaseErrorMessage(e);
    }

    final flatIdByNumber = {for (final f in flats) f.flatNumber: f.id};
    try {
      await db.from('finance_entry_allocations').insert([
        for (final s in allocationSplits)
          {
            'finance_entry_id': entryId,
            'flat_id': flatIdByNumber[s.flatNumber],
            'flat_number': s.flatNumber,
            'amount': s.amount,
          },
      ]);
    } catch (e) {
      await _quietDeleteEntry(entryId);
      return supabaseErrorMessage(e);
    }
    return null;
  }

  /// `syncFinanceLedgerFromGroupExpenseEdit` — update (or create) the ledger row of an edited expense.
  Future<String?> syncFinanceLedgerFromGroupExpenseEdit({
    required String societyId,
    required String adminName,
    required String groupName,
    required String expenseId,
    required String title,
    required double total,
    required String expenseDate,
    required String paymentMethod,
    String? screenshotUrl,
    required String? notes,
    required String? vendorOrService,
    required List<({String id, String flatNumber})> flats,
    required List<LedgerAllocation> allocationSplits,
    required String counterpartyName,
    required String? counterpartyRelation,
    required String expenseCategory,
    String? eventTitle,
  }) async {
    Map<String, dynamic>? fe;
    try {
      fe = await db.from('finance_entries').select('id').eq('expense_id', expenseId).maybeSingle();
    } catch (e) {
      return supabaseErrorMessage(e);
    }
    if (fe == null || fe['id'] == null) {
      return insertFinanceLedgerForGroupExpense(
        societyId: societyId,
        adminName: adminName,
        groupName: groupName,
        expenseId: expenseId,
        title: title,
        total: total,
        expenseDate: expenseDate,
        paymentMethod: paymentMethod,
        screenshotUrl: screenshotUrl,
        notes: notes,
        vendorOrService: vendorOrService,
        allocationSplits: allocationSplits,
        flats: flats,
        counterpartyName: counterpartyName,
        counterpartyRelation: counterpartyRelation,
        expenseCategory: expenseCategory,
        eventTitle: eventTitle,
      );
    }
    final entryId = '${fe['id']}';
    final transactionDate = expenseDate.length > 10 ? expenseDate.substring(0, 10) : expenseDate;
    final entryMonth = entryMonthFromExpenseDate(transactionDate);
    final amounts = [for (final s in allocationSplits) s.amount];
    final sum = round2(amounts.fold<double>(0, (a, b) => a + b));
    if ((sum - total).abs() > 0.02) return 'Split amounts do not match expense total for ledger sync';
    final allocationStyle = _allocationStyleForAmounts(amounts);
    final t = buildGroupExpenseLedgerTitle(
      expenseCategory: expenseCategory,
      groupName: groupName,
      expenseTitle: title,
      eventTitle: eventTitle,
    );
    final ledgerNotes = joinNoteLines([
      t.detailNote,
      (notes?.trim().isNotEmpty ?? false) ? notes!.trim() : null,
      (vendorOrService?.trim().isNotEmpty ?? false) ? 'Vendor: ${vendorOrService!.trim()}' : null,
    ]);

    try {
      await db.from('finance_entries').update({
        'entry_month': entryMonth,
        'transaction_date': transactionDate,
        'total_amount': total,
        'aggregate_flat_count': allocationSplits.length,
        'allocation_style': allocationStyle,
        'title': t.ledgerTitle,
        'notes': ledgerNotes,
        'payment_method': paymentMethod,
        'created_by': adminName,
      }).eq('id', entryId);
    } catch (e) {
      return supabaseErrorMessage(e);
    }

    try {
      await db.from('finance_entry_allocations').delete().eq('finance_entry_id', entryId);
    } catch (_) {
      // Web ignores this result as well.
    }

    final flatIdByNumber = {for (final f in flats) f.flatNumber: f.id};
    try {
      await db.from('finance_entry_allocations').insert([
        for (final s in allocationSplits)
          {
            'finance_entry_id': entryId,
            'flat_id': flatIdByNumber[s.flatNumber],
            'flat_number': s.flatNumber,
            'amount': s.amount,
          },
      ]);
    } catch (e) {
      return supabaseErrorMessage(e);
    }

    try {
      await db.from('finance_entry_counterparties').update({
        'name': _cap500(counterpartyName),
        'relation_to_society': counterpartyRelation == null ? null : _cap500(counterpartyRelation),
      }).eq('finance_entry_id', entryId);
    } catch (e) {
      return supabaseErrorMessage(e);
    }
    return null;
  }

  static String _cap500(String s) => s.length > 500 ? s.substring(0, 500) : s;

  static Future<void> _quietDeleteEntry(String entryId) async {
    try {
      await db.from('finance_entries').delete().eq('id', entryId);
    } catch (_) {}
  }
}
