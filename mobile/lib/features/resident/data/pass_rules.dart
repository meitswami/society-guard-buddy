/// Visitor pass helpers for the resident Passes tab (web `handleCreatePass` + list rendering),
/// plus the WhatsApp share text used on mobile.
library;

import 'dart:math';

import '../../../core/format/formatters.dart';

/// Six-digit OTP exactly like web `Math.floor(100000 + Math.random() * 900000)`.
String generatePassOtp([Random? random]) => (100000 + (random ?? Random()).nextInt(900000)).toString();

/// `HH:mm` from a DB `time` value (`09:00:00` → `09:00`, web `.slice(0, 5)`).
String hhmm(String? time) {
  final t = (time ?? '').trim();
  return t.length >= 5 ? t.substring(0, 5) : t;
}

/// `dd/MM/yyyy · 09:00 – 18:00` under each pass card.
String passSlotLabel({required String validDate, String? start, String? end}) {
  final date = Fmt.isoToDisplay(validDate);
  final s = hhmm(start), e = hhmm(end);
  if (s.isEmpty && e.isEmpty) return date;
  return '$date · $s – $e';
}

/// Message shared with the guest on WhatsApp.
String passShareMessage({
  required String otp,
  required String flatNumber,
  required String societyName,
  required String validDate,
  String? guestName,
  String? start,
  String? end,
  bool hindi = false,
}) {
  final slot = passSlotLabel(validDate: validDate, start: start, end: end);
  final name = (guestName ?? '').trim();
  if (hindi) {
    return [
      if (name.isNotEmpty) 'नमस्ते $name,',
      '$societyName में फ्लैट $flatNumber के लिए आपका आगंतुक प्रवेश पत्र तैयार है।',
      'ओटीपी: $otp',
      'मान्य: $slot',
      'गेट पर गार्ड को यह ओटीपी दिखाएँ।',
    ].join('\n');
  }
  return [
    if (name.isNotEmpty) 'Hi $name,',
    'Your visitor pass for Flat $flatNumber at $societyName is ready.',
    'OTP: $otp',
    'Valid: $slot',
    'Show this OTP to the guard at the gate.',
  ].join('\n');
}

/// Members invited to use the resident app (shared flat login) — mobile WhatsApp invite text.
String memberInviteMessage({
  required String memberName,
  required String phone,
  required String flatNumber,
  required String societyName,
  required String invitedBy,
  bool hindi = false,
}) {
  if (hindi) {
    return [
      'नमस्ते $memberName,',
      '$invitedBy ने आपको $societyName के फ्लैट $flatNumber में कुटुम्बिका निवासी ऐप पर जोड़ा है।',
      'अपने मोबाइल नंबर $phone और फ्लैट के कूटशब्द से प्रवेश करें (कूटशब्द परिवार से पूछें)।',
    ].join('\n');
  }
  return [
    'Hi $memberName,',
    '$invitedBy added you to Flat $flatNumber at $societyName on the Kutumbika resident app.',
    'Sign in with your mobile number $phone and the flat password (ask your family for it).',
  ].join('\n');
}
