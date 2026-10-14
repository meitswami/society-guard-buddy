import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/flat_row.dart';

class SocietyRow {
  const SocietyRow({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;

  factory SocietyRow.fromRow(Map<String, dynamic> r) => SocietyRow(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        logoUrl: r['logo_url'] as String?,
      );
}

/// Thrown when the society list request fails (web `new Error('Could not load societies')`).
class SocietyLoadException implements Exception {
  const SocietyLoadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Delay after a failed / empty attempt `attemptIndex` (0-based): 800 ms × 2^i,
/// exactly like web `fetchActiveSocietiesWithRetry` (800, 1600, 3200, 6400 ms).
Duration societyRetryDelay(int attemptIndex) => Duration(milliseconds: 800 * (1 << attemptIndex));

/// Generic port of the web retry loop in `societiesLogin.ts`:
/// - returns as soon as an attempt yields rows, or on the last attempt (even when empty);
/// - remembers the last error and waits with exponential backoff between attempts;
/// - throws the last error when the final attempt failed.
Future<List<T>> fetchListWithRetry<T>(
  Future<List<T>> Function() fetch, {
  int attempts = 4,
  Future<void> Function(Duration delay)? wait,
  void Function(int attempt, Object error)? onAttemptFailed,
}) async {
  final sleep = wait ?? (Duration d) => Future<void>.delayed(d);
  Object? lastError;
  for (var i = 0; i < attempts; i++) {
    try {
      final rows = await fetch();
      if (rows.isNotEmpty || i == attempts - 1) return rows;
    } catch (e) {
      lastError = e;
      onAttemptFailed?.call(i + 1, e);
    }
    await sleep(societyRetryDelay(i));
  }
  throw lastError ?? const SocietyLoadException('Could not load societies');
}

/// Port of `src/lib/societiesLogin.ts` plus the flat lookups the login screens need.
class SocietyService {
  SupabaseClient get _db => SupabaseBootstrap.client;

  /// Active societies (id, name, logo) — empty when Supabase is not configured.
  Future<List<SocietyRow>> fetchActiveSocieties() async {
    if (!Env.isConfigured) return const [];

    final rows = await _db.from('societies').select('id, name, logo_url').eq('is_active', true).order('name', ascending: true);

    return (rows as List).map((r) => SocietyRow.fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  /// Web `fetchActiveSocietiesByName`: active societies A–Z. Throws when the request fails,
  /// so callers can show an error instead of an empty list.
  Future<List<SocietyRow>> fetchActiveSocietiesByName() async {
    if (!Env.isConfigured) return const [];
    try {
      final rows = await _db.from('societies').select('id, name').eq('is_active', true).order('name', ascending: true);
      return (rows as List).map((r) => SocietyRow.fromRow(Map<String, dynamic>.from(r as Map))).toList();
    } on PostgrestException catch (e) {
      throw SocietyLoadException(e.message.isNotEmpty ? e.message : 'Could not load societies');
    }
  }

  /// Web `fetchActiveSocietiesWithRetry(attempts = 4)` — the first request on a freshly
  /// opened app often fails while the network is still coming up.
  Future<List<SocietyRow>> fetchActiveSocietiesWithRetry({int attempts = 4}) async {
    // Demo builds without `.env`: nothing to retry against.
    if (!Env.isConfigured) return const [];
    return fetchListWithRetry<SocietyRow>(
      fetchActiveSocietiesByName,
      attempts: attempts,
      onAttemptFailed: (attempt, e) => debugPrint('[societies] load attempt $attempt failed: $e'),
    );
  }

  /// Flats of a society for the login flat picker (`id, flat_number`, ordered by flat number).
  Future<List<FlatRow>> fetchLoginFlats(String societyId) async {
    if (!Env.isConfigured) return const [];
    final rows = await _db.from('flats').select('id, flat_number').eq('society_id', societyId).order('flat_number', ascending: true);
    return (rows as List).map((r) => FlatRow.fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  /// Ids of every flat in the society (`flats.select('id').eq('society_id', …)`).
  Future<List<String>> fetchSocietyFlatIds(String societyId) async {
    if (!Env.isConfigured) return const [];
    final rows = await _db.from('flats').select('id').eq('society_id', societyId);
    return (rows as List).map((r) => (r as Map)['id'] as String).toList();
  }

  /// Web `getResidentByPhoneInSociety`: the `resident_users` row for this phone in any flat
  /// of the society (null when none — or when the phone is on several flats, like web
  /// `maybeSingle()` returning no data).
  Future<Map<String, dynamic>?> getResidentByPhoneInSociety(String phone, String societyId) async {
    final ids = await fetchSocietyFlatIds(societyId);
    if (ids.isEmpty) return null;
    try {
      final row = await _db.from('resident_users').select('*').eq('phone', phone).inFilter('flat_id', ids).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } on PostgrestException {
      return null;
    }
  }

  /// Society display name (falls back to empty when unknown).
  Future<String> fetchSocietyName(String societyId) async {
    if (!Env.isConfigured) return '';
    try {
      final row = await _db.from('societies').select('name').eq('id', societyId).maybeSingle();
      return (row?['name'] as String?) ?? '';
    } on PostgrestException {
      return '';
    }
  }
}
