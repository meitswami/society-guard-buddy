import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_models.dart';
import '../data/events_notify.dart';
import '../data/events_storage.dart';
import '../data/expense_repository.dart';
import '../data/query_helpers.dart';
import '../logic/expense_balances.dart';
import '../logic/expense_heads.dart';
import '../logic/finance_dates.dart';
import '../logic/flat_options.dart';
import '../logic/js_compat.dart';
import '../logic/split_math.dart';
import '../widgets/ev_fields.dart';
import '../widgets/ev_i18n.dart';
import '../widgets/ev_ui.dart';
import '../widgets/flat_multi_select.dart';
import 'expense_edit_sheets.dart';

/// Port of `src/components/ExpenseSplitter.tsx` (food / payment / general modes).
class ExpenseSplitterView extends StatefulWidget {
  const ExpenseSplitterView({
    super.key,
    required this.societyId,
    required this.adminName,
    this.mode = SplitterMode.general,
    this.embedded = false,
    this.onOpenFinance,
    this.onRecordsChanged,
    this.hub,
    this.query = '',
    this.initialHeadQuery,
  });

  final String societyId;
  final String adminName;
  final SplitterMode mode;
  final bool embedded;
  final VoidCallback? onOpenFinance;
  final VoidCallback? onRecordsChanged;
  final EvReloadHub? hub;

  /// Client-side filter for food / general groups (admin global search).
  final String query;

  /// Pre-filled "Search expense heads" text (payment mode).
  final String? initialHeadQuery;

  @override
  State<ExpenseSplitterView> createState() => _ExpenseSplitterViewState();
}

enum _Funding { residents, societyFund }

class _ExpenseSplitterViewState extends State<ExpenseSplitterView> {
  static const _repo = ExpenseRepository();

  SplitterData _data = SplitterData.empty;
  MemberIndex _members = MemberIndex(const []);
  bool _loading = true;
  Object? _error;

  bool get _food => widget.mode == SplitterMode.food;
  bool get _payment => widget.mode == SplitterMode.payment;

  bool _includeVacant = false;
  late _Funding _funding = _payment ? _Funding.societyFund : _Funding.residents;
  String _splitMode = 'by_headcount';
  List<String> _splitFlats = const [];
  List<String> _paidByFlats = const [];
  Map<String, String> _customSplits = {};
  bool _showGroupForm = false;
  String? _showExpenseForm;

  int _gfV = 0;
  String _gfName = '';
  String _gfDescription = '';
  String _gfEventId = '';
  String _gfMajorHead = '';
  String _gfAdult = '1';
  String _gfChild = '0.5';
  late String _headQuery = widget.initialHeadQuery?.trim() ?? '';

  int _efV = 0;
  String _efTitle = '';
  String _efTotal = '';
  String _efVendor = '';
  String _efServiceKind = 'one_time';
  String _efDate = todayRecordingDate();
  String _efMethod = 'cash';
  String _efNotes = '';
  PickedAttachment? _bill;
  bool _billUploading = false;
  bool _saving = false;
  NotifyAudience _notify = NotifyAudience.none;

  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    widget.hub?.register(this, _loadAll);
    _loadAll();
  }

  @override
  void dispose() {
    widget.hub?.unregister(this);
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final d = await _repo.loadSplitter(widget.societyId, widget.mode);
      if (!mounted) return;
      setState(() {
        _data = d;
        _members = MemberIndex(d.flats.members);
        _loading = false;
        _error = null;
        _selected.removeWhere((id) => !d.expenses.any((e) => e.id == id));
      });
    } catch (e) {
      if (!mounted) return;
      if (_loading) {
        setState(() {
          _loading = false;
          _error = e;
        });
      } else {
        AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  void _changed() => widget.onRecordsChanged?.call();

  List<FlatLite> get _flats => _data.flats.flats;
  List<FlatLite> get _activeFlats => _includeVacant ? _flats : _flats.where((f) => f.isOccupied == true).toList();
  List<ExpenseGroup> get _groups => _data.groups;
  List<ExpenseRow> get _expenses => _data.expenses;
  List<({String id, String flatNumber})> get _ledgerFlats => [for (final f in _flats) (id: f.id, flatNumber: f.flatNumber)];

  String _ledgerCategory() => _food ? 'food' : 'payment';
  String _counterpartyPrefix() => _food ? 'Event food' : (_payment ? 'Society payment' : 'Event expense');

  ExpenseGroup? _group(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  String? _eventTitleForGroup(String groupId) {
    final g = _group(groupId);
    if (g?.eventId == null) return null;
    for (final ev in _data.events) {
      if (ev.id == g!.eventId) return ev.title;
    }
    return null;
  }

  FlatLite? _activeFlat(String fn) {
    for (final f in _activeFlats) {
      if (f.flatNumber == fn) return f;
    }
    return null;
  }

  List<String> _targetFlatNumbers() {
    final eligible = [for (final f in _activeFlats) f.flatNumber];
    final eligibleSet = eligible.toSet();
    final chosen = _splitFlats.isNotEmpty ? _splitFlats : eligible;
    final out = <String>[];
    for (final n in chosen) {
      if (eligibleSet.contains(n) && !out.contains(n)) out.add(n);
    }
    return out;
  }

  ({double adult, double child}) _groupWeights(String groupId) {
    final g = _group(groupId);
    final a = g?.adultWeight ?? 1;
    final c = g?.childWeight ?? 0.5;
    return (adult: a == 0 || a.isNaN ? 1 : a, child: c == 0 || c.isNaN ? 0.5 : c);
  }

  ({List<FlatHeadcount> rows, List<HeadcountAmount> amounts, double adult, double child}) _headcountPreview(String groupId) {
    final targets = _targetFlatNumbers();
    final w = _groupWeights(groupId);
    final rows = [for (final n in targets) _members.headcount(n, _activeFlat(n)?.id, w.adult, w.child)];
    final total = jsNumberOr(_efTotal, 0);
    final amounts = total > 0 ? computeHeadcountAmounts(total, rows) : const <HeadcountAmount>[];
    return (rows: rows, amounts: amounts, adult: w.adult, child: w.child);
  }

  void _resetExpenseForm() {
    _efTitle = '';
    _efTotal = '';
    _efVendor = '';
    _efServiceKind = 'one_time';
    _efDate = todayRecordingDate();
    _efMethod = 'cash';
    _efNotes = '';
    _bill = null;
    _splitMode = _payment ? 'even' : 'by_headcount';
    _splitFlats = const [];
    _paidByFlats = const [];
    _customSplits = {};
    _funding = _payment ? _Funding.societyFund : _Funding.residents;
    _notify = NotifyAudience.none;
    _showExpenseForm = null;
    _efV++;
  }

  void _toast(String msg, [BadgeTone tone = BadgeTone.alert]) => AppFeedback.toast(context, msg, tone: tone);

  // ------------------------------------------------------------------ groups

  Future<void> _addGroup() async {
    if (widget.societyId.isEmpty) {
      _toast(context.ev('spl.selectSociety'));
      return;
    }
    if (_gfName.isEmpty) return;
    if (_food && _gfEventId.isEmpty) {
      _toast(context.ev('spl.linkEventRequired'));
      return;
    }
    if (_payment && _gfMajorHead.isEmpty) {
      _toast(context.ev('spl.majorHeadRequired'));
      return;
    }
    try {
      await _repo.insertGroup({
        'name': _gfName.trim(),
        'description': _gfDescription.trim().isEmpty ? null : _gfDescription.trim(),
        'created_by': widget.adminName,
        'society_id': widget.societyId,
        'event_id': _payment ? null : (_gfEventId.isEmpty ? null : _gfEventId),
        'group_kind': _food ? 'event' : (_payment ? 'general' : 'event'),
        'major_head': _payment ? _gfMajorHead : null,
        'adult_weight': jsNumberOr(_gfAdult, 1),
        'child_weight': jsNumberOr(_gfChild, 0.5),
      });
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      return;
    }
    if (!mounted) return;
    setState(() {
      _gfName = '';
      _gfDescription = '';
      _gfEventId = '';
      _gfMajorHead = '';
      _gfAdult = '1';
      _gfChild = '0.5';
      _gfV++;
      _showGroupForm = false;
    });
    _toast(context.ev('spl.groupCreated'), BadgeTone.success);
    _loadAll();
  }

  Future<void> _deleteGroup(String groupId) async {
    final count = _expenses.where((e) => e.groupId == groupId).length;
    if (count > 0) {
      _toast(context.ev('spl.groupInUse'));
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: context.ev('spl.deleteGroupTitle'),
      message: context.ev('evc.cannotUndo'),
      confirmLabel: context.ev('spl.deleteGroup'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.deleteGroup(groupId, widget.societyId);
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      return;
    }
    if (!mounted) return;
    _toast(context.ev('spl.groupDeleted'), BadgeTone.success);
    _loadAll();
  }

  Future<void> _editGroup(ExpenseGroup g) async {
    final saved = await GroupEditSheet.show(
      context,
      group: g,
      societyId: widget.societyId,
      payment: _payment,
      events: _data.events,
    );
    if (saved == true && mounted) _loadAll();
  }

  // ---------------------------------------------------------------- expenses

  Future<void> _addExpense(String groupId) async {
    if (_efTitle.trim().isEmpty || _efTotal.isEmpty) {
      _toast(context.ev('spl.titleTotalRequired'));
      return;
    }
    final recordingDate = todayRecordingDate();
    final billingDate = _efDate.length > 10 ? _efDate.substring(0, 10) : _efDate;
    final entryMonth = billingMonthFromDate(billingDate);
    if (!isBillingDateInEntryMonth(billingDate, entryMonth)) {
      _toast(context.ev('spl.billingMonth'));
      return;
    }
    final total = jsNumber(_efTotal);
    if (!jsPositive(total)) {
      _toast(context.ev('spl.validTotal'));
      return;
    }
    setState(() => _saving = true);
    try {
      await _addExpenseInner(groupId, total, billingDate, recordingDate);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addExpenseInner(String groupId, double total, String billingDate, String recordingDate) async {
    final title = _efTitle.trim();
    try {
      final dup = await _repo.duplicateExists(groupId: groupId, title: title, total: total, expenseDate: _efDate);
      if (dup) {
        if (!mounted) return;
        final ok = await AppFeedback.confirm(
          context,
          title: context.ev('spl.dupTitle'),
          message: context.ev('spl.dupText', {'amt': jsNumStr(total)}),
          confirmLabel: context.ev('spl.recordAnyway'),
          cancelLabel: context.t('common.cancel'),
        );
        if (!ok) return;
      }
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      return;
    }
    if (!mounted) return;

    // Validate the split before uploading the bill (the web uploads first; same messages).
    final paidBy = [..._paidByFlats];
    final targets = _targetFlatNumbers();
    List<Map<String, dynamic>> splitRows = const [];
    if (_funding == _Funding.residents) {
      if (paidBy.isEmpty) {
        _toast(context.ev('spl.paidByRequired'));
        return;
      }
      if (targets.isEmpty) {
        _toast(context.ev('spl.targetsRequired'));
        return;
      }
      final nowIso = DateTime.now().toUtc().toIso8601String();
      Map<String, dynamic> row(String fn, double amount) {
        final flat = _activeFlat(fn);
        final settled = paidBy.contains(fn);
        return {
          'expense_id': '',
          'flat_number': fn,
          'amount': amount,
          'is_settled': settled,
          'settled_at': settled ? nowIso : null,
          'resident_name': residentLabelForFlatRow(flat?.id, flat?.ownerName, _data.flats.primaryByFlatId),
        };
      }

      if (_splitMode == 'even') {
        splitRows = [for (final s in computeEqualSplitAmounts(total, targets)) row(s.flatNumber, s.amount)];
      } else if (_splitMode == 'by_headcount') {
        final w = _groupWeights(groupId);
        final headRows = [for (final n in targets) _members.headcount(n, _activeFlat(n)?.id, w.adult, w.child)];
        final unitSum = headRows.fold<double>(0, (s, r) => s + r.units);
        if (unitSum <= 0) {
          _toast(context.ev('evm.err.noHeadcountUnits'));
          return;
        }
        splitRows = [for (final a in computeHeadcountAmounts(total, headRows)) row(a.flatNumber, a.amount)];
      } else {
        final entries = [
          for (final n in targets)
            if (jsPositive(jsNumber(_customSplits[n] ?? ''))) MapEntry(n, _customSplits[n]!),
        ];
        if (entries.isEmpty) {
          _toast(context.ev('spl.customRequired'));
          return;
        }
        final customTotal = round2(entries.fold<double>(0, (s, e) => s + jsNumber(e.value)));
        if ((customTotal - total).abs() > 0.01) {
          _toast(context.ev('spl.customMismatch', {'sum': customTotal.toStringAsFixed(2), 'total': total.toStringAsFixed(2)}));
          return;
        }
        splitRows = [for (final e in entries) row(e.key, round2(jsNumber(e.value)))];
      }
    }

    String? billUrl;
    final file = _bill;
    if (file != null) {
      if (!file.isImage && !file.isAudio && !file.isPdf) {
        _toast(context.ev('spl.billType'));
        return;
      }
      if (file.size > EventsStorage.maxBytes) {
        _toast(context.ev('spl.billSize'));
        return;
      }
      setState(() => _billUploading = true);
      try {
        billUrl = await EventsStorage.uploadExpenseBill(groupId, file);
      } catch (e) {
        if (mounted) {
          setState(() => _billUploading = false);
          _toast(supabaseErrorMessage(e));
        }
        return;
      }
      if (!mounted) return;
      setState(() => _billUploading = false);
    }

    final groupName = _group(groupId)?.name ?? 'Expense group';
    final vendor = _efVendor.trim().isEmpty ? null : _efVendor.trim();
    final notes = _efNotes.trim().isEmpty ? null : _efNotes.trim();
    final snapKind = _efServiceKind;
    final snapPm = _efMethod;
    final snapDate = _efDate;
    final notifyAudience = _notify;
    final allFlatNums = [for (final f in _flats) f.flatNumber];

    if (_funding == _Funding.societyFund) {
      String expenseId;
      try {
        expenseId = await _repo.insertExpense({
          'group_id': groupId,
          'title': title,
          'total_amount': total,
          'paid_by_flat': 'SOCIETY',
          'paid_by_flats': <String>[],
          'paid_by_name': widget.adminName,
          'split_type': 'society_fund',
          'payment_method': _efMethod,
          'bill_screenshot_url': billUrl,
          'service_kind': _efServiceKind,
          'vendor_or_service': vendor,
          'expense_date': billingDate,
          'recording_date': recordingDate,
          'notes': notes,
          'record_status': 'active',
          'expense_category': _food ? 'food' : 'payment',
        });
      } catch (e) {
        if (mounted) _toast(supabaseErrorMessage(e).isEmpty ? context.ev('spl.saveFailed') : supabaseErrorMessage(e));
        return;
      }
      if (!_food) {
        final err = await _repo.insertFinanceLedgerForGroupExpense(
          societyId: widget.societyId,
          adminName: widget.adminName,
          groupName: groupName,
          expenseId: expenseId,
          title: title,
          total: total,
          expenseDate: billingDate,
          paymentMethod: _efMethod,
          screenshotUrl: billUrl,
          notes: notes,
          vendorOrService: vendor,
          allocationSplits: [LedgerAllocation('SOCIETY', total)],
          flats: _ledgerFlats,
          counterpartyName: '${_counterpartyPrefix()}: $groupName',
          counterpartyRelation: 'Society fund (no per-flat split)',
          expenseCategory: _ledgerCategory(),
          eventTitle: _eventTitleForGroup(groupId),
        );
        if (err != null) {
          if (mounted) _toast(err);
          try {
            await _repo.deleteExpense(expenseId);
          } catch (_) {}
          return;
        }
      }
      if (!mounted) return;
      setState(_resetExpenseForm);
      var suffix = '';
      if (notifyAudience == NotifyAudience.all && widget.societyId.isNotEmpty) {
        final lines = [
          '${widget.adminName} recorded a society / corpus expense in “$groupName”.',
          '“$title” — ₹${jsLocaleIn(total)} ($snapPm, $snapKind). No per-flat split.',
          if (vendor != null) 'Vendor / service: $vendor.',
          if (snapDate.isNotEmpty) 'Expense date: $snapDate.',
          if (notes != null) notes,
          'Shared with all ${allFlatNums.length} society flat(s).',
          if (billUrl != null) 'A receipt image may be attached when available.',
        ];
        final ok = await EventsNotify.notifyResidentsOfRecord(
          societyId: widget.societyId,
          adminName: widget.adminName,
          audience: NotifyAudience.all,
          selectedFlatNumbers: const [],
          title: 'Society expense: $title',
          message: lines.join(' '),
          notificationType: 'society_expense',
          billUrl: billUrl,
        );
        if (!mounted) return;
        if (ok) {
          suffix = ' · ${context.ev('spl.residentsNotified')}';
        } else {
          _toast(context.ev('spl.notifyFailed'));
        }
      }
      if (!mounted) return;
      _toast('${context.ev('spl.societyRecorded')}$suffix', BadgeTone.success);
      _loadAll();
      _changed();
      return;
    }

    final splitType = splitTypeFor(splitMode: _splitMode, hasSplitFlats: _splitFlats.isNotEmpty);
    String expenseId;
    try {
      expenseId = await _repo.insertExpense({
        'group_id': groupId,
        'title': title,
        'total_amount': total,
        'paid_by_flat': paidBy.first,
        'paid_by_flats': paidBy,
        'paid_by_name': widget.adminName,
        'split_type': splitType,
        'payment_method': _efMethod,
        'bill_screenshot_url': billUrl,
        'service_kind': _efServiceKind,
        'vendor_or_service': vendor,
        'expense_date': billingDate,
        'recording_date': recordingDate,
        'notes': notes,
        'record_status': 'active',
        'expense_category': _food ? 'food' : 'payment',
      });
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      return;
    }
    final rows = [
      for (final r in splitRows) {...r, 'expense_id': expenseId}
    ];
    try {
      await _repo.insertSplits(rows);
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      try {
        await _repo.deleteExpense(expenseId);
      } catch (_) {}
      return;
    }
    if (!_food) {
      final err = await _repo.insertFinanceLedgerForGroupExpense(
        societyId: widget.societyId,
        adminName: widget.adminName,
        groupName: groupName,
        expenseId: expenseId,
        title: title,
        total: total,
        expenseDate: _efDate,
        paymentMethod: _efMethod,
        screenshotUrl: billUrl,
        notes: notes,
        vendorOrService: vendor,
        allocationSplits: [for (final r in rows) LedgerAllocation(r['flat_number'] as String, r['amount'] as double)],
        flats: _ledgerFlats,
        counterpartyName: '${_counterpartyPrefix()}: $groupName',
        counterpartyRelation: 'Advanced by flat(s): ${paidBy.join(', ')}',
        expenseCategory: _ledgerCategory(),
        eventTitle: _eventTitleForGroup(groupId),
      );
      if (err != null) {
        if (mounted) _toast(err);
        try {
          await _repo.deleteSplitsOf(expenseId);
          await _repo.deleteExpense(expenseId);
        } catch (_) {}
        return;
      }
    }
    if (!mounted) return;
    final notifyFlats = <String>[];
    for (final f in [...targets, ...paidBy]) {
      if (!notifyFlats.contains(f)) notifyFlats.add(f);
    }
    final mode = _splitMode;
    setState(_resetExpenseForm);

    var suffix = '';
    if (notifyAudience != NotifyAudience.none && widget.societyId.isNotEmpty) {
      final methodLabel = snapPm.replaceAll('_', ' ');
      final lines = [
        '${widget.adminName} added an expense in “$groupName”.',
        '“$title” — total ₹${jsLocaleIn(total)} ($methodLabel, $snapKind).',
        'Split across: ${targets.join(', ')}.',
        'Paid by (advanced): ${paidBy.join(', ')}.',
        if (vendor != null) 'Vendor / service: $vendor.',
        if (snapDate.isNotEmpty) 'Expense date: $snapDate.',
        if (notes != null) notes,
        if (notifyAudience == NotifyAudience.all) 'This update was shared with all ${allFlatNums.length} society flat(s).',
        if (billUrl != null) 'Open the notification to view the attached receipt image (when available).',
      ];
      final ok = await EventsNotify.notifyResidentsOfRecord(
        societyId: widget.societyId,
        adminName: widget.adminName,
        audience: notifyAudience,
        selectedFlatNumbers: notifyFlats,
        title: 'Expense recorded: $title',
        message: lines.join(' '),
        notificationType: 'society_expense',
        billUrl: billUrl,
      );
      if (!mounted) return;
      if (ok) {
        suffix = ' · ${context.ev('spl.residentsNotified')}';
      } else {
        _toast(context.ev('spl.notifyFailed'));
      }
    }
    if (!mounted) return;
    final msg = mode == 'custom'
        ? context.ev('spl.addedCustom')
        : mode == 'by_headcount'
            ? context.ev('spl.addedHeadcount')
            : context.ev('spl.addedEqual');
    _toast('$msg$suffix', BadgeTone.success);
    _loadAll();
    _changed();
  }

  Future<void> _settle(String splitId) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.ev('spl.settleTitle'),
      message: context.ev('spl.settleText'),
      confirmLabel: context.ev('spl.settleYes'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    try {
      await _repo.settleSplit(splitId);
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      return;
    }
    if (!mounted) return;
    AppFeedback.success(context, title: context.ev('spl.settled'), message: context.ev('spl.settledText'));
    _loadAll();
  }

  Future<void> _deleteExpense(String id) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.ev('spl.deleteExpTitle'),
      message: context.ev('spl.deleteExpText'),
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.deleteExpense(id);
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      return;
    }
    if (!mounted) return;
    setState(() => _selected.remove(id));
    _toast(context.ev('spl.expenseDeleted'), BadgeTone.success);
    _loadAll();
  }

  Future<void> _updateRecordStatus(String id, String status) async {
    try {
      await _repo.updateExpense(id, {'record_status': status});
    } catch (e) {
      if (mounted) _toast(supabaseErrorMessage(e));
      return;
    }
    if (!mounted) return;
    _toast(context.ev('spl.statusUpdated'), BadgeTone.success);
    _loadAll();
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final ok = await AppFeedback.confirm(
      context,
      title: context.ev('spl.bulkDeleteTitle', {'n': _selected.length}),
      message: context.ev('spl.bulkDeleteText'),
      confirmLabel: context.ev('spl.deleteAll'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    for (final id in [..._selected]) {
      try {
        await _repo.deleteExpense(id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(_selected.clear);
    _toast(context.ev('spl.selectedDeleted'), BadgeTone.success);
    _loadAll();
  }

  Future<void> _bulkStatus(String status) async {
    if (_selected.isEmpty) return;
    final ok = await AppFeedback.confirm(
      context,
      title: context.ev('spl.bulkStatusTitle', {'n': _selected.length, 'status': context.ev('spl.rs.$status')}),
      confirmLabel: context.ev('spl.apply'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    for (final id in [..._selected]) {
      try {
        await _repo.updateExpense(id, {'record_status': status});
      } catch (_) {}
    }
    if (!mounted) return;
    setState(_selected.clear);
    _toast(context.ev('spl.statusUpdated'), BadgeTone.success);
    _loadAll();
  }

  Future<void> _openExpenseEdit(ExpenseRow exp) async {
    final saved = await ExpenseEditSheet.show(
      context,
      expense: exp,
      splits: [
        for (final s in _data.splits)
          if (s.expenseId == exp.id) s
      ],
      societyId: widget.societyId,
      adminName: widget.adminName,
      groupName: _group(exp.groupId ?? '')?.name ?? 'Expense group',
      food: _food,
      counterpartyPrefix: _counterpartyPrefix(),
      eventTitle: _eventTitleForGroup(exp.groupId ?? ''),
      flats: _ledgerFlats,
    );
    if (saved == true && mounted) {
      _loadAll();
      _changed();
    }
  }

  // ---------------------------------------------------------------------- UI

  bool _groupMatchesQuery(ExpenseGroup g) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (g.name.toLowerCase().contains(q) || (g.description ?? '').toLowerCase().contains(q)) return true;
    if ((_eventTitleForGroup(g.id) ?? '').toLowerCase().contains(q)) return true;
    return _expenses
        .any((e) => e.groupId == g.id && (e.title.toLowerCase().contains(q) || (e.vendorOrService ?? '').toLowerCase().contains(q)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (widget.societyId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: EvHint(context.ev('spl.noSociety'), size: 14, align: TextAlign.center),
      );
    }
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(
        message: supabaseErrorMessage(_error!),
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _loadAll();
        },
      );
    }

    final balances = computeFlatBalances(
      flatNumbers: [for (final f in _flats) f.flatNumber],
      expenses: _expenses,
      splits: _data.splits,
    );
    final nonZero = nonZeroBalances(balances);
    final flatOptions = flatOptionsWithPrimaryLabel(_flats, _data.flats.primaryByFlatId);

    final filteredPaymentGroups = _payment
        ? [
            for (final g in _groups)
              if (groupMatchesPaymentHeadSearch(name: g.name, description: g.description, majorHead: g.majorHead, query: _headQuery)) g,
          ]
        : _groups;
    final grouped = paymentGroupsByMajorHead<ExpenseGroup>(filteredPaymentGroups, nameOf: (g) => g.name, majorHeadOf: (g) => g.majorHead);
    final listItems = <Object>[]; // String = major head heading, ExpenseGroup = card
    if (!_payment) {
      listItems.addAll(_groups.where(_groupMatchesQuery));
    } else {
      for (final major in kSocietyPaymentMajorHeads) {
        final section = grouped[major] ?? const <ExpenseGroup>[];
        if (section.isEmpty) continue;
        listItems.add(major);
        listItems.addAll(section);
      }
    }

    final showStats = !(_payment && widget.embedded);
    return EvColumn(
      spacing: 12,
      children: [
        if (showStats) const RecordingDateBanner(),
        if (!widget.embedded)
          PageHeader(
            icon: Icons.call_split,
            title: context.ev(_food ? 'spl.title.food' : (_payment ? 'spl.title.payment' : 'spl.title.general')),
            subtitle: context.ev(_food ? 'spl.sub.food' : (_payment ? 'spl.sub.payment' : 'spl.sub.general')),
            bottomSpacing: 0,
          ),
        if (_food && widget.onOpenFinance != null) EvRichHint(context.ev('spl.nonFoodHint'), size: 10, onLinkTap: widget.onOpenFinance),
        if (showStats) ...[
          Row(
            children: [
              Expanded(
                child: DescriptiveStatCard(
                  compact: true,
                  title: context.ev('met.eligible.title'),
                  description: context.ev('met.eligible.desc'),
                  howCalculated: context.ev('met.eligible.how'),
                  value: '${_includeVacant ? _flats.length : _activeFlats.length}',
                  caption: _includeVacant
                      ? context.ev('spl.allFlats', {'n': _flats.length})
                      : context.ev('spl.occupiedFlats', {'n': _activeFlats.length}),
                ),
              ),
              const SizedBox(width: 8),
              EvOutlineButton(
                label: _includeVacant ? context.ev('evc.vacantOn') : context.ev('evc.vacantOff'),
                onTap: () => setState(() => _includeVacant = !_includeVacant),
              ),
            ],
          ),
          CardSection(
            onTap: () => AppFeedback.info(
              context,
              title: context.ev('met.balances.title'),
              description: context.ev('met.balances.desc'),
              howCalculated: context.ev('met.balances.how'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nonZero.isEmpty ? context.ev('spl.allSettled') : context.ev('spl.flatsWithBalance', {'n': nonZero.length}),
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: nonZero.isEmpty ? t.mutedForeground : t.foreground),
                      ),
                    ),
                    Icon(Icons.info_outline, size: 14, color: t.mutedForeground),
                  ],
                ),
                Text(context.ev('met.balances.title'), style: AppText.caption(context)),
                const SizedBox(height: 8),
                for (final e in nonZero)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text('${context.ev('evc.flat')} ${e.key}', style: const TextStyle(fontSize: 14))),
                        Text(
                          e.value > 0 ? '+₹${e.value.toStringAsFixed(2)}' : '-₹${e.value.abs().toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: e.value > 0 ? t.success : t.destructive),
                        ),
                      ],
                    ),
                  ),
                if (nonZero.isEmpty) EvHint('${context.ev('spl.allSettledBang')} 🎉', size: 12),
              ],
            ),
          ),
        ],
        if (_payment)
          AppTextField(
            key: const ValueKey('head-search'),
            hint: context.ev('spl.headSearch'),
            initialValue: _headQuery,
            caps: false,
            prefixIcon: Icons.search,
            onChanged: (v) => setState(() => _headQuery = v),
          ),
        AppButton(
          icon: Icons.add,
          label: context.ev(_food ? 'spl.newGroup.food' : (_payment ? 'spl.newGroup.payment' : 'spl.newGroup.general')),
          onPressed: () => setState(() => _showGroupForm = !_showGroupForm),
        ),
        if (_showGroupForm) _groupForm(context, grouped),
        if (_expenses.isNotEmpty) _bulkBar(context),
        if (_payment && _headQuery.trim().isNotEmpty && filteredPaymentGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: EvHint(context.ev('spl.noHeadMatch', {'q': _headQuery.trim()}), size: 14, align: TextAlign.center),
          ),
        if (!_payment && _groups.isNotEmpty && listItems.isEmpty) EmptyView(message: context.ev('evc.noMatch', {'q': widget.query.trim()})),
        for (final item in listItems)
          if (item is String)
            Container(
              padding: const EdgeInsets.only(bottom: 4, top: 4),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTokens.tint(t.border, 0.6)))),
              child: Text(item, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: t.mutedForeground)),
            )
          else
            _groupCard(context, item as ExpenseGroup, flatOptions),
      ],
    );
  }

  Widget _bulkBar(BuildContext context) {
    final t = context.tokens;
    return CardSection(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EvOutlineButton(
            fontSize: 10,
            label: context.ev('spl.selectAll'),
            onTap: () => setState(() => _selected
              ..clear()
              ..addAll(_expenses.map((e) => e.id))),
          ),
          EvOutlineButton(fontSize: 10, label: context.ev('spl.clearSelection'), onTap: () => setState(_selected.clear)),
          if (_selected.isNotEmpty) ...[
            EvHint(context.ev('spl.nSelected', {'n': _selected.length})),
            EvOutlineButton(fontSize: 10, color: t.destructive, label: context.ev('spl.deleteSelected'), onTap: _bulkDelete),
            PopupMenuButton<String>(
              onSelected: _bulkStatus,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'active', child: Text(context.ev('spl.setActive'))),
                PopupMenuItem(value: 'archived', child: Text(context.ev('spl.setArchived'))),
              ],
              child: IgnorePointer(
                  child: EvOutlineButton(fontSize: 10, icon: Icons.arrow_drop_down, label: context.ev('spl.bulkStatus'), onTap: () {})),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gfField(String id, String hint, String value, ValueChanged<String> onChanged,
      {int maxLines = 1, bool number = false, String? label}) {
    return AppTextField(
      key: ValueKey('gf-$id-$_gfV'),
      label: label,
      hint: hint,
      initialValue: value,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 2 : null,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
      onChanged: onChanged,
    );
  }

  Widget _groupForm(BuildContext context, Map<String, List<ExpenseGroup>> grouped) {
    final subHeads = _gfMajorHead.isEmpty ? const <ExpenseGroup>[] : (grouped[_gfMajorHead] ?? const <ExpenseGroup>[]);
    final t = context.tokens;
    return CardSection(
      child: EvColumn(
        spacing: 12,
        children: [
          if (_payment) ...[
            AppDropdown<String>(
              label: context.ev('spl.majorHead'),
              hint: context.ev('spl.chooseMajor'),
              items: kSocietyPaymentMajorHeads,
              value: _gfMajorHead.isEmpty ? null : _gfMajorHead,
              labelOf: (h) => h,
              onChanged: (v) => setState(() => _gfMajorHead = v ?? ''),
            ),
            if (subHeads.isNotEmpty)
              EvPanel(
                padding: const EdgeInsets.all(10),
                spacing: 6,
                children: [
                  EvTinyLabel(context.ev('spl.existingSubHeads')),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in subHeads)
                        Material(
                          color: t.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: t.border)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => setState(() {
                              _showGroupForm = false;
                              _showExpenseForm = g.id;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: Text(g.name, style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  EvHint(context.ev('spl.subHeadTapHint')),
                ],
              ),
            _gfField('name', context.ev('spl.subHeadHint'), _gfName, (v) => _gfName = v, label: context.ev('spl.newSubHead')),
            EvHint(context.ev('spl.subHeadNote')),
          ] else
            _gfField('name', context.ev(_food ? 'spl.groupName.food' : 'spl.groupName.general'), _gfName, (v) => _gfName = v),
          if (!_payment)
            AppDropdown<String>(
              items: ['', for (final ev in _data.events) ev.id],
              value: _gfEventId,
              labelOf: (id) {
                if (id.isEmpty) return context.ev(_food ? 'spl.selectEventRequired' : 'spl.linkEventOptional');
                final ev = _data.events.firstWhere((e) => e.id == id);
                return '${ev.title} (${ev.eventDate})';
              },
              onChanged: (v) => setState(() => _gfEventId = v ?? ''),
            ),
          _gfField('desc', context.ev('evc.descriptionOptional'), _gfDescription, (v) => _gfDescription = v, maxLines: 3),
          if (!_payment) ...[
            EvTwoCol(
              left: _gfField('aw', '1', _gfAdult, (v) => _gfAdult = v, number: true, label: context.ev('evc.adultWeight')),
              right: _gfField('cw', '0.5', _gfChild, (v) => _gfChild = v, number: true, label: context.ev('evc.childWeight')),
            ),
            EvHint(context.ev('spl.weightsHint')),
          ],
          if (_payment) EvHint(context.ev('spl.paymentGroupHint')),
          AppButton(label: context.ev('spl.createGroup'), onPressed: _addGroup),
        ],
      ),
    );
  }

  Widget _groupCard(BuildContext context, ExpenseGroup g, List<FlatOption> flatOptions) {
    final t = context.tokens;
    final gExpenses = _expenses.where((e) => e.groupId == g.id).toList();
    final linkedTitle = g.eventId == null ? null : (_eventTitleForGroup(g.id) ?? context.ev('spl.calendarEvent'));
    final open = _showExpenseForm == g.id;
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (_payment && (g.majorHead ?? '').isNotEmpty)
                      Text(
                        resolveGroupMajorHead(name: g.name, majorHead: g.majorHead),
                        style: TextStyle(fontSize: 10, letterSpacing: 0.5, color: t.mutedForeground),
                      ),
                    if (linkedTitle != null)
                      Text(context.ev('spl.linkedEvent', {'title': linkedTitle}), style: TextStyle(fontSize: 10, color: t.primary)),
                    if (!_payment)
                      EvHint(context.ev('spl.weights', {'a': jsNumStr(g.adultWeight ?? 1), 'c': jsNumStr(g.childWeight ?? 0.5)})),
                    if ((g.description ?? '').isNotEmpty) Text(g.description!, style: AppText.caption(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.ev('spl.editGroup'),
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 18, color: t.mutedForeground),
                onPressed: () => _editGroup(g),
              ),
              if (gExpenses.isEmpty)
                IconButton(
                  tooltip: context.ev('spl.deleteGroup'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, size: 18, color: t.mutedForeground),
                  onPressed: () => _deleteGroup(g.id),
                )
              else
                Tooltip(
                  message: context.ev('spl.inUseTip'),
                  child: SizedBox(
                      width: 44,
                      child: Text(context.ev('spl.inUse'),
                          textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: t.mutedForeground))),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: EvLink(
              context.ev('spl.addExpense'),
              size: 12,
              icon: Icons.add,
              onTap: () => setState(() {
                if (open) {
                  _resetExpenseForm();
                } else {
                  _showExpenseForm = g.id;
                }
              }),
            ),
          ),
          if (open) ...[
            Divider(height: 16, color: t.border),
            _expenseForm(context, g, flatOptions),
            const SizedBox(height: 12),
          ],
          for (final exp in gExpenses) _expenseTile(context, exp),
        ],
      ),
    );
  }

  Widget _ef(String id, String hint, String value, ValueChanged<String> onChanged, {int maxLines = 1, bool number = false}) {
    return AppTextField(
      key: ValueKey('ef-$id-$_efV'),
      hint: hint,
      initialValue: value,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : null,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
      onChanged: onChanged,
    );
  }

  Widget _expenseForm(BuildContext context, ExpenseGroup g, List<FlatOption> flatOptions) {
    final t = context.tokens;
    final modeKey = _food ? 'food' : (_payment ? 'payment' : 'general');
    final dateField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvDateField(label: context.ev('spl.billingDate'), value: _efDate, onChanged: (v) => setState(() => _efDate = v)),
        const SizedBox(height: 4),
        EvHint(context.ev('spl.usedInReports', {'month': fmtIsoMonthToDisplay(billingMonthFromDate(_efDate))})),
      ],
    );
    final targets = _targetFlatNumbers();
    return EvColumn(
      children: [
        _ef('title', context.ev('spl.expTitle.$modeKey'), _efTitle, (v) => _efTitle = v),
        _ef('vendor', context.ev('spl.vendor.$modeKey'), _efVendor, (v) => _efVendor = v),
        if (!_food && !_payment)
          EvTwoCol(
            left: AppDropdown<String>(
              items: const ['one_time', 'recurring', 'temporary'],
              value: _efServiceKind,
              labelOf: (k) => context.ev('spl.sk.$k'),
              onChanged: (v) => setState(() => _efServiceKind = v ?? 'one_time'),
            ),
            right: dateField,
          )
        else
          dateField,
        AppTextField(
          key: ValueKey('ef-total-$_efV'),
          hint: context.ev('spl.totalAmount'),
          initialValue: _efTotal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => setState(() => _efTotal = v),
        ),
        AppDropdown<String>(
          items: const ['cash', 'upi', 'bank_transfer', 'cheque', 'other'],
          value: _efMethod,
          labelOf: (m) => paymentMethodLabel(context, m),
          onChanged: (v) => setState(() => _efMethod = v ?? 'cash'),
        ),
        _ef('notes', context.ev('spl.internalNotes'), _efNotes, (v) => _efNotes = v, maxLines: 4),
        EvAttachmentField(
          label: context.ev('spl.billOptional'),
          file: _bill,
          kinds: const {AttachKind.image, AttachKind.pdf, AttachKind.audio},
          onChanged: (f) => setState(() => _bill = f),
        ),
        EvPanel(
          spacing: 2,
          children: [
            Text(context.ev('spl.whoPays'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            EvRadioRow(
              label: context.ev('spl.fundResidents'),
              selected: _funding == _Funding.residents,
              onTap: () => setState(() {
                _funding = _Funding.residents;
                _notify = NotifyAudience.none;
              }),
            ),
            EvRadioRow(
              label: context.ev('spl.fundSociety'),
              selected: _funding == _Funding.societyFund,
              onTap: () => setState(() {
                _funding = _Funding.societyFund;
                _notify = NotifyAudience.none;
              }),
            ),
          ],
        ),
        if (_funding == _Funding.residents) ...[
          FlatMultiSelect(
            compact: true,
            flats: flatOptions,
            selected: _paidByFlats,
            onChanged: (v) => setState(() => _paidByFlats = v),
            label: context.ev('spl.paidBy'),
          ),
          FlatMultiSelect(
            compact: true,
            flats: flatOptions,
            selected: _splitFlats,
            onChanged: (nums) => setState(() {
              _splitFlats = nums;
              _customSplits = {
                for (final n in nums)
                  if (_customSplits.containsKey(n)) n: _customSplits[n]!
              };
            }),
            label: context.ev('spl.splitAmong'),
            emptyHint: context.ev('spl.splitAmongHint'),
          ),
          AppDropdown<String>(
            items: const ['by_headcount', 'even', 'custom'],
            value: _splitMode,
            labelOf: (m) => context.ev('spl.mode.$m'),
            onChanged: (m) => setState(() {
              _splitMode = m ?? 'by_headcount';
              if (_splitMode != 'custom') _customSplits = {};
              _efV++;
            }),
          ),
          if (_splitMode == 'by_headcount')
            () {
              final p = _headcountPreview(g.id);
              return Container(
                constraints: const BoxConstraints(maxHeight: 208),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                child: SingleChildScrollView(
                  child: EvColumn(
                    spacing: 6,
                    children: [
                      EvHint(context.ev('spl.headcountHint')),
                      if (p.rows.isEmpty)
                        EvHint(context.ev('evc.selectOrAll'), size: 12)
                      else
                        for (final r in p.rows)
                          () {
                            HeadcountAmount? amt;
                            for (final a in p.amounts) {
                              if (a.flatNumber == r.flatNumber) {
                                amt = a;
                                break;
                              }
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${context.ev('evc.flat')} ${r.flatNumber}: ${peopleText(context, r.adults, r.kids)} '
                                    '(×${jsNumStr(p.adult)}/×${jsNumStr(p.child)})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(amt != null ? rupeeRaw(amt.amount) : '—', style: AppText.mono(context, size: 12)),
                              ],
                            );
                          }(),
                    ],
                  ),
                ),
              );
            }()
          else if (_splitMode == 'even')
            EvHint(
              context.ev('spl.evenPreview', {
                'amt': targets.isNotEmpty && jsNumberOr(_efTotal, 0) != 0
                    ? (jsNumberOr(_efTotal, 0) / targets.length).toStringAsFixed(2)
                    : '…',
                'n': targets.isNotEmpty ? targets.length : _activeFlats.length,
              }),
              size: 11,
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              child: EvColumn(
                children: [
                  EvHint(context.ev('spl.customHint')),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 192),
                    child: SingleChildScrollView(
                      child: EvColumn(
                        spacing: 6,
                        children: [
                          for (final n in (_splitFlats.isNotEmpty ? _splitFlats : [for (final f in _activeFlats) f.flatNumber]))
                            Row(
                              children: [
                                SizedBox(width: 72, child: Text('${context.ev('evc.flat')} $n', style: const TextStyle(fontSize: 12))),
                                Expanded(
                                  child: AppTextField(
                                    key: ValueKey('cs-$n-$_efV'),
                                    hint: '₹',
                                    initialValue: _customSplits[n] ?? '',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (v) => setState(() => _customSplits = {..._customSplits, n: v}),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  EvHint(context.ev('spl.customSum', {
                    'sum': _customSplits.values.fold<double>(0, (s, v) => s + jsNumberOr(v, 0)).toStringAsFixed(2),
                  })),
                ],
              ),
            ),
        ],
        EvPanel(
          padding: const EdgeInsets.all(12),
          spacing: 2,
          children: [
            Text(context.ev('spl.notifyTitle'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            EvHint(context.ev('spl.notifyHint')),
            const SizedBox(height: 4),
            EvRadioRow(
                label: context.ev('spl.notifyNone'),
                selected: _notify == NotifyAudience.none,
                onTap: () => setState(() => _notify = NotifyAudience.none)),
            if (_funding == _Funding.residents)
              EvRadioRow(
                label: context.ev('spl.notifyFlats', {
                  'n': {...targets, ..._paidByFlats}.length
                }),
                selected: _notify == NotifyAudience.selectedFlats,
                onTap: () => setState(() => _notify = NotifyAudience.selectedFlats),
              ),
            EvRadioRow(
              label: context.ev('spl.notifyAll', {'n': _flats.length}),
              selected: _notify == NotifyAudience.all,
              onTap: () => setState(() => _notify = NotifyAudience.all),
            ),
          ],
        ),
        AppButton(
          label: _billUploading
              ? context.ev('evc.uploading')
              : _funding == _Funding.societyFund
                  ? context.ev('spl.btn.society')
                  : _splitMode == 'custom'
                      ? context.ev('spl.btn.custom')
                      : _splitMode == 'by_headcount'
                          ? context.ev('spl.btn.headcount')
                          : context.ev('spl.btn.equal'),
          loading: _billUploading || _saving,
          onPressed: () => _addExpense(g.id),
        ),
      ],
    );
  }

  Widget _expenseTile(BuildContext context, ExpenseRow exp) {
    final t = context.tokens;
    final expSplits = [
      for (final s in _data.splits)
        if (s.expenseId == exp.id) s
    ];
    final creditors = paidByFlatsOf(exp);
    final status = exp.recordStatus ?? 'active';
    final archived = status == 'archived';
    final billLine = [
      serviceKindLabel(context, exp.serviceKind),
      paymentMethodLabel(context, (exp.paymentMethod.isEmpty ? 'cash' : exp.paymentMethod)),
      '${context.ev('spl.bill')}: ${(exp.expenseDate ?? '').isNotEmpty ? fmtIsoDateToDisplay(exp.expenseDate) : ''}'
          '${(exp.recordingDate ?? '').isNotEmpty && exp.recordingDate != exp.expenseDate ? ' · ${context.ev('spl.rec')}: ${fmtIsoDateToDisplay(exp.recordingDate)}' : ''}',
    ].join(' · ');
    return Opacity(
      opacity: archived ? 0.8 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.muted, t.isDark ? 0.5 : 0.6),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: archived ? Border.all(color: t.border) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 24,
                  child: Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: _selected.contains(exp.id),
                    onChanged: (v) => setState(() => v == true ? _selected.add(exp.id) : _selected.remove(exp.id)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exp.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      if ((exp.vendorOrService ?? '').isNotEmpty)
                        Text(exp.vendorOrService!,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: t.mutedForeground)),
                      EvHint(billLine),
                      if (archived) ...[const SizedBox(height: 4), EvPill(context.ev('spl.rs.archived'), fontSize: 9)],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(rupeeRaw(exp.totalAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            EvHint(
              exp.splitType == 'society_fund'
                  ? context.ev('spl.fromSociety')
                  : '${context.ev('spl.paidByLabel')}: ${creditors.map((c) => '${context.ev('evc.flat')} $c').join(', ')}',
            ),
            if ((exp.billScreenshotUrl ?? '').isNotEmpty)
              EvLink(context.ev('spl.viewBill'), onTap: () => openEvUrl(context, exp.billScreenshotUrl!)),
            if (exp.attachmentUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final url in exp.attachmentUrls)
                    EvLink(attachmentFileName(url), icon: Icons.attach_file, onTap: () => openEvUrl(context, url)),
                ],
              ),
            if ((exp.notes ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: EvHint(exp.notes!, italic: true)),
            const SizedBox(height: 6),
            for (final s in expSplits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${context.ev('evc.flat')} ${s.flatNumber}',
                          children: [
                            if ((s.residentName ?? '').isNotEmpty)
                              TextSpan(text: ' · ${s.residentName}', style: TextStyle(color: t.mutedForeground)),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(rupeeRaw(s.amount), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if (s.isSettled)
                      EvPill('✓', color: t.success)
                    else
                      EvMiniChip(label: context.ev('spl.settle'), onTap: () => _settle(s.id)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTokens.tint(t.border, 0.6)))),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EvOutlineButton(
                      fontSize: 10, icon: Icons.edit_outlined, label: context.ev('evc.edit'), onTap: () => _openExpenseEdit(exp)),
                  PopupMenuButton<String>(
                    initialValue: status,
                    onSelected: (v) {
                      if (v != status) _updateRecordStatus(exp.id, v);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'active', child: Text(context.ev('spl.rs.active'))),
                      PopupMenuItem(value: 'archived', child: Text(context.ev('spl.rs.archived'))),
                    ],
                    child: IgnorePointer(
                      child: EvOutlineButton(
                        fontSize: 10,
                        icon: Icons.arrow_drop_down,
                        label: context.ev('spl.rs.$status') == 'spl.rs.$status' ? status : context.ev('spl.rs.$status'),
                        onTap: () {},
                      ),
                    ),
                  ),
                  EvOutlineButton(
                    fontSize: 10,
                    icon: Icons.delete_outline,
                    color: t.destructive,
                    label: context.t('common.delete'),
                    onTap: () => _deleteExpense(exp.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
