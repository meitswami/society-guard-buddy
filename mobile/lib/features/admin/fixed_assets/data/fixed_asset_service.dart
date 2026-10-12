import '../../../../core/supabase/db.dart';
import '../logic/fixed_asset_types.dart';

class ExpenseGroupOption {
  const ExpenseGroupOption(
      {required this.id, required this.name, this.majorHead, this.description});

  final String id;
  final String name;
  final String? majorHead;
  final String? description;
}

/// Port of `src/services/fixedAssets/fixedAssetService.ts`.
class FixedAssetService {
  const FixedAssetService();

  Future<List<FixedAsset>> fetchFixedAssets(String societyId) async {
    if (!dbReady) return const [];
    final data = await db
        .from('fixed_assets')
        .select('*')
        .eq('society_id', societyId)
        .order('sub_head')
        .order('asset_name');
    return rowsOf(data).map(FixedAsset.fromJson).toList();
  }

  /// Inserts the standard templates that are not in the register yet; returns how many were added.
  Future<int> seedStandardAssetTemplates(
      String societyId, String createdBy) async {
    if (!dbReady) return 0;
    final existing = rowsOf(
      await db
          .from('fixed_assets')
          .select('template_key')
          .eq('society_id', societyId)
          .not('template_key', 'is', null),
    );
    final keys = {
      for (final r in existing)
        if ((r['template_key'] ?? '').toString().isNotEmpty)
          r['template_key'].toString(),
    };
    final rows = templateSeedRows(societyId, createdBy, keys);
    if (rows.isEmpty) return 0;
    await db.from('fixed_assets').insert(rows);
    return rows.length;
  }

  Future<FixedAsset> createFixedAsset(
      String societyId, Map<String, Object?> input, String createdBy) async {
    final row = await db
        .from('fixed_assets')
        .insert({
          'society_id': societyId,
          ...input,
          'major_head': input['major_head'] ?? 'FIXED ASSETS',
          'source_type': input['source_type'] ?? 'manual',
          'status': input['status'] ?? 'active',
          'created_by': createdBy,
        })
        .select()
        .single();
    return FixedAsset.fromJson(row);
  }

  Future<FixedAsset> updateFixedAsset(
      String societyId, String id, Map<String, Object?> input) async {
    final row = await db
        .from('fixed_assets')
        .update(input)
        .eq('id', id)
        .eq('society_id', societyId)
        .select()
        .single();
    return FixedAsset.fromJson(row);
  }

  Future<void> deleteFixedAsset(String societyId, String id) async {
    await db
        .from('fixed_assets')
        .delete()
        .eq('id', id)
        .eq('society_id', societyId);
  }

  Future<List<ExpenseGroupOption>> fetchExpenseGroupsForFixedAssets(
      String societyId) async {
    if (!dbReady) return const [];
    final data = await db
        .from('expense_groups')
        .select('id, name, major_head, description')
        .eq('society_id', societyId)
        .eq('group_kind', 'general')
        .order('name');
    return [
      for (final g in rowsOf(data))
        if (isFixedAssetExpenseGroup(
            name: (g['name'] ?? '').toString(),
            majorHead: g['major_head']?.toString()))
          ExpenseGroupOption(
            id: (g['id'] ?? '').toString(),
            name: (g['name'] ?? '').toString(),
            majorHead: g['major_head']?.toString(),
            description: g['description']?.toString(),
          ),
    ];
  }

  Future<String?> societyName(String societyId) async {
    if (!dbReady) return null;
    final row = await db
        .from('societies')
        .select('name')
        .eq('id', societyId)
        .maybeSingle();
    final n = row?['name']?.toString();
    return (n == null || n.isEmpty) ? null : n;
  }
}
