import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/export/export_kit.dart';
import '../../../../core/ui/ui.dart';
import '../data/audit_logger.dart';
import '../data/audit_service.dart';
import '../data/bank_recon_service.dart';
import '../logic/bank_reconciliation.dart';
import '../logic/js_compat.dart';
import 'audit_ui.dart';

enum _LineFilter { all, exceptions, suggested, unmatched, confirmed }

/// Port of `BankReconciliation.tsx`: CSV import, auto-match to maintenance receipts / ledger,
/// confirm / reject / manual link, bulk confirm, exceptions export.
class BankReconciliationPanel extends StatefulWidget {
  const BankReconciliationPanel(
      {super.key,
      required this.societyId,
      required this.adminName,
      this.refreshSeq = 0});

  final String societyId;
  final String adminName;
  final int refreshSeq;

  @override
  State<BankReconciliationPanel> createState() =>
      _BankReconciliationPanelState();
}

class _BankReconciliationPanelState extends State<BankReconciliationPanel> {
  final _service = const BankReconService();
  List<BankImportRow> _imports = const [];
  String? _selectedId;
  List<BankLineRow> _lines = const [];
  List<BankMatchRow> _matches = const [];
  List<SuggestedMatch> _pending = const [];
  List<ReconcilableTarget> _targets = const [];
  Map<String, ReconcilableTarget> _targetByKey = const {};
  bool _loading = false;
  bool _importing = false;
  bool _runningMatch = false;
  String? _busyLineId;
  final _bankName = TextEditingController();
  final _last4 = TextEditingController();
  final _search = TextEditingController();
  _LineFilter _filter = _LineFilter.all;
  String? _manualPickLineId;

  @override
  void initState() {
    super.initState();
    _loadImports();
  }

  @override
  void didUpdateWidget(covariant BankReconciliationPanel old) {
    super.didUpdateWidget(old);
    if (old.refreshSeq != widget.refreshSeq ||
        old.societyId != widget.societyId) {
      _loadImports();
      if (_selectedId != null) _loadDetail(_selectedId!);
    }
  }

  @override
  void dispose() {
    _bankName.dispose();
    _last4.dispose();
    _search.dispose();
    super.dispose();
  }

  void _toastError(Object e, String fallbackEn, String fallbackHi) {
    if (!mounted) return;
    var msg = e is BankCsvException
        ? (context.isHi
            ? (e.code == 'missing_date'
                ? 'CSV में तिथि कॉलम होना चाहिए (date, value date, transaction date आदि)'
                : 'CSV में amount या debit/credit कॉलम होने चाहिए')
            : e.message)
        : auditErrText(e);
    if (msg.trim().isEmpty) msg = context.tr(fallbackEn, fallbackHi);
    AppFeedback.toast(context, msg, tone: BadgeTone.alert);
  }

  Future<void> _loadImports() async {
    try {
      final rows = await _service.loadImports(widget.societyId);
      if (mounted) setState(() => _imports = rows);
    } catch (_) {
      if (mounted) setState(() => _imports = const []);
    }
  }

  BankImportRow? get _selectedImport {
    for (final i in _imports) {
      if (i.id == _selectedId) return i;
    }
    return null;
  }

  Future<int> _runMatchAndPersist(List<BankLineRow> lineRows, String from,
      String to, List<BankMatchRow> existing) async {
    final targets = await _service.fetchTargets(widget.societyId, from, to);
    final matchedLineIds = existing.map((m) => m.statementLineId).toSet();
    final used = <String>{};
    for (final m in existing) {
      if (m.status == 'confirmed' || m.status == 'manual') {
        if (m.maintenancePaymentId != null)
          used.add('maintenance_payment:${m.maintenancePaymentId}');
        if (m.financeEntryId != null)
          used.add('finance_entry:${m.financeEntryId}');
      }
    }
    final inputs = lineRows
        .where((l) => !matchedLineIds.contains(l.id))
        .map((l) => l.forMatch)
        .toList();
    final suggestions = suggestMatches(inputs, targets)
        .where((s) => !used.contains(targetKey(s.target)))
        .toList();
    for (final s in suggestions) {
      await _service.persistMatch(
          societyId: widget.societyId,
          adminName: widget.adminName,
          suggestion: s,
          status: 'suggested');
      used.add(targetKey(s.target));
    }
    return suggestions.length;
  }

  Future<void> _loadDetail(String importId, {String? from, String? to}) async {
    setState(() => _loading = true);
    try {
      var periodFrom = from ?? '';
      var periodTo = to ?? '';
      if (periodFrom.isEmpty || periodTo.isEmpty) {
        final imp = _imports.where((i) => i.id == importId).firstOrNull;
        periodFrom = imp?.periodFrom ?? '';
        periodTo = imp?.periodTo ?? '';
      }
      if (periodFrom.isEmpty || periodTo.isEmpty) {
        final p = await _service.importPeriod(importId);
        periodFrom = p.from;
        periodTo = p.to;
      }
      final lineRows = await _service.loadLines(importId);
      final matches = lineRows.isEmpty
          ? <BankMatchRow>[]
          : await _service.loadMatches(lineRows.map((l) => l.id).toList());
      final targets =
          await _service.fetchTargets(widget.societyId, periodFrom, periodTo);
      final byKey = {for (final t in targets) targetKey(t): t};

      final matchedLineIds = matches.map((m) => m.statementLineId).toSet();
      final used = <String>{};
      for (final m in matches) {
        if (m.maintenancePaymentId != null)
          used.add('maintenance_payment:${m.maintenancePaymentId}');
        if (m.financeEntryId != null)
          used.add('finance_entry:${m.financeEntryId}');
      }

      final dbSuggested =
          matches.where((m) => m.status == 'suggested').toList();
      final hydrated = <SuggestedMatch>[];
      for (final m in dbSuggested) {
        final line =
            lineRows.where((l) => l.id == m.statementLineId).firstOrNull;
        if (line == null) continue;
        final target = byKey[m.targetKey];
        final isPayment = m.matchType == 'maintenance_payment';
        hydrated.add(SuggestedMatch(
          statementLineId: m.statementLineId,
          matchType: m.matchType,
          maintenancePaymentId: m.maintenancePaymentId,
          financeEntryId: m.financeEntryId,
          matchConfidence: m.matchConfidence,
          reasons: const ['Saved suggestion'],
          target: target ??
              (isPayment
                  ? ReconcilablePayment(
                      id: m.maintenancePaymentId ?? m.financeEntryId ?? '',
                      amount: line.amount,
                      date: line.lineDate,
                      paymentMethod: 'bank',
                      transactionId: null,
                      flatNumber: '',
                      label: 'Linked record',
                      savedFallback: true,
                    )
                  : ReconcilableLedgerEntry(
                      id: m.maintenancePaymentId ?? m.financeEntryId ?? '',
                      amount: line.amount,
                      date: line.lineDate,
                      paymentMethod: 'bank',
                      transactionId: null,
                      title: null,
                      destination: '',
                      label: 'Linked record',
                      savedFallback: true,
                    )),
        ));
      }
      final dbSuggestedLineIds =
          dbSuggested.map((m) => m.statementLineId).toSet();
      final needCompute = lineRows
          .where((l) =>
              !matchedLineIds.contains(l.id) &&
              !dbSuggestedLineIds.contains(l.id))
          .toList();
      final computed = needCompute.isEmpty
          ? <SuggestedMatch>[]
          : suggestMatches(needCompute.map((l) => l.forMatch).toList(),
              targets.where((t) => !used.contains(targetKey(t))).toList());

      if (!mounted) return;
      setState(() {
        _lines = lineRows;
        _matches = matches;
        _targets = targets;
        _targetByKey = byKey;
        _pending = [...hydrated, ...computed];
      });
    } catch (e) {
      _toastError(e, 'Could not load statement', 'विवरण लोड नहीं हो सका');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(String? id) {
    setState(() {
      _selectedId = id;
      _filter = _LineFilter.all;
      _search.clear();
      _manualPickLineId = null;
      if (id == null) {
        _lines = const [];
        _matches = const [];
        _pending = const [];
        _targets = const [];
      }
    });
    if (id != null) _loadDetail(id);
  }

  Future<void> _downloadTemplate() async {
    try {
      await ExportKit.shareCsv(
          Uint8List.fromList(utf8.encode(bankReconCsvTemplate())),
          'bank-statement-template.csv');
    } catch (e) {
      _toastError(e, 'Could not share file', 'फ़ाइल साझा नहीं हो सकी');
    }
  }

  Future<void> _pickFile() async {
    if (widget.societyId.isEmpty) return;
    final picked =
        await FilePicker.pickFiles(type: FileType.any, withData: true);
    final file = picked?.files.firstOrNull;
    if (file == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final bytes = file.bytes;
      if (bytes == null)
        throw Exception(
            context.tr('Could not read file', 'फ़ाइल पढ़ी नहीं जा सकी'));
      final text =
          utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
      final parsed = parseBankStatementCsv(text);
      if (parsed.isEmpty) {
        if (mounted)
          AppFeedback.toast(
              context,
              context.tr('No valid rows found in CSV',
                  'CSV में कोई मान्य पंक्ति नहीं मिली'),
              tone: BadgeTone.alert);
        return;
      }
      final dates = parsed.map((r) => r.lineDate).toList()..sort();
      final from = dates.first, to = dates.last;
      final importId = await _service.insertImport(
        societyId: widget.societyId,
        bankName: _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        accountLast4: _last4.text.trim().isEmpty ? null : _last4.text.trim(),
        periodFrom: from,
        periodTo: to,
        fileName: file.name,
        importedBy: widget.adminName,
      );
      final lineRows =
          await _service.insertLines(importId, widget.societyId, parsed);
      final count = await _runMatchAndPersist(lineRows, from, to, const []);
      await AuditLogger.log(
        societyId: widget.societyId,
        eventType: 'bank_recon_import',
        userType: 'admin',
        userName: widget.adminName,
        details: {
          'import_id': importId,
          'line_count': parsed.length,
          'suggestions_persisted': count,
          'file_name': file.name
        },
      );
      if (!mounted) return;
      AppFeedback.toast(
        context,
        context.isHi
            ? '${parsed.length} पंक्तियाँ आयात · $count स्वतः मिलान'
            : 'Imported ${parsed.length} lines · $count auto-matched',
        tone: BadgeTone.success,
      );
      await _loadImports();
      if (!mounted) return;
      setState(() {
        _selectedId = importId;
        _filter = _LineFilter.all;
        _search.clear();
      });
      await _loadDetail(importId, from: from, to: to);
    } catch (e) {
      _toastError(e, 'Import failed', 'आयात विफल');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirm(SuggestedMatch s, {bool manual = false}) async {
    setState(() => _busyLineId = s.statementLineId);
    try {
      await _service.persistMatch(
          societyId: widget.societyId,
          adminName: widget.adminName,
          suggestion: s,
          status: manual ? 'manual' : 'confirmed');
      await AuditLogger.log(
        societyId: widget.societyId,
        eventType: manual ? 'bank_recon_manual' : 'bank_recon_confirm',
        userType: 'admin',
        userName: widget.adminName,
        details: {
          'statement_line_id': s.statementLineId,
          'match_type': s.matchType,
          'target_id': s.maintenancePaymentId ?? s.financeEntryId,
          'confidence': s.matchConfidence,
        },
      );
      if (!mounted) return;
      AppFeedback.toast(
          context,
          manual
              ? context.tr('Manual link saved', 'मैन्युअल लिंक सहेजा गया')
              : context.tr('Match confirmed', 'मिलान पुष्ट'),
          tone: BadgeTone.success);
      setState(() => _manualPickLineId = null);
      if (_selectedId != null) await _loadDetail(_selectedId!);
    } catch (e) {
      _toastError(e, 'Could not confirm match', 'मिलान पुष्ट नहीं हो सका');
    } finally {
      if (mounted) setState(() => _busyLineId = null);
    }
  }

  Future<void> _reject(SuggestedMatch s) async {
    setState(() => _busyLineId = s.statementLineId);
    try {
      await _service.persistMatch(
          societyId: widget.societyId,
          adminName: widget.adminName,
          suggestion: s,
          status: 'rejected');
      await AuditLogger.log(
        societyId: widget.societyId,
        eventType: 'bank_recon_reject',
        userType: 'admin',
        userName: widget.adminName,
        details: {'statement_line_id': s.statementLineId},
      );
      if (_selectedId != null) await _loadDetail(_selectedId!);
    } catch (e) {
      _toastError(e, 'Could not reject match', 'सुझाव अस्वीकार नहीं हो सका');
    } finally {
      if (mounted) setState(() => _busyLineId = null);
    }
  }

  Future<void> _bulkConfirm() async {
    final high = _pending
        .where((s) => s.matchConfidence >= highConfidenceThreshold)
        .toList();
    if (high.isEmpty) {
      AppFeedback.toast(
          context,
          context.tr('No high-confidence suggestions to confirm',
              'पुष्टि के लिए कोई उच्च-विश्वास सुझाव नहीं'));
      return;
    }
    setState(() => _runningMatch = true);
    try {
      for (final s in high) {
        await _service.persistMatch(
            societyId: widget.societyId,
            adminName: widget.adminName,
            suggestion: s,
            status: 'confirmed');
      }
      await AuditLogger.log(
        societyId: widget.societyId,
        eventType: 'bank_recon_bulk_confirm',
        userType: 'admin',
        userName: widget.adminName,
        details: {'count': high.length},
      );
      if (!mounted) return;
      AppFeedback.toast(
          context,
          context.isHi
              ? '${high.length} उच्च-विश्वास मिलान पुष्ट'
              : 'Confirmed ${high.length} high-confidence matches',
          tone: BadgeTone.success);
      if (_selectedId != null) await _loadDetail(_selectedId!);
    } catch (e) {
      _toastError(e, 'Bulk confirm failed', 'सामूहिक पुष्टि विफल');
    } finally {
      if (mounted) setState(() => _runningMatch = false);
    }
  }

  Future<void> _rerun() async {
    final imp = _selectedImport;
    if (imp == null) return;
    setState(() => _runningMatch = true);
    try {
      final count = await _runMatchAndPersist(
        _lines,
        imp.periodFrom,
        imp.periodTo,
        _matches
            .where((m) => m.status == 'confirmed' || m.status == 'manual')
            .toList(),
      );
      if (!mounted) return;
      AppFeedback.toast(
        context,
        count > 0
            ? (context.isHi
                ? '$count नए सुझाव बने'
                : 'Generated $count new suggestions')
            : context.tr('No new matches found', 'कोई नया मिलान नहीं मिला'),
        tone: count > 0 ? BadgeTone.success : BadgeTone.neutral,
      );
      await _loadDetail(imp.id);
    } catch (e) {
      _toastError(e, 'Auto-match failed', 'स्वतः मिलान विफल');
    } finally {
      if (mounted) setState(() => _runningMatch = false);
    }
  }

  Map<String, String> get _statusByLine =>
      {for (final m in _matches) m.statementLineId: m.status};

  Map<String, SuggestedMatch> get _suggestionByLine =>
      {for (final s in _pending) s.statementLineId: s};

  String _status(String lineId, Map<String, String> statuses,
          Map<String, SuggestedMatch> sugg) =>
      reconLineStatus(lineId, statuses, sugg.keys.toSet());

  Future<void> _exportExceptions() async {
    final statuses = _statusByLine, sugg = _suggestionByLine;
    final rows = [
      for (final l in _lines)
        if (_status(l.id, statuses, sugg) != 'confirmed')
          (
            lineDate: l.lineDate,
            amount: l.amount,
            description: l.description,
            reference: l.reference,
            status: _status(l.id, statuses, sugg)
          ),
    ];
    try {
      await ExportKit.shareCsv(
          Uint8List.fromList(utf8.encode(bankReconExceptionsCsv(rows))),
          'bank-recon-exceptions.csv');
    } catch (e) {
      _toastError(e, 'Could not share file', 'फ़ाइल साझा नहीं हो सकी');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final imp = _selectedImport;
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppTokens.tint(t.primary, 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.apartment_outlined, size: 20, color: t.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Bank Reconciliation', 'बैंक मिलान'),
                        style: AppText.sectionTitle(context)),
                    Text(
                      context.tr(
                          'Import bank CSV and match credits/debits to maintenance receipts and ledger entries.',
                          'बैंक CSV आयात करें और जमा/निकासी को रखरखाव रसीदों व लेजर प्रविष्टियों से मिलाएँ।'),
                      style: TextStyle(fontSize: 11, color: t.mutedForeground),
                    ),
                  ]),
            ),
            SmallButton(
                label: context.tr('Template', 'टेम्पलेट'),
                icon: Icons.download_outlined,
                fontSize: 10,
                onPressed: _downloadTemplate),
          ]),
          const SizedBox(height: 16),
          InnerBox(
            color: Color.alphaBlend(AppTokens.tint(t.muted, 0.2), t.card),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('Import statement', 'विवरण आयात करें'),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: PanelInput(
                            controller: _bankName,
                            hint: context.tr('Bank name (optional)',
                                'बैंक का नाम (वैकल्पिक)'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: _last4,
                        hint: context.tr(
                            'Account last 4 digits', 'खाते के अंतिम 4 अंक'),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: context.tr('Upload CSV', 'CSV अपलोड करें'),
                      icon: Icons.upload_outlined,
                      dense: true,
                      expand: false,
                      loading: _importing,
                      onPressed: widget.societyId.isEmpty ? null : _pickFile,
                    ),
                  ),
                ]),
          ),
          if (_imports.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(context.tr('Past imports', 'पिछले आयात'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: t.mutedForeground)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final i in _imports)
                _Chip(
                  label:
                      '${fmtIsoDateToDisplay(i.periodFrom)} – ${fmtIsoDateToDisplay(i.periodTo)}${(i.bankName ?? '').isNotEmpty ? ' · ${i.bankName}' : ''}',
                  selected: _selectedId == i.id,
                  solid: true,
                  onTap: () => _select(i.id),
                ),
            ]),
          ],
          if (imp != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text(
                  '${imp.fileName ?? context.tr('Import', 'आयात')} · ${_lines.length} ${context.tr('lines', 'पंक्तियाँ')}',
                  style: AppText.caption(context),
                ),
              ),
              TextButton.icon(
                onPressed: () => _loadDetail(imp.id),
                icon: Icon(Icons.refresh, size: 14, color: t.mutedForeground),
                label: Text(context.tr('Refresh', 'रीफ्रेश'),
                    style: TextStyle(fontSize: 10, color: t.mutedForeground)),
              ),
            ]),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()))
            else
              ..._detail(),
          ],
          if (_imports.isEmpty && !_importing) ...[
            const SizedBox(height: 16),
            Text(
              context.tr(
                  'No bank statements imported yet. Upload a CSV to start reconciling.',
                  'अभी कोई बैंक विवरण आयात नहीं हुआ। मिलान शुरू करने के लिए CSV अपलोड करें।'),
              textAlign: TextAlign.center,
              style: AppText.caption(context),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _detail() {
    final t = context.tokens;
    final hi = context.isHi;
    final statuses = _statusByLine;
    final sugg = _suggestionByLine;
    final summaryMap = Map<String, String>.of(statuses);
    for (final s in _pending) {
      summaryMap.putIfAbsent(s.statementLineId, () => 'suggested');
    }
    final summary = computeReconciliationSummary(
        [for (final l in _lines) (id: l.id, amount: l.amount)], summaryMap);
    final usedKeys = <String>{
      for (final m in _matches)
        if (m.status == 'confirmed' ||
            m.status == 'manual' ||
            m.status == 'suggested') ...[
          if (m.maintenancePaymentId != null)
            'maintenance_payment:${m.maintenancePaymentId}',
          if (m.financeEntryId != null) 'finance_entry:${m.financeEntryId}',
        ],
    };
    int count(bool Function(String) f) =>
        _lines.where((l) => f(_status(l.id, statuses, sugg))).length;
    final chips = <(_LineFilter, String, int)>[
      (_LineFilter.all, context.tr('All', 'सभी'), _lines.length),
      (
        _LineFilter.exceptions,
        context.tr('Exceptions', 'अपवाद'),
        count((s) => s != 'confirmed')
      ),
      (
        _LineFilter.suggested,
        context.tr('Suggested', 'सुझाए गए'),
        count((s) => s == 'suggested')
      ),
      (
        _LineFilter.unmatched,
        context.tr('Unmatched', 'बेमेल'),
        count((s) => s == 'unmatched')
      ),
      (
        _LineFilter.confirmed,
        context.tr('Confirmed', 'पुष्ट'),
        count((s) => s == 'confirmed')
      ),
    ];
    final q = _search.text.trim().toLowerCase();
    final filtered = _lines.where((l) {
      final st = _status(l.id, statuses, sugg);
      if (_filter == _LineFilter.unmatched && st != 'unmatched') return false;
      if (_filter == _LineFilter.suggested && st != 'suggested') return false;
      if (_filter == _LineFilter.confirmed && st != 'confirmed') return false;
      if (_filter == _LineFilter.exceptions && st == 'confirmed') return false;
      if (q.isNotEmpty) {
        final hay =
            '${l.description ?? ''} ${l.reference ?? ''} ${jsNumStr(l.amount)}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    final highCount = _pending
        .where((s) => s.matchConfidence >= highConfidenceThreshold)
        .length;

    return [
      StatGrid(spacing: 8, children: [
        DescriptiveStatCard(
          compact: true,
          title: context.tr('Credits', 'जमा'),
          value: jsInr(summary.statementCredits),
          caption: context.tr('Credits', 'जमा'),
          description: hi
              ? 'विवरण की कुल जमा राशि। मिलान: ${jsInr(summary.matchedCredits)} · बाकी: ${jsInr(summary.unmatchedCredits)}'
              : 'Total credits in the statement. Matched ${jsInr(summary.matchedCredits)} · unmatched ${jsInr(summary.unmatchedCredits)}',
          howCalculated: context.tr(
              'Sum of positive statement amounts; matched = confirmed or manual links.',
              'विवरण की धनात्मक राशियों का योग; मिलान = पुष्ट या मैन्युअल लिंक।'),
        ),
        DescriptiveStatCard(
          compact: true,
          title: context.tr('Debits', 'निकासी'),
          value: jsInr(summary.statementDebits),
          caption: context.tr('Debits', 'निकासी'),
          description: hi
              ? 'विवरण की कुल निकासी। मिलान: ${jsInr(summary.matchedDebits)} · बाकी: ${jsInr(summary.unmatchedDebits)}'
              : 'Total debits in the statement. Matched ${jsInr(summary.matchedDebits)} · unmatched ${jsInr(summary.unmatchedDebits)}',
          howCalculated: context.tr(
              'Sum of negative statement amounts (absolute).',
              'विवरण की ऋणात्मक राशियों का योग (निरपेक्ष)।'),
        ),
        DescriptiveStatCard(
          compact: true,
          title: context.tr('Lines', 'पंक्तियाँ'),
          value: '${summary.lineCount}',
          caption: context.tr('Lines', 'पंक्तियाँ'),
          description: hi
              ? '${summary.matchedCount} पुष्ट · ${summary.suggestedCount} सुझाए गए'
              : '${summary.matchedCount} confirmed · ${summary.suggestedCount} suggested',
        ),
        DescriptiveStatCard(
          compact: true,
          title: context.tr('Exceptions', 'अपवाद'),
          value: '${summary.exceptionCount}',
          caption: context.tr('Exceptions', 'अपवाद'),
          description: context.tr('Unmatched or pending', 'बेमेल या लंबित'),
          valueColor: summary.exceptionCount > 0 ? t.warning : null,
        ),
      ]),
      const SizedBox(height: 4),
      Text(
        hi
            ? 'मिलान जमा ${jsInr(summary.matchedCredits)} · मिलान निकासी ${jsInr(summary.matchedDebits)} · ${summary.matchedCount} पुष्ट · ${summary.suggestedCount} सुझाए गए'
            : 'Matched credits ${jsInr(summary.matchedCredits)} · matched debits ${jsInr(summary.matchedDebits)} · ${summary.matchedCount} confirmed · ${summary.suggestedCount} suggested',
        style: AppText.tiny(context),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SmallButton(
          label: hi
              ? 'उच्च-विश्वास पुष्ट करें ($highCount)'
              : 'Confirm high-confidence ($highCount)',
          icon: Icons.check_circle_outline,
          style: SmallBtnStyle.success,
          busy: _runningMatch,
          onPressed: _pending.isEmpty ? null : _bulkConfirm,
        ),
        SmallButton(
          label: context.tr('Re-run auto-match', 'स्वतः मिलान फिर चलाएँ'),
          icon: Icons.auto_awesome_outlined,
          onPressed: _runningMatch ? null : _rerun,
        ),
        SmallButton(
            label: context.tr('Export exceptions', 'अपवाद निर्यात करें'),
            icon: Icons.file_upload_outlined,
            onPressed: _exportExceptions),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (final c in chips)
          _Chip(
              label: '${c.$2} (${c.$3})',
              selected: _filter == c.$1,
              onTap: () => setState(() => _filter = c.$1)),
      ]),
      const SizedBox(height: 8),
      PanelInput(
        controller: _search,
        hint: context.tr('Search narration…', 'विवरण खोजें…'),
        prefixIcon: Icons.search,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
              context.tr('No lines match this filter.',
                  'इस फ़िल्टर से कोई पंक्ति मेल नहीं खाती।'),
              textAlign: TextAlign.center,
              style: AppText.caption(context)),
        )
      else
        for (final l in filtered) ...[
          _lineCard(l, statuses, sugg, usedKeys),
          const SizedBox(height: 8)
        ],
    ];
  }

  Widget _lineCard(BankLineRow line, Map<String, String> statuses,
      Map<String, SuggestedMatch> sugg, Set<String> usedKeys) {
    final t = context.tokens;
    final hi = context.isHi;
    BankMatchRow? match;
    for (final m in _matches) {
      if (m.statementLineId == line.id) match = m;
    }
    final suggestion = sugg[line.id];
    final isCredit = line.amount > 0;
    final busy = _busyLineId == line.id;
    final isConfirmed = match != null &&
        (match.status == 'confirmed' || match.status == 'manual');
    final isRejected = match?.status == 'rejected';
    final status = _status(line.id, statuses, sugg);
    String? confirmedLabel;
    if (isConfirmed) {
      confirmedLabel = _targetByKey[match.targetKey]?.displayLabel(hi: hi) ??
          suggestion?.target.displayLabel(hi: hi);
    }
    final manualOpen = _manualPickLineId == line.id;
    final candidates = manualOpen
        ? rankCandidatesForLine(line.forMatch, _targets,
            usedTargetKeys: usedKeys)
        : const <SuggestedMatch>[];

    final Color border = isConfirmed
        ? AppTokens.tint(t.success, 0.3)
        : isRejected
            ? t.muted
            : suggestion != null
                ? AppTokens.tint(t.warning, 0.3)
                : t.border;
    final Color bg = isConfirmed
        ? Color.alphaBlend(AppTokens.tint(t.success, 0.05), t.card)
        : isRejected
            ? Color.alphaBlend(AppTokens.tint(t.muted, 0.2), t.card)
            : suggestion != null
                ? Color.alphaBlend(AppTokens.tint(t.warning, 0.05), t.card)
                : t.card;

    final box = InnerBox(
      borderColor: border,
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.payments_outlined,
                              size: 14,
                              color: isCredit ? t.success : t.destructive),
                          Text(
                              '${isCredit ? '+' : '−'}${jsInr(line.amount.abs())}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(fmtIsoDateToDisplay(line.lineDate),
                              style: AppText.caption(context)),
                          if (isConfirmed)
                            TinyChip(
                                match.status == 'manual'
                                    ? context.tr('Manual', 'मैन्युअल')
                                    : context.tr('Confirmed', 'पुष्ट'),
                                tone: Tone.success,
                                pill: false),
                          if (suggestion != null && !isConfirmed && !isRejected)
                            TinyChip(
                                hi
                                    ? '${(suggestion.matchConfidence * 100).round()}% मेल'
                                    : '${(suggestion.matchConfidence * 100).round()}% match',
                                tone: Tone.warning,
                                pill: false),
                          if (status == 'unmatched')
                            TinyChip(context.tr('Unmatched', 'बेमेल'),
                                icon: Icons.warning_amber_rounded, pill: false),
                        ]),
                    const SizedBox(height: 4),
                    Text(
                        (line.description ?? '').isEmpty
                            ? '—'
                            : line.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(context)),
                    if ((line.reference ?? '').isNotEmpty)
                      Text(line.reference!,
                          style: AppText.mono(context,
                              size: 10, color: t.mutedForeground)),
                    if (isConfirmed && confirmedLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('→ $confirmedLabel',
                            style: TextStyle(fontSize: 11, color: t.success)),
                      ),
                    if (suggestion != null && !isConfirmed)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text.rich(TextSpan(
                            style: TextStyle(fontSize: 11, color: t.foreground),
                            children: [
                              TextSpan(
                                  text:
                                      '→ ${suggestion.target.displayLabel(hi: hi)}'),
                              TextSpan(
                                text:
                                    ' (${suggestion.reasons.map((r) => reconReasonLabel(r, hi: hi)).join(', ')})',
                                style: TextStyle(color: t.mutedForeground),
                              ),
                            ])),
                      ),
                  ]),
            ),
            const SizedBox(width: 6),
            if (suggestion != null && !isConfirmed && !isRejected) ...[
              SquareIconButton(
                icon: Icons.check_circle_outline,
                tone: Tone.success,
                busy: busy,
                tooltip: context.tr('Confirm match', 'मिलान पुष्ट करें'),
                onPressed: () => _confirm(suggestion),
              ),
              const SizedBox(width: 4),
              SquareIconButton(
                icon: Icons.cancel_outlined,
                tone: Tone.destructive,
                tooltip: context.tr('Reject suggestion', 'सुझाव अस्वीकार करें'),
                onPressed: busy ? null : () => _reject(suggestion),
              ),
              const SizedBox(width: 4),
            ],
            if (!isConfirmed)
              SquareIconButton(
                icon: Icons.link,
                tooltip: context.tr('Link manually', 'मैन्युअल रूप से जोड़ें'),
                onPressed: () => setState(
                    () => _manualPickLineId = manualOpen ? null : line.id),
              ),
          ]),
          if (manualOpen) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: t.border),
            const SizedBox(height: 12),
            Text(
                context.tr('Pick a ledger record (same amount, bank channel)',
                    'एक लेजर रिकॉर्ड चुनें (समान राशि, बैंक माध्यम)'),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: t.mutedForeground)),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              Text(
                  context.tr('No matching candidates in this period.',
                      'इस अवधि में कोई मेल खाता विकल्प नहीं।'),
                  style: AppText.tiny(context))
            else
              for (final c in candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: t.border)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: busy ? null : () => _confirm(c, manual: true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(children: [
                          Expanded(
                            child: Text(c.target.displayLabel(hi: hi),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11)),
                          ),
                          Text('${(c.matchConfidence * 100).round()}%',
                              style: TextStyle(
                                  fontSize: 10, color: t.mutedForeground)),
                        ]),
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
    return isRejected ? Opacity(opacity: 0.6, child: box) : box;
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.solid = false});

  final String label;
  final bool selected;
  final bool solid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = selected
        ? (solid ? t.primary : AppTokens.tint(t.primary, 0.15))
        : Colors.transparent;
    final fg = selected
        ? (solid ? t.primaryForeground : t.primary)
        : t.mutedForeground;
    return Material(
      color: bg,
      shape: StadiumBorder(
          side: BorderSide(color: selected ? t.primary : t.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
        ),
      ),
    );
  }
}
