import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/flat_member.dart';
import '../models/resident_user.dart';
import '../utils/member_categories.dart';
import '../utils/phone_utils.dart';

class ResidentOnboardingFailure implements Exception {
  ResidentOnboardingFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What first-time login must do for a flat (web `completeResidentOtpOnboarding`).
enum OnboardingStepKind {
  /// Flat has no members yet → ask for the first primary (owner) name.
  firstPrimary,

  /// Members exist but none can be primary → "Household not set up".
  noPrimary,

  /// The primary member already has this phone → create / refresh the login row.
  linkPrimary,

  /// The primary member has no phone → ask "Are you '{name}'?"; if not, add a new member.
  claimPrimary,

  /// The primary has another phone → the caller adds themselves as a household member.
  newMember,
}

class OnboardingDecision {
  const OnboardingDecision(this.kind, {this.primary});
  final OnboardingStepKind kind;
  final FlatMember? primary;
}

/// Web `pickPrimaryMember`: the `is_primary` member, else the first member whose relation
/// may be primary (household, not tenant / staff).
FlatMember? pickPrimaryMember(List<FlatMember> members) {
  for (final m in members) {
    if (m.isPrimary) return m;
  }
  for (final m in members) {
    if (allowsPrimaryMember(m.relation)) return m;
  }
  return null;
}

/// Pure decision of web `completeResidentOtpOnboarding` once no login row exists yet.
OnboardingDecision decideResidentOnboarding({required List<FlatMember> members, required String phone}) {
  final normalized = normalizeLoginPhone(phone);
  if (members.isEmpty) return const OnboardingDecision(OnboardingStepKind.firstPrimary);
  final primary = pickPrimaryMember(members);
  if (primary == null) return const OnboardingDecision(OnboardingStepKind.noPrimary);
  final rawPhone = primary.phone ?? '';
  final primaryPhone = rawPhone.isNotEmpty ? normalizeLoginPhone(rawPhone) : '';
  if (primaryPhone.isNotEmpty && primaryPhone == normalized) {
    return OnboardingDecision(OnboardingStepKind.linkPrimary, primary: primary);
  }
  if (rawPhone.isEmpty || primaryPhone.isEmpty) {
    return OnboardingDecision(OnboardingStepKind.claimPrimary, primary: primary);
  }
  return OnboardingDecision(OnboardingStepKind.newMember, primary: primary);
}

/// `members` insert for the first primary of an empty flat.
Map<String, dynamic> buildFirstPrimaryPayload({
  required String flatId,
  required String name,
  required String phone,
  String? gender,
}) =>
    {
      'flat_id': flatId,
      'name': name,
      'phone': normalizeLoginPhone(phone),
      'relation': 'owner',
      'gender': (gender == null || gender.isEmpty) ? null : gender,
      'is_primary': true,
    };

/// `members` insert for a new household / staff member (web `swalNewHouseholdMember` result).
/// Staff and other restricted categories carry ID photos and police verification.
Map<String, dynamic> buildNewMemberPayload({
  required String flatId,
  required String name,
  required String phone,
  required String relation,
  String? gender,
  String? idPhotoFront,
  String? idPhotoBack,
  String? policeVerification,
}) {
  final restricted = isRestrictedMemberCategory(relation);
  return {
    'flat_id': flatId,
    'name': name,
    'phone': normalizeLoginPhone(phone),
    'relation': relation,
    'gender': (gender == null || gender.isEmpty) ? null : gender,
    'is_primary': false,
    'id_photo_front': restricted ? idPhotoFront : null,
    'id_photo_back': restricted && (idPhotoBack?.isNotEmpty ?? false) ? idPhotoBack : null,
    'police_verification': restricted ? (policeVerification ?? 'pending') : null,
  };
}

const _pwAnimals = [
  'Tiger', 'Eagle', 'Panda', 'Lion', 'Fox', 'Wolf', 'Bear', 'Hawk', 'Deer', 'Owl', //
  'Dolphin', 'Falcon', 'Cobra', 'Rhino', 'Shark',
];
const _pwFruits = [
  'Mango', 'Apple', 'Grape', 'Peach', 'Lemon', 'Berry', 'Melon', 'Guava', 'Plum', 'Cherry', //
  'Kiwi', 'Papaya', 'Fig', 'Olive', 'Coconut',
];
const _pwSymbols = ['@', '#', r'$', '!', '&', '*', '%'];

/// Web `generateFlatPassword`: animal + fruit + 2-digit number + symbol (same word lists).
String generateWebFlatPassword([Random? random]) {
  final r = random ?? Random();
  final animal = _pwAnimals[r.nextInt(_pwAnimals.length)];
  final fruit = _pwFruits[r.nextInt(_pwFruits.length)];
  final num = 10 + r.nextInt(90);
  final sym = _pwSymbols[r.nextInt(_pwSymbols.length)];
  return '$animal$fruit$num$sym';
}

class ResidentOnboardingService {
  SupabaseClient get _db => SupabaseBootstrap.client;

  /// Existing `resident_users` row for flat + phone.
  Future<ResidentUser?> findExistingUser(String flatId, String phone) async {
    if (!Env.isConfigured) return null;
    final normalized = normalizeLoginPhone(phone);
    try {
      final row = await _db.from('resident_users').select('*').eq('flat_id', flatId).eq('phone', normalized).maybeSingle();
      if (row == null) return null;
      return ResidentUser.fromRow(Map<String, dynamic>.from(row));
    } on PostgrestException {
      return null;
    }
  }

  /// `members.select('*').eq('flat_id', …)` — same (unordered) query as the web.
  Future<List<FlatMember>> fetchFlatMembers(String flatId) async {
    if (!Env.isConfigured) return const [];
    final rows = await _db.from('members').select('*').eq('flat_id', flatId);
    return (rows as List).map((r) => FlatMember.fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  /// Older API (primary first).
  Future<List<FlatMember>> fetchMembers(String flatId) async {
    if (!Env.isConfigured) return const [];
    final rows = await _db.from('members').select('*').eq('flat_id', flatId).order('is_primary', ascending: false);
    return (rows as List).map((r) => FlatMember.fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  FlatMember? pickPrimary(List<FlatMember> members) => pickPrimaryMember(members);

  /// Inserts a `members` row; throws [ResidentOnboardingFailure] with the database message.
  Future<void> insertMember(Map<String, dynamic> payload) async {
    if (!Env.isConfigured) throw ResidentOnboardingFailure('Supabase not configured');
    try {
      await _db.from('members').insert(payload);
    } on PostgrestException catch (e) {
      throw ResidentOnboardingFailure(e.message);
    }
  }

  /// `members.update({ phone })` for the primary who claims this number.
  Future<void> updateMemberPhone({required String memberId, required String phone}) async {
    if (!Env.isConfigured) throw ResidentOnboardingFailure('Supabase not configured');
    try {
      await _db.from('members').update({'phone': normalizeLoginPhone(phone)}).eq('id', memberId);
    } on PostgrestException catch (e) {
      throw ResidentOnboardingFailure(e.message);
    }
  }

  /// `flats.update({ owner_name, is_occupied: true })` after the first primary is added.
  Future<void> markFlatOwner({required String flatId, required String ownerName}) async {
    if (!Env.isConfigured) return;
    await _db.from('flats').update({'owner_name': ownerName, 'is_occupied': true}).eq('id', flatId);
  }

  /// Web `ensureResidentUserRow`: refreshes the name on an existing login row, or inserts one
  /// with the flat's shared password (or a generated one). Null when the insert fails.
  Future<ResidentUser?> ensureResidentUserRow({
    required String flatId,
    required String flatNumber,
    required String phone,
    required String name,
    required bool mustChangePassword,
  }) async {
    if (!Env.isConfigured) return null;
    final normalized = normalizeLoginPhone(phone);
    Map<String, dynamic>? existing;
    try {
      existing = await _db.from('resident_users').select('*').eq('flat_id', flatId).eq('phone', normalized).maybeSingle();
    } on PostgrestException {
      existing = null;
    }
    if (existing != null) {
      await _db.from('resident_users').update({'name': name}).eq('id', existing['id'] as String);
      return ResidentUser(
        id: existing['id'] as String,
        name: name,
        phone: normalized,
        flatId: existing['flat_id'] as String,
        flatNumber: (existing['flat_number'] as String?) ?? flatNumber,
      );
    }

    Map<String, dynamic>? flatMate;
    try {
      flatMate = await _db.from('resident_users').select('password').eq('flat_id', flatId).limit(1).maybeSingle();
    } on PostgrestException {
      flatMate = null;
    }
    final password = (flatMate?['password'] as String?) ?? generateWebFlatPassword();

    try {
      final ins = await _db
          .from('resident_users')
          .insert({
            'flat_id': flatId,
            'flat_number': flatNumber,
            'name': name,
            'phone': normalized,
            'password': password,
            'must_change_password': mustChangePassword,
          })
          .select('*')
          .single();
      return ResidentUser.fromRow(Map<String, dynamic>.from(ins));
    } on PostgrestException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Older convenience API (kept for existing callers)
  // ---------------------------------------------------------------------------

  Future<ResidentUser> createFirstPrimary({
    required String flatId,
    required String flatNumber,
    required String phone,
    required String name,
    String? gender,
  }) async {
    await insertMember(buildFirstPrimaryPayload(flatId: flatId, name: name.trim(), phone: phone, gender: gender));
    await markFlatOwner(flatId: flatId, ownerName: name.trim());
    final user = await ensureResidentUserRow(
      flatId: flatId,
      flatNumber: flatNumber,
      phone: phone,
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
    await updateMemberPhone(memberId: memberId, phone: phone);
    final user = await ensureResidentUserRow(
      flatId: flatId,
      flatNumber: flatNumber,
      phone: phone,
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
    if (!allowsResidentLogin(relation)) {
      throw ResidentOnboardingFailure('This role cannot use the resident app. Ask the primary member.');
    }
    await insertMember(buildNewMemberPayload(
      flatId: flatId,
      name: name.trim(),
      phone: phone,
      relation: relation,
      gender: gender,
    ));
    final user = await ensureResidentUserRow(
      flatId: flatId,
      flatNumber: flatNumber,
      phone: phone,
      name: name.trim(),
      mustChangePassword: false,
    );
    if (user == null) throw ResidentOnboardingFailure('Could not create login');
    return user;
  }
}
