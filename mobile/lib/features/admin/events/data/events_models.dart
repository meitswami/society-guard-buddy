import '../../../../core/format/formatters.dart';

/// Row models for the Events & food, expense splitter and donations modules.
/// Column names follow `src/integrations/supabase/types.ts`.

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s;
}

double? _numOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _intOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

List<String> _stringList(Object? v) {
  if (v is List) {
    return [
      for (final e in v)
        if (e is String) e,
    ];
  }
  return const [];
}

/// `events` row.
class EventRow {
  const EventRow({
    required this.id,
    required this.title,
    required this.eventDate,
    this.description,
    this.eventTime,
    this.location,
    this.contributionAmount = 0,
    this.status = 'upcoming',
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String eventDate;
  final String? eventTime;
  final String? location;
  final double contributionAmount;
  final String status;
  final String? createdBy;
  final String? createdAt;

  factory EventRow.fromJson(Map<String, dynamic> j) => EventRow(
        id: asString(j['id']),
        title: asString(j['title']),
        description: _str(j['description']),
        eventDate: asString(j['event_date']),
        eventTime: _str(j['event_time']),
        location: _str(j['location']),
        contributionAmount: asDouble(j['contribution_amount']),
        status: asString(j['status']).isEmpty ? 'upcoming' : asString(j['status']),
        createdBy: _str(j['created_by']),
        createdAt: _str(j['created_at']),
      );
}

/// `event_rsvps` row.
class EventRsvp {
  const EventRsvp({required this.id, required this.eventId, required this.flatNumber, this.status, this.membersCount});

  final String id;
  final String? eventId;
  final String flatNumber;
  final String? status;
  final int? membersCount;

  factory EventRsvp.fromJson(Map<String, dynamic> j) => EventRsvp(
        id: asString(j['id']),
        eventId: _str(j['event_id']),
        flatNumber: asString(j['flat_number']),
        status: _str(j['status']),
        membersCount: _intOrNull(j['members_count']),
      );
}

/// `event_contributions` row.
class EventContribution {
  const EventContribution({
    required this.id,
    required this.eventId,
    required this.amount,
    required this.paymentMethod,
    this.flatNumber,
    this.flatId,
    this.residentName,
    this.screenshotUrl,
    this.verifiedAt,
    this.verifiedBy,
    this.contributorType,
    this.outsiderName,
    this.adultCount,
    this.kidCount,
    this.splitMode,
    this.receiptBasis,
    this.batchLabel,
    this.batchId,
    this.transactionId,
    this.createdAt,
  });

  final String id;
  final String? eventId;
  final String? flatNumber;
  final String? flatId;
  final String? residentName;
  final double amount;
  final String paymentMethod;
  final String? screenshotUrl;
  final String? verifiedAt;
  final String? verifiedBy;
  final String? contributorType;
  final String? outsiderName;
  final int? adultCount;
  final int? kidCount;
  final String? splitMode;
  final String? receiptBasis;
  final String? batchLabel;
  final String? batchId;
  final String? transactionId;
  final String? createdAt;

  /// Web treats an empty string like a missing flat (`!c.flat_number`).
  bool get hasFlat => (flatNumber ?? '').isNotEmpty;

  factory EventContribution.fromJson(Map<String, dynamic> j) => EventContribution(
        id: asString(j['id']),
        eventId: _str(j['event_id']),
        flatNumber: _str(j['flat_number']),
        flatId: _str(j['flat_id']),
        residentName: _str(j['resident_name']),
        amount: asDouble(j['amount']),
        paymentMethod: asString(j['payment_method']),
        screenshotUrl: _str(j['screenshot_url']),
        verifiedAt: _str(j['verified_at']),
        verifiedBy: _str(j['verified_by']),
        contributorType: _str(j['contributor_type']),
        outsiderName: _str(j['outsider_name']),
        adultCount: _intOrNull(j['adult_count']),
        kidCount: _intOrNull(j['kid_count']),
        splitMode: _str(j['split_mode']),
        receiptBasis: _str(j['receipt_basis']),
        batchLabel: _str(j['batch_label']),
        batchId: _str(j['batch_id']),
        transactionId: _str(j['transaction_id']),
        createdAt: _str(j['created_at']),
      );
}

/// `expense_groups` row.
class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.name,
    this.description,
    this.eventId,
    this.groupKind,
    this.majorHead,
    this.adultWeight,
    this.childWeight,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? eventId;
  final String? groupKind;
  final String? majorHead;
  final double? adultWeight;
  final double? childWeight;
  final String? createdAt;

  factory ExpenseGroup.fromJson(Map<String, dynamic> j) => ExpenseGroup(
        id: asString(j['id']),
        name: asString(j['name']),
        description: _str(j['description']),
        eventId: _str(j['event_id']),
        groupKind: _str(j['group_kind']),
        majorHead: _str(j['major_head']),
        adultWeight: _numOrNull(j['adult_weight']),
        childWeight: _numOrNull(j['child_weight']),
        createdAt: _str(j['created_at']),
      );
}

/// `expenses` row.
class ExpenseRow {
  const ExpenseRow({
    required this.id,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    required this.paidByFlat,
    this.paidByFlatsRaw,
    this.paidByName,
    this.splitType = 'equal',
    this.paymentMethod = 'cash',
    this.billScreenshotUrl,
    this.attachmentUrlsRaw,
    this.serviceKind,
    this.vendorOrService,
    this.expenseDate,
    this.recordingDate,
    this.notes,
    this.recordStatus,
    this.expenseCategory,
    this.createdAt,
  });

  final String id;
  final String? groupId;
  final String title;
  final double totalAmount;
  final String paidByFlat;
  final Object? paidByFlatsRaw;
  final String? paidByName;
  final String splitType;
  final String paymentMethod;
  final String? billScreenshotUrl;
  final Object? attachmentUrlsRaw;
  final String? serviceKind;
  final String? vendorOrService;
  final String? expenseDate;
  final String? recordingDate;
  final String? notes;
  final String? recordStatus;
  final String? expenseCategory;
  final String? createdAt;

  bool get isAttachmentArray => attachmentUrlsRaw is List;

  /// `Array.isArray(attachment_urls) ? attachment_urls : []` (string entries).
  List<String> get attachmentUrls => _stringList(attachmentUrlsRaw);

  factory ExpenseRow.fromJson(Map<String, dynamic> j) => ExpenseRow(
        id: asString(j['id']),
        groupId: _str(j['group_id']),
        title: asString(j['title']),
        totalAmount: asDouble(j['total_amount']),
        paidByFlat: asString(j['paid_by_flat']),
        paidByFlatsRaw: j['paid_by_flats'],
        paidByName: _str(j['paid_by_name']),
        splitType: asString(j['split_type']).isEmpty ? 'equal' : asString(j['split_type']),
        paymentMethod: asString(j['payment_method']),
        billScreenshotUrl: _str(j['bill_screenshot_url']),
        attachmentUrlsRaw: j['attachment_urls'],
        serviceKind: _str(j['service_kind']),
        vendorOrService: _str(j['vendor_or_service']),
        expenseDate: _str(j['expense_date']),
        recordingDate: _str(j['recording_date']),
        notes: _str(j['notes']),
        recordStatus: _str(j['record_status']),
        expenseCategory: _str(j['expense_category']),
        createdAt: _str(j['created_at']),
      );
}

/// `expense_splits` row.
class ExpenseSplit {
  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.flatNumber,
    required this.amount,
    this.isSettled = false,
    this.settledAt,
    this.residentName,
  });

  final String id;
  final String? expenseId;
  final String flatNumber;
  final double amount;
  final bool isSettled;
  final String? settledAt;
  final String? residentName;

  factory ExpenseSplit.fromJson(Map<String, dynamic> j) => ExpenseSplit(
        id: asString(j['id']),
        expenseId: _str(j['expense_id']),
        flatNumber: asString(j['flat_number']),
        amount: asDouble(j['amount']),
        isSettled: j['is_settled'] == true,
        settledAt: _str(j['settled_at']),
        residentName: _str(j['resident_name']),
      );
}

/// `event_food_fund_adjustments` row.
class EventFoodAdjustment {
  const EventFoodAdjustment({
    required this.id,
    required this.adjustmentKind,
    required this.amount,
    required this.sourceType,
    this.eventId,
    this.flatNumber,
    this.paymentMethod = 'cash',
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String? eventId;
  final String adjustmentKind;
  final double amount;
  final String sourceType;
  final String? flatNumber;
  final String paymentMethod;
  final String? notes;
  final String? createdBy;
  final String? createdAt;

  factory EventFoodAdjustment.fromJson(Map<String, dynamic> j) => EventFoodAdjustment(
        id: asString(j['id']),
        eventId: _str(j['event_id']),
        adjustmentKind: asString(j['adjustment_kind']),
        amount: asDouble(j['amount']),
        sourceType: asString(j['source_type']),
        flatNumber: _str(j['flat_number']),
        paymentMethod: asString(j['payment_method']),
        notes: _str(j['notes']),
        createdBy: _str(j['created_by']),
        createdAt: _str(j['created_at']),
      );
}

/// Food bill row as listed in the reconciliation (`expenses` + group name / event).
class FoodExpenseRow {
  const FoodExpenseRow({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.expenseDate,
    required this.paymentMethod,
    required this.groupId,
    required this.groupName,
    this.billScreenshotUrl,
    this.attachmentUrls,
    this.eventId,
  });

  final String id;
  final String title;
  final double totalAmount;
  final String expenseDate;
  final String paymentMethod;
  final String? billScreenshotUrl;
  final List<String>? attachmentUrls;
  final String groupId;
  final String groupName;
  final String? eventId;
}

/// `donation_campaigns` row.
class DonationCampaign {
  const DonationCampaign({
    required this.id,
    required this.title,
    this.description,
    this.targetAmount = 0,
    this.collectedAmount,
    this.status = 'active',
    this.endDate,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final double targetAmount;
  final double? collectedAmount;
  final String status;
  final String? endDate;
  final String? createdBy;
  final String? createdAt;

  factory DonationCampaign.fromJson(Map<String, dynamic> j) => DonationCampaign(
        id: asString(j['id']),
        title: asString(j['title']),
        description: _str(j['description']),
        targetAmount: asDouble(j['target_amount']),
        collectedAmount: _numOrNull(j['collected_amount']),
        status: asString(j['status']).isEmpty ? 'active' : asString(j['status']),
        endDate: _str(j['end_date']),
        createdBy: _str(j['created_by']),
        createdAt: _str(j['created_at']),
      );
}

/// `donation_payments` row.
class DonationPayment {
  const DonationPayment({
    required this.id,
    required this.campaignId,
    required this.flatNumber,
    required this.amount,
    this.flatId,
    this.residentName,
    this.paymentMethod = 'cash',
    this.transactionId,
    this.screenshotUrl,
    this.verifiedBy,
    this.verifiedAt,
    this.createdAt,
  });

  final String id;
  final String? campaignId;
  final String flatNumber;
  final double amount;
  final String? flatId;
  final String? residentName;
  final String paymentMethod;
  final String? transactionId;
  final String? screenshotUrl;
  final String? verifiedBy;
  final String? verifiedAt;
  final String? createdAt;

  factory DonationPayment.fromJson(Map<String, dynamic> j) => DonationPayment(
        id: asString(j['id']),
        campaignId: _str(j['campaign_id']),
        flatNumber: asString(j['flat_number']),
        amount: asDouble(j['amount']),
        flatId: _str(j['flat_id']),
        residentName: _str(j['resident_name']),
        paymentMethod: asString(j['payment_method']),
        transactionId: _str(j['transaction_id']),
        screenshotUrl: _str(j['screenshot_url']),
        verifiedBy: _str(j['verified_by']),
        verifiedAt: _str(j['verified_at']),
        createdAt: _str(j['created_at']),
      );
}
