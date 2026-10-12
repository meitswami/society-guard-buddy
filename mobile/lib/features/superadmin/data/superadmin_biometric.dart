import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/supabase/db.dart';
import 'superadmin_models.dart';

/// Superadmin fingerprint / face login — native counterpart of web `useBiometric` +
/// `BiometricSetup` for `user_type = 'superadmin'`.
///
/// The web registers a WebAuthn passkey and stores it in `biometric_credentials`
/// (max 3 per user, oldest replaced). On the phone the OS biometric prompt
/// (`local_auth`) unlocks a random device credential kept in secure storage; the same
/// credential id is registered in `biometric_credentials`, so the device shows up in
/// (and can be removed from) the web and mobile device lists, and removing it there
/// revokes the phone's quick login.
class SuperadminBiometric {
  SuperadminBiometric({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  static const String userType = 'superadmin';
  static const int maxCredentialsPerUser = 3;
  static const String _storageKey = 'kutumbika_superadmin_bio_v1';

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  /// Web `isAvailable()` — device has biometrics (or a device credential) to verify the user.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _verifyUser(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// Locally stored `{credentialId, userId}` pairs (one per superadmin on this device).
  Future<List<Map<String, String>>> _local() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (e is Map && e['credentialId'] is String && e['userId'] is String)
            {'credentialId': e['credentialId'] as String, 'userId': e['userId'] as String},
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocal(List<Map<String, String>> entries) async {
    if (entries.isEmpty) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: jsonEncode(entries));
    }
  }

  /// True when this device holds a superadmin credential (login screen shows the button).
  Future<bool> hasLocalCredential() async => (await _local()).isNotEmpty;

  Future<String?> _localCredentialFor(String userId) async {
    for (final e in await _local()) {
      if (e['userId'] == userId) return e['credentialId'];
    }
    return null;
  }

  static String _newCredentialId() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(32, (_) => r.nextInt(256)));
  }

  /// Web `register(userType, userId, userName)`.
  Future<bool> register(String userId, String userName) async {
    if (!dbReady) return false;
    final ok = await _verifyUser('Confirm to enable fingerprint login');
    if (!ok) return false;
    try {
      final credentialId = await _localCredentialFor(userId) ?? _newCredentialId();
      final existing = rowsOf(await db
          .from('biometric_credentials')
          .select('id, credential_id, created_at')
          .eq('user_type', userType)
          .eq('user_id', userId)
          .order('created_at', ascending: true));
      final duplicate = existing.any((c) => c['credential_id'] == credentialId);
      if (!duplicate) {
        if (existing.length >= maxCredentialsPerUser) {
          final toDelete = existing.length - maxCredentialsPerUser + 1;
          final ids = existing.take(toDelete).map((c) => '${c['id']}').toList();
          if (ids.isNotEmpty) await db.from('biometric_credentials').delete().inFilter('id', ids);
        }
        await db.from('biometric_credentials').insert({
          'user_type': userType,
          'user_id': userId,
          'credential_id': credentialId,
          'public_key': 'native-local-auth:${kIsWeb ? 'web' : Platform.operatingSystem}',
        });
      }
      final local = (await _local()).where((e) => e['userId'] != userId).toList()
        ..add({'credentialId': credentialId, 'userId': userId});
      await _saveLocal(local);
      return true;
    } catch (e) {
      debugPrint('Biometric registration failed: $e');
      return false;
    }
  }

  /// Web `authenticate('superadmin')` — returns the matching `super_admins.id`, or null.
  Future<String?> authenticate() async {
    if (!dbReady) return null;
    final local = await _local();
    if (local.isEmpty) return null;
    final ok = await _verifyUser('Sign in to the Super Admin panel');
    if (!ok) return null;
    try {
      final ids = local.map((e) => e['credentialId']!).toList();
      final rows = rowsOf(await db
          .from('biometric_credentials')
          .select('credential_id, user_id')
          .eq('user_type', userType)
          .inFilter('credential_id', ids));
      final valid = {for (final r in rows) '${r['credential_id']}': '${r['user_id']}'};
      // Credentials removed on the server (web or another phone) no longer unlock this device.
      final kept = local.where((e) => valid.containsKey(e['credentialId'])).toList();
      if (kept.length != local.length) await _saveLocal(kept);
      for (final e in kept) {
        final userId = valid[e['credentialId']];
        if (userId != null && userId.isNotEmpty) return userId;
      }
      return null;
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return null;
    }
  }

  /// Web `listCredentials(userType, userId)` (newest first) + which one is this phone.
  Future<List<BiometricDevice>> listCredentials(String userId) async {
    if (!dbReady) return const [];
    final mine = await _localCredentialFor(userId);
    final rows = rowsOf(await db
        .from('biometric_credentials')
        .select('id, credential_id, created_at')
        .eq('user_type', userType)
        .eq('user_id', userId)
        .order('created_at', ascending: false));
    return [
      for (final r in rows)
        BiometricDevice(
          id: '${r['id']}',
          credentialId: '${r['credential_id'] ?? ''}',
          createdAt: '${r['created_at'] ?? ''}',
          thisDevice: mine != null && r['credential_id'] == mine,
        ),
    ];
  }

  /// Web `removeCredential(rowId)`; forgets the local key when it was this phone's.
  Future<bool> removeCredential(BiometricDevice device, String userId) async {
    try {
      await db.from('biometric_credentials').delete().eq('id', device.id);
      if (device.thisDevice) {
        await _saveLocal((await _local()).where((e) => e['userId'] != userId).toList());
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
