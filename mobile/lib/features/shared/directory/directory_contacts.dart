/// Shared directory contact normalization & resolution helpers —
/// port of web `src/lib/directoryContacts.ts` (same rules as the
/// `dispatch-directory-message` edge function).
library;

/// Digits with country code for WhatsApp (10-digit numbers get `91`), or null when invalid.
String? normalizeWhatsAppPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) digits = '91$digits';
  if (digits.length < 11 || digits.length > 15) return null;
  return digits;
}

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Lower-cased email, or null when empty / invalid.
String? normalizeEmail(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  if (v.isEmpty) return null;
  if (!_emailRe.hasMatch(v)) return null;
  return v;
}

/// Web `DirectoryMemberContact`.
class DirectoryMemberContact {
  const DirectoryMemberContact({
    this.id,
    this.flatId,
    this.flatNumber,
    this.name,
    this.phone,
    this.whatsappPhone,
    this.email,
    this.notifyWhatsapp,
    this.notifyEmail,
    this.isPrimary,
  });

  final String? id;
  final String? flatId;
  final String? flatNumber;
  final String? name;
  final String? phone;
  final String? whatsappPhone;
  final String? email;
  final bool? notifyWhatsapp;
  final bool? notifyEmail;
  final bool? isPrimary;

  factory DirectoryMemberContact.fromRow(Map<String, dynamic> m) => DirectoryMemberContact(
        id: m['id']?.toString(),
        flatId: m['flat_id']?.toString(),
        flatNumber: m['flat_number']?.toString(),
        name: m['name']?.toString(),
        phone: m['phone']?.toString(),
        whatsappPhone: m['whatsapp_phone']?.toString(),
        email: m['email']?.toString(),
        notifyWhatsapp: m['notify_whatsapp'] as bool?,
        notifyEmail: m['notify_email'] as bool?,
        isPrimary: m['is_primary'] as bool?,
      );
}

class ResolvedChannelTargets {
  const ResolvedChannelTargets({required this.whatsapp, required this.emails});

  final List<String> whatsapp;
  final List<String> emails;
}

/// Resolve WhatsApp + email targets from directory members (primary first).
/// WhatsApp: `whatsapp_phone` → `phone` (respects `notify_whatsapp`).
/// Email: `member.email` (respects `notify_email`).
ResolvedChannelTargets resolveMemberChannelTargets(
  List<DirectoryMemberContact> members, {
  bool whatsapp = true,
  bool email = true,
}) {
  final wa = <String>{};
  final emails = <String>{};
  // Stable sort: primary members first, original order otherwise (like Array.prototype.sort).
  final indexed = members.asMap().entries.toList()
    ..sort((a, b) {
      final p = (b.value.isPrimary == true ? 1 : 0) - (a.value.isPrimary == true ? 1 : 0);
      return p != 0 ? p : a.key.compareTo(b.key);
    });
  for (final e in indexed) {
    final m = e.value;
    if (whatsapp && m.notifyWhatsapp != false) {
      final p = normalizeWhatsAppPhone(m.whatsappPhone ?? m.phone);
      if (p != null) wa.add(p);
    }
    if (email && m.notifyEmail != false) {
      final em = normalizeEmail(m.email);
      if (em != null) emails.add(em);
    }
  }
  return ResolvedChannelTargets(whatsapp: wa.toList(), emails: emails.toList());
}
