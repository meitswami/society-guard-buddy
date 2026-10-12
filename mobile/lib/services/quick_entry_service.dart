import '../core/config/env.dart';
import '../features/gate/data/gate_directory_service.dart';
import '../features/gate/data/quick_entry_logic.dart';
import 'visitor_service.dart';

/// Flattened Quick Entry row (legacy API kept for existing callers).
class QuickEntryRow {
  const QuickEntryRow({
    required this.key,
    required this.name,
    required this.phone,
    required this.flatNumber,
    required this.purpose,
    required this.category,
    this.company,
    this.visitCount = 0,
    this.isStaff = false,
  });

  final String key;
  final String name;
  final String phone;
  final String flatNumber;
  final String purpose;
  final String category;
  final String? company;
  final int visitCount;
  final bool isStaff;
}

/// Quick Entry data (registered staff + frequent visitors) — web `QuickEntryPage`.
class QuickEntryService {
  final _visitors = VisitorService();
  final _directory = const GateDirectoryService();

  /// Builds the Quick Entry list for the society (society-scoped flats / members / visitors).
  Future<List<QuickRow>> fetchQuickRows(String societyId) async {
    if (!Env.isConfigured) return const [];
    final flats = await _directory.fetchFlats(societyId);
    final (visitors, members) = await (
      _visitors.fetchAll(societyId),
      _directory.fetchMembers(flats.map((f) => f.id).toList()),
    ).wait;
    return buildQuickRows(visitors: visitors, members: members, flats: flats);
  }

  /// Legacy flattened rows.
  Future<List<QuickEntryRow>> fetchRows(String societyId) async {
    final rows = await fetchQuickRows(societyId);
    return rows
        .map((r) => QuickEntryRow(
              key: r.key,
              name: r.visitor.name,
              phone: r.visitor.phone,
              flatNumber: r.visitor.flatNumber,
              purpose: r.visitor.purpose,
              category: r.visitor.category,
              company: r.visitor.company,
              visitCount: r.visitCount,
              isStaff: r.isStaff,
            ))
        .toList();
  }

  /// Legacy: open visit of [row] among [visitors] (same phone, else same name + flat).
  VisitorEntry? findActiveVisit(
      List<VisitorEntry> visitors, QuickEntryRow row) {
    final inside = visitors.where((v) => v.isInside).toList();
    for (final v in inside) {
      if (v.phone == row.phone) return v;
    }
    final nameLc = row.name.trim().toLowerCase();
    final flatLc = row.flatNumber.trim().toLowerCase();
    for (final v in inside) {
      if (v.flatNumber.trim().toLowerCase() == flatLc &&
          v.name.trim().toLowerCase() == nameLc) {
        return v;
      }
    }
    return null;
  }
}
