import 'finance_audit_detection.dart';
import 'integrity_audit_engine.dart' show AuditChargeRow;
import 'js_compat.dart';

/// Pure computation behind `src/components/ManualAuditTracer.tsx` (`trace`).

String _l(bool hi, String en, String hindi) => hi ? hindi : en;

bool _truthy(String? s) => s != null && s.isNotEmpty;

/// Earliest month selectable in the tracer (`FINANCE_REPORTING_EARLIEST_MONTH`).
const String financeReportingEarliestMonth = '2026-02';

enum TraceSource { periodReport, flatReport, paymentsTab, receiptsTab }

/// Web id (`period_report` …).
String traceSourceId(TraceSource s) => switch (s) {
      TraceSource.periodReport => 'period_report',
      TraceSource.flatReport => 'flat_report',
      TraceSource.paymentsTab => 'payments_tab',
      TraceSource.receiptsTab => 'receipts_tab',
    };

/// Option label in the "Report Source" select.
String traceSourceOption(TraceSource s, {bool hi = false}) => switch (s) {
      TraceSource.periodReport => _l(hi, 'Period Report', 'अवधि रिपोर्ट'),
      TraceSource.flatReport => _l(hi, 'Flat Report', 'फ्लैट रिपोर्ट'),
      TraceSource.paymentsTab => _l(hi, 'Payments Tab', 'भुगतान टैब'),
      TraceSource.receiptsTab => _l(hi, 'Receipts Tab', 'रसीद टैब'),
    };

/// `source.replace(/_/g, ' ')` on the web (lower-case words), Hindi label otherwise.
String traceSourceText(TraceSource s, {bool hi = false}) =>
    hi ? traceSourceOption(s, hi: true) : traceSourceId(s).replaceAll('_', ' ');

enum TraceSeverity { error, warning, info }

class TraceFinding {
  const TraceFinding({
    required this.id,
    required this.severity,
    required this.title,
    required this.description,
    required this.origin,
    required this.navigateTo,
    required this.navigateLabel,
    this.navigateSubTab,
    this.data,
  });

  final String id;
  final TraceSeverity severity;
  final String title;
  final String description;
  final String origin;

  /// Admin tab id: `finance` | `audit` | `report`.
  final String navigateTo;
  final String navigateLabel;

  /// Finance sub-tab the label refers to (`payments` / `receipts`), if any.
  final String? navigateSubTab;
  final Map<String, Object?>? data;
}

class TraceResult {
  const TraceResult({
    required this.source,
    required this.computedTotal,
    required this.expectedTotal,
    required this.difference,
    required this.findings,
  });

  final TraceSource source;
  final double computedTotal;

  /// `null` when the trace ran without an expected amount.
  final double? expectedTotal;
  final double? difference;
  final List<TraceFinding> findings;
}

/// JS `Number(s)` + `Number.isFinite` for the optional expected amount.
double? parseExpectedAmount(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  if (n == null || n.isNaN || n.isInfinite) return null;
  return n;
}

String _paymentDate(AuditPaymentRow p) => _truthy(p.dueDate)
    ? p.dueDate!
    : (_truthy(p.paymentDate) ? p.paymentDate! : p.createdAt);

String _ledgerDate(AuditLedgerRow e) =>
    _truthy(e.entryMonth) ? '${e.entryMonth}-01' : e.createdAt;

TraceResult computeManualTrace({
  required List<AuditChargeRow> charges,
  required List<AuditPaymentRow> payments,
  required List<AuditLedgerRow> ledger,
  required String month,
  required String expectedAmount,
  required TraceSource source,
  bool hi = false,
}) {
  final expected = parseExpectedAmount(expectedAmount);
  final findings = <TraceFinding>[];
  var idx = 0;
  void add({
    required TraceSeverity severity,
    required String title,
    required String description,
    required String origin,
    required String navigateTo,
    required String navigateLabel,
    String? navigateSubTab,
    Map<String, Object?>? data,
  }) {
    findings.add(TraceFinding(
      id: 'tf-${idx++}',
      severity: severity,
      title: title,
      description: description,
      origin: origin,
      navigateTo: navigateTo,
      navigateLabel: navigateLabel,
      navigateSubTab: navigateSubTab,
      data: data,
    ));
  }

  String inr(num n) => jsInr(n);
  final monthLabel = fmtIsoMonthToDisplay(month);
  final sourceText = traceSourceText(source, hi: hi);

  try {
    final bounds = monthBoundsMs(month);
    if (bounds == null) {
      throw FormatException(_l(hi, 'Invalid month', 'अमान्य माह'));
    }
    bool inMonth(String? d) {
      final t = jsTimeMs(d);
      return t != null && t >= bounds.fromMs && t <= bounds.toMs;
    }

    final chargeMap = {for (final c in charges) c.id: c};
    final verified =
        payments.where((p) => p.paymentStatus == 'verified').toList();
    final linkedFeIds = <String>{
      for (final p in verified)
        if (p.hasFinanceEntry) p.financeEntryId!,
    };
    final ledgerById = <String, AuditLedgerRow>{};
    for (final e in ledger) {
      ledgerById.putIfAbsent(e.id, () => e);
    }

    // ─── What the period report shows for this month ───
    var periodReportTotal = 0.0;
    final periodPayments = <AuditPaymentRow>[];
    for (final p in verified) {
      if (inMonth(_paymentDate(p))) {
        periodReportTotal += p.amount;
        periodPayments.add(p);
      }
    }
    final unlinkedInMonth = <AuditLedgerRow>[];
    for (final e in ledger) {
      if (e.destination == 'separate_entry') continue;
      if (!inMonth(_ledgerDate(e))) continue;
      if (!linkedFeIds.contains(e.id)) {
        periodReportTotal += e.totalAmount;
        unlinkedInMonth.add(e);
      }
    }

    // ─── Flat report total for this month ───
    var flatReportTotal = 0.0;
    final countedFeIds = <String>{};
    for (final p in verified) {
      if (inMonth(_paymentDate(p))) {
        flatReportTotal += p.amount;
        if (p.hasFinanceEntry) countedFeIds.add(p.financeEntryId!);
      }
    }
    for (final e in ledger) {
      if (e.destination == 'separate_entry') continue;
      if (!inMonth(_ledgerDate(e))) continue;
      if (e.recordMode == 'flats_only' && countedFeIds.contains(e.id)) continue;
      flatReportTotal += e.totalAmount;
    }

    final computedTotal =
        source == TraceSource.periodReport || source == TraceSource.receiptsTab
            ? periodReportTotal
            : flatReportTotal;
    final difference = expected != null ? computedTotal - expected : null;
    final amountMatches = difference != null && difference.abs() < 1;

    // 1. Date-boundary payments.
    final boundary =
        <({AuditPaymentRow p, String paymentMonth, String entryMonth})>[];
    for (final p in verified) {
      if (!p.hasFinanceEntry) continue;
      final pDate = _paymentDate(p);
      final pMonth = pDate.isNotEmpty ? (ymOf(pDate) ?? '') : '';
      final entry = ledgerById[p.financeEntryId];
      if (entry == null) continue;
      final eMonth = entry.entryMonth ?? '';
      if (pMonth.isNotEmpty &&
          eMonth.isNotEmpty &&
          pMonth != eMonth &&
          (pMonth == month || eMonth == month)) {
        boundary.add((p: p, paymentMonth: pMonth, entryMonth: eMonth));
      }
    }
    final boundaryTotal = boundary.fold(0.0, (s, x) => s + x.p.amount);
    if (boundary.isNotEmpty) {
      add(
        severity: TraceSeverity.error,
        title: _l(
            hi,
            '${boundary.length} Date-Boundary Payment(s) — ${inr(boundaryTotal)}',
            '${boundary.length} तिथि-सीमा भुगतान — ${inr(boundaryTotal)}'),
        description: _l(
          hi,
          'These payments have due_date in one month but their finance_entry has entry_month in a different month. This causes the payment to appear in one report but the ledger entry in another.',
          'इन भुगतानों की due_date एक माह में है पर उनकी finance_entry का entry_month दूसरे माह में है। इससे भुगतान एक रिपोर्ट में और लेजर प्रविष्टि दूसरी रिपोर्ट में दिखती है।',
        ),
        origin: _l(
            hi,
            'Finance → Payments tab. The payment due_date does not match the finance_entry entry_month.',
            'वित्त → भुगतान टैब। भुगतान की due_date, finance_entry के entry_month से मेल नहीं खाती।'),
        navigateTo: 'finance',
        navigateSubTab: 'payments',
        navigateLabel: _l(hi, 'Go to Payments', 'भुगतान पर जाएँ'),
        data: {
          'payments': [
            for (final x in boundary.take(10))
              {
                'id': jsSlice(x.p.id, 0, 8),
                'flat': x.p.flatNumber,
                'amount': x.p.amount,
                'paymentMonth': x.paymentMonth,
                'entryMonth': x.entryMonth,
                'method': x.p.paymentMethod,
              },
          ],
        },
      );
    }

    // 2. Unlinked ledger entries adding extra receipts.
    final unlinkedTotal =
        unlinkedInMonth.fold(0.0, (s, e) => s + e.totalAmount);
    if (unlinkedInMonth.isNotEmpty) {
      add(
        severity: TraceSeverity.error,
        title: _l(
            hi,
            '${unlinkedInMonth.length} Unlinked Ledger Entry/Entries — ${inr(unlinkedTotal)}',
            '${unlinkedInMonth.length} बिना लिंक लेजर प्रविष्टियाँ — ${inr(unlinkedTotal)}'),
        description: _l(
          hi,
          'These finance_entries have no linked maintenance_payments. The period report counts their total_amount as additional receipts, inflating the total.',
          'इन finance_entries से कोई maintenance_payments जुड़ा नहीं है। अवधि रिपोर्ट इनके total_amount को अतिरिक्त रसीद मानकर गिनती है, जिससे योग बढ़ जाता है।',
        ),
        origin: _l(
            hi,
            'Finance → Receipts tab. These entries exist in the ledger but have no corresponding payment records.',
            'वित्त → रसीदें टैब। ये प्रविष्टियाँ लेजर में हैं पर इनके संबंधित भुगतान रिकॉर्ड नहीं हैं।'),
        navigateTo: 'finance',
        navigateSubTab: 'receipts',
        navigateLabel: _l(hi, 'Go to Receipts', 'रसीदों पर जाएँ'),
        data: {
          'entries': [
            for (final e in unlinkedInMonth.take(10))
              {
                'id': jsSlice(e.id, 0, 8),
                'title': e.title,
                'amount': e.totalAmount,
                'mode': e.recordMode,
                'destination': e.destination,
                'entryMonth': e.entryMonth,
              },
          ],
        },
      );
    }

    // 3. Duplicate payments in this month (flat + charge + month + channel).
    final dupeGroups = <String, List<AuditPaymentRow>>{};
    for (final p in periodPayments) {
      final d = _paymentDate(p);
      final monthKey = d.isNotEmpty ? (ymOf(d) ?? 'unknown') : 'unknown';
      final key =
          '${p.flatNumber}||${p.chargeId}||$monthKey||${normalizePaymentChannel(p.paymentMethod).name}';
      dupeGroups.putIfAbsent(key, () => []).add(p);
    }
    final dupes = dupeGroups.entries.where((e) => e.value.length > 1).toList();
    final dupeTotal = dupes.fold(
        0.0, (s, e) => s + e.value.skip(1).fold(0.0, (ss, p) => ss + p.amount));
    if (dupes.isNotEmpty) {
      add(
        severity: TraceSeverity.error,
        title: _l(
            hi,
            '${dupes.length} Duplicate Payment Group(s) — ${inr(dupeTotal)} extra',
            '${dupes.length} डुप्लिकेट भुगतान समूह — ${inr(dupeTotal)} अतिरिक्त'),
        description: _l(
            hi,
            'Same flat + same charge + same channel recorded multiple times in $monthLabel.',
            '$monthLabel में एक ही फ्लैट + एक ही शुल्क + एक ही माध्यम कई बार दर्ज है।'),
        origin: _l(hi, 'Finance → Payments tab. Delete the duplicate entries.',
            'वित्त → भुगतान टैब। डुप्लिकेट प्रविष्टियाँ हटाएँ।'),
        navigateTo: 'audit',
        navigateLabel:
            _l(hi, 'Go to Duplicate Alarms', 'डुप्लिकेट अलार्म पर जाएँ'),
        data: {
          'duplicates': [
            for (final e in dupes.take(5))
              {
                'flat': e.key.split('||').first,
                'count': e.value.length,
                'totalAmount': e.value.fold(0.0, (s, p) => s + p.amount)
              },
          ],
        },
      );
    }

    // 4. Payments with wrong amount vs charge definition.
    final wrong =
        <({AuditPaymentRow p, double expected, String chargeTitle})>[];
    for (final p in periodPayments) {
      final charge = chargeMap[p.chargeId];
      if (charge == null || !charge.isMonthly) continue;
      if (charge.amount > 0 && (p.amount - charge.amount).abs() > 1) {
        wrong.add((p: p, expected: charge.amount, chargeTitle: charge.title));
      }
    }
    if (wrong.isNotEmpty) {
      final amtDiff = wrong.fold(0.0, (s, x) => s + (x.p.amount - x.expected));
      final dir = amtDiff > 0 ? _l(hi, 'over', 'अधिक') : _l(hi, 'under', 'कम');
      add(
        severity: TraceSeverity.warning,
        title: _l(
            hi,
            '${wrong.length} Payment(s) with Non-Standard Amount — ${inr(amtDiff.abs())} $dir',
            'गैर-मानक राशि वाले ${wrong.length} भुगतान — ${inr(amtDiff.abs())} $dir'),
        description: _l(
          hi,
          'These payments have a different amount than the charge definition. Could be partial payments, penalties, or data entry errors.',
          'इन भुगतानों की राशि शुल्क परिभाषा से अलग है। आंशिक भुगतान, जुर्माना, या डेटा प्रविष्टि की गलती हो सकती है।',
        ),
        origin: _l(
            hi,
            'Finance → Payments tab. Compare each payment amount against the charge definition.',
            'वित्त → भुगतान टैब। हर भुगतान राशि की तुलना शुल्क परिभाषा से करें।'),
        navigateTo: 'finance',
        navigateSubTab: 'payments',
        navigateLabel: _l(hi, 'Go to Payments', 'भुगतान पर जाएँ'),
        data: {
          'payments': [
            for (final x in wrong.take(10))
              {
                'flat': x.p.flatNumber,
                'recorded': x.p.amount,
                'expected': x.expected,
                'charge': x.chargeTitle,
                'diff': x.p.amount - x.expected
              },
          ],
        },
      );
    }

    // 5. Orphaned payments in this month.
    final orphans = periodPayments.where((p) => !p.hasFinanceEntry).toList();
    if (orphans.isNotEmpty) {
      final orphanTotal = orphans.fold(0.0, (s, p) => s + p.amount);
      final flats = <String>[];
      for (final p in orphans) {
        if (!flats.contains(p.flatNumber)) flats.add(p.flatNumber);
      }
      add(
        severity: TraceSeverity.warning,
        title: _l(
            hi,
            '${orphans.length} Orphaned Payment(s) — ${inr(orphanTotal)}',
            '${orphans.length} बिना लिंक भुगतान — ${inr(orphanTotal)}'),
        description: _l(
          hi,
          'These payments have no linked finance_entry. They are counted in totals but lack a ledger trail, which can cause flat report vs period report mismatch.',
          'इन भुगतानों से कोई finance_entry नहीं जुड़ी है। ये योग में गिने जाते हैं पर इनका लेजर रिकॉर्ड नहीं है, जिससे फ्लैट रिपोर्ट और अवधि रिपोर्ट में अंतर आ सकता है।',
        ),
        origin: _l(
            hi,
            'Finance → Payments tab. These need to be re-recorded properly or linked to a ledger entry.',
            'वित्त → भुगतान टैब। इन्हें सही तरीके से फिर से दर्ज करना होगा या किसी लेजर प्रविष्टि से जोड़ना होगा।'),
        navigateTo: 'finance',
        navigateSubTab: 'payments',
        navigateLabel: _l(hi, 'Go to Payments', 'भुगतान पर जाएँ'),
        data: {
          'count': orphans.length,
          'total': orphanTotal,
          'flats': flats.take(10).toList()
        },
      );
    }

    // 6. Period report vs flat report.
    final reportDiff = (periodReportTotal - flatReportTotal).abs();
    if (reportDiff > 1) {
      add(
        severity: TraceSeverity.warning,
        title: _l(
            hi,
            'Period Report vs Flat Report Mismatch — ${inr(reportDiff)}',
            'अवधि रिपोर्ट बनाम फ्लैट रिपोर्ट असंगति — ${inr(reportDiff)}'),
        description: _l(
            hi,
            'Period report shows ${inr(periodReportTotal)} but flat report shows ${inr(flatReportTotal)} for $monthLabel.',
            '$monthLabel के लिए अवधि रिपोर्ट ${inr(periodReportTotal)} दिखाती है पर फ्लैट रिपोर्ट ${inr(flatReportTotal)} दिखाती है।'),
        origin: _l(
            hi,
            'Reports → Financial: compare head-wise and flat-wise views for this month.',
            'रिपोर्ट → वित्तीय: इस माह के शीर्ष-वार और फ्लैट-वार दृश्य की तुलना करें।'),
        navigateTo: 'report',
        navigateLabel: _l(hi, 'Go to Reports', 'रिपोर्ट पर जाएँ'),
        data: {
          'periodReport': periodReportTotal,
          'flatReport': flatReportTotal,
          'difference': reportDiff
        },
      );
    }

    // 7. Amount comparison / clean scan summary.
    if (expected != null && amountMatches && findings.isEmpty) {
      add(
        severity: TraceSeverity.info,
        title: _l(hi, 'No discrepancy detected', 'कोई असंगति नहीं मिली'),
        description: _l(
            hi,
            'The $sourceText shows ${inr(computedTotal)} which matches your expected ${inr(expected)}.',
            '$sourceText ${inr(computedTotal)} दिखाता है जो आपकी अपेक्षित राशि ${inr(expected)} से मेल खाता है।'),
        origin: _l(hi, 'System computation matches expected value.',
            'प्रणाली की गणना अपेक्षित मान से मेल खाती है।'),
        navigateTo: 'finance',
        navigateLabel: _l(hi, 'Open Finance', 'वित्त खोलें'),
      );
    } else if (expected != null && difference != null && difference.abs() > 1) {
      final breakdown = <String>[
        if (boundary.isNotEmpty)
          _l(hi, 'Date-boundary: ${inr(boundaryTotal)}',
              'तिथि-सीमा: ${inr(boundaryTotal)}'),
        if (unlinkedInMonth.isNotEmpty)
          _l(hi, 'Unlinked ledger: ${inr(unlinkedTotal)}',
              'बिना लिंक लेजर: ${inr(unlinkedTotal)}'),
        if (dupes.isNotEmpty)
          _l(hi, 'Duplicates: ${inr(dupeTotal)}',
              'डुप्लिकेट: ${inr(dupeTotal)}'),
      ];
      final sources = breakdown.isNotEmpty
          ? breakdown.join(' + ')
          : _l(hi, 'Could not pinpoint — check individual payments manually.',
              'सटीक पता नहीं चला — अलग-अलग भुगतान स्वयं जाँचें।');
      final sign = difference > 0 ? '+' : '';
      add(
        severity: TraceSeverity.info,
        title: _l(hi, 'Discrepancy Breakdown: $sign${inr(difference)}',
            'असंगति विवरण: $sign${inr(difference)}'),
        description: _l(
            hi,
            'System shows ${inr(computedTotal)}, you expected ${inr(expected)}. Possible sources: $sources',
            'प्रणाली ${inr(computedTotal)} दिखाती है, आपने ${inr(expected)} अपेक्षित किया। संभावित स्रोत: $sources'),
        origin: _l(
            hi,
            'Multiple sources may contribute. Expand findings above for details.',
            'कई स्रोत योगदान दे सकते हैं। विवरण के लिए ऊपर के निष्कर्ष खोलें।'),
        navigateTo: 'finance',
        navigateLabel: _l(hi, 'Open Finance Module', 'वित्त मॉड्यूल खोलें'),
      );
    } else if (expected == null && findings.isEmpty) {
      add(
        severity: TraceSeverity.info,
        title: _l(hi, 'No structural issues found',
            'कोई संरचनात्मक समस्या नहीं मिली'),
        description: _l(
          hi,
          'Scanned $monthLabel without an expected amount. System $sourceText total is ${inr(computedTotal)}. Enter an expected collection to compare against bank/manual figures.',
          '$monthLabel को बिना अपेक्षित राशि के जाँचा गया। प्रणाली $sourceText का योग ${inr(computedTotal)} है। बैंक/मैन्युअल आँकड़ों से तुलना के लिए अपेक्षित संग्रह दर्ज करें।',
        ),
        origin: _l(
            hi,
            'Structural checks only — date-boundary, unlinked ledger, duplicates, orphans, report mismatch.',
            'केवल संरचनात्मक जाँच — तिथि-सीमा, बिना लिंक लेजर, डुप्लिकेट, बिना लिंक भुगतान, रिपोर्ट असंगति।'),
        navigateTo: 'finance',
        navigateLabel: _l(hi, 'Open Finance', 'वित्त खोलें'),
      );
    }

    return TraceResult(
      source: source,
      computedTotal: computedTotal,
      expectedTotal: expected,
      difference: difference,
      findings: findings,
    );
  } catch (err) {
    return manualTraceError(err,
        source: source, expectedAmount: expectedAmount, hi: hi);
  }
}

/// Web `catch` branch of `trace()`.
TraceResult manualTraceError(Object err,
    {required TraceSource source,
    required String expectedAmount,
    bool hi = false}) {
  final expected = parseExpectedAmount(expectedAmount);
  final msg = err.toString().trim();
  return TraceResult(
    source: source,
    computedTotal: 0,
    expectedTotal: expected,
    difference: expected != null ? 0 : null,
    findings: [
      TraceFinding(
        id: 'err',
        severity: TraceSeverity.error,
        title: _l(hi, 'Trace Failed', 'ट्रेस विफल'),
        description: msg.isNotEmpty
            ? msg
            : _l(hi, 'Unexpected error', 'अनपेक्षित त्रुटि'),
        origin: _l(hi, 'System error', 'सिस्टम त्रुटि'),
        navigateTo: 'audit',
        navigateLabel: _l(hi, 'Stay here', 'यहीं रहें'),
      ),
    ],
  );
}
