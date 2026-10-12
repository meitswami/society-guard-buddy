import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/supabase/db.dart';

/// Port of `src/lib/auditLogger.ts` → `audit_logs` rows with IP + device info.
/// (Candidate for the shared kit — other modules log login / password events too.)
abstract final class AuditLogger {
  static String? _userAgent;

  static Future<String> _clientIp() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.getUrl(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 3));
      final data = jsonDecode(body);
      if (data is Map && data['ip'] != null) return data['ip'].toString();
      return 'unknown';
    } catch (_) {
      return 'unknown';
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _ua() async {
    if (_userAgent != null) return _userAgent!;
    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    _userAgent = 'Kutumbika/$version (${Platform.operatingSystem} ${Platform.operatingSystemVersion}; Flutter app)';
    return _userAgent!;
  }

  static Map<String, Object?> _deviceInfo() {
    double? w, h;
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isNotEmpty) {
        final v = views.first;
        w = v.physicalSize.width / v.devicePixelRatio;
        h = v.physicalSize.height / v.devicePixelRatio;
      }
    } catch (_) {}
    final os = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iOS'
            : Platform.operatingSystem;
    return {
      'browser': 'Kutumbika app',
      'os': os,
      'platform': Platform.operatingSystemVersion,
      'language': Platform.localeName,
      'isMobile': Platform.isAndroid || Platform.isIOS,
      'screenWidth': w?.round(),
      'screenHeight': h?.round(),
    };
  }

  /// `logAuditEvent` — never throws.
  static Future<void> log({
    required String? societyId,
    required String eventType,
    required String userType,
    String? userId,
    String? userName,
    Map<String, Object?> details = const {},
    String severity = 'info',
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
        'user_agent': await _ua(),
        'device_info': _deviceInfo(),
        'details': details,
        'severity': severity,
      });
    } catch (_) {
      // Audit logging must never break the action being logged (web logs to console).
    }
  }
}
