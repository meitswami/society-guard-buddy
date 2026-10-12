// Form / filter state owned by the module so it survives sub-tab switches (web keeps it in
// FinanceManager state).

import 'package:flutter/widgets.dart';

import '../logic/finance_dates.dart';
import '../logic/record_receipt_plan.dart';
import '../logic/transactions_view.dart';

/// Web `MaintenanceChargeFormState` + show/edit flags.
class ChargeFormModel extends ChangeNotifier {
  final title = TextEditingController();
  final amount = TextEditingController();
  final newSubHead = TextEditingController();
  String frequency = 'monthly';
  String majorHead = '';
  String expenseGroupId = '';
  bool showForm = false;
  String? editingId;

  void reset() {
    title.clear();
    amount.clear();
    newSubHead.clear();
    frequency = 'monthly';
    majorHead = '';
    expenseGroupId = '';
  }

  void changed() => notifyListeners();

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    newSubHead.dispose();
    super.dispose();
  }
}

/// Web `PaymentHeadFormState` + show/edit flags.
class PaymentHeadFormModel extends ChangeNotifier {
  final name = TextEditingController();
  final description = TextEditingController();
  String majorHead = '';
  bool showForm = false;
  String? editingId;

  void reset() {
    name.clear();
    description.clear();
    majorHead = '';
  }

  void changed() => notifyListeners();

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }
}

/// Web `payForm` + receipt file + notify audience.
class RecordReceiptFormModel extends ChangeNotifier {
  String recordMode = kModeFlatsOnly;
  String destination = kDestCurrentMonth;
  String allocationStyle = kAllocSamePerFlat;
  bool allocationIncludeVacant = false;
  final outsiderName = TextEditingController();
  final outsiderRelation = TextEditingController();
  final outsiderAmount = TextEditingController();
  final entryTitle = TextEditingController();
  String chargeId = '';
  List<String> selectedFlats = [];
  final amount = TextEditingController();
  String paymentMethod = 'cash';
  final transactionId = TextEditingController();
  final screenshotUrl = TextEditingController();
  final notes = TextEditingController();
  String dueDate = todayRecordingDate();

  /// `none` | `selected_flats` | `all`
  String notifyAudience = 'none';
  String autoSelectedChargeHint = '';
  bool showPaymentForm = false;
  bool uploading = false;
  bool saving = false;

  /// Picked receipt / bill file (image or PDF).
  ({List<int> bytes, String name, String? mime})? file;

  RecordReceiptInput snapshot() => RecordReceiptInput(
        recordMode: recordMode,
        destination: destination,
        allocationStyle: allocationStyle,
        allocationIncludeVacant: allocationIncludeVacant,
        outsiderName: outsiderName.text,
        outsiderRelation: outsiderRelation.text,
        outsiderAmount: outsiderAmount.text,
        entryTitle: entryTitle.text,
        chargeId: chargeId,
        selectedFlats: List.of(selectedFlats),
        amount: amount.text,
        paymentMethod: paymentMethod,
        transactionId: transactionId.text,
        notes: notes.text,
        dueDate: dueDate,
      );

  void reset() {
    recordMode = kModeFlatsOnly;
    destination = kDestCurrentMonth;
    allocationStyle = kAllocSamePerFlat;
    allocationIncludeVacant = false;
    for (final c in [
      outsiderName,
      outsiderRelation,
      outsiderAmount,
      entryTitle,
      amount,
      transactionId,
      screenshotUrl,
      notes
    ]) {
      c.clear();
    }
    chargeId = '';
    selectedFlats = [];
    paymentMethod = 'cash';
    dueDate = todayRecordingDate();
    autoSelectedChargeHint = '';
    notifyAudience = 'none';
    file = null;
  }

  void changed() => notifyListeners();

  @override
  void dispose() {
    for (final c in [
      outsiderName,
      outsiderRelation,
      outsiderAmount,
      entryTitle,
      amount,
      transactionId,
      screenshotUrl,
      notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Transactions tab filters + selection.
class TransactionsFilterModel extends ChangeNotifier {
  final search = TextEditingController();
  String filterStatus = 'all';
  String paymentTypeFilter = 'all';
  String paymentMonthFilter = 'all';
  String receiptModeFilter = 'all';
  final Set<String> selectedKeys = {};
  String? distributingEntryId;

  TransactionsQuery query({required bool includeVacant}) => TransactionsQuery(
        filterStatus: filterStatus,
        paymentTypeFilter: paymentTypeFilter,
        paymentMonthFilter: paymentMonthFilter,
        receiptModeFilter: receiptModeFilter,
        search: search.text,
        includeVacantFlats: includeVacant,
      );

  void changed() => notifyListeners();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}
