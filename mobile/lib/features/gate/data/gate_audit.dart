import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/supabase/db.dart';

/// `audit_logs` writer for gate events — mirrors web `logAuditEvent` (`src/lib/auditLogger.ts`):
/// same columns, client IP via ipify, device info, never throws.
abstract final class GateAudit {
  static Future<String> _clientIp() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client
          .getUrl(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 3));
      final ip = (jsonDecode(body) as Map)['ip'];
      return ip is String && ip.isNotEmpty ? ip : 'unknown';
    } catch (_) {
      return 'unknown';
    } finally {
      client.close(force: true);
    }
  }

  static String get _os {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return Platform.operatingSystem;
  }

  static Map<String, dynamic> _deviceInfo() => {
        'browser': 'Kutumbika app',
        'os': _os,
        'platform': kIsWeb ? 'web' : Platform.operatingSystemVersion,
        'language': kIsWeb ? 'unknown' : Platform.localeName,
        'isMobile': true,
      };

  static String get _userAgent => kIsWeb
      ? 'Kutumbika app'
      : 'Kutumbika app ($_os ${Platform.operatingSystemVersion})';

  static Future<void> log({
    required String? societyId,
    required String eventType,
    required String userType,
    String? userId,
    String? userName,
    Map<String, dynamic>? details,
    String severity = 'info',
  }) async {
    if (!dbReady) return;
    try {
      final ip = await _clientIp();
      await db.from('audit_logs').insert({
        'society_id': societyId,
        'event_type': eventType,
        'user_type': userType,
        'user_id': (userId == null || userId.isEmpty) ? null : userId,
        'user_name': (userName == null || userName.isEmpty) ? null : userName,
        'ip_address': ip,
        'user_agent': _userAgent,
        'device_info': _deviceInfo(),
        'details': details ?? <String, dynamic>{},
        'severity': severity,
      });
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }
}
