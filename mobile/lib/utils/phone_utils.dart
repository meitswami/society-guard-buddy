/// Port of `normalizeLoginPhone` from web `residentLoginOnboarding.ts`.
String normalizeLoginPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 10) return digits;
  return digits.substring(digits.length - 10);
}

/// `value.replace(/\D/g, '')`, optionally capped like an `<input maxLength>`.
String digitsOnly(String value, {int? maxLength}) {
  final d = value.replaceAll(RegExp(r'\D'), '');
  if (maxLength != null && d.length > maxLength) {
    return d.substring(0, maxLength);
  }
  return d;
}

/// Digits for `https://wa.me/<digits>`: 10-digit Indian numbers get the `91` prefix
/// (web `.replace(/\D/g, '').replace(/^(\d{10})$/, '91$1')`).
String waMeDigits(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length == 10 ? '91$d' : d;
}
