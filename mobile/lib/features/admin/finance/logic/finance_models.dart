// Finance data models — mirror the rows the web `financeService.ts` loads
// (`maintenance_charges`, `maintenance_payments`, `finance_entries` + embeds, …).

double _d(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _dn(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _i(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

String? _s(Object? v) => v?.toString();

String _str(Object? v, [String fallback = '']) => v == null ? fallback : v.toString();

bool _b(Object? v) => v == true || v?.toString() == 'true';

/// `maintenance_charges` row (web "receipt type").
class FinanceCharge {
  const FinanceCharge({
    required this.id,
    required this.title,
    this.amount = 0,
    this.frequency = 'monthly',
    this.dueDay = 1,
    this.expenseGroupId,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.societyId,
  });

  final String id;
  final String title;
  final double amount;
  final String frequency;
  final int dueDay;
  final String? expenseGroupId;
  final bool isActive;
  final String? createdAt;
  final String? createdBy;
  final String? societyId;

  factory FinanceCharge.fromJson(Map<String, dynamic> j) => FinanceCharge(
        id: _str(j['id']),
        title: _str(j['title']),
        amount: _d(j['amount']),
        frequency: _str(j['frequency']),
        dueDay: j['due_day'] == null ? 1 : _i(j['due_day']),
        expenseGroupId: _s(j['expense_group_id']),
        isActive: j['is_active'] == null ? true : _b(j['is_active']),
        createdAt: _s(j['created_at']),
        createdBy: _s(j['created_by']),
        societyId: _s(j['society_id']),
      );
}

/// `maintenance_payments` row (web "receipt").
class FinancePayment {
  const FinancePayment({
    this.id = '',
    this.chargeId,
    this.flatId,
    this.flatNumber = '',
    this.residentName,
    this.amount = 0,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'pending',
    this.paymentDate,
    this.dueDate,
    this.recordingDate,
    this.transactionId,
    this.screenshotUrl,
    this.notes,
    this.submittedBy,
    this.verifiedBy,
    this.verifiedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.receiptNumber,
    this.financeEntryId,
    this.createdAt = '',
  });

  final String id;
  final String? chargeId;
  final String? flatId;
  final String flatNumber;
  final String? residentName;
  final double amount;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentDate;
  final String? dueDate;
  final String? recordingDate;
  final String? transactionId;
  final String? screenshotUrl;
  final String? notes;
  final String? submittedBy;
  final String? verifiedBy;
  final String? verifiedAt;
  final String? reviewedAt;
  final String? rejectionReason;
  final String? receiptNumber;
  final String? financeEntryId;
  final String createdAt;

  factory FinancePayment.fromJson(Map<String, dynamic> j) => FinancePayment(
        id: _str(j['id']),
        chargeId: _s(j['charge_id']),
        flatId: _s(j['flat_id']),
        flatNumber: _str(j['flat_number']),
        residentName: _s(j['resident_name']),
        amount: _d(j['amount']),
        paymentMethod: _str(j['payment_method']),
        paymentStatus: _str(j['payment_status']),
        paymentDate: _s(j['payment_date']),
        dueDate: _s(j['due_date']),
        recordingDate: _s(j['recording_date']),
        transactionId: _s(j['transaction_id']),
        screenshotUrl: _s(j['screenshot_url']),
        notes: _s(j['notes']),
        submittedBy: _s(j['submitted_by']),
        verifiedBy: _s(j['verified_by']),
        verifiedAt: _s(j['verified_at']),
        reviewedAt: _s(j['reviewed_at']),
        rejectionReason: _s(j['rejection_reason']),
        receiptNumber: _s(j['receipt_number']),
        financeEntryId: _s(j['finance_entry_id']),
        createdAt: _str(j['created_at']),
      );
}

/// `finance_entry_counterparties` embed.
class FinanceCounterparty {
  const FinanceCounterparty({required this.name, this.relationToSociety});

  final String name;
  final String? relationToSociety;

  factory FinanceCounterparty.fromJson(Map<String, dynamic> j) =>
      FinanceCounterparty(name: _str(j['name']), relationToSociety: _s(j['relation_to_society']));
}

/// `finance_entry_allocations` embed.
class FinanceAllocation {
  const FinanceAllocation({required this.flatNumber, this.amount = 0, this.flatId});

  final String flatNumber;
  final double amount;
  final String? flatId;

  factory FinanceAllocation.fromJson(Map<String, dynamic> j) =>
      FinanceAllocation(flatNumber: _str(j['flat_number']), amount: _d(j['amount']), flatId: _s(j['flat_id']));
}

List<Map<String, dynamic>> _embedList(Object? raw) {
  if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (raw is Map) return [Map<String, dynamic>.from(raw)];
  return const [];
}

/// `finance_entries` row with counterparties + allocations (web `FinanceLedgerRow`).
/// `recordMode` / `destination` stay nullable: legacy rows can miss them (web render test).
class FinanceLedgerRow {
  const FinanceLedgerRow({
    this.id = '',
    this.societyId = '',
    this.recordMode,
    this.destination,
    this.allocationStyle = 'none',
    this.includeVacant = false,
    this.entryMonth,
    this.transactionDate,
    this.totalAmount = 0,
    this.aggregateFlatCount = 0,
    this.chargeId,
    this.expenseId,
    this.distributedAt,
    this.title,
    this.notes,
    this.screenshotUrl,
    this.transactionId,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'verified',
    this.createdBy,
    this.createdAt = '',
    this.counterparties = const [],
    this.allocations = const [],
    this.allocationsLoaded = true,
  });

  final String id;
  final String societyId;
  final String? recordMode;
  final String? destination;
  final String allocationStyle;
  final bool includeVacant;
  final String? entryMonth;
  final String? transactionDate;
  final double totalAmount;
  final int aggregateFlatCount;
  final String? chargeId;
  final String? expenseId;
  final String? distributedAt;
  final String? title;
  final String? notes;
  final String? screenshotUrl;
  final String? transactionId;
  final String paymentMethod;
  final String paymentStatus;
  final String? createdBy;
  final String createdAt;
  final List<FinanceCounterparty> counterparties;
  final List<FinanceAllocation> allocations;

  /// False when the row came without the allocations embed (web `null`).
  final bool allocationsLoaded;

  FinanceCounterparty? get counterparty => counterparties.isEmpty ? null : counterparties.first;

  factory FinanceLedgerRow.fromJson(Map<String, dynamic> j) => FinanceLedgerRow(
        id: _str(j['id']),
        societyId: _str(j['society_id']),
        recordMode: _s(j['record_mode']),
        destination: _s(j['destination']),
        allocationStyle: _str(j['allocation_style'], 'none'),
        includeVacant: _b(j['include_vacant']),
        entryMonth: _s(j['entry_month']),
        transactionDate: _s(j['transaction_date']),
        totalAmount: _d(j['total_amount']),
        aggregateFlatCount: _i(j['aggregate_flat_count']),
        chargeId: _s(j['charge_id']),
        expenseId: _s(j['expense_id']),
        distributedAt: _s(j['distributed_at']),
        title: _s(j['title']),
        notes: _s(j['notes']),
        screenshotUrl: _s(j['screenshot_url']),
        transactionId: _s(j['transaction_id']),
        paymentMethod: _str(j['payment_method']),
        paymentStatus: _str(j['payment_status'], 'verified'),
        createdBy: _s(j['created_by']),
        createdAt: _str(j['created_at']),
        counterparties: _embedList(j['finance_entry_counterparties']).map(FinanceCounterparty.fromJson).toList(),
        allocations: _embedList(j['finance_entry_allocations']).map(FinanceAllocation.fromJson).toList(),
        allocationsLoaded: j['finance_entry_allocations'] != null,
      );
}

/// `flats` row used across finance (web `SocietyFlatRow`).
class SocietyFlatRow {
  const SocietyFlatRow({required this.id, required this.flatNumber, this.ownerName, this.isOccupied});

  final String id;
  final String flatNumber;
  final String? ownerName;
  final bool? isOccupied;

  bool get occupied => isOccupied == true;

  factory SocietyFlatRow.fromJson(Map<String, dynamic> j) => SocietyFlatRow(
        id: _str(j['id']),
        flatNumber: _str(j['flat_number']),
        ownerName: _s(j['owner_name']),
        isOccupied: j['is_occupied'] == null ? null : _b(j['is_occupied']),
      );
}

/// `expense_groups` (group_kind = general) — web "payment type" / payment sub-head.
class PaymentExpenseGroup {
  const PaymentExpenseGroup({required this.id, required this.name, this.majorHead, this.description});

  final String id;
  final String name;
  final String? majorHead;
  final String? description;

  factory PaymentExpenseGroup.fromJson(Map<String, dynamic> j) => PaymentExpenseGroup(
        id: _str(j['id']),
        name: _str(j['name']),
        majorHead: _s(j['major_head']),
        description: _s(j['description']),
      );
}

class FinanceResidentUser {
  const FinanceResidentUser({required this.id, required this.name, required this.flatNumber, required this.flatId});

  final String id;
  final String name;
  final String flatNumber;
  final String flatId;

  factory FinanceResidentUser.fromJson(Map<String, dynamic> j) => FinanceResidentUser(
        id: _str(j['id']),
        name: _str(j['name']),
        flatNumber: _str(j['flat_number']),
        flatId: _str(j['flat_id']),
      );
}

/// `reserve_fund_transfers` row.
class ReserveTransfer {
  const ReserveTransfer({
    required this.id,
    required this.entryMonth,
    required this.amount,
    required this.direction,
    this.paymentMethod = 'bank_transfer',
    this.notes,
    this.createdAt = '',
  });

  final String id;
  final String entryMonth;
  final double amount;
  final String direction;
  final String paymentMethod;
  final String? notes;
  final String createdAt;

  factory ReserveTransfer.fromJson(Map<String, dynamic> j) => ReserveTransfer(
        id: _str(j['id']),
        entryMonth: _str(j['entry_month']),
        amount: _d(j['amount']),
        direction: _str(j['direction']),
        paymentMethod: _str(j['payment_method'], 'bank_transfer'),
        notes: _s(j['notes']),
        createdAt: _str(j['created_at']),
      );
}

/// `finance_opening_balance_anchors` row (web `OpeningBalanceAnchorRow`).
class OpeningBalanceAnchor {
  const OpeningBalanceAnchor({
    this.id,
    required this.asOnDate,
    this.cashAmount,
    this.bankAmount,
    this.otherAmount,
    this.notes,
  });

  final String? id;
  final String asOnDate;
  final double? cashAmount;
  final double? bankAmount;
  final double? otherAmount;
  final String? notes;

  factory OpeningBalanceAnchor.fromJson(Map<String, dynamic> j) {
    final d = _str(j['as_on_date']);
    return OpeningBalanceAnchor(
      id: _s(j['id']),
      asOnDate: d.length >= 10 ? d.substring(0, 10) : d,
      cashAmount: _dn(j['cash_amount']),
      bankAmount: _dn(j['bank_amount']),
      otherAmount: _dn(j['other_amount']),
      notes: _s(j['notes']),
    );
  }
}

/// `finance_reminder_settings` (defaults match web `emptyCoreData`).
class FinanceReminderSettings {
  const FinanceReminderSettings({
    this.enabled = true,
    this.schedule = 'once_12pm',
    this.dueDay = 1,
    this.autoIssueEnabled = true,
    this.autoIssueWhatsapp = true,
    this.autoIssueEmail = false,
    this.reminderWhatsapp = false,
    this.reminderEmail = false,
    this.billSoundKey = 'melody',
  });

  final bool enabled;
  final String schedule;
  final int dueDay;
  final bool autoIssueEnabled;
  final bool autoIssueWhatsapp;
  final bool autoIssueEmail;
  final bool reminderWhatsapp;
  final bool reminderEmail;
  final String billSoundKey;

  /// Web `fetchSocietyFinanceCore` normalisation of the settings row.
  factory FinanceReminderSettings.fromRow(Map<String, dynamic>? row) {
    if (row == null) return const FinanceReminderSettings();
    final due = _i(row['due_day']);
    final sound = row['bill_sound_key']?.toString() ?? '';
    return FinanceReminderSettings(
      enabled: row['enabled'] == true,
      schedule: row['schedule'] == 'twice_12pm_7pm' ? 'twice_12pm_7pm' : 'once_12pm',
      dueDay: (due == 0 ? 1 : due).clamp(1, 28),
      autoIssueEnabled: row['auto_issue_enabled'] is bool ? row['auto_issue_enabled'] as bool : true,
      autoIssueWhatsapp: row['auto_issue_whatsapp'] is bool ? row['auto_issue_whatsapp'] as bool : true,
      autoIssueEmail: row['auto_issue_email'] is bool ? row['auto_issue_email'] as bool : false,
      reminderWhatsapp: row['reminder_whatsapp'] is bool ? row['reminder_whatsapp'] as bool : false,
      reminderEmail: row['reminder_email'] is bool ? row['reminder_email'] as bool : false,
      billSoundKey: sound.isEmpty ? 'melody' : sound,
    );
  }

  FinanceReminderSettings copyWith({
    bool? enabled,
    String? schedule,
    int? dueDay,
    bool? autoIssueEnabled,
    bool? autoIssueWhatsapp,
    bool? autoIssueEmail,
    bool? reminderWhatsapp,
    bool? reminderEmail,
    String? billSoundKey,
  }) =>
      FinanceReminderSettings(
        enabled: enabled ?? this.enabled,
        schedule: schedule ?? this.schedule,
        dueDay: dueDay ?? this.dueDay,
        autoIssueEnabled: autoIssueEnabled ?? this.autoIssueEnabled,
        autoIssueWhatsapp: autoIssueWhatsapp ?? this.autoIssueWhatsapp,
        autoIssueEmail: autoIssueEmail ?? this.autoIssueEmail,
        reminderWhatsapp: reminderWhatsapp ?? this.reminderWhatsapp,
        reminderEmail: reminderEmail ?? this.reminderEmail,
        billSoundKey: billSoundKey ?? this.billSoundKey,
      );
}

/// Everything `fetchSocietyFinanceCore` returns (web `SocietyFinanceCoreData`).
class FinanceCoreData {
  const FinanceCoreData({
    this.flats = const [],
    this.primaryByFlatId = const {},
    this.societyName = '',
    this.residentUsers = const [],
    this.settings = const FinanceReminderSettings(),
    this.charges = const [],
    this.paymentExpenseGroups = const [],
    this.payments = const [],
    this.ledgerEntries = const [],
    this.expenseCategoryById = const {},
    this.reserveTransfers = const [],
  });

  final List<SocietyFlatRow> flats;
  final Map<String, String> primaryByFlatId;
  final String societyName;
  final List<FinanceResidentUser> residentUsers;
  final FinanceReminderSettings settings;
  final List<FinanceCharge> charges;
  final List<PaymentExpenseGroup> paymentExpenseGroups;
  final List<FinancePayment> payments;
  final List<FinanceLedgerRow> ledgerEntries;
  final Map<String, String> expenseCategoryById;
  final List<ReserveTransfer> reserveTransfers;
}

/// `event_contributions` row (+ event title) for the Transactions reference list.
class EventContribRefRow {
  const EventContribRefRow({
    required this.id,
    this.eventId = '',
    this.flatNumber,
    this.amount = 0,
    this.paymentMethod = 'cash',
    this.verifiedAt,
    this.residentName,
    this.receiptBasis,
    this.batchLabel,
    this.outsiderName,
    this.splitMode,
    this.screenshotUrl,
    this.eventTitle = 'Event',
  });

  final String id;
  final String eventId;
  final String? flatNumber;
  final double amount;
  final String paymentMethod;
  final String? verifiedAt;
  final String? residentName;
  final String? receiptBasis;
  final String? batchLabel;
  final String? outsiderName;
  final String? splitMode;
  final String? screenshotUrl;
  final String eventTitle;

  factory EventContribRefRow.fromJson(Map<String, dynamic> j, {String eventTitle = 'Event'}) => EventContribRefRow(
        id: _str(j['id']),
        eventId: _str(j['event_id']),
        flatNumber: _s(j['flat_number']),
        amount: _d(j['amount']),
        paymentMethod: _str(j['payment_method']),
        verifiedAt: _s(j['verified_at']),
        residentName: _s(j['resident_name']),
        receiptBasis: _s(j['receipt_basis']),
        batchLabel: _s(j['batch_label']),
        outsiderName: _s(j['outsider_name']),
        splitMode: _s(j['split_mode']),
        screenshotUrl: _s(j['screenshot_url']),
        eventTitle: eventTitle,
      );
}

/// Event food `expenses` row for the Transactions reference list.
class EventFoodRefRow {
  const EventFoodRefRow({
    required this.id,
    required this.title,
    this.totalAmount = 0,
    this.expenseDate = '',
    this.paymentMethod = 'cash',
    this.billScreenshotUrl,
    this.groupName = 'Food group',
    this.eventTitle,
  });

  final String id;
  final String title;
  final double totalAmount;
  final String expenseDate;
  final String paymentMethod;
  final String? billScreenshotUrl;
  final String groupName;
  final String? eventTitle;
}

class FinanceEventReference {
  const FinanceEventReference({this.contributions = const [], this.foodExpenses = const []});

  final List<EventContribRefRow> contributions;
  final List<EventFoodRefRow> foodExpenses;
}

/// `expenses` (payment category) row for the flat-wise report.
class FlatReportExpense {
  const FlatReportExpense({
    required this.id,
    this.title = '',
    this.totalAmount = 0,
    this.expenseDate = '',
    this.paymentMethod = 'cash',
    this.groupName = 'Unknown group',
  });

  final String id;
  final String title;
  final double totalAmount;
  final String expenseDate;
  final String paymentMethod;
  final String groupName;
}

/// `expense_splits` row for the flat-wise report.
class FlatReportSplit {
  const FlatReportSplit({
    this.id = '',
    required this.expenseId,
    required this.flatNumber,
    this.amount = 0,
    this.isSettled = false,
  });

  final String id;
  final String expenseId;
  final String flatNumber;
  final double amount;
  final bool isSettled;
}

class FinanceFlatReportData {
  const FinanceFlatReportData({this.expenses = const [], this.splits = const []});

  final List<FlatReportExpense> expenses;
  final List<FlatReportSplit> splits;
}

/// Helper used by forms: JS `Number(x).toString()` (no trailing `.0`).
String numToInput(num v) {
  if (v.isNaN) return '';
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toString();
}
