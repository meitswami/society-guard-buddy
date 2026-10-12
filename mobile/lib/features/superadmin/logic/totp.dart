import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Port of `src/lib/superadminTotp.ts`, byte-compatible with the web's `otplib` v13
/// (functional API): RFC 4648 Base32 secrets, RFC 6238 TOTP with HMAC-SHA1,
/// 6 digits, 30 s period, verification with `epochTolerance: 30` (±1 time step).
/// Codes generated here match Microsoft / Google Authenticator and the web app.
const String kTotpIssuer = 'Society Guard Buddy';
const int kTotpDigits = 6;
const int kTotpPeriodSeconds = 30;

/// Web `verifySync({ epochTolerance: 30 })`.
const int kTotpEpochToleranceSeconds = 30;

/// otplib guardrails: secrets must decode to 16..64 bytes or verification throws.
const int kTotpMinSecretBytes = 16;
const int kTotpMaxSecretBytes = 64;

/// otplib `generateSecret()` default length (20 bytes → 32 Base32 characters).
const int kTotpSecretBytes = 20;

/// RFC 4648 Base32 (alphabet `A–Z2–7`), as used by otplib's scure plugin.
abstract final class Base32 {
  static const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Encodes without `=` padding (otplib `encode(bytes)` strips padding).
  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final b in bytes) {
      buffer = (buffer << 8) | (b & 0xff);
      bits += 8;
      while (bits >= 5) {
        out.write(alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) out.write(alphabet[(buffer << (5 - bits)) & 31]);
    return out.toString();
  }

  /// Decodes like otplib: upper-cases first and tolerates missing `=` padding.
  /// Returns `null` for characters outside the alphabet (otplib throws).
  static Uint8List? decode(String input) {
    final s = input.toUpperCase().replaceFirst(RegExp(r'=+$'), '');
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in s.split('')) {
      final v = alphabet.indexOf(ch);
      if (v < 0) return null;
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 0xff);
        bits -= 8;
      }
      buffer &= (1 << bits) - 1;
    }
    return Uint8List.fromList(out);
  }
}

/// RFC 4226 HOTP value for [counter] (dynamic truncation, zero-padded).
String hotpCode(List<int> key, int counter, {int digits = kTotpDigits}) {
  final msg = Uint8List(8);
  var c = counter;
  for (var i = 7; i >= 0; i--) {
    msg[i] = c % 256;
    c = c ~/ 256;
  }
  final mac = Hmac(sha1, key).convert(msg).bytes;
  final offset = mac[mac.length - 1] & 0x0f;
  final binary = ((mac[offset] & 0x7f) << 24) |
      ((mac[offset + 1] & 0xff) << 16) |
      ((mac[offset + 2] & 0xff) << 8) |
      (mac[offset + 3] & 0xff);
  var mod = 1;
  for (var i = 0; i < digits; i++) {
    mod *= 10;
  }
  return (binary % mod).toString().padLeft(digits, '0');
}

int _nowEpochSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Floor division that matches JS `Math.floor(a / b)` for negative values too.
int _floorDiv(int a, int b) => (a / b).floor();

/// TOTP code for [secret] at [epochSeconds] (defaults to now) — otplib `generateSync`.
/// Returns `null` when the secret is not valid Base32 or outside the 16..64 byte guardrail.
String? generateTotpCode(String secret, {int? epochSeconds}) {
  final key = _secretKey(secret);
  if (key == null) return null;
  final epoch = epochSeconds ?? _nowEpochSeconds();
  return hotpCode(key, _floorDiv(epoch, kTotpPeriodSeconds));
}

Uint8List? _secretKey(String secret) {
  final key = Base32.decode(secret);
  if (key == null ||
      key.length < kTotpMinSecretBytes ||
      key.length > kTotpMaxSecretBytes) {
    return null;
  }
  return key;
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Web `verifyTotpCode(secret, token)`: strips whitespace, requires exactly 6 digits,
/// then accepts the codes of time steps `floor((t-30)/30) .. floor((t+30)/30)`.
bool verifyTotpCode(String secret, String token, {int? epochSeconds}) {
  final cleaned = token.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{6}$').hasMatch(cleaned)) return false;
  final key = _secretKey(secret);
  if (key == null) return false;
  final epoch = epochSeconds ?? _nowEpochSeconds();
  final minCounter =
      max(0, _floorDiv(epoch - kTotpEpochToleranceSeconds, kTotpPeriodSeconds));
  final maxCounter =
      _floorDiv(epoch + kTotpEpochToleranceSeconds, kTotpPeriodSeconds);
  var valid = false;
  for (var c = minCounter; c <= maxCounter; c++) {
    // Check every step (no early exit) like a constant-time comparison loop.
    if (_constantTimeEquals(hotpCode(key, c), cleaned)) valid = true;
  }
  return valid;
}

/// Web `generateTotpSecret()` (otplib `generateSecret()`): 20 random bytes, Base32.
String generateTotpSecret([Random? random]) {
  final r = random ?? Random.secure();
  return Base32.encode(
      List<int>.generate(kTotpSecretBytes, (_) => r.nextInt(256)));
}

/// JS `encodeURIComponent` — Dart's `Uri.encodeComponent` keeps the same
/// unreserved set (`A–Z a–z 0–9 - _ . ! ~ * ' ( )`).
String encodeUriComponent(String s) => Uri.encodeComponent(s);

/// Web `buildTotpKeyUri(secret, username)` — otplib `generateURI` output:
/// `otpauth://totp/<issuer>:<label>?secret=…&issuer=…` (sha1 / 6 digits / 30 s omitted).
String buildTotpKeyUri(String secret, String username) {
  final label = '$kTotpIssuer:$username';
  final encodedLabel = label.split(':').map(encodeUriComponent).join(':');
  final params = <String>[
    'secret=${encodeUriComponent(secret)}',
    'issuer=${encodeUriComponent(kTotpIssuer)}',
  ];
  return 'otpauth://totp/$encodedLabel?${params.join('&')}';
}

/// Web `totpQrImageUrl(uri, size)` (QR image service used on the web page).
String totpQrImageUrl(String otpauthUri, {int size = 180}) =>
    'https://api.qrserver.com/v1/create-qr-code/?size=${size}x$size&data=${encodeUriComponent(otpauthUri)}';

/// Seconds left in the current 30 s window (for the countdown hint).
int totpSecondsRemaining({int? epochSeconds}) {
  final epoch = epochSeconds ?? _nowEpochSeconds();
  return kTotpPeriodSeconds - (epoch % kTotpPeriodSeconds);
}
