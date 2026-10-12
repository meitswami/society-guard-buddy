import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../../../core/supabase/db.dart';

/// `audit_logs` writer for the people module — port of web `logAuditEvent`
/// (`src/lib/auditLogger.ts`). Best-effort: never throws.
abstract final class PeopleAudit {
  static Map<String, dynamic> _deviceInfo() {
    if (kIsWeb)
      return {
        'browser': 'web',
        'os': 'Unknown',
        'platform': 'web',
        'isMobile': false
      };
    return {
      'browser': 'Kutumbika app',
      'os': Platform.isAndroid
          ? 'Android'
          : (Platform.isIOS ? 'iOS' : Platform.operatingSystem),
      'platform': Platform.operatingSystem,
      'language': Platform.localeName,
      'isMobile': Platform.isAndroid || Platform.isIOS,
    };
  }

  static String _userAgent() {
    if (kIsWeb) return 'Kutumbika mobile (web)';
    return 'Kutumbika mobile (${Platform.operatingSystem} ${Platform.operatingSystemVersion})';
  }

  static Future<void> log({
    required String? societyId,
    required String eventType,
    required String userType,
    String? userId,
    String? userName,
    Map<String, dynamic> details = const {},
    String severity = 'info',
  }) async {
    if (!dbReady) return;
    try {
      await db.from('audit_logs').insert({
        'society_id': societyId,
        'event_type': eventType,
        'user_type': userType,
        'user_id': (userId == null || userId.isEmpty) ? null : userId,
        'user_name': (userName == null || userName.isEmpty) ? null : userName,
        'ip_address': 'unknown',
        'user_agent': _userAgent(),
        'device_info': _deviceInfo(),
        'details': details,
        'severity': severity,
      });
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }

  /// Web `auditPasswordReset(userType, userId, userName, resetBy)`.
  static Future<void> passwordReset({
    required String? societyId,
    required String userType,
    required String userId,
    required String userName,
    required String resetBy,
  }) =>
      log(
        societyId: societyId,
        eventType: 'password_reset',
        userType: userType,
        userId: userId,
        userName: userName,
        details: {'reset_by': resetBy},
        severity: 'warning',
      );
}

/// Web `verifyAdminPassword` (`src/lib/adminVerify.ts`).
Future<bool> verifyAdminPassword(String adminId, String password) async {
  final trimmed = password.trim();
  if (trimmed.isEmpty || !dbReady) return false;
  try {
    final row = await db
        .from('admins')
        .select('id')
        .eq('id', adminId)
        .eq('password', trimmed)
        .maybeSingle();
    return row != null;
  } catch (e) {
    debugPrint('verifyAdminPassword: $e');
    return false;
  }
}
