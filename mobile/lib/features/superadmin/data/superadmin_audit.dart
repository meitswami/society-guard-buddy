import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/supabase/db.dart';

/// Port of `src/lib/auditLogger.ts` (`logAuditEvent` + helpers) for the Superadmin
/// screens: inserts into `audit_logs` with the client IP (ipify, 3 s timeout),
/// a user agent string and device info. Never throws.
abstract final class SuperadminAudit {
  static String? _userAgent;

  static Future<String> _clientIp() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.getUrl(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 3));
      final data = jsonDecode(body);
      final ip = data is Map ? data['ip'] : null;
      return ip is String && ip.isNotEmpty ? ip : 'unknown';
    } catch (_) {
      return 'unknown';
    } finally {
      client.close(force: true);
    }
  }

  static String _os() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  static Future<String> _agent() async {
    if (_userAgent != null) return _userAgent!;
    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    final osVersion = kIsWeb ? '' : Platform.operatingSystemVersion;
    _userAgent = 'KutumbikaMobile/$version (Flutter; ${_os()} $osVersion)'.trim();
    return _userAgent!;
  }

  static Map<String, dynamic> _deviceInfo() {
    final os = _os();
    return {
      'browser': 'Kutumbika app',
      'os': os,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'language': kIsWeb ? 'unknown' : Platform.localeName,
      'isMobile': os == 'Android' || os == 'iOS',
    };
  }

  /// Web `logAuditEvent(event)`.
  static Future<void> log({
    required String eventType,
    String userType = 'superadmin',
    String? userId,
    String? userName,
    Map<String, dynamic>? details,
    String severity = 'info',
    String? societyId,
  }) async {
    if (!dbReady) return;
    try {
      final ip = await _clientIp();
      await db.from('audit_logs').insert({
        'society_id': societyId,
        'event_type': eventType,
        'user_type': userType,
        'user_id': userId,
        'user_name': userName,
        'ip_address': ip,
        'user_agent': await _agent(),
        'device_info': _deviceInfo(),
        'details': details ?? <String, dynamic>{},
        'severity': severity,
      });
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }

  /// Web `auditLoginSuccess('superadmin', id, name, method)`.
  static void loginSuccess(String userId, String userName, String method) => unawaited(log(
        eventType: 'login_success',
        userId: userId,
        userName: userName,
        details: {'method': method},
      ));

  /// Web `auditLoginFailed('superadmin', attemptedId, reason)`.
  static void loginFailed(String attemptedId, [String reason = 'invalid_credentials']) => unawaited(log(
        eventType: 'login_failed',
        userId: attemptedId,
        details: {'reason': reason},
        severity: 'warning',
      ));

  /// Web `auditPasswordReset(userType, userId, userName, resetBy)`.
  static void passwordReset({
    required String userType,
    required String userId,
    required String userName,
    required String resetBy,
    String? societyId,
  }) =>
      unawaited(log(
        eventType: 'password_reset',
        userType: userType,
        userId: userId,
        userName: userName,
        details: {'reset_by': resetBy},
        severity: 'warning',
        societyId: societyId,
      ));
}
