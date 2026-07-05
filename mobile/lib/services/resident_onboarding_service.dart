import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/flat_member.dart';
import '../models/resident_user.dart';
import '../utils/member_categories.dart';
import '../utils/password_generator.dart';
import '../utils/phone_utils.dart';

class ResidentOnboardingFailure implements Exception {
  ResidentOnboardingFailure(this.message);
  final String message;
}

class ResidentOnboardingService {
  Future<ResidentUser?> findExistingUser(String flatId, String phone) async {
    if (!Env.isConfigured) return null;
    final normalized = normalizeLoginPhone(phone);
    final row = await SupabaseBootstrap.client
        .from('resident_users')
        .select('*')
        .eq('flat_id', flatId)
        .eq('phone', normalized)
        .maybeSingle();
    if (row == null) return null;
    return ResidentUser.fromRow(Map<String, dynamic>.from(row));
  }

  Future<ResidentUser> createFirstPrimary({
    required String flatId,
    required String flatNumber,
    required String phone,
    required String name,
    String? gender,
  }) async {
    if (!Env.isConfigured) throw ResidentOnboardingFailure('Supabase not configured');

    final normalized = normalizeLoginPhone(phone);
    await SupabaseBootstrap.client.from('members').insert({
      'flat_id': flatId,
      'name': name.trim(),
      'phone': normalized,
      'relation': 'owner',
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      'is_primary': true,
    });
    await SupabaseBootstrap.client.from('flats').update({
      'owner_name': name.trim(),
      'is_occupied': true,
    }).eq('id', flatId);

    final user = await _ensureResidentUserRow(
      flatId: flatId,
      flatNumber: flatNumber,
      phone: normalized,
      name: name.trim(),
      mustChangePassword: true,
    );
    if (user == null) throw ResidentOnboardingFailure('Could not create login');
    return user;
  }

  Future<ResidentUser> linkPrimaryPhone({
    required String memberId,
    required String flatId,
    required String flatNumber,
    required String phone,
    required String name,
  }) async {
    if (!Env.isConfigured) throw ResidentOnboardingFailure('Supabase not configured');

    final normalized = normalizeLoginPhone(phone);
    await SupabaseBootstrap.client.from('members').update({'phone': normalized}).eq('id', memberId);

    final user = await _ensureResidentUserRow(
      flatId: flatId,
      flatNumber: flatNumber,
      phone: normalized,
      name: name,
      mustChangePassword: false,
    );
    if (user == null) throw ResidentOnboardingFailure('Could not create login');
    return user;
  }

  Future<ResidentUser> addHouseholdMemberAndLogin({
    required String flatId,
    required String flatNumber,
    required String phone,
    required String name,
    required String relation,
    String? gender,
  }) async {
    if (!Env.isConfigured) throw ResidentOnboardingFailure('Supabase not configured');

    if (!allowsResidentLogin(relation)) {
      throw ResidentOnboardingFailure('This role cannot use the resident app. Ask the primary member.');
    }

    final normalized = normalizeLoginPhone(phone);
    await SupabaseBootstrap.client.from('members').insert({
      'flat_id': flatId,
      'name': name.trim(),
      'phone': normalized,
      'relation': relation,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      'is_primary': false,
    });

    final user = await _ensureResidentUserRow(
      flatId: flatId,
      flatNumber: flatNumber,
      phone: normalized,
      name: name.trim(),
      mustChangePassword: false,
    );
    if (user == null) throw ResidentOnboardingFailure('Could not create login');
    return user;
  }

  Future<List<FlatMember>> fetchMembers(String flatId) async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseBootstrap.client
        .from('members')
        .select('*')
        .eq('flat_id', flatId)
        .order('is_primary', ascending: false);
    return (rows as List)
        .map((r) => FlatMember.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  FlatMember? pickPrimary(List<FlatMember> members) {
    final prim = members.where((m) => m.isPrimary).toList();
    if (prim.isNotEmpty) return prim.first;
    final household = members.where((m) => allowsPrimaryMember(m.relation)).toList();
    return household.isNotEmpty ? household.first : null;
  }

  Future<ResidentUser?> _ensureResidentUserRow({
    required String flatId,
    required String flatNumber,
    required String phone,
    required String name,
    required bool mustChangePassword,
  }) async {
    final existing = await SupabaseBootstrap.client
        .from('resident_users')
        .select('*')
        .eq('flat_id', flatId)
        .eq('phone', phone)
        .maybeSingle();
    if (existing != null) {
      await SupabaseBootstrap.client.from('resident_users').update({'name': name}).eq('id', existing['id']);
      return ResidentUser.fromRow(Map<String, dynamic>.from(existing));
    }

    final flatMate = await SupabaseBootstrap.client
        .from('resident_users')
        .select('password')
        .eq('flat_id', flatId)
        .limit(1)
        .maybeSingle();
    final password = flatMate?['password'] as String? ?? generateFlatPassword();

    final ins = await SupabaseBootstrap.client
        .from('resident_users')
        .insert({
          'flat_id': flatId,
          'flat_number': flatNumber,
          'name': name,
          'phone': phone,
          'password': password,
          'must_change_password': mustChangePassword,
        })
        .select('*')
        .single();

    return ResidentUser.fromRow(Map<String, dynamic>.from(ins));
  }
}
