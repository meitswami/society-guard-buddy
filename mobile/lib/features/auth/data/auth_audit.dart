import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/supabase/db.dart';

/// Port of web `src/lib/auditLogger.ts` for the login / password-reset events.
/// Rows go to `audit_logs` with the same columns (event_type, user_type, user_id,
/// user_name, ip_address, user_agent, device_info, details, severity, society_id).
/// Fire-and-forget: failures are only logged, never shown.
abstract final class AuthAudit {
  static String? _ipCache;
  static String? _agentCache;

  static Future<String> _clientIp() async {
    if (_ipCache != null) return _ipCache!;
    if (kIsWeb) return 'unknown';
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 3));
      final ip = (jsonDecode(body) as Map)['ip'];
      if (ip is String && ip.isNotEmpty) _ipCache = ip;
      return _ipCache ?? 'unknown';
    } catch (_) {
      return 'unknown';
    } finally {
      client?.close(force: true);
    }
  }

  static String _osName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  static Future<String> _userAgent() async {
    if (_agentCache != null) return _agentCache!;
    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    final osVersion = kIsWeb ? '' : Platform.operatingSystemVersion;
    _agentCache = 'Kutumbika-Flutter/${version.isEmpty ? 'unknown' : version} (${_osName()}; $osVersion)';
    return _agentCache!;
  }

  static Map<String, Object?> _deviceInfo() {
    final views = PlatformDispatcher.instance.views;
    final view = views.isEmpty ? null : views.first;
    final ratio = view?.devicePixelRatio ?? 1;
    final size = view == null ? null : view.physicalSize / ratio;
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return {
      'browser': 'Flutter app',
      'os': _osName(),
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'language': PlatformDispatcher.instance.locale.toLanguageTag(),
      'isMobile': isMobile,
      'screenWidth': size?.width.round(),
      'screenHeight': size?.height.round(),
    };
  }

  /// Web `logAuditEvent`.
  static Future<void> log({
    required String eventType,
    required String userType,
    String? userId,
    String? userName,
    Map<String, Object?>? details,
    String severity = 'info',
    String? societyId,
  }) async {
    if (!dbReady) return;
    try {
      final ip = await _clientIp();
      final agent = await _userAgent();
      await db.from('audit_logs').insert({
        'society_id': (societyId == null || societyId.isEmpty) ? null : societyId,
        'event_type': eventType,
        'user_type': userType,
        'user_id': (userId == null || userId.isEmpty) ? null : userId,
        'user_name': (userName == null || userName.isEmpty) ? null : userName,
        'ip_address': ip,
        'user_agent': agent,
        'device_info': _deviceInfo(),
        'details': details ?? const <String, Object?>{},
        'severity': severity,
      });
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }

  /// `auditLoginSuccess(userType, userId, userName, method = 'password')`.
  static void loginSuccess(String userType, String userId, String userName, {String method = 'password', String? societyId}) {
    unawaited(log(
      eventType: 'login_success',
      userType: userType,
      userId: userId,
      userName: userName,
      details: {'method': method},
      societyId: societyId,
    ));
  }

  /// `auditLoginFailed(userType, attemptedId, reason = 'invalid_credentials')`.
  static void loginFailed(String userType, String attemptedId, {String reason = 'invalid_credentials', String? societyId}) {
    unawaited(log(
      eventType: 'login_failed',
      userType: userType,
      userId: attemptedId,
      details: {'reason': reason},
      severity: 'warning',
      societyId: societyId,
    ));
  }

  /// `auditBiometricLogin(userType, userId, userName)`.
  static void biometricLogin(String userType, String userId, String userName, {String? societyId}) {
    unawaited(log(
      eventType: 'login_success',
      userType: userType,
      userId: userId,
      userName: userName,
      details: {'method': 'biometric'},
      societyId: societyId,
    ));
  }

  /// `auditPasswordReset(userType, userId, userName, resetBy)`.
  static void passwordReset(String userType, String userId, String userName, String resetBy, {String? societyId}) {
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
}
