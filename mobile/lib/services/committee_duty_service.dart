import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/committee_duty.dart';

class CommitteeDutyService {
  Future<CommitteeDutiesChart?> fetchActiveChart(String societyId) async {
    if (!Env.isConfigured) return null;

    final chartRow = await SupabaseBootstrap.client
        .from('committee_duties_charts')
        .select('*')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .maybeSingle();

    if (chartRow == null) return null;

    final chart = Map<String, dynamic>.from(chartRow as Map);
    final dutyRows = await SupabaseBootstrap.client
        .from('committee_duty_rows')
        .select('*')
        .eq('chart_id', chart['id'])
        .order('sort_order')
        .order('duty_label');

    final rows = (dutyRows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    if (rows.isEmpty) return null;

    return CommitteeDutiesChart.fromChartAndRows(chart, rows);
  }
}
