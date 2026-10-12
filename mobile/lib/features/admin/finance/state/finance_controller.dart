// Finance module state — web `useFinanceManagerData` + `useFinanceMutations` cache invalidation
// + the FinanceManager-level UI state shared across sub-tabs.

import 'package:flutter/foundation.dart';

import '../data/finance_repository.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_derived.dart';
import '../logic/finance_models.dart';

/// Web `FinanceSubTab`.
enum FinanceSubTab { maintenance, createPayment, payments, recordPayment, receipts, totals }

FinanceSubTab? financeSubTabFromWire(String? v) => switch (v) {
      'maintenance' => FinanceSubTab.maintenance,
      'create_payment' => FinanceSubTab.createPayment,
      'payments' => FinanceSubTab.payments,
      'record_payment' => FinanceSubTab.recordPayment,
      'receipts' => FinanceSubTab.receipts,
      'totals' => FinanceSubTab.totals,
      _ => null,
    };

class FinanceController extends ChangeNotifier {
  FinanceController({required this.repo, required this.societyId, required this.adminName});

  final FinanceRepository repo;
  final String societyId;
  final String adminName;

  FinanceCoreData? _data;
  FinanceDerived? _derived;
  bool loading = false;
  bool fetching = false;
  Object? error;

  FinanceEventReference? eventRef;
  bool eventRefLoading = false;
  Object? eventRefError;

  /// Editable reminder / bill settings (reset from the server on every load, like web).
  FinanceReminderSettings settings = const FinanceReminderSettings();

  /// Bumped after Record receipt so Head fund reconciliation reloads (web `headReconciliationKey`).
  int headReconciliationKey = 0;

  /// Totals tab reporting month (`yyyy-MM`).
  String totalsMonth = ymOf(DateTime.now());

  bool _disposed = false;

  FinanceCoreData get data => _data ?? const FinanceCoreData();
  FinanceDerived get derived => _derived ??= FinanceDerived(data);
  bool get hasData => _data != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_data == null) {
      loading = true;
    } else {
      fetching = true;
    }
    error = null;
    _notify();
    try {
      final d = await repo.fetchCore(societyId, adminName);
      _data = d;
      _derived = null;
      settings = d.settings;
      error = null;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      fetching = false;
      _notify();
    }
  }

  /// Web `invalidateFinanceQueries` — refetch core data (and event reference when loaded).
  Future<void> invalidateAll() async {
    final refresh = <Future<void>>[load()];
    if (eventRef != null) refresh.add(loadEventReference(force: true));
    await Future.wait(refresh);
  }

  Future<void> loadEventReference({bool force = false}) async {
    if (eventRefLoading || (eventRef != null && !force)) return;
    eventRefLoading = true;
    eventRefError = null;
    _notify();
    try {
      eventRef = await repo.fetchEventReference(societyId);
    } catch (e) {
      eventRefError = e;
      eventRef ??= const FinanceEventReference();
    } finally {
      eventRefLoading = false;
      _notify();
    }
  }

  void updateSettings(FinanceReminderSettings s) {
    settings = s;
    _notify();
  }

  void setTotalsMonth(String m) {
    totalsMonth = m;
    _notify();
  }

  void bumpHeadReconciliation() {
    headReconciliationKey++;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
