import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers last login society / role / flat / mobile for autofill (fields stay editable).
class LoginRemember {
  LoginRemember._();

  static const _key = 'sgb_login_remember_v1';

  static Future<LoginRememberData?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['v'] != 1) return null;
      return LoginRememberData(
        societyId: map['societyId'] as String?,
        role: map['role'] as String?,
        flatId: map['flatId'] as String?,
        phone: map['phone'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> write({
    String? societyId,
    String? role,
    String? flatId,
    String? phone,
    bool clearRole = false,
    bool clearFlat = false,
    bool clearPhone = false,
  }) async {
    final prev = await read();
    final next = LoginRememberData(
      societyId: societyId ?? prev?.societyId,
      role: clearRole ? null : (role ?? prev?.role),
      flatId: clearFlat ? null : (flatId ?? prev?.flatId),
      phone: clearPhone ? null : _normalizePhone(phone ?? prev?.phone),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'v': 1,
        if (next.societyId != null) 'societyId': next.societyId,
        if (next.role != null) 'role': next.role,
        if (next.flatId != null) 'flatId': next.flatId,
        if (next.phone != null) 'phone': next.phone,
      }),
    );
  }

  static String? _normalizePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits.isEmpty ? null : digits;
  }
}

class LoginRememberData {
  const LoginRememberData({
    this.societyId,
    this.role,
    this.flatId,
    this.phone,
  });

  final String? societyId;
  final String? role;
  final String? flatId;
  final String? phone;
}
