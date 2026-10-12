/// Port of `runPushHealthCheck` / `copyHealthReport` in `NotificationCenter.tsx`, adapted
/// to the native FCM client (environment, device support, permission, token registration,
/// token row in `fcm_web_tokens`, test push through `send-push-notification`).
library;

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/format/formatters.dart';
import '../../../models/session_models.dart';
import '../../../services/push_notification_service.dart';
import 'notification_media_storage.dart';
import 'notification_repository.dart';

class HealthStep {
  const HealthStep(this.label, this.ok, this.detail);

  final String label;
  final bool ok;
  final String detail;
}

class PushHealthOutcome {
  const PushHealthOutcome(
      {required this.steps,
      required this.summary,
      required this.passed,
      required this.okNotes,
      required this.issues});

  final List<HealthStep> steps;
  final String summary;
  final bool passed;
  final List<String> okNotes;
  final List<String> issues;
}

const kHealthSummaryOk = 'All checks passed. Push pipeline looks healthy.';
const kHealthSummaryFail = 'Some checks failed. See details below.';
const kHealthSummaryCrash = 'Health check crashed unexpectedly.';

/// Web `copyHealthReport` text.
String buildPushHealthReport({
  required DateTime time,
  required String adminName,
  String? adminId,
  String? societyId,
  required String summary,
  required List<HealthStep> steps,
}) {
  final lines = <String>[
    'Push Health Check Report',
    'Time: ${time.toUtc().toIso8601String()}',
    'Admin: $adminName${adminId != null && adminId.isNotEmpty ? ' ($adminId)' : ''}',
    'Society: ${societyId ?? 'N/A'}',
    '',
    'Summary: ${summary.isEmpty ? 'N/A' : summary}',
    '',
    for (var i = 0; i < steps.length; i++)
      '${i + 1}. ${steps[i].ok ? 'PASS' : 'FAIL'} - ${steps[i].label}: ${steps[i].detail}',
  ];
  return lines.join('\n');
}

/// Interprets the `send-push-notification` response (web: error → config failure;
/// `channel == fcm && sent > 0` → delivered).
HealthStep interpretPushResponse(Map<String, dynamic>? data) {
  final err = data?['error'];
  if (err != null)
    return HealthStep('Edge secret/config', false, err.toString());
  final sent = data?['sent'];
  final sentN = sent is num ? sent.toInt() : int.tryParse('${sent ?? 0}') ?? 0;
  if (data?['channel'] == 'fcm' && sentN > 0) {
    return const HealthStep(
        'Push delivery', true, 'Accepted by FCM for this device token');
  }
  return HealthStep(
      'Push delivery', false, 'Not confirmed: ${jsonEncode(data)}');
}

class PushHealthCheck {
  const PushHealthCheck({this.repo = const NotificationRepository()});

  final NotificationRepository repo;

  Future<PushHealthOutcome> run(SessionAdmin session,
      {required void Function(List<HealthStep> steps) onStep}) async {
    final steps = <HealthStep>[];
    final issues = <String>[];
    final ok = <String>[];
    void step(String label, bool pass, String detail) {
      steps.add(HealthStep(label, pass, detail));
      onStep(List.unmodifiable(steps));
    }

    final adminId = session.admin.id;
    final adminName = session.admin.name;
    final societyId = session.societyId;
    final firebase = Env.isFirebaseConfigured;
    try {
      if (!firebase) {
        issues.add('Env config: missing Firebase keys in the app .env');
        step('Environment', false,
            'Missing Firebase API key / project / app id in the app .env');
      } else {
        ok.add('Env config: Firebase keys present');
        step('Environment', true, 'Firebase project + app id found');
      }

      var supported = false;
      if (firebase) {
        try {
          supported = await FirebaseMessaging.instance.isSupported();
        } catch (_) {
          supported = false;
        }
      }
      if (!supported) {
        issues.add(
            'Device support: Firebase messaging unavailable on this device/build');
        step('Device support', false,
            'Firebase messaging unavailable on this device/build');
      } else {
        ok.add('Device support: supported');
        step('Device support', true, 'Firebase messaging is supported');
      }

      if (firebase) {
        try {
          final settings =
              await FirebaseMessaging.instance.getNotificationSettings();
          switch (settings.authorizationStatus) {
            case AuthorizationStatus.denied:
              issues.add('Permission: blocked in device settings');
              step('Notification permission', false,
                  'Blocked in device settings');
            case AuthorizationStatus.notDetermined:
              issues.add('Permission: not granted yet (prompt not accepted)');
              step('Notification permission', false,
                  'Not granted yet (prompt not accepted)');
            case AuthorizationStatus.authorized:
            case AuthorizationStatus.provisional:
              ok.add('Permission: granted');
              step('Notification permission', true, 'Granted');
          }
        } catch (e) {
          issues.add('Permission: could not read ($e)');
          step('Notification permission', false,
              'Could not read notification settings: $e');
        }
      }

      await PushNotificationService().registerForSession(session);
      step('Token registration', true, 'Registration attempt completed');

      String? token;
      try {
        token = await repo.latestAdminToken(adminId, societyId: societyId);
        if (token == null || token.isEmpty) {
          token = null;
          issues.add('Token DB: no FCM token found for this admin/device');
          step('Token in database', false,
              'No FCM token found for this admin/device');
        } else {
          ok.add('Token DB: token present');
          step('Token in database', true, 'Token found');
        }
      } on PostgrestException catch (e) {
        issues.add('Token DB: query failed (${e.message})');
        step('Token in database', false, e.message);
      }

      if (token != null) {
        try {
          final data = await repo.invokePush({
            'title': 'Push Health Check',
            'message':
                'Test push from $adminName (${Fmt.time(DateTime.now())})',
            'target_tokens': [token],
            'target_type': 'user',
            'society_id': societyId,
            'sound_key': 'digital',
            'sound_custom_url': '',
          });
          final s = interpretPushResponse(data);
          if (s.ok) {
            ok.add('Delivery: accepted by FCM for this device token');
          } else if (s.label == 'Edge secret/config') {
            issues.add('Edge secret/config: ${s.detail}');
          } else {
            issues.add('Delivery: not confirmed (${jsonEncode(data)})');
          }
          step(s.label, s.ok, s.detail);
        } on FunctionException catch (e) {
          final d = e.details;
          if (d is Map && d['error'] != null) {
            issues.add('Edge secret/config: ${d['error']}');
            step('Edge secret/config', false, d['error'].toString());
          } else {
            final m = commsErrorMessage(e);
            issues.add('Edge function: invoke failed ($m)');
            step('Edge function invoke', false, m);
          }
        }
      }

      final passed = issues.isEmpty;
      return PushHealthOutcome(
        steps: steps,
        summary: passed ? kHealthSummaryOk : kHealthSummaryFail,
        passed: passed,
        okNotes: ok,
        issues: issues,
      );
    } catch (e) {
      step('Unexpected error', false, commsErrorMessage(e));
      return PushHealthOutcome(
          steps: steps,
          summary: kHealthSummaryCrash,
          passed: false,
          okNotes: ok,
          issues: [...issues, '$e']);
    }
  }
}
