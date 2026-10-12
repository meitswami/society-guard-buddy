import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers last login society / role / flat / mobile for autofill (fields stay editable).
/// Port of web `src/lib/loginRemember.ts` — same storage key and JSON shape (`v: 1`).
class LoginRemember {
  LoginRemember._();

  static const storageKey = 'sgb_login_remember_v1';

  /// Web `sessionStorage['sgb_open_family_tab']` — set after first-time onboarding so the
  /// resident area opens the Family tab once.
  static const openFamilyTabKey = 'sgb_open_family_tab';

  static const validRoles = {'guard', 'admin', 'resident'};

  /// Web `normalizePhone`: last 10 digits when there are at least 10, otherwise all digits
  /// (null when there are none).
  static String? normalizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final all = phone.replaceAll(RegExp(r'\D'), '');
    final last10 = all.length > 10 ? all.substring(all.length - 10) : all;
    if (last10.length >= 10) return last10;
    return all.isEmpty ? null : all;
  }

  /// Parses the stored JSON (null for missing / corrupt / other versions).
  static LoginRememberData? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map || map['v'] != 1) return null;
      String? s(Object? v) => v is String ? v : null;
      return LoginRememberData(
        societyId: s(map['societyId']),
        role: s(map['role']),
        flatId: s(map['flatId']),
        phone: s(map['phone']),
      );
    } catch (_) {
      return null;
    }
  }

  static String encode(LoginRememberData data) => jsonEncode(data.toJson());

  /// Web `writeLoginRemember(patch)` merge rules. A key present in [patch] overwrites the
  /// stored value (blank / null clears it); keys not present keep the previous value.
  static LoginRememberData merge(LoginRememberData? prev, Map<String, String?> patch) {
    String? blankToNull(String? v) {
      final t = v?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    var next = prev ?? const LoginRememberData();
    if (patch.containsKey('societyId')) {
      next = next.copyWith(societyId: () => blankToNull(patch['societyId']));
    }
    if (patch.containsKey('role')) {
      final r = patch['role'];
      next = next.copyWith(role: () => (r == null || r.isEmpty) ? null : r);
    }
    if (patch.containsKey('flatId')) {
      next = next.copyWith(flatId: () => blankToNull(patch['flatId']));
    }
    if (patch.containsKey('phone')) {
      next = next.copyWith(phone: () => normalizePhone(patch['phone']));
    }
    return next;
  }

  static Future<LoginRememberData?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decode(prefs.getString(storageKey));
    } catch (_) {
      return null;
    }
  }

  /// Merge-patch remembered login fields (see [merge]). Keys: `societyId`, `role`, `flatId`, `phone`.
  static Future<void> patch(Map<String, String?> patch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = merge(decode(prefs.getString(storageKey)), patch);
      await prefs.setString(storageKey, encode(next));
    } catch (_) {
      // Storage unavailable — autofill is best effort, like web quota / private mode.
    }
  }

  /// Older API kept for existing callers: non-null arguments overwrite, `clear*` flags remove.
  static Future<void> write({
    String? societyId,
    String? role,
    String? flatId,
    String? phone,
    bool clearRole = false,
    bool clearFlat = false,
    bool clearPhone = false,
  }) {
    return LoginRemember.patch({
      if (societyId != null) 'societyId': societyId,
      if (clearRole) 'role': null else if (role != null) 'role': role,
      if (clearFlat) 'flatId': null else if (flatId != null) 'flatId': flatId,
      if (clearPhone) 'phone': null else if (phone != null) 'phone': phone,
    });
  }

  /// Flag the resident area to open the Family tab once (web `sgb_open_family_tab`).
  static Future<void> setOpenFamilyTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(openFamilyTabKey, '1');
    } catch (_) {}
  }

  /// Reads and clears the Family-tab flag (resident shell calls this once after login).
  static Future<bool> consumeOpenFamilyTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getString(openFamilyTabKey) == '1';
      if (on) await prefs.remove(openFamilyTabKey);
      return on;
    } catch (_) {
      return false;
    }
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

  /// Role only when it is one of `guard` / `admin` / `resident` (web restore check).
  String? get validRole => LoginRemember.validRoles.contains(role) ? role : null;

  LoginRememberData copyWith({
    String? Function()? societyId,
    String? Function()? role,
    String? Function()? flatId,
    String? Function()? phone,
  }) =>
      LoginRememberData(
        societyId: societyId == null ? this.societyId : societyId(),
        role: role == null ? this.role : role(),
        flatId: flatId == null ? this.flatId : flatId(),
        phone: phone == null ? this.phone : phone(),
      );

  Map<String, Object?> toJson() => {
        'v': 1,
        if (societyId != null) 'societyId': societyId,
        if (role != null) 'role': role,
        if (flatId != null) 'flatId': flatId,
        if (phone != null) 'phone': phone,
      };

  @override
  bool operator ==(Object other) =>
      other is LoginRememberData &&
      other.societyId == societyId &&
      other.role == role &&
      other.flatId == flatId &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(societyId, role, flatId, phone);

  @override
  String toString() => 'LoginRememberData(societyId: $societyId, role: $role, flatId: $flatId, phone: $phone)';
}
