import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class VisitorEntry {
  const VisitorEntry({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatNumber,
    required this.category,
    required this.entryTime,
    this.exitTime,
    this.vehicleNumber,
  });

  final String id;
  final String name;
  final String phone;
  final String flatNumber;
  final String category;
  final String entryTime;
  final String? exitTime;
  final String? vehicleNumber;

  bool get isInside => exitTime == null || exitTime!.isEmpty;
}

class VisitorService {
  Future<List<VisitorEntry>> fetchToday(String societyId) async {
    if (!Env.isConfigured) return const [];

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await SupabaseBootstrap.client
        .from('visitors')
        .select('*')
        .eq('society_id', societyId)
        .gte('entry_time', '${today}T00:00:00')
        .order('entry_time', ascending: false)
        .limit(200);

    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return VisitorEntry(
        id: m['id'] as String,
        name: m['name'] as String? ?? 'Unknown',
        phone: m['phone'] as String? ?? '',
        flatNumber: m['flat_number'] as String? ?? '',
        category: m['category'] as String? ?? 'visitor',
        entryTime: m['entry_time'] as String? ?? '',
        exitTime: m['exit_time'] as String?,
        vehicleNumber: m['vehicle_number'] as String?,
      );
    }).toList();
  }

  Future<void> markExit(String visitorId) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('visitors').update({
      'exit_time': DateTime.now().toIso8601String(),
    }).eq('id', visitorId);
  }
}
