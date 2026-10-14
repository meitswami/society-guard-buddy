import 'dart:async';

import '../../../core/supabase/db.dart';
import '../logic/kiosk_conversation.dart';
import '../logic/kiosk_copy.dart';

/// After a failure (no API key, offline), stop calling for a while.
DateTime _disabledUntil = DateTime.fromMillisecondsSinceEpoch(0);

/// Ask the `kiosk-assistant` Edge Function to read a transcript — port of web
/// `aiExtract` (`src/lib/kiosk/kioskAi.ts`). Returns null when the function is
/// unavailable or slow — callers always have a local fallback.
Future<KioskAiResult?> kioskAiExtract(
  KioskAiField field,
  List<String> transcripts,
  KioskLang lang, {
  List<String>? flats,
  String? societyId,
  Duration timeout = const Duration(milliseconds: 5000),
}) async {
  if (DateTime.now().isBefore(_disabledUntil)) return null;
  if (!dbReady) return null;
  final transcript = transcripts.where((t) => t.isNotEmpty).take(3).toList();
  if (transcript.isEmpty) return null;
  try {
    final data = await invokeFunction('kiosk-assistant', {
      'field': field.name,
      'transcripts': transcript,
      'lang': lang.id,
      if (flats != null) 'flats': flats.take(800).toList(),
      'society_id': societyId,
    }).timeout(timeout);
    final found = data?['found'];
    if (data == null || found is! bool) {
      _disabledUntil = DateTime.now().add(const Duration(minutes: 5));
      return null;
    }
    final value = data['value'];
    return KioskAiResult(found: found, value: (value == null ? '' : '$value').trim());
  } on TimeoutException {
    // Slow network: skip this answer but keep trying next time (web `Promise.race`).
    return null;
  } catch (_) {
    _disabledUntil = DateTime.now().add(const Duration(minutes: 5));
    return null;
  }
}
