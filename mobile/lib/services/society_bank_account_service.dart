import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/society_bank_account.dart';

class SocietyBankAccountService {
  Future<SocietyBankAccount?> fetchPrimary(String societyId) async {
    if (!Env.isConfigured) return null;

    final row = await SupabaseBootstrap.client
        .from('society_bank_accounts')
        .select(
          'id, society_id, bank_name, account_holder_name, account_number, ifsc, branch_name, upi_vpa',
        )
        .eq('society_id', societyId)
        .eq('is_active', true)
        .eq('is_primary', true)
        .maybeSingle();

    if (row == null) return null;
    return SocietyBankAccount.fromRow(Map<String, dynamic>.from(row));
  }
}
