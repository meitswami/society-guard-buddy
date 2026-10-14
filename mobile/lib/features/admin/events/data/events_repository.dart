import '../../../../core/supabase/db.dart';
import '../logic/flat_options.dart';
import '../logic/split_math.dart';
import 'events_models.dart';
import 'events_notify.dart';
import 'query_helpers.dart';

/// Flats + primary member names (+ optionally all members for headcounts) of a society.
class SocietyFlatsData {
  const SocietyFlatsData({required this.flats, required this.primaryByFlatId, this.members = const []});

  final List<FlatLite> flats;
  final Map<String, String> primaryByFlatId;
  final List<FlatMemberRow> members;

  static const empty = SocietyFlatsData(flats: [], primaryByFlatId: {});
}

class EventManagerData {
  const EventManagerData({
    required this.events,
    required this.rsvps,
    required this.contributions,
    required this.flats,
  });

  final List<EventRow> events;
  final List<EventRsvp> rsvps;
  final List<EventContribution> contributions;
  final SocietyFlatsData flats;

  static const empty = EventManagerData(events: [], rsvps: [], contributions: [], flats: SocietyFlatsData.empty);
}

class ReconciliationData {
  const ReconciliationData({
    required this.events,
    required this.contributions,
    required this.foodExpenses,
    required this.adjustments,
  });

  final List<EventRow> events;
  final List<EventContribution> contributions;
  final List<FoodExpenseRow> foodExpenses;
  final List<EventFoodAdjustment> adjustments;

  static const empty = ReconciliationData(events: [], contributions: [], foodExpenses: [], adjustments: []);
}

/// Food bill row of the read-only Finance → Receipts reference (`EventFoodRefRow`).
class FinanceFoodRefRow {
  const FinanceFoodRefRow({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.expenseDate,
    required this.paymentMethod,
    required this.groupName,
    this.billScreenshotUrl,
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

/// Contribution row + its event title (Finance reference list).
class EventContributionRef {
  const EventContributionRef(this.contribution, this.eventTitle);

  final EventContribution contribution;
  final String eventTitle;
}

/// Queries of `EventManager`, `EventFoodReconciliation`, `EventContributionEditModal`
/// and `fetchFinanceEventReference` — same tables, columns, filters and ordering as the web.
class EventsRepository {
  const EventsRepository();

  Future<SocietyFlatsData> loadFlats(String societyId, {bool withMembers = true, bool withOccupancy = true}) async {
    if (!dbReady || societyId.isEmpty) return SocietyFlatsData.empty;
    final cols = withOccupancy ? 'flat_number, id, owner_name, is_occupied' : 'id, flat_number, owner_name';
    final flatRows = rowsOf(await db.from('flats').select(cols).eq('society_id', societyId).orderAsc('flat_number'));
    final flats = flatRows.map(FlatLite.fromJson).toList();
    return _withMembers(flats, withMembers: withMembers);
  }

  Future<SocietyFlatsData> _withMembers(List<FlatLite> flats, {required bool withMembers}) async {
    final flatIds = [for (final f in flats) f.id];
    if (flatIds.isEmpty) return SocietyFlatsData(flats: flats, primaryByFlatId: const {});
    final results = await Future.wait([
      db.from('members').select('flat_id, name').eq('is_primary', true).inFilter('flat_id', flatIds),
      if (withMembers) db.from('members').select('id, flat_id, name, age, relation').inFilter('flat_id', flatIds),
    ]);
    final primary = <String, String>{};
    for (final row in rowsOf(results[0])) {
      final fid = row['flat_id']?.toString();
      final name = row['name']?.toString().trim() ?? '';
      if (fid != null && fid.isNotEmpty && name.isNotEmpty) primary[fid] = name;
    }
    final members = withMembers ? rowsOf(results[1]).map(FlatMemberRow.fromJson).toList() : const <FlatMemberRow>[];
    return SocietyFlatsData(flats: flats, primaryByFlatId: primary, members: members);
  }

  // ---------------------------------------------------------------- EventManager

  Future<EventManagerData> loadEventManager(String societyId) async {
    if (!dbReady || societyId.isEmpty) return EventManagerData.empty;
    final first = await Future.wait([
      db.from('events').select().eq('society_id', societyId).orderDesc('event_date'),
      db.from('flats').select('flat_number, id, owner_name, is_occupied').eq('society_id', societyId).orderAsc('flat_number'),
    ]);
    final events = rowsOf(first[0]).map(EventRow.fromJson).toList();
    final flats = rowsOf(first[1]).map(FlatLite.fromJson).toList();
    final eventIds = [for (final e in events) e.id];
    final second = await Future.wait<Object?>([
      eventIds.isEmpty ? Future.value(const []) : db.from('event_rsvps').select().inFilter('event_id', eventIds),
      eventIds.isEmpty ? Future.value(const []) : db.from('event_contributions').select().inFilter('event_id', eventIds),
      _withMembers(flats, withMembers: true),
    ]);
    return EventManagerData(
      events: events,
      rsvps: rowsOf(second[0]).map(EventRsvp.fromJson).toList(),
      contributions: rowsOf(second[1]).map(EventContribution.fromJson).toList(),
      flats: second[2] as SocietyFlatsData,
    );
  }

  Future<void> insertEvent({
    required String societyId,
    required String adminName,
    required String title,
    required String? description,
    required String eventDate,
    required String? eventTime,
    required String? location,
    required double contributionAmount,
  }) async {
    await db.from('events').insert([
      {
        'title': title,
        'description': description,
        'event_date': eventDate,
        'event_time': eventTime,
        'location': location,
        'contribution_amount': contributionAmount,
        'created_by': adminName,
        'society_id': societyId,
      },
    ]);
  }

  /// "New Event" notification to everyone + push (EventManager.addEvent).
  Future<void> announceEvent({
    required String societyId,
    required String adminName,
    required String title,
    required String message,
  }) async {
    await db.from('notifications').insert([
      {
        'title': title,
        'message': message,
        'type': 'event',
        'target_type': 'all',
        'created_by': adminName,
        'society_id': societyId,
      },
    ]);
    await EventsNotify.invokePush(title: title, message: message, targetType: 'all', societyId: societyId);
  }

  /// Per-flat "Payment Due" reminders + one push (EventManager.sendContribReminders).
  Future<void> sendContributionReminders({
    required String societyId,
    required String adminName,
    required EventRow event,
    required List<String> unpaidFlatNumbers,
    required String contributionText,
  }) async {
    final title = 'Payment Due: ${event.title}';
    // Same rows as the web's per-flat inserts, sent in one request (much faster on mobile data).
    await db.from('notifications').insert([
      for (final flat in unpaidFlatNumbers)
        {
          'title': title,
          'message': 'Flat $flat, your contribution of ₹$contributionText for ${event.title} is pending.',
          'type': 'event_reminder',
          'target_type': 'flat',
          'target_id': flat,
          'created_by': adminName,
          'society_id': societyId,
        },
    ]);
    await EventsNotify.invokePush(
      title: title,
      message: 'Your contribution of ₹$contributionText for ${event.title} is pending.',
      targetType: 'flat',
      societyId: societyId,
      targetFlatNumbers: unpaidFlatNumbers,
    );
  }

  Future<void> insertContributions(List<Map<String, dynamic>> rows) async {
    await db.from('event_contributions').insert(rows);
  }

  Future<EventContribution?> getContribution(String id) async {
    final data = await db.from('event_contributions').select().eq('id', id).maybeSingle();
    return data == null ? null : EventContribution.fromJson(data);
  }

  Future<void> updateContribution(String id, Map<String, dynamic> payload) async {
    await db.from('event_contributions').update(payload).eq('id', id);
  }

  Future<void> deleteContribution(String id) async {
    await db.from('event_contributions').delete().eq('id', id);
  }

  // ------------------------------------------------------- EventFoodReconciliation

  Future<ReconciliationData> loadReconciliation(String societyId) async {
    if (!dbReady || societyId.isEmpty) return ReconciliationData.empty;
    final evRows = rowsOf(
      await db
          .from('events')
          .select('id, title, event_date, contribution_amount')
          .eq('society_id', societyId)
          .orderDesc('event_date')
          .limit(120),
    );
    final events = evRows.map(EventRow.fromJson).toList();
    final eventIds = [for (final e in events) e.id];

    final groups = rowsOf(await db.from('expense_groups').select('id, name, event_id, group_kind').eq('society_id', societyId));
    final groupById = {for (final g in groups) '${g['id']}': g};
    final groupIds = groupById.keys.toList();

    final res = await Future.wait<Object?>([
      eventIds.isEmpty
          ? Future.value(const [])
          : db.from('event_contributions').select().inFilter('event_id', eventIds).orderDesc('verified_at'),
      groupIds.isEmpty
          ? Future.value(const [])
          : db
              .from('expenses')
              .select('id, title, total_amount, expense_date, payment_method, bill_screenshot_url, attachment_urls, group_id')
              .inFilter('group_id', groupIds)
              .eq('expense_category', 'food')
              .eq('record_status', 'active')
              .orderDesc('expense_date'),
    ]);
    final contributions = rowsOf(res[0]).map(EventContribution.fromJson).toList();

    final adjustments = rowsOf(
      await db.from('event_food_fund_adjustments').select().eq('society_id', societyId).orderDesc('created_at'),
    ).map(EventFoodAdjustment.fromJson).toList();

    final foodExpenses = [
      for (final ex in rowsOf(res[1]))
        () {
          final g = groupById['${ex['group_id']}'];
          final rawAttachments = ex['attachment_urls'];
          final bill = ex['bill_screenshot_url']?.toString();
          return FoodExpenseRow(
            id: '${ex['id']}',
            title: '${ex['title'] ?? ''}',
            totalAmount: ex['total_amount'] is num ? (ex['total_amount'] as num).toDouble() : double.tryParse('${ex['total_amount']}') ?? 0,
            expenseDate: '${ex['expense_date'] ?? ''}',
            paymentMethod: '${ex['payment_method'] ?? ''}',
            billScreenshotUrl: (bill == null || bill.isEmpty) ? null : bill,
            attachmentUrls: rawAttachments is List
                ? [
                    for (final u in rawAttachments)
                      if (u is String) u
                  ]
                : null,
            groupId: '${ex['group_id'] ?? ''}',
            groupName: (g?['name'] ?? 'Food group').toString(),
            eventId: g?['event_id']?.toString(),
          );
        }(),
    ];

    return ReconciliationData(
      events: events,
      contributions: contributions,
      foodExpenses: foodExpenses,
      adjustments: adjustments,
    );
  }

  Future<String?> flatIdByNumber(String societyId, String flatNumber) async {
    final data = await db.from('flats').select('id').eq('society_id', societyId).eq('flat_number', flatNumber).maybeSingle();
    return data?['id']?.toString();
  }

  Future<void> insertAdjustment(Map<String, dynamic> row) async {
    await db.from('event_food_fund_adjustments').insert(row);
  }

  // ------------------------------------------------- Finance → receipts reference

  /// `fetchFinanceEventReference(societyId)` — read-only lists shown under Finance → Receipts.
  Future<({List<EventContributionRef> contributions, List<FinanceFoodRefRow> foodExpenses})> fetchFinanceEventReference(
    String societyId,
  ) async {
    if (!dbReady || societyId.isEmpty) return (contributions: <EventContributionRef>[], foodExpenses: <FinanceFoodRefRow>[]);
    final first = await Future.wait([
      db.from('events').select('id, title').eq('society_id', societyId).orderDesc('event_date').limit(100),
      db.from('expense_groups').select('id, name, event_id').eq('society_id', societyId).eq('group_kind', 'event'),
    ]);
    final eventsRows = rowsOf(first[0]);
    final groups = rowsOf(first[1]);
    final eventIds = [for (final e in eventsRows) '${e['id']}'];
    final eventTitleById = {for (final e in eventsRows) '${e['id']}': '${e['title']}'};
    final groupById = {for (final g in groups) '${g['id']}': g};
    final groupIds = groupById.keys.toList();

    final second = await Future.wait<Object?>([
      eventIds.isEmpty
          ? Future.value(const [])
          : db.from('event_contributions').select().inFilter('event_id', eventIds).orderDesc('verified_at').limit(150),
      groupIds.isEmpty
          ? Future.value(const [])
          : db
              .from('expenses')
              .select('id, title, total_amount, expense_date, payment_method, bill_screenshot_url, group_id')
              .inFilter('group_id', groupIds)
              .eq('expense_category', 'food')
              .eq('record_status', 'active')
              .orderDesc('expense_date')
              .limit(150),
    ]);

    final contributions = [
      for (final c in rowsOf(second[0])) EventContributionRef(EventContribution.fromJson(c), eventTitleById['${c['event_id']}'] ?? 'Event'),
    ];
    final food = [
      for (final ex in rowsOf(second[1]))
        () {
          final g = groupById['${ex['group_id']}'];
          final evId = g?['event_id']?.toString();
          final bill = ex['bill_screenshot_url']?.toString();
          return FinanceFoodRefRow(
            id: '${ex['id']}',
            title: '${ex['title'] ?? ''}',
            totalAmount: ex['total_amount'] is num ? (ex['total_amount'] as num).toDouble() : double.tryParse('${ex['total_amount']}') ?? 0,
            expenseDate: '${ex['expense_date'] ?? ''}',
            paymentMethod: '${ex['payment_method'] ?? ''}',
            billScreenshotUrl: (bill == null || bill.isEmpty) ? null : bill,
            groupName: (g?['name'] ?? 'Food group').toString(),
            eventTitle: evId == null ? null : eventTitleById[evId],
          );
        }(),
    ];
    return (contributions: contributions, foodExpenses: food);
  }
}
