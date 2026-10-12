import '../../../../core/supabase/db.dart';
import '../logic/bank_reconciliation.dart';
import '../logic/js_compat.dart';

class BankImportRow {
  const BankImportRow({
    required this.id,
    this.bankName,
    this.accountLast4,
    required this.periodFrom,
    required this.periodTo,
    this.fileName,
    this.importedBy,
    required this.createdAt,
  });

  final String id;
  final String? bankName;
  final String? accountLast4;
  final String periodFrom;
  final String periodTo;
  final String? fileName;
  final String? importedBy;
  final String createdAt;

  factory BankImportRow.fromJson(Map<String, dynamic> j) => BankImportRow(
        id: (j['id'] ?? '').toString(),
        bankName: j['bank_name']?.toString(),
        accountLast4: j['account_last4']?.toString(),
        periodFrom: (j['period_from'] ?? '').toString(),
        periodTo: (j['period_to'] ?? '').toString(),
        fileName: j['file_name']?.toString(),
        importedBy: j['imported_by']?.toString(),
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

class BankLineRow {
  const BankLineRow({required this.id, required this.importId, required this.lineDate, required this.amount, this.description, this.reference});

  final String id;
  final String importId;
  final String lineDate;
  final double amount;
  final String? description;
  final String? reference;

  StatementLineForMatch get forMatch =>
      StatementLineForMatch(id: id, lineDate: lineDate, amount: amount, description: description, reference: reference);

  factory BankLineRow.fromJson(Map<String, dynamic> j) => BankLineRow(
        id: (j['id'] ?? '').toString(),
        importId: (j['import_id'] ?? '').toString(),
        lineDate: (j['line_date'] ?? '').toString(),
        amount: jsNumber(j['amount']),
        description: j['description']?.toString(),
        reference: j['reference']?.toString(),
      );
}

class BankMatchRow {
  const BankMatchRow({
    required this.id,
    required this.statementLineId,
    required this.matchType,
    this.maintenancePaymentId,
    this.financeEntryId,
    required this.matchConfidence,
    required this.status,
    this.matchedBy,
    this.notes,
  });

  final String id;
  final String statementLineId;
  final String matchType;
  final String? maintenancePaymentId;
  final String? financeEntryId;
  final double matchConfidence;
  final String status;
  final String? matchedBy;
  final String? notes;

  /// `maintenance_payment:<id>` or `finance_entry:<id>`.
  String get targetKey =>
      maintenancePaymentId != null ? 'maintenance_payment:$maintenancePaymentId' : 'finance_entry:$financeEntryId';

  factory BankMatchRow.fromJson(Map<String, dynamic> j) => BankMatchRow(
        id: (j['id'] ?? '').toString(),
        statementLineId: (j['statement_line_id'] ?? '').toString(),
        matchType: (j['match_type'] ?? '').toString(),
        maintenancePaymentId: j['maintenance_payment_id']?.toString(),
        financeEntryId: j['finance_entry_id']?.toString(),
        matchConfidence: jsNumber(j['match_confidence']),
        status: (j['status'] ?? '').toString(),
        matchedBy: j['matched_by']?.toString(),
        notes: j['notes']?.toString(),
      );
}

const _lineCols = 'id, import_id, line_date, amount, description, reference';

/// Supabase calls of `BankReconciliation.tsx`.
class BankReconService {
  const BankReconService();

  Future<List<BankImportRow>> loadImports(String societyId) async {
    if (!dbReady) return const [];
    final data =
        await db.from('bank_statement_imports').select('*').eq('society_id', societyId).order('created_at', ascending: false);
    return rowsOf(data).map(BankImportRow.fromJson).toList();
  }

  Future<({String from, String to})> importPeriod(String importId) async {
    final row = await db.from('bank_statement_imports').select('period_from, period_to').eq('id', importId).single();
    return (from: (row['period_from'] ?? '').toString(), to: (row['period_to'] ?? '').toString());
  }

  Future<List<BankLineRow>> loadLines(String importId) async {
    final data = await db.from('bank_statement_lines').select(_lineCols).eq('import_id', importId).order('line_date');
    return rowsOf(data).map(BankLineRow.fromJson).toList();
  }

  /// Matches for these lines (chunked so long statements do not exceed URL limits).
  Future<List<BankMatchRow>> loadMatches(List<String> lineIds) async {
    final out = <BankMatchRow>[];
    for (var i = 0; i < lineIds.length; i += 80) {
      final chunk = lineIds.sublist(i, i + 80 > lineIds.length ? lineIds.length : i + 80);
      final data = await db.from('bank_reconciliation_matches').select('*').inFilter('statement_line_id', chunk);
      out.addAll(rowsOf(data).map(BankMatchRow.fromJson));
    }
    return out;
  }

  /// `fetchReconcilableData`: unmatched verified bank-channel payments + ledger rows in the period (± tolerance).
  Future<List<ReconcilableTarget>> fetchTargets(String societyId, String periodFrom, String periodTo) async {
    final confirmed = rowsOf(await db
        .from('bank_reconciliation_matches')
        .select('maintenance_payment_id, finance_entry_id')
        .eq('society_id', societyId)
        .inFilter('status', ['confirmed', 'manual']));
    final matchedPaymentIds = {
      for (final m in confirmed)
        if (m['maintenance_payment_id'] != null) m['maintenance_payment_id'].toString(),
    };
    final matchedEntryIds = {
      for (final m in confirmed)
        if (m['finance_entry_id'] != null) m['finance_entry_id'].toString(),
    };

    final charges = rowsOf(await db.from('maintenance_charges').select('id, title').eq('society_id', societyId));
    final titleById = {for (final c in charges) (c['id'] ?? '').toString(): (c['title'] ?? '').toString()};
    final payments = titleById.isEmpty
        ? <Map<String, dynamic>>[]
        : rowsOf(await db
            .from('maintenance_payments')
            .select('id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, transaction_id, charge_id')
            .inFilter('charge_id', titleById.keys.toList()));
    final ledger = rowsOf(await db
        .from('finance_entries')
        .select('id, total_amount, payment_method, payment_status, transaction_date, entry_month, created_at, transaction_id, title, destination')
        .eq('society_id', societyId));

    final all = buildReconcilableTargets(
      [for (final p in payments) ReconPaymentInput.fromJson(p, chargeTitle: titleById[(p['charge_id'] ?? '').toString()] ?? '')],
      [for (final e in ledger) ReconLedgerInput.fromJson(e)],
      matchedPaymentIds,
      matchedEntryIds,
    );
    return filterTargetsToPeriod(all, periodFrom, periodTo);
  }

  /// `persistMatch`: update the line's existing match row or insert one.
  Future<void> persistMatch({
    required String societyId,
    required String adminName,
    required SuggestedMatch suggestion,
    required String status,
  }) async {
    final confirmedLike = status == 'confirmed' || status == 'manual';
    final payload = {
      'statement_line_id': suggestion.statementLineId,
      'society_id': societyId,
      'match_type': suggestion.matchType,
      'maintenance_payment_id': suggestion.maintenancePaymentId,
      'finance_entry_id': suggestion.financeEntryId,
      'match_confidence': suggestion.matchConfidence,
      'status': status,
      'matched_by': confirmedLike ? adminName : null,
      'matched_at': confirmedLike ? DateTime.now().toUtc().toIso8601String() : null,
    };
    final existing = await db
        .from('bank_reconciliation_matches')
        .select('id')
        .eq('statement_line_id', suggestion.statementLineId)
        .limit(1)
        .maybeSingle();
    if (existing != null && existing['id'] != null) {
      await db.from('bank_reconciliation_matches').update(payload).eq('id', existing['id'] as Object);
      return;
    }
    await db.from('bank_reconciliation_matches').insert(payload).select('id').single();
  }

  Future<String> insertImport({
    required String societyId,
    String? bankName,
    String? accountLast4,
    required String periodFrom,
    required String periodTo,
    required String fileName,
    required String importedBy,
  }) async {
    final row = await db
        .from('bank_statement_imports')
        .insert({
          'society_id': societyId,
          'bank_name': bankName,
          'account_last4': accountLast4,
          'period_from': periodFrom,
          'period_to': periodTo,
          'file_name': fileName,
          'imported_by': importedBy,
        })
        .select('id')
        .single();
    return (row['id'] ?? '').toString();
  }

  Future<List<BankLineRow>> insertLines(String importId, String societyId, List<BankStatementCsvRow> rows) async {
    final payload = [
      for (final r in rows)
        {
          'import_id': importId,
          'society_id': societyId,
          'line_date': r.lineDate,
          'amount': r.amount,
          'description': r.description.isEmpty ? null : r.description,
          'reference': r.reference.isEmpty ? null : r.reference,
          'raw_row': r.rawRow,
        },
    ];
    final data = await db.from('bank_statement_lines').insert(payload).select(_lineCols);
    return rowsOf(data).map(BankLineRow.fromJson).toList();
  }
}
