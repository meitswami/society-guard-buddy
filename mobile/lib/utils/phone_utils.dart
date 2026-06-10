/// Port of `normalizeLoginPhone` from web `residentLoginOnboarding.ts`.
String normalizeLoginPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 10) return digits;
  return digits.substring(digits.length - 10);
}
