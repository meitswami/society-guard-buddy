/// Mobile counterpart of web `logAuditEvent` (`src/lib/auditLogger.ts`) for the events
/// raised in this module (password change, sensitive-action verification).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/supabase/db.dart';

Map<String, dynamic> _deviceInfo() {
  if (kIsWeb) {
    return {
      'browser': 'Kutumbika app',
      'os': 'web',
      'platform': 'web',
      'isMobile': false
    };
  }
  return {
    'browser': 'Kutumbika app',
    'os': Platform.operatingSystem,
    'osVersion': Platform.operatingSystemVersion,
    'platform': Platform.operatingSystem,
    'language': Platform.localeName,
    'isMobile': Platform.isAndroid || Platform.isIOS,
  };
}

String _userAgent() {
  if (kIsWeb) return 'Kutumbika-Flutter/web';
  return 'Kutumbika-Flutter/${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
}

Future<String> _clientIp() async {
  if (kIsWeb) return 'unknown';
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
    final ip = (jsonDecode(body) as Map)['ip']?.toString();
    return (ip == null || ip.isEmpty) ? 'unknown' : ip;
  } catch (_) {
    return 'unknown';
  } finally {
    client.close(force: true);
  }
}

/// Inserts one `audit_logs` row; never throws (web logs and swallows errors).
Future<void> logCommsAuditEvent({
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
    final ip = await _clientIp();
    await db.from('audit_logs').insert([
      {
        'society_id': societyId,
        'event_type': eventType,
        'user_type': userType,
        'user_id': userId,
        'user_name': userName,
        'ip_address': ip,
        'user_agent': _userAgent(),
        'device_info': _deviceInfo(),
        'details': details,
        'severity': severity,
      },
    ]);
  } catch (e) {
    debugPrint('Audit log failed: $e');
  }
}

/// Web `auditPasswordChange(userType, userId, userName, changedBy)`.
Future<void> auditPasswordChange({
  required String? societyId,
  required String userType,
  required String userId,
  required String userName,
  String? changedBy,
}) =>
    logCommsAuditEvent(
      societyId: societyId,
      eventType: 'password_change',
      userType: userType,
      userId: userId,
      userName: userName,
      details: {'changed_by': changedBy ?? 'self'},
    );
