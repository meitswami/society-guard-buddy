import 'finance_audit_detection.dart';
import 'js_compat.dart';

/// Pure computation behind `src/components/FinanceIntegrityAudit.tsx` (`runAudit`).
/// The widget loads the rows; this file turns them into findings + fix queue.

String _l(bool hi, String en, String hindi) => hi ? hindi : en;

bool _truthy(String? s) => s != null && s.isNotEmpty;

class AuditChargeRow {
  const AuditChargeRow(
      {required this.id,
      required this.title,
      required this.amount,
      required this.frequency});

  final String id;
  final String title;
  final double amount;
  final String? frequency;

  bool get isMonthly => (frequency ?? '').toLowerCase() == 'monthly';

  factory AuditChargeRow.fromJson(Map<String, dynamic> j) => AuditChargeRow(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        amount: jsNumber(j['amount']),
        frequency: jsStrOrNull(j['frequency']),
      );
}

class AuditFlatRow {
  const AuditFlatRow(
      {required this.id, required this.flatNumber, required this.isOccupied});

  final String id;
  final String flatNumber;
  final bool? isOccupied;

  factory AuditFlatRow.fromJson(Map<String, dynamic> j) => AuditFlatRow(
        id: (j['id'] ?? '').toString(),
        flatNumber: (j['flat_number'] ?? '').toString(),
        isOccupied: j['is_occupied'] is bool ? j['is_occupied'] as bool : null,
      );
}

enum FindingSeverity { critical, warning, info, pass }

enum FindingKind {
  duplicatePayments,
  ledgerOvercount,
  recordingMismatch,
  orphanedPayments,
  generic
}

class AuditFinding {
  const AuditFinding({
    required this.id,
    required this.severity,
    required this.title,
    required this.description,
    required this.reason,
    required this.rectification,
    this.faultTrace,
    this.kind,
    this.data,
    this.ledgerIssues,
    this.channelTrace,
    this.recordingMismatchMonths,
  });

  final String id;
  final FindingSeverity severity;
  final String title;
  final String description;
  final String reason;
  final String rectification;
  final String? faultTrace;
  final FindingKind? kind;
  final Map<String, Object?>? data;
  final List<LedgerOvercountMonth>? ledgerIssues;
  final ChannelBalanceTrace? channelTrace;
  final List<RecordingMismatchMonth>? recordingMismatchMonths;
}

class AuditSummary {
  const AuditSummary(
      {required this.critical,
      required this.warning,
      required this.info,
      required this.pass});

  final int critical;
  final int warning;
  final int info;
  final int pass;
}

class IntegrityAuditInput {
  const IntegrityAuditInput(
      {required this.charges,
      required this.payments,
      required this.ledger,
      required this.flats});

  final List<AuditChargeRow> charges;
  final List<AuditPaymentRow> payments;
  final List<AuditLedgerRow> ledger;
  final List<AuditFlatRow> flats;
}

class IntegrityAuditResult {
  const IntegrityAuditResult(
      {required this.ranAt,
      required this.findings,
      required this.fixQueue,
      required this.summary});

  final DateTime ranAt;
  final List<AuditFinding> findings;
  final List<AuditFixQueueItem> fixQueue;
  final AuditSummary summary;
}

class _Builder {
  _Builder(this.hi);

  final bool hi;
  final List<AuditFinding> findings = [];
  var _idx = 0;

  void add({
    required FindingSeverity severity,
    required String title,
    required String description,
    String reason = '',
    String rectification = '',
    String? faultTrace,
    FindingKind? kind,
    Map<String, Object?>? data,
    List<LedgerOvercountMonth>? ledgerIssues,
    ChannelBalanceTrace? channelTrace,
    List<RecordingMismatchMonth>? recordingMismatchMonths,
  }) {
    findings.add(AuditFinding(
      id: 'f-${_idx++}',
      severity: severity,
      title: title,
      description: description,
      reason: reason,
      rectification: rectification,
      faultTrace: faultTrace,
      kind: kind,
      data: data,
      ledgerIssues: ledgerIssues,
      channelTrace: channelTrace,
      recordingMismatchMonths: recordingMismatchMonths,
    ));
  }

  void error(Object err) {
    final msg = err.toString().trim();
    add(
      severity: FindingSeverity.critical,
      title: _l(hi, 'Audit Engine Error', 'ऑडिट इंजन त्रुटि'),
      description: msg.isNotEmpty
          ? msg
          : _l(hi, 'An unexpected error occurred while running the audit.',
              'ऑडिट चलाते समय अनपेक्षित त्रुटि हुई।'),
      reason: _l(hi, 'Database connectivity issue or missing table.',
          'डेटाबेस कनेक्शन समस्या या तालिका उपलब्ध नहीं।'),
      rectification: _l(
        hi,
        'Check your internet connection and try again. If the issue persists, contact support.',
        'अपना इंटरनेट कनेक्शन जाँचें और फिर से प्रयास करें। समस्या बनी रहे तो सहायता से संपर्क करें।',
      ),
    );
  }
}

AuditSummary _summaryOf(List<AuditFinding> f) => AuditSummary(
      critical: f.where((x) => x.severity == FindingSeverity.critical).length,
      warning: f.where((x) => x.severity == FindingSeverity.warning).length,
      info: f.where((x) => x.severity == FindingSeverity.info).length,
      pass: f.where((x) => x.severity == FindingSeverity.pass).length,
    );

/// Result when loading the data failed (web `catch` branch).
IntegrityAuditResult integrityAuditError(Object err,
    {DateTime? now, bool hi = false}) {
  final b = _Builder(hi)..error(err);
  return IntegrityAuditResult(
      ranAt: now ?? DateTime.now(),
      findings: b.findings,
      fixQueue: const [],
      summary: _summaryOf(b.findings));
}

/// Runs every self-audit rule on the loaded rows.
IntegrityAuditResult computeIntegrityAudit(IntegrityAuditInput input,
    {DateTime? now, bool hi = false}) {
  final ranAt = now ?? DateTime.now();
  final b = _Builder(hi);

  var duplicateGroups = <DuplicatePaymentGroup>[];
  var ledgerOvercountIssues = <LedgerOvercountMonth>[];
  var recordingMismatchMonths = <RecordingMismatchMonth>[];
  var orphanedPayments = <AuditPaymentRow>[];
  ChannelBalanceTrace? cashTrace;
  ChannelBalanceTrace? bankTrace;

  String inr(num n) => jsInr(n);
  String m(String ym) => fmtIsoMonthToDisplay(ym);

  try {
    final charges = input.charges;
    final chargeMap = {for (final c in charges) c.id: c};
    final allPayments = input.payments;
    final allLedger = input.ledger;
    final monthlyChargeIds = [
      for (final c in charges)
        if (c.isMonthly) c.id
    ];
    final chargeTitleById = {for (final c in charges) c.id: c.title};
    final verifiedPayments =
        allPayments.where((p) => p.paymentStatus == 'verified').toList();

    /* ─── 2. Negative cash / bank balance ─── */
    final receipt = {
      PaymentChannel.cash: 0.0,
      PaymentChannel.bank: 0.0,
      PaymentChannel.other: 0.0
    };
    final expense = {
      PaymentChannel.cash: 0.0,
      PaymentChannel.bank: 0.0,
      PaymentChannel.other: 0.0
    };
    final linkedFeIds = <String>{};
    for (final p in verifiedPayments) {
      final ch = normalizePaymentChannel(p.paymentMethod);
      receipt[ch] = receipt[ch]! + p.amount;
      if (p.hasFinanceEntry) linkedFeIds.add(p.financeEntryId!);
    }
    for (final e in allLedger) {
      final ch = normalizePaymentChannel(e.paymentMethod);
      if (e.destination == 'separate_entry') {
        expense[ch] = expense[ch]! + e.totalAmount;
      } else if (!linkedFeIds.contains(e.id)) {
        receipt[ch] = receipt[ch]! + e.totalAmount;
      }
    }
    final cashBalance =
        receipt[PaymentChannel.cash]! - expense[PaymentChannel.cash]!;
    final bankBalance =
        receipt[PaymentChannel.bank]! - expense[PaymentChannel.bank]!;

    final channelTxns = buildChannelTransactions(
        verifiedPayments, allLedger, linkedFeIds,
        hi: hi);
    cashTrace = traceChannelBalanceDeficit(channelTxns, PaymentChannel.cash);
    bankTrace = traceChannelBalanceDeficit(channelTxns, PaymentChannel.bank);

    for (final isCash in [true, false]) {
      final balance = isCash ? cashBalance : bankBalance;
      final trace = isCash ? cashTrace : bankTrace;
      final ch = isCash ? PaymentChannel.cash : PaymentChannel.bank;
      final inflow = receipt[ch]!, outflow = expense[ch]!;
      if (balance < 0) {
        final faultDate = trace?.firstNegativeDate;
        final faultMonth = trace?.firstNegativeMonth;
        final monthPart = faultMonth != null ? ' (${m(faultMonth)})' : '';
        final period = faultDate == null
            ? ''
            : (faultMonth != null ? m(faultMonth) : jsSlice(faultDate, 0, 7));
        final String faultDesc;
        if (faultDate != null) {
          faultDesc = isCash
              ? _l(
                  hi,
                  'Negative cash first appears on ${fmtIsoDateToDisplay(faultDate)}$monthPart.',
                  'ऋणात्मक नकद पहली बार ${fmtIsoDateToDisplay(faultDate)}$monthPart को दिखा।')
              : _l(
                  hi,
                  'Negative bank balance first appears on ${fmtIsoDateToDisplay(faultDate)}$monthPart.',
                  'ऋणात्मक बैंक शेष पहली बार ${fmtIsoDateToDisplay(faultDate)}$monthPart को दिखा।');
        } else {
          faultDesc = isCash
              ? _l(
                  hi,
                  'Cash outflow exceeds cash inflow across all recorded dates.',
                  'सभी दर्ज तिथियों में नकद बहिर्वाह नकद अंतर्वाह से अधिक है।')
              : _l(
                  hi,
                  'Bank outflow exceeds bank inflow across all recorded dates.',
                  'सभी दर्ज तिथियों में बैंक बहिर्वाह बैंक अंतर्वाह से अधिक है।');
        }
        final String rectification;
        if (faultDate != null) {
          rectification = isCash
              ? _l(
                  hi,
                  '1. Open Reports → Financial, set statement period to $period and review cash-channel entries.\n2. Review the entries listed under "Trace to fault" — correct payment_method or delete duplicate expenses.\n3. If a receipt exists under bank/UPI for the same payment, retag it as cash or change the expense to bank.\n4. Re-run this audit after fixing.',
                  '1. रिपोर्ट → वित्तीय खोलें, विवरण अवधि $period रखें और नकद माध्यम की प्रविष्टियाँ जाँचें।\n2. "गड़बड़ी तक ट्रेस" में दी गई प्रविष्टियाँ देखें — payment_method सुधारें या डुप्लिकेट खर्च हटाएँ।\n3. यदि उसी भुगतान की रसीद बैंक/UPI में दर्ज है, तो उसे नकद टैग करें या खर्च को बैंक में बदलें।\n4. सुधार के बाद यह ऑडिट फिर से चलाएँ।',
                )
              : _l(
                  hi,
                  '1. Open Reports → Financial, set statement period to $period and review bank-channel entries.\n2. Review entries under "Trace to fault" — correct payment_method or remove duplicate bank expenses.\n3. If the receipt was recorded as cash, retag it as UPI/bank or change the expense channel.\n4. Re-run this audit after fixing.',
                  '1. रिपोर्ट → वित्तीय खोलें, विवरण अवधि $period रखें और बैंक माध्यम की प्रविष्टियाँ जाँचें।\n2. "गड़बड़ी तक ट्रेस" की प्रविष्टियाँ देखें — payment_method सुधारें या डुप्लिकेट बैंक खर्च हटाएँ।\n3. यदि रसीद नकद में दर्ज हुई थी, तो उसे UPI/बैंक टैग करें या खर्च का माध्यम बदलें।\n4. सुधार के बाद यह ऑडिट फिर से चलाएँ।',
                );
        } else {
          rectification = isCash
              ? _l(
                  hi,
                  '1. Go to Reports → Financial and review cash-channel entries to identify mismatched items.\n2. Check if any expense marked "cash" should actually be "bank/UPI".\n3. Verify all cash receipts are in "verified" status.\n4. Look for duplicate expense entries under cash channel.\n5. Correct the payment_method on the wrongly tagged entry from Finance → Transactions.',
                  '1. रिपोर्ट → वित्तीय में जाकर नकद माध्यम की प्रविष्टियाँ जाँचें और गलत मदें पहचानें।\n2. देखें कि "cash" चिह्नित कोई खर्च वास्तव में "bank/UPI" तो नहीं होना चाहिए।\n3. सुनिश्चित करें कि सभी नकद रसीदें "verified" स्थिति में हों।\n4. नकद माध्यम में डुप्लिकेट खर्च प्रविष्टियाँ खोजें।\n5. वित्त → लेन-देन से गलत टैग वाली प्रविष्टि का payment_method सुधारें।',
                )
              : _l(
                  hi,
                  '1. Go to Reports → Financial and review bank-channel entries.\n2. Check if any receipt marked "cash" should be "UPI/bank".\n3. Verify no bank receipts are stuck in "pending" or "rejected" status.\n4. Look for duplicate expense entries under bank channel.\n5. Correct the payment_method on mismatched entries in Finance → Transactions.',
                  '1. रिपोर्ट → वित्तीय में बैंक माध्यम की प्रविष्टियाँ जाँचें।\n2. देखें कि "cash" चिह्नित कोई रसीद "UPI/bank" तो नहीं होनी चाहिए।\n3. सुनिश्चित करें कि कोई बैंक रसीद "pending" या "rejected" स्थिति में अटकी न हो।\n4. बैंक माध्यम में डुप्लिकेट खर्च प्रविष्टियाँ खोजें।\n5. वित्त → लेन-देन में गलत प्रविष्टियों का payment_method सुधारें।',
                );
        }
        b.add(
          severity: FindingSeverity.critical,
          title: isCash
              ? _l(hi, 'Negative Cash Balance: ${inr(balance.abs())}',
                  'ऋणात्मक नकद शेष: ${inr(balance.abs())}')
              : _l(hi, 'Negative Bank Balance: ${inr(balance.abs())}',
                  'ऋणात्मक बैंक शेष: ${inr(balance.abs())}'),
          description: isCash
              ? _l(
                  hi,
                  '$faultDesc Cash outflow (${inr(outflow)}) exceeds cash inflow (${inr(inflow)}).',
                  '$faultDesc नकद बहिर्वाह (${inr(outflow)}) नकद अंतर्वाह (${inr(inflow)}) से अधिक है।')
              : _l(
                  hi,
                  '$faultDesc Bank outflow (${inr(outflow)}) exceeds bank inflow (${inr(inflow)}).',
                  '$faultDesc बैंक बहिर्वाह (${inr(outflow)}) बैंक अंतर्वाह (${inr(inflow)}) से अधिक है।'),
          reason: isCash
              ? _l(
                  hi,
                  'Usually caused by a cash expense on the fault date without a matching cash receipt, or a receipt tagged as bank/UPI instead of cash.',
                  'आमतौर पर गड़बड़ी की तिथि पर बिना मेल खाती नकद रसीद के नकद खर्च, या नकद की जगह बैंक/UPI टैग की गई रसीद के कारण होता है।',
                )
              : _l(
                  hi,
                  'Usually caused by a bank/UPI expense on the fault date without a matching bank receipt, or a receipt incorrectly tagged as cash.',
                  'आमतौर पर गड़बड़ी की तिथि पर बिना मेल खाती बैंक रसीद के बैंक/UPI खर्च, या गलती से नकद टैग की गई रसीद के कारण होता है।',
                ),
          faultTrace: trace != null
              ? formatChannelBalanceFaultTrace(trace, hi: hi)
              : null,
          rectification: rectification,
          data: isCash
              ? {
                  'cashReceipts': inflow,
                  'cashExpenses': outflow,
                  'deficit': balance,
                  'faultDate': faultDate,
                  'faultMonth': faultMonth
                }
              : {
                  'bankReceipts': inflow,
                  'bankExpenses': outflow,
                  'deficit': balance,
                  'faultDate': faultDate,
                  'faultMonth': faultMonth
                },
          channelTrace: trace,
        );
      } else {
        b.add(
          severity: FindingSeverity.pass,
          title: isCash
              ? _l(hi, 'Cash Balance OK: ${inr(balance)}',
                  'नकद शेष ठीक: ${inr(balance)}')
              : _l(hi, 'Bank Balance OK: ${inr(balance)}',
                  'बैंक शेष ठीक: ${inr(balance)}'),
          description: isCash
              ? _l(hi, 'Cash inflow covers all cash outflow.',
                  'नकद अंतर्वाह सभी नकद बहिर्वाह को पूरा करता है।')
              : _l(hi, 'Bank inflow covers all bank outflow.',
                  'बैंक अंतर्वाह सभी बैंक बहिर्वाह को पूरा करता है।'),
        );
      }
    }

    /* ─── 3. Duplicate payments (monthly charges, across charges) ─── */
    duplicateGroups = findDuplicatePaymentGroups(allPayments, chargeTitleById,
        chargeIds: monthlyChargeIds, groupAcrossCharges: true);
    if (duplicateGroups.isNotEmpty) {
      final uniqueMonths = <String>[];
      for (final g in duplicateGroups) {
        if (!uniqueMonths.contains(g.month)) uniqueMonths.add(g.month);
      }
      final monthSummary = (List<String>.of(uniqueMonths)..sort())
          .reversed
          .take(5)
          .map(m)
          .join(', ');
      final sampleGroups = duplicateGroups.take(4).map((g) {
        return hi
            ? '  • ${m(g.month)}: फ्लैट ${g.flatNumber}, ${g.chargeTitle} (${g.paymentMethod}) — ${g.count} पंक्तियाँ, ${inr(g.totalAmount)}'
            : '  • ${m(g.month)}: Flat ${g.flatNumber}, ${g.chargeTitle} (${g.paymentMethod}) — ${g.count} rows, ${inr(g.totalAmount)}';
      }).join('\n');
      final n = duplicateGroups.length;
      b.add(
        severity: FindingSeverity.critical,
        kind: FindingKind.duplicatePayments,
        title: _l(hi, '$n Duplicate Payment Group${n > 1 ? 's' : ''} Found',
            '$n डुप्लिकेट भुगतान समूह मिले'),
        description: _l(
          hi,
          'Duplicate rows in month(s): $monthSummary. Same flat + billing month has multiple monthly maintenance receipts (any charge / cash / UPI).',
          'इन माह में डुप्लिकेट पंक्तियाँ: $monthSummary। एक ही फ्लैट + बिलिंग माह के लिए कई मासिक रखरखाव रसीदें हैं (कोई भी शुल्क / नकद / UPI)।',
        ),
        reason: _l(
          hi,
          'Two or more payment rows exist for the same flat and month. This is different from ledger double-count (an extra finance_entries receipt without duplicate payments).',
          'एक ही फ्लैट और माह के लिए दो या अधिक भुगतान पंक्तियाँ हैं। यह लेजर दोहरी गिनती से अलग है (डुप्लिकेट भुगतान के बिना अतिरिक्त finance_entries रसीद)।',
        ),
        faultTrace: hi
            ? 'प्रभावित माह: $monthSummary\nडुप्लिकेट समूह:\n$sampleGroups'
            : 'Affected months: $monthSummary\nDuplicate groups:\n$sampleGroups',
        rectification: _l(
          hi,
          'Scroll to "Duplicate maintenance payment rows" above, expand the group for the month listed, and delete or edit the extra payment. Keep one verified row per flat per month.',
          'ऊपर "डुप्लिकेट रखरखाव भुगतान पंक्तियाँ" तक स्क्रॉल करें, बताए गए माह का समूह खोलें, और अतिरिक्त भुगतान हटाएँ या संपादित करें। प्रति फ्लैट प्रति माह एक सत्यापित पंक्ति रखें।',
        ),
        data: {'duplicateGroups': n, 'months': uniqueMonths},
      );
    } else {
      b.add(
        severity: FindingSeverity.pass,
        title: _l(hi, 'No Duplicate Payment Rows',
            'कोई डुप्लिकेट भुगतान पंक्ति नहीं'),
        description: _l(
            hi,
            'Each flat has at most one monthly maintenance payment per billing month.',
            'हर फ्लैट का प्रति बिलिंग माह अधिकतम एक मासिक रखरखाव भुगतान है।'),
      );
    }

    /* ─── 4. Recording vs reporting discrepancy ─── */
    final mpTotal = verifiedPayments.fold(0.0, (s, p) => s + p.amount);
    final feFlatsOnlyTotal = allLedger
        .where((e) =>
            e.recordMode == 'flats_only' && e.paymentStatus == 'verified')
        .fold(0.0, (s, e) => s + e.totalAmount);
    final discrepancy = (mpTotal - feFlatsOnlyTotal).abs();
    recordingMismatchMonths =
        analyzeRecordingMismatchByMonth(verifiedPayments, allLedger, hi: hi);
    if (discrepancy > 1) {
      final earliest = recordingMismatchMonths.isEmpty
          ? null
          : stableSorted(recordingMismatchMonths,
              (a, b) => jsLocaleCompare(a.month, b.month)).first.month;
      final monthHint = earliest == null
          ? ''
          : _l(hi, 'Mismatch traceable from ${m(earliest)} onward.',
              'असंगति ${m(earliest)} से आगे ट्रेस की जा सकती है।');
      final trace =
          formatRecordingMismatchFaultTrace(recordingMismatchMonths, hi: hi);
      b.add(
        severity: FindingSeverity.warning,
        kind: FindingKind.recordingMismatch,
        title: _l(hi, 'Recording vs Ledger Discrepancy: ${inr(discrepancy)}',
            'दर्ज बनाम लेजर असंगति: ${inr(discrepancy)}'),
        description: _l(
          hi,
          'Sum of verified maintenance_payments (${inr(mpTotal)}) does not match sum of finance_entries[flats_only] (${inr(feFlatsOnlyTotal)}). $monthHint',
          'सत्यापित maintenance_payments का योग (${inr(mpTotal)}) finance_entries[flats_only] के योग (${inr(feFlatsOnlyTotal)}) से मेल नहीं खाता। $monthHint',
        ),
        reason: _l(
          hi,
          'Lifetime totals differ — often orphaned payments (no finance_entry_id), deleted ledger rows, or amount edits in only one table. Expand "Trace to fault" to see which month and entries caused the gap.',
          'कुल योग अलग हैं — अक्सर बिना लिंक भुगतान (finance_entry_id नहीं), हटाई गई लेजर पंक्तियाँ, या केवल एक तालिका में राशि बदलना। किस माह और प्रविष्टियों से अंतर आया, यह देखने के लिए "गड़बड़ी तक ट्रेस" खोलें।',
        ),
        faultTrace: trace.isEmpty ? null : trace,
        rectification: _l(
          hi,
          '1. Start with the earliest month in "Trace to fault" — open Reports → Financial for that statement period.\n2. Fix orphan payments or orphan ledger rows listed for that month.\n3. If amounts differ on linked pairs, align in Finance → Record receipt or Transactions.\n4. Re-run audit; repeat for the next affected month if needed.',
          '1. "गड़बड़ी तक ट्रेस" के सबसे पुराने माह से शुरू करें — उस विवरण अवधि के लिए रिपोर्ट → वित्तीय खोलें।\n2. उस माह की बिना लिंक भुगतान या बिना लिंक लेजर पंक्तियाँ सुधारें।\n3. यदि जुड़ी जोड़ियों में राशि अलग है, तो वित्त → रसीद दर्ज करें या लेन-देन में मिलाएँ।\n4. ऑडिट फिर चलाएँ; ज़रूरत हो तो अगले प्रभावित माह के लिए दोहराएँ।',
        ),
        data: {
          'maintenancePaymentsTotal': mpTotal,
          'financeEntriesTotal': feFlatsOnlyTotal,
          'difference': discrepancy,
          'affectedMonths': [for (final x in recordingMismatchMonths) x.month],
        },
        recordingMismatchMonths: recordingMismatchMonths,
      );
    } else {
      b.add(
        severity: FindingSeverity.pass,
        title: _l(hi, 'Recording & Reporting Figures Match',
            'दर्ज और रिपोर्ट के आँकड़े मेल खाते हैं'),
        description: _l(
            hi,
            'Maintenance payments total matches finance ledger entries total.',
            'रखरखाव भुगतान का योग वित्त लेजर प्रविष्टियों के योग से मेल खाता है।'),
      );
    }

    /* ─── 5. Period report ledger double-count ─── */
    ledgerOvercountIssues =
        analyzeLedgerOvercountByMonth(verifiedPayments, allLedger);
    if (ledgerOvercountIssues.isNotEmpty) {
      final totalExcess =
          ledgerOvercountIssues.fold(0.0, (s, x) => s + x.excess);
      final orphanCount =
          ledgerOvercountIssues.fold(0, (s, x) => s + x.unlinkedLedger.length);
      final earliest = stableSorted(ledgerOvercountIssues,
          (a, b) => jsLocaleCompare(a.month, b.month)).first.month;
      final lines = ledgerOvercountIssues.take(6).map((issue) {
        final orphanLines = issue.unlinkedLedger.take(2).map((e) {
          final t = _truthy(e.title) ? e.title! : _l(hi, 'Entry', 'प्रविष्टि');
          return hi
              ? '${e.ledgerDate} बिना लिंक "$t" ${inr(e.totalAmount)}'
              : '${e.ledgerDate} orphan "$t" ${inr(e.totalAmount)}';
        }).join('; ');
        final boundaryLines = issue.dateBoundary.take(2).map((x) {
          return hi
              ? 'फ्लैट ${x.payment.flatNumber}: भुगतान माह ${m(x.paymentMonth)} बनाम लेजर ${m(x.entryMonth)}'
              : 'Flat ${x.payment.flatNumber}: payment month ${m(x.paymentMonth)} vs ledger ${m(x.entryMonth)}';
        }).join('; ');
        final parts =
            [orphanLines, boundaryLines].where((s) => s.isNotEmpty).join(' | ');
        return '  • ${m(issue.month)} (+${inr(issue.excess)})${parts.isNotEmpty ? ': $parts' : ''}';
      }).toList();
      final monthsList = ledgerOvercountIssues
          .map((x) => '${m(x.month)} (+${inr(x.excess)})')
          .join(', ');
      final n = ledgerOvercountIssues.length;
      b.add(
        severity: FindingSeverity.critical,
        kind: FindingKind.ledgerOvercount,
        title: _l(
            hi,
            'Ledger Double-Count in Reports: ${inr(totalExcess)} across $n month(s)',
            'रिपोर्ट में लेजर दोहरी गिनती: ${inr(totalExcess)}, $n माह में'),
        description: _l(
          hi,
          'Period reports count extra receipt(s) beyond verified payments — usually $orphanCount unlinked finance_entries row(s). Earliest anomaly: ${m(earliest)}. Months: $monthsList.',
          'अवधि रिपोर्ट सत्यापित भुगतानों से अधिक रसीदें गिनती हैं — आमतौर पर $orphanCount बिना लिंक finance_entries पंक्तियाँ। सबसे पहली गड़बड़ी: ${m(earliest)}। माह: $monthsList।',
        ),
        reason: _l(
          hi,
          'An extra finance ledger receipt exists without linked maintenance_payments (or payment/ledger months disagree). This inflates period reports but does NOT appear in "duplicate payment rows" — there may still be only one payment per flat.',
          'बिना जुड़े maintenance_payments के एक अतिरिक्त वित्त लेजर रसीद मौजूद है (या भुगतान/लेजर के माह मेल नहीं खाते)। इससे अवधि रिपोर्ट बढ़ जाती है पर यह "डुप्लिकेट भुगतान पंक्तियाँ" में नहीं दिखता — हो सकता है प्रति फ्लैट केवल एक ही भुगतान हो।',
        ),
        faultTrace: [
          _l(hi, 'Earliest affected month: ${m(earliest)}',
              'सबसे पहला प्रभावित माह: ${m(earliest)}'),
          if (lines.isNotEmpty)
            '${_l(hi, 'Month → entry trail:', 'माह → प्रविष्टि क्रम:')}\n${lines.join('\n')}',
        ].join('\n\n'),
        rectification: _l(
          hi,
          'Use the "Ledger double-count (period reports)" panel above: start with the earliest month in the trace, delete orphan ledger entries, or align payment due_date with ledger entry_month. Then re-run this audit.',
          'ऊपर "लेजर दोहरी गिनती (अवधि रिपोर्ट)" पैनल का उपयोग करें: ट्रेस के सबसे पुराने माह से शुरू करें, बिना लिंक लेजर प्रविष्टियाँ हटाएँ, या भुगतान की due_date को लेजर entry_month से मिलाएँ। फिर यह ऑडिट दोबारा चलाएँ।',
        ),
        data: {
          'months': [
            for (final x in ledgerOvercountIssues)
              {
                'month': x.month,
                'excess': x.excess,
                'unlinkedCount': x.unlinkedLedger.length,
                'boundaryCount': x.dateBoundary.length
              },
          ],
        },
        ledgerIssues: ledgerOvercountIssues,
      );
    } else {
      b.add(
        severity: FindingSeverity.pass,
        title: _l(
            hi, 'Period Report Totals Verified', 'अवधि रिपोर्ट योग सत्यापित'),
        description: _l(hi, 'No ledger double-count in monthly period reports.',
            'मासिक अवधि रिपोर्ट में कोई लेजर दोहरी गिनती नहीं।'),
      );
    }

    /* ─── 6. Orphaned payments (no finance_entry_id) ─── */
    orphanedPayments =
        verifiedPayments.where((p) => !p.hasFinanceEntry).toList();
    if (orphanedPayments.isNotEmpty) {
      final orphanTotal = orphanedPayments.fold(0.0, (s, p) => s + p.amount);
      final byMonth = <String, List<AuditPaymentRow>>{};
      for (final p in orphanedPayments) {
        final d = _truthy(p.dueDate)
            ? p.dueDate!
            : (_truthy(p.paymentDate) ? p.paymentDate! : p.createdAt);
        final key = d.isNotEmpty ? (ymOf(d) ?? 'unknown') : 'unknown';
        byMonth.putIfAbsent(key, () => []).add(p);
      }
      final sortedEntries = stableSorted(
          byMonth.entries,
          (MapEntry<String, List<AuditPaymentRow>> a,
                  MapEntry<String, List<AuditPaymentRow>> b) =>
              jsLocaleCompare(a.key, b.key));
      final monthLines = sortedEntries.take(6).map((entry) {
        final rows = entry.value;
        final total = rows.fold(0.0, (s, p) => s + p.amount);
        final samples = rows.take(2).map((p) {
          final date = _truthy(p.dueDate)
              ? p.dueDate!
              : (_truthy(p.paymentDate)
                  ? p.paymentDate!
                  : _l(hi, 'no date', 'कोई तिथि नहीं'));
          return hi
              ? '$date फ्लैट ${p.flatNumber} ${inr(p.amount)}'
              : '$date Flat ${p.flatNumber} ${inr(p.amount)}';
        }).join('; ');
        final label = entry.key == 'unknown'
            ? _l(hi, 'Unknown month', 'अज्ञात माह')
            : m(entry.key);
        return hi
            ? '  • $label: ${rows.length} बिना लिंक, ${inr(total)} — $samples'
            : '  • $label: ${rows.length} orphan(s), ${inr(total)} — $samples';
      }).join('\n');
      final known = byMonth.keys.where((k) => k != 'unknown').toList()..sort();
      final earliestOrphan = known.isEmpty ? null : known.first;
      final n = orphanedPayments.length;
      b.add(
        severity: FindingSeverity.warning,
        kind: FindingKind.orphanedPayments,
        title: _l(
            hi,
            '$n Orphaned Payment${n > 1 ? 's' : ''} (${inr(orphanTotal)})',
            '$n बिना लिंक भुगतान (${inr(orphanTotal)})'),
        description: earliestOrphan != null
            ? _l(
                hi,
                'These verified payments have no linked finance_entry record. Earliest: ${m(earliestOrphan)}.',
                'इन सत्यापित भुगतानों का कोई जुड़ा finance_entry रिकॉर्ड नहीं है। सबसे पुराना: ${m(earliestOrphan)}।')
            : _l(
                hi,
                'These verified payments have no linked finance_entry record.',
                'इन सत्यापित भुगतानों का कोई जुड़ा finance_entry रिकॉर्ड नहीं है।'),
        reason: _l(
          hi,
          'Likely recorded before the ledger system was introduced, or the finance_entry was deleted while the payment remained.',
          'संभवतः लेजर प्रणाली शुरू होने से पहले दर्ज किए गए, या भुगतान रहते हुए finance_entry हटा दी गई।',
        ),
        faultTrace: monthLines.isNotEmpty
            ? '${_l(hi, 'Orphans by month:', 'माहवार बिना लिंक भुगतान:')}\n$monthLines'
            : null,
        rectification: _l(
          hi,
          'Start with the earliest month in the trace. Finance → Payments: re-record with ledger, or delete orphan payment rows if they are mistakes.',
          'ट्रेस के सबसे पुराने माह से शुरू करें। वित्त → भुगतान: लेजर के साथ फिर से दर्ज करें, या गलती वाली बिना लिंक भुगतान पंक्तियाँ हटाएँ।',
        ),
        data: {
          'count': n,
          'total': orphanTotal,
          'samples': [
            for (final p in orphanedPayments.take(8))
              {
                'id': jsSlice(p.id, 0, 8),
                'flat': p.flatNumber,
                'amount': p.amount,
                'due': p.dueDate
              },
          ],
        },
      );
    } else {
      b.add(
        severity: FindingSeverity.pass,
        title: _l(hi, 'All Payments Linked to Ledger',
            'सभी भुगतान लेजर से जुड़े हैं'),
        description: _l(
            hi,
            'Every verified payment has a corresponding finance_entry.',
            'हर सत्यापित भुगतान की एक संबंधित finance_entry है।'),
      );
    }

    /* ─── 7. Finance entries with wrong flat count ─── */
    final linkedCount = <String, int>{};
    for (final p in allPayments) {
      if (p.hasFinanceEntry)
        linkedCount[p.financeEntryId!] =
            (linkedCount[p.financeEntryId!] ?? 0) + 1;
    }
    final mismatchIds = <String>[];
    for (final e in allLedger) {
      final agg = e.aggregateFlatCount ?? 0;
      if (e.recordMode == 'flats_only' && agg > 0) {
        final linked = linkedCount[e.id] ?? 0;
        if (linked > 0 && linked != agg) mismatchIds.add(e.id);
      }
    }
    if (mismatchIds.isNotEmpty) {
      final n = mismatchIds.length;
      b.add(
        severity: FindingSeverity.warning,
        title: _l(hi, '$n Ledger Entries with Flat Count Mismatch',
            'फ्लैट संख्या असंगति वाली $n लेजर प्रविष्टियाँ'),
        description: _l(
            hi,
            'The aggregate_flat_count on these finance_entries does not match the actual number of linked payments.',
            'इन finance_entries की aggregate_flat_count जुड़े भुगतानों की वास्तविक संख्या से मेल नहीं खाती।'),
        reason: _l(
            hi,
            'A payment was deleted or added after the finance_entry was created without updating the entry metadata.',
            'finance_entry बनने के बाद कोई भुगतान हटाया या जोड़ा गया और प्रविष्टि का मेटाडेटा अपडेट नहीं हुआ।'),
        rectification: _l(
            hi,
            'Review these entries in Finance → Receipts tab. The totals may be incorrect. Delete and re-record if needed.',
            'इन प्रविष्टियों को वित्त → रसीदें टैब में जाँचें। योग गलत हो सकते हैं। ज़रूरत हो तो हटाकर फिर से दर्ज करें।'),
        data: {'entryIds': mismatchIds.take(5).toList()},
      );
    }

    /* ─── 8. Charge amount vs recorded payment ─── */
    final monthlyCharges = charges.where((c) => c.isMonthly).toList();
    var amountMismatchCount = 0;
    for (final p in verifiedPayments) {
      final charge = chargeMap[p.chargeId];
      if (charge == null || !charge.isMonthly) continue;
      if (charge.amount > 0 && p.amount != charge.amount) amountMismatchCount++;
    }
    if (amountMismatchCount > 0) {
      final n = amountMismatchCount;
      b.add(
        severity: FindingSeverity.info,
        title: _l(hi, '$n Payment${n > 1 ? 's' : ''} with Non-Standard Amount',
            'गैर-मानक राशि वाले $n भुगतान'),
        description: _l(
            hi,
            'Some payments have a different amount than the charge definition.',
            'कुछ भुगतानों की राशि शुल्क परिभाषा से अलग है।'),
        reason: _l(
            hi,
            'Could be partial payments, penalty additions, discounts, or data entry errors.',
            'आंशिक भुगतान, जुर्माना जोड़, छूट, या डेटा प्रविष्टि की गलतियाँ हो सकती हैं।'),
        rectification: _l(
            hi,
            'Review in Finance → Payments tab. Filter by charge type and compare amounts. Correct any that are clearly wrong.',
            'वित्त → भुगतान टैब में जाँचें। शुल्क प्रकार से छानें और राशियों की तुलना करें। जो स्पष्ट रूप से गलत हों उन्हें सुधारें।'),
        data: {'count': n},
      );
    }

    /* ─── 9. Pending payments stuck > 7 days ─── */
    final nowMs = ranAt.millisecondsSinceEpoch;
    final oldPending = allPayments.where((p) {
      if (p.paymentStatus != 'pending') return false;
      final t = jsTimeMs(p.createdAt);
      return t != null && nowMs - t > 7 * 24 * 60 * 60 * 1000;
    }).toList();
    if (oldPending.isNotEmpty) {
      final n = oldPending.length;
      b.add(
        severity: FindingSeverity.warning,
        title: _l(hi, '$n Payment${n > 1 ? 's' : ''} Pending > 7 Days',
            '$n भुगतान 7 दिन से अधिक लंबित'),
        description: _l(
            hi,
            'These payments have been in "pending" status for over a week without verification.',
            'ये भुगतान बिना सत्यापन के एक सप्ताह से अधिक समय से "pending" स्थिति में हैं।'),
        reason: _l(
            hi,
            'Admin may have missed verifying them, or they were submitted by residents and never reviewed.',
            'हो सकता है एडमिन इन्हें सत्यापित करना भूल गए, या निवासियों ने जमा किए और कभी समीक्षा नहीं हुई।'),
        rectification: _l(
            hi,
            'Go to Finance → Payments tab, filter by "Pending" status, and verify or reject each one.',
            'वित्त → भुगतान टैब में जाएँ, "Pending" स्थिति से छानें, और हर एक को सत्यापित या अस्वीकार करें।'),
        data: {'count': n},
      );
    }

    /* ─── 10. Occupied flats with no payment this month ─── */
    final currentMonth = ymOfDate(ranAt);
    final paidFlats = <String>{};
    for (final p in verifiedPayments) {
      final d = _truthy(p.dueDate)
          ? p.dueDate!
          : (_truthy(p.paymentDate) ? p.paymentDate! : p.createdAt);
      if (d.isNotEmpty && ymOf(d) == currentMonth) paidFlats.add(p.flatNumber);
    }
    final unpaid = input.flats
        .where(
            (f) => f.isOccupied != false && !paidFlats.contains(f.flatNumber))
        .toList();
    if (unpaid.isNotEmpty && monthlyCharges.isNotEmpty) {
      final n = unpaid.length;
      final list =
          '${unpaid.take(10).map((f) => f.flatNumber).join(', ')}${n > 10 ? '…' : ''}';
      b.add(
        severity: FindingSeverity.info,
        title: _l(
            hi,
            '$n Flat${n > 1 ? 's' : ''} Unpaid This Month (${m(currentMonth)})',
            'इस माह $n फ्लैट अदत्त (${m(currentMonth)})'),
        description: _l(
            hi,
            'Occupied flats without a verified payment for ${m(currentMonth)}: $list',
            '${m(currentMonth)} के लिए बिना सत्यापित भुगतान वाले भरे हुए फ्लैट: $list'),
        reason: _l(
            hi,
            'Either payment not yet recorded, or resident has not paid.',
            'या तो भुगतान अभी दर्ज नहीं हुआ, या निवासी ने भुगतान नहीं किया।'),
        rectification: _l(
            hi,
            'Send reminders from Finance → Reminders tab, or record payments if already received.',
            'वित्त → रिमाइंडर टैब से रिमाइंडर भेजें, या यदि भुगतान मिल चुका है तो दर्ज करें।'),
        data: {
          'count': n,
          'flats': [for (final f in unpaid.take(20)) f.flatNumber]
        },
      );
    }
  } catch (err) {
    b.error(err);
  }

  final fixQueue = buildAuditFixQueue(
    AuditFixQueueInput(
      duplicateGroups: duplicateGroups,
      ledgerOvercountIssues: ledgerOvercountIssues,
      recordingMismatchMonths: recordingMismatchMonths,
      orphanedPayments: orphanedPayments,
      cashTrace: cashTrace,
      bankTrace: bankTrace,
    ),
    hi: hi,
  );

  return IntegrityAuditResult(
      ranAt: ranAt,
      findings: b.findings,
      fixQueue: fixQueue,
      summary: _summaryOf(b.findings));
}
