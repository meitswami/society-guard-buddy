import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/admin_user.dart';
import '../models/biometric_enrollment.dart';
import '../models/guard_session.dart';
import '../models/resident_user.dart';
import '../models/session_models.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'geofence_service.dart';
import 'guard_session_service.dart';

class BiometricLoginFailure implements Exception {
  BiometricLoginFailure(this.message);
  final String message;
}

/// Quick login via device biometrics + secure storage (native counterpart to web WebAuthn).
class BiometricLoginService {
  static const maxEnrollmentsPerUser = 3;
  static const _indexKey = 'kutumbika_bio_login_index';

  final _storage = const FlutterSecureStorage();
  final _biometric = BiometricService();
  final _auth = AuthService();
  final _geofence = GeofenceService();
  final _guardSessions = GuardSessionService();

  Future<List<BiometricEnrollment>> listEnrollments() async {
    if (kIsWeb) return const [];
    final raw = await _storage.read(key: _indexKey);
    if (raw == null || raw.isEmpty) return const [];

    final ids = (jsonDecode(raw) as List).cast<String>();
    final out = <BiometricEnrollment>[];
    for (final id in ids) {
      final row = await _storage.read(key: _enrollmentKey(id));
      if (row == null) continue;
      out.add(BiometricEnrollment.fromJson(jsonDecode(row) as Map<String, dynamic>));
    }
    return out;
  }

  Future<List<BiometricEnrollment>> matchingEnrollments({
    required String societyId,
    required String role,
    String? flatId,
  }) async {
    final all = await listEnrollments();
    return all
        .where((e) => e.matchesLogin(societyId: societyId, role: role, flatId: flatId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<({String role, String userDbId, bool allowed})?> userContextFromSession(
    AppSessionState session,
  ) async {
    switch (session) {
      case SessionResident(:final resident):
        return (role: 'resident', userDbId: resident.id, allowed: true);
      case SessionGuard(:final societyId, :final guard):
        final dbId = await _auth.fetchGuardDbId(
          societyId: societyId,
          guardId: guard.guardId,
        );
        if (dbId == null) return null;
        return (role: 'guard', userDbId: dbId, allowed: true);
      case SessionAdmin(:final admin):
        return (
          role: 'admin',
          userDbId: admin.id,
          allowed: admin.permissions.biometric,
        );
      default:
        return null;
    }
  }

  Future<bool> hasEnrollment({
    required String role,
    required String userDbId,
  }) async {
    final all = await listEnrollments();
    return all.any((e) => e.role == role && e.userDbId == userDbId);
  }

  Future<int> enrollmentCount({
    required String role,
    required String userDbId,
  }) async {
    final all = await listEnrollments();
    return all.where((e) => e.role == role && e.userDbId == userDbId).length;
  }

  Future<void> enroll({
    required String role,
    required String userDbId,
    required String displayName,
    required String societyId,
    required String societyName,
    String? flatId,
    String? flatNumber,
    String? guardId,
  }) async {
    if (kIsWeb) throw BiometricLoginFailure('Biometric login is not available on web');

    final supported = await _biometric.isDeviceSupported();
    if (!supported) {
      throw BiometricLoginFailure('Biometrics not available on this device');
    }

    final ok = await _biometric.authenticate(
      reason: 'Confirm to enable fingerprint login',
      biometricOnly: false,
    );
    if (!ok) throw BiometricLoginFailure('Biometric confirmation cancelled');

    final existing = await listEnrollments();
    final forUser = existing.where((e) => e.role == role && e.userDbId == userDbId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (forUser.length >= maxEnrollmentsPerUser) {
      final toRemove = forUser.take(forUser.length - maxEnrollmentsPerUser + 1);
      for (final old in toRemove) {
        await removeEnrollment(old.id);
      }
    }

    final enrollment = BiometricEnrollment(
      id: const Uuid().v4(),
      role: role,
      userDbId: userDbId,
      displayName: displayName,
      societyId: societyId,
      societyName: societyName,
      flatId: flatId,
      flatNumber: flatNumber,
      guardId: guardId,
      createdAt: DateTime.now(),
    );

    await _storage.write(
      key: _enrollmentKey(enrollment.id),
      value: jsonEncode(enrollment.toJson()),
    );

    final ids = existing.map((e) => e.id).toList()..add(enrollment.id);
    await _storage.write(key: _indexKey, value: jsonEncode(ids));

    await _biometric.setEnabled(true);
  }

  Future<void> enrollFromSession(AppSessionState session) async {
    switch (session) {
      case SessionResident(:final societyId, :final societyName, :final resident):
        await enroll(
          role: 'resident',
          userDbId: resident.id,
          displayName: resident.name,
          societyId: societyId,
          societyName: societyName,
          flatId: resident.flatId,
          flatNumber: resident.flatNumber,
        );
      case SessionGuard(:final societyId, :final societyName, :final guard):
        final dbId = await _auth.fetchGuardDbId(
          societyId: societyId,
          guardId: guard.guardId,
        );
        if (dbId == null) throw BiometricLoginFailure('Guard record not found');
        await enroll(
          role: 'guard',
          userDbId: dbId,
          displayName: guard.name,
          societyId: societyId,
          societyName: societyName,
          guardId: guard.guardId,
        );
      case SessionAdmin(:final societyId, :final societyName, :final admin):
        if (!admin.permissions.biometric) {
          throw BiometricLoginFailure('Biometric not enabled for your admin role');
        }
        await enroll(
          role: 'admin',
          userDbId: admin.id,
          displayName: admin.name,
          societyId: societyId,
          societyName: societyName,
        );
      default:
        throw BiometricLoginFailure('Not logged in');
    }
  }

  Future<void> removeEnrollment(String enrollmentId) async {
    await _storage.delete(key: _enrollmentKey(enrollmentId));
    final all = await listEnrollments();
    final ids = all.where((e) => e.id != enrollmentId).map((e) => e.id).toList();
    if (ids.isEmpty) {
      await _storage.delete(key: _indexKey);
    } else {
      await _storage.write(key: _indexKey, value: jsonEncode(ids));
    }
  }

  Future<void> removeAllForUser({
    required String role,
    required String userDbId,
  }) async {
    final all = await listEnrollments();
    for (final e in all.where((e) => e.role == role && e.userDbId == userDbId)) {
      await removeEnrollment(e.id);
    }
  }

  Future<BiometricLoginResult> loginWithBiometric({
    required String societyId,
    required String role,
    String? flatId,
    BiometricEnrollment? enrollment,
  }) async {
    if (kIsWeb) throw BiometricLoginFailure('Use password or OTP on web');

    final supported = await _biometric.isDeviceSupported();
    if (!supported) throw BiometricLoginFailure('Biometrics not available');

    final matches = await matchingEnrollments(
      societyId: societyId,
      role: role,
      flatId: flatId,
    );
    if (matches.isEmpty) {
      throw BiometricLoginFailure('Fingerprint login not set up for this account');
    }

    final picked = enrollment ?? matches.first;

    final ok = await _biometric.authenticate(
      reason: 'Sign in to Kutumbika',
      biometricOnly: false,
    );
    if (!ok) throw BiometricLoginFailure('Biometric sign-in cancelled');

    switch (role) {
      case 'resident':
        final resident = await _auth.fetchResidentById(picked.userDbId);
        if (resident == null) throw BiometricLoginFailure('Resident account not found');
        if (resident.flatId != flatId) {
          throw BiometricLoginFailure('This fingerprint login is for a different flat');
        }
        final flatSociety = await _auth.fetchFlatSocietyId(resident.flatId);
        if (flatSociety != societyId) {
          throw BiometricLoginFailure('Society mismatch');
        }
        return BiometricLoginResult.resident(
          societyId: societyId,
          societyName: picked.societyName,
          resident: resident,
        );

      case 'guard':
        await _geofence.isWithinGeofence(societyId);
        final guardRow = await _auth.fetchGuardByDbId(picked.userDbId);
        if (guardRow == null || guardRow.societyId != societyId) {
          throw BiometricLoginFailure('Guard account not found');
        }
        final shiftId = await _guardSessions.startShift(
          societyId: societyId,
          guard: guardRow.session,
        );
        if (shiftId == null) throw BiometricLoginFailure('Could not start guard shift');
        return BiometricLoginResult.guard(
          societyId: societyId,
          societyName: picked.societyName,
          guard: guardRow.session,
          shiftId: shiftId,
        );

      case 'admin':
        final admin = await _auth.fetchAdminById(picked.userDbId);
        if (admin == null || admin.societyId != societyId) {
          throw BiometricLoginFailure('Admin account not found');
        }
        if (!admin.permissions.biometric) {
          throw BiometricLoginFailure('Biometric login disabled for this admin');
        }
        return BiometricLoginResult.admin(
          societyId: societyId,
          societyName: picked.societyName,
          admin: admin,
        );

      default:
        throw BiometricLoginFailure('Unsupported role');
    }
  }

  String _enrollmentKey(String id) => 'kutumbika_bio_login_$id';
}

sealed class BiometricLoginResult {
  const BiometricLoginResult();

  factory BiometricLoginResult.resident({
    required String societyId,
    required String societyName,
    required ResidentUser resident,
  }) = BiometricLoginResident;

  factory BiometricLoginResult.guard({
    required String societyId,
    required String societyName,
    required GuardSession guard,
    required String shiftId,
  }) = BiometricLoginGuard;

  factory BiometricLoginResult.admin({
    required String societyId,
    required String societyName,
    required AdminUser admin,
  }) = BiometricLoginAdmin;
}

class BiometricLoginResident extends BiometricLoginResult {
  const BiometricLoginResident({
    required this.societyId,
    required this.societyName,
    required this.resident,
  });

  final String societyId;
  final String societyName;
  final ResidentUser resident;
}

class BiometricLoginGuard extends BiometricLoginResult {
  const BiometricLoginGuard({
    required this.societyId,
    required this.societyName,
    required this.guard,
    required this.shiftId,
  });

  final String societyId;
  final String societyName;
  final GuardSession guard;
  final String shiftId;
}

class BiometricLoginAdmin extends BiometricLoginResult {
  const BiometricLoginAdmin({
    required this.societyId,
    required this.societyName,
    required this.admin,
  });

  final String societyId;
  final String societyName;
  final AdminUser admin;
}
