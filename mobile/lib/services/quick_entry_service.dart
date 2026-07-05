import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../utils/member_categories.dart';
import 'visitor_service.dart';

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

class QuickEntryService {
  Future<List<QuickEntryRow>> fetchRows(String societyId) async {
    if (!Env.isConfigured) return const [];

    final visitorService = VisitorService();
    final visitors = await visitorService.fetchToday(societyId);

    final phoneCounts = <String, int>{};
    final latestByPhone = <String, VisitorEntry>{};
    for (final v in visitors) {
      phoneCounts[v.phone] = (phoneCounts[v.phone] ?? 0) + 1;
      final existing = latestByPhone[v.phone];
      if (existing == null || v.entryTime.compareTo(existing.entryTime) > 0) {
        latestByPhone[v.phone] = v;
      }
    }

    final rows = <String, QuickEntryRow>{};

    final members = await SupabaseBootstrap.client
        .from('members')
        .select('id, name, phone, flat_id, relation, household_group')
        .not('phone', 'is', null);

    final flats = await SupabaseBootstrap.client
        .from('flats')
        .select('id, flat_number')
        .eq('society_id', societyId);
    final flatNumById = {
      for (final f in flats as List)
        f['id'] as String: f['flat_number'] as String,
    };

    for (final m in members as List) {
      final relation = m['relation'] as String?;
      final group = (m['household_group'] as String? ?? '').toLowerCase();
      final isStaff = group == 'serviceman' || isRestrictedMemberCategory(relation);
      if (!isStaff) continue;

      final flatId = m['flat_id'] as String?;
      final flatNumber = flatId != null ? flatNumById[flatId] : null;
      final phone = (m['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
      if (flatNumber == null || phone.length < 10) continue;

      rows[phone] = QuickEntryRow(
        key: 'staff-${m['id']}',
        name: m['name'] as String,
        phone: phone.length > 10 ? phone.substring(phone.length - 10) : phone,
        flatNumber: flatNumber,
        purpose: 'Staff visit',
        category: 'service',
        isStaff: true,
      );
    }

    for (final entry in phoneCounts.entries) {
      if (entry.value < 2) continue;
      final v = latestByPhone[entry.key];
      if (v == null) continue;
      final existing = rows[entry.key];
      if (existing != null) {
        rows[entry.key] = QuickEntryRow(
          key: existing.key,
          name: existing.name,
          phone: existing.phone,
          flatNumber: existing.flatNumber,
          purpose: existing.purpose,
          category: existing.category,
          company: existing.company,
          visitCount: entry.value,
          isStaff: existing.isStaff,
        );
      } else {
        rows[entry.key] = QuickEntryRow(
          key: 'freq-${entry.key}',
          name: v.name,
          phone: v.phone,
          flatNumber: v.flatNumber,
          purpose: v.category == 'visitor' ? 'Regular visit' : v.category,
          category: v.category,
          visitCount: entry.value,
        );
      }
    }

    final list = rows.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  VisitorEntry? findActiveVisit(List<VisitorEntry> visitors, QuickEntryRow row) {
    final inside = visitors.where((v) => v.isInside).toList();
    final byPhone = inside.where((v) => v.phone == row.phone).toList();
    if (byPhone.isNotEmpty) return byPhone.first;

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
