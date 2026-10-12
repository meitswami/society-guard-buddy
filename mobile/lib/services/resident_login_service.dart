import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/guard_session.dart';
import '../models/resident_user.dart';
import '../utils/phone_utils.dart';

class ResidentLoginFailure implements Exception {
  ResidentLoginFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `guards` row used by OTP login (web `GuardRow` in `guardOtpLogin.ts`).
class GuardLoginRow {
  const GuardLoginRow({
    required this.id,
    required this.guardId,
    required this.name,
    required this.password,
    this.phone,
    this.authMode,
    this.societyId,
  });

  final String id;
  final String guardId;
  final String name;
  final String password;
  final String? phone;
  final String? authMode;
  final String? societyId;

  factory GuardLoginRow.fromRow(Map<String, dynamic> r) => GuardLoginRow(
        id: r['id'] as String,
        guardId: r['guard_id'] as String,
        name: (r['name'] as String?) ?? '',
        password: (r['password'] as String?) ?? '',
        phone: r['phone'] as String?,
        authMode: r['auth_mode'] as String?,
        societyId: r['society_id'] as String?,
      );

  GuardSession toSession() => GuardSession(guardId: guardId, name: name, password: password);
}

enum GuardOtpFailureReason { notFound, passwordMode, noPhone }

/// Web `GuardOtpLookupResult`.
sealed class GuardOtpLookupResult {
  const GuardOtpLookupResult();
}

class GuardOtpFound extends GuardOtpLookupResult {
  const GuardOtpFound(this.guard);
  final GuardLoginRow guard;
}

class GuardOtpNotFound extends GuardOtpLookupResult {
  const GuardOtpNotFound(this.reason);
  final GuardOtpFailureReason reason;
}

/// Pure decision of web `findGuardForOtpLogin` over the society's guard rows:
/// phone must have 10 digits, match a guard's registered phone (last 10 digits),
/// and that guard must use `auth_mode = 'otp'` — otherwise `password_mode`.
GuardOtpLookupResult classifyGuardOtpCandidates(List<GuardLoginRow> rows, String phone) {
  final normalized = normalizeLoginPhone(phone);
  if (normalized.length < 10) return const GuardOtpNotFound(GuardOtpFailureReason.notFound);
  if (rows.isEmpty) return const GuardOtpNotFound(GuardOtpFailureReason.notFound);
  final withPhone = rows.where((g) {
    final p = g.phone;
    return p != null && p.isNotEmpty && normalizeLoginPhone(p) == normalized;
  }).toList();
  if (withPhone.isEmpty) return const GuardOtpNotFound(GuardOtpFailureReason.notFound);
  for (final g in withPhone) {
    if (g.authMode == 'otp') return GuardOtpFound(g);
  }
  return const GuardOtpNotFound(GuardOtpFailureReason.passwordMode);
}

/// Port of web OTP post-verify lookups (`societiesLogin`, `guardOtpLogin`).
class ResidentLoginService {
  SupabaseClient get _db => SupabaseBootstrap.client;

  /// Web `findGuardForOtpLogin(phone, societyId)`.
  Future<GuardOtpLookupResult> lookupGuardForOtp(String phone, String societyId) async {
    final normalized = normalizeLoginPhone(phone);
    if (normalized.length < 10 || !Env.isConfigured) {
      return const GuardOtpNotFound(GuardOtpFailureReason.notFound);
    }
    List<GuardLoginRow> rows;
    try {
      final data = await _db.from('guards').select('*').eq('society_id', societyId);
      rows = (data as List).map((g) => GuardLoginRow.fromRow(Map<String, dynamic>.from(g as Map))).toList();
    } on PostgrestException {
      return const GuardOtpNotFound(GuardOtpFailureReason.notFound);
    }
    return classifyGuardOtpCandidates(rows, normalized);
  }

  /// The flat id this phone already belongs to inside the society (null when none or when
  /// several rows match — web `maybeSingle()` returns no data then).
  Future<String?> otherFlatForPhone({required String phone, required String societyId}) async {
    if (!Env.isConfigured) return null;
    final flats = await _db.from('flats').select('id').eq('society_id', societyId);
    final flatIds = (flats as List).map((f) => (f as Map)['id'] as String).toList();
    if (flatIds.isEmpty) return null;
    try {
      final other = await _db
          .from('resident_users')
          .select('flat_id')
          .eq('phone', normalizeLoginPhone(phone))
          .inFilter('flat_id', flatIds)
          .maybeSingle();
      return other?['flat_id'] as String?;
    } on PostgrestException {
      return null;
    }
  }

  /// Older API: resident for a verified phone on the chosen flat, or [ResidentLoginFailure].
  Future<ResidentUser> findResidentForOtp({
    required String phone,
    required String societyId,
    required String flatId,
  }) async {
    if (!Env.isConfigured) {
      throw ResidentLoginFailure('Supabase not configured');
    }

    final normalized = normalizeLoginPhone(phone);
    final other = await otherFlatForPhone(phone: normalized, societyId: societyId);
    if (other != null && other != flatId) {
      throw ResidentLoginFailure('This phone is registered to another flat');
    }

    final flatsInSoc = await _db.from('flats').select('id').eq('society_id', societyId);
    final flatIds = (flatsInSoc as List).map((f) => (f as Map)['id'] as String).toList();
    if (flatIds.isEmpty) {
      throw ResidentLoginFailure('No resident account for this phone.');
    }

    Map<String, dynamic>? resident;
    try {
      resident = await _db.from('resident_users').select('*').eq('phone', normalized).inFilter('flat_id', flatIds).maybeSingle();
    } on PostgrestException {
      resident = null;
    }

    if (resident == null) {
      throw ResidentLoginFailure('No resident account for this phone.');
    }
    if (resident['flat_id'] != flatId) {
      throw ResidentLoginFailure('This phone is registered to another flat');
    }
    return ResidentUser.fromRow(Map<String, dynamic>.from(resident));
  }

  /// Older API: OTP guard for a verified phone, or [ResidentLoginFailure].
  Future<GuardSession> findGuardForOtp({
    required String phone,
    required String societyId,
  }) async {
    if (!Env.isConfigured) {
      throw ResidentLoginFailure('Supabase not configured');
    }
    final result = await lookupGuardForOtp(phone, societyId);
    return switch (result) {
      GuardOtpFound(:final guard) => guard.toSession(),
      GuardOtpNotFound(reason: GuardOtpFailureReason.passwordMode) =>
        throw ResidentLoginFailure('This guard uses ID & password login'),
      GuardOtpNotFound() => throw ResidentLoginFailure('Phone not registered for any guard'),
    };
  }
}
