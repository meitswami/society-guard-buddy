import '../data/report_models.dart';
import 'finance_period_report.dart';
import 'js_compat.dart';
import 'report_detail_row.dart';

/// Port of `src/lib/reportQueryFilter.ts` — the shared Reports search box.

String normalizeReportQuery(String query) => query.trim().toLowerCase();

bool matchesHaystack(String haystack, String query) {
  final q = normalizeReportQuery(query);
  if (q.isEmpty) return true;
  return haystack.toLowerCase().contains(q);
}

List<ReportVisitor> filterVisitorRows(
    List<ReportVisitor> visitors, String query) {
  final q = normalizeReportQuery(query);
  if (q.isEmpty) return visitors;
  return visitors.where((v) {
    final haystack = [
      v.name,
      v.phone,
      v.flatNumber,
      v.purpose,
      v.guardName,
      v.category,
      v.company ?? '',
      v.vehicleNumber ?? '',
      v.documentNumber,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

List<FinancePeriodLedgerEntry> filterLedgerEntries(
    List<FinancePeriodLedgerEntry> entries, String query) {
  final q = normalizeReportQuery(query);
  if (q.isEmpty) return entries;
  return entries.where((e) {
    final haystack = [
      e.id,
      e.recordMode ?? '',
      e.destination,
      e.paymentMethod ?? '',
      e.paymentStatus ?? '',
      e.title ?? '',
      e.notes ?? '',
      e.transactionId ?? '',
      e.transactionDate ?? '',
      e.entryMonth ?? '',
      jsNumberString(e.totalAmount),
      jsNumberString(e.aggregateFlatCount),
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

List<ReportDetailRow> filterReportDetailRows(
    List<ReportDetailRow> rows, String query) {
  final q = normalizeReportQuery(query);
  if (q.isEmpty) return rows;
  return rows.where((row) {
    final haystack = [
      row.label,
      row.sublabel ?? '',
      row.date ?? '',
      row.status ?? '',
      row.extra ?? '',
      row.amount != null ? jsNumberString(row.amount!) : '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}

List<ReportShiftRow> filterShiftRows(
    List<ReportShiftRow> shifts, String query) {
  final q = normalizeReportQuery(query);
  if (q.isEmpty) return shifts;
  return shifts.where((s) {
    final haystack = [s.guardName, s.guardId, s.loginTime, s.logoutTime ?? '']
        .join(' ')
        .toLowerCase();
    return haystack.contains(q);
  }).toList();
}
