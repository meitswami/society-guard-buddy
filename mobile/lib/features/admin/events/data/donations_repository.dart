import '../../../../core/supabase/db.dart';
import '../logic/flat_options.dart';
import 'events_models.dart';
import 'events_repository.dart';
import 'query_helpers.dart';

class DonationsData {
  const DonationsData({required this.campaigns, required this.donations, required this.flats});

  final List<DonationCampaign> campaigns;
  final List<DonationPayment> donations;
  final SocietyFlatsData flats;

  static const empty = DonationsData(campaigns: [], donations: [], flats: SocietyFlatsData.empty);
}

/// Queries of `DonationManager` (`donation_campaigns`, `donation_payments`).
class DonationsRepository {
  const DonationsRepository();

  Future<DonationsData> load(String societyId) async {
    if (!dbReady || societyId.isEmpty) return DonationsData.empty;
    final first = await Future.wait([
      db.from('donation_campaigns').select().eq('society_id', societyId).orderDesc('created_at'),
      db.from('flats').select('flat_number, id, owner_name').eq('society_id', societyId).orderAsc('flat_number'),
    ]);
    final campaigns = rowsOf(first[0]).map(DonationCampaign.fromJson).toList();
    final flats = rowsOf(first[1]).map(FlatLite.fromJson).toList();
    final campaignIds = [for (final c in campaigns) c.id];
    final flatIds = [for (final f in flats) f.id];
    final second = await Future.wait<Object?>([
      campaignIds.isEmpty
          ? Future.value(const [])
          : db.from('donation_payments').select().inFilter('campaign_id', campaignIds).orderDesc('created_at'),
      flatIds.isEmpty
          ? Future.value(const [])
          : db.from('members').select('flat_id, name').eq('is_primary', true).inFilter('flat_id', flatIds),
    ]);
    final primary = <String, String>{};
    for (final row in rowsOf(second[1])) {
      final fid = row['flat_id']?.toString();
      final name = row['name']?.toString().trim() ?? '';
      if (fid != null && fid.isNotEmpty && name.isNotEmpty) primary[fid] = name;
    }
    return DonationsData(
      campaigns: campaigns,
      donations: rowsOf(second[0]).map(DonationPayment.fromJson).toList(),
      flats: SocietyFlatsData(flats: flats, primaryByFlatId: primary),
    );
  }

  Future<void> insertCampaign({
    required String societyId,
    required String adminName,
    required String title,
    required String? description,
    required double targetAmount,
    required String? endDate,
  }) async {
    await db.from('donation_campaigns').insert([
      {
        'title': title,
        'description': description,
        'target_amount': targetAmount,
        'created_by': adminName,
        'end_date': endDate,
        'society_id': societyId,
      },
    ]);
  }

  Future<void> insertDonations(List<Map<String, dynamic>> rows) async {
    await db.from('donation_payments').insert(rows);
  }

  Future<void> setCollectedAmount(String campaignId, double collected) async {
    await db.from('donation_campaigns').update({'collected_amount': collected}).eq('id', campaignId);
  }
}
