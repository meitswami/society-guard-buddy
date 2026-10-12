import 'flat360_models.dart';

/// Port of web `src/lib/flat360Timeline.ts` plus the pure helpers of
/// `src/services/flat360/flat360Service.ts` / `src/lib/notificationAudience.ts`.

/// `new Date(at).getTime()` — date-only strings are UTC midnight like JavaScript;
/// unparsable values sort as the epoch.
int flat360TimeMs(String at) {
  final s = at.trim();
  if (s.isEmpty) return 0;
  final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
  final parsed = DateTime.tryParse(dateOnly ? '${s}T00:00:00Z' : s);
  return parsed?.millisecondsSinceEpoch ?? 0;
}

class Flat360MergedTimeline {
  const Flat360MergedTimeline(this.timeline, this.hasMore);

  final List<Flat360TimelineItem> timeline;
  final bool hasMore;
}

/// Newest first, capped at [limit].
Flat360MergedTimeline mergeFlat360Timeline(List<Flat360TimelineItem> items, int limit) {
  final sorted = [...items]..sort((a, b) => flat360TimeMs(b.at).compareTo(flat360TimeMs(a.at)));
  return Flat360MergedTimeline(sorted.take(limit).toList(), sorted.length > limit);
}

/// English labels (web `timelineKindLabel`).
String timelineKindLabel(Flat360TimelineKind kind) => switch (kind) {
      Flat360TimelineKind.payment => 'Payment',
      Flat360TimelineKind.notification => 'Notice',
      Flat360TimelineKind.ticket => 'Feedback',
      Flat360TimelineKind.meeting => 'Meeting',
      Flat360TimelineKind.eventContribution => 'Event',
      Flat360TimelineKind.visitor => 'Visitor',
    };

/// Hindi labels for [timelineKindLabel].
String timelineKindLabelHi(Flat360TimelineKind kind) => switch (kind) {
      Flat360TimelineKind.payment => 'भुगतान',
      Flat360TimelineKind.notification => 'सूचना',
      Flat360TimelineKind.ticket => 'प्रतिक्रिया',
      Flat360TimelineKind.meeting => 'बैठक',
      Flat360TimelineKind.eventContribution => 'कार्यक्रम',
      Flat360TimelineKind.visitor => 'आगंतुक',
    };

/// Web `paymentStatusLabel`.
String paymentStatusLabel(String status) {
  final s = status.toLowerCase();
  if (s == 'verified') return 'Verified';
  if (s == 'pending') return 'Pending';
  if (s == 'rejected') return 'Rejected';
  return status;
}

/// date-fns `subMonths(date, n)`: same day-of-month, clamped to the target month's last day.
DateTime subMonthsClamped(DateTime date, int months) {
  final totalMonths = date.year * 12 + (date.month - 1) - months;
  final y = totalMonths ~/ 12;
  final m = totalMonths % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  final d = date.day > lastDay ? lastDay : date.day;
  return DateTime(y, m, d, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
}

/// Web `cutoffIso(monthsBack)` → UTC ISO string.
String flat360CutoffIso(int monthsBack, {DateTime? now}) =>
    subMonthsClamped(now ?? DateTime.now(), monthsBack).toUtc().toIso8601String();

/// Web `notificationVisibleToResident` (flat / person / society-wide).
bool notificationVisibleToResident({
  required String? targetType,
  required String? targetId,
  required Flat360ResidentContext resident,
  required String flatNumber,
}) {
  final type = targetType ?? '';
  final id = (targetId ?? '').trim();
  if (type == 'all') return true;
  if (type == 'flat') {
    if (id == flatNumber) return true;
    if (id.contains(',')) {
      return id.split(',').map((s) => s.trim()).contains(flatNumber);
    }
  }
  if (type == 'user') {
    if (id == resident.id) return true;
    if (id == resident.name) return true;
    if (id.contains(',')) {
      final parts = id.split(',').map((s) => s.trim()).toList();
      return parts.contains(resident.id) || parts.contains(resident.name);
    }
  }
  return false;
}

/// Admin view filter: flat-targeted notices are kept only when they list this flat
/// (an empty target keeps the row, as on the web).
bool notificationVisibleForFlatAdmin({
  required String? targetType,
  required String? targetId,
  required String flatNumber,
}) {
  if ((targetType ?? '') != 'flat') return true;
  final target = (targetId ?? '').trim();
  final targets = target.contains(',') ? target.split(',').map((s) => s.trim()).toList() : [target];
  if (target.isNotEmpty && !targets.contains(flatNumber)) return false;
  return true;
}

/// Payment method label: `String(method || 'cash').replace(/_/g, ' ')`.
String paymentMethodLabel(String? method) {
  final m = (method == null || method.isEmpty) ? 'cash' : method;
  return m.replaceAll('_', ' ');
}

/// JavaScript `String.prototype.slice(0, n)`.
String jsSlice(String s, int n) => s.length <= n ? s : s.substring(0, n);
