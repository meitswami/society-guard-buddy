/// Pure helpers for the admin Settings panels: letterhead / report settings
/// (`pdfLetterhead.ts`, `SocietyReportSettingsPanel.tsx`), society address and the society
/// bank account (`societyBankAccount.ts`, `societyBankAccountService.ts`).
library;

/// Web `PDF_MARGIN_MM`.
const double kPdfMarginMm = 19.05;

/// Web `LETTERHEAD_NOT_CONFIGURED_WARNING`.
const String kLetterheadNotConfiguredWarning =
    'Official society letterhead has not been configured.';

/// Web `letterheadAddressLine`: `address · city, state · pincode` (blank parts dropped).
String letterheadAddressLine(
    {String? address, String? city, String? state, String? pincode}) {
  final cityState =
      [city, state].where((p) => p != null && p.isNotEmpty).join(', ');
  final parts = [address, cityState, pincode]
      .map((p) => (p ?? '').trim())
      .where((p) => p.isNotEmpty);
  return parts.join(' · ');
}

/// `Number(x)` + `Number.isFinite(n) && n > 0 ? n : fallback` (report layout inputs).
double parseLayoutMm(String raw, double fallback) {
  final n = double.tryParse(raw.trim());
  if (n == null || !n.isFinite || n <= 0) return fallback;
  return n;
}

/// Mode saved with the report settings (web `onSaveSettings`).
String letterheadModeForSave(
    {String? letterheadUrl, String? storagePath, String? currentMode}) {
  final hasAsset =
      (letterheadUrl ?? '').isNotEmpty || (storagePath ?? '').isNotEmpty;
  if (hasAsset) return 'image';
  return (currentMode ?? '').isNotEmpty ? currentMode! : 'auto';
}

/// Society letterhead fields used by the report settings panel (web `SocietyLetterhead`).
class SocietyLetterheadInfo {
  const SocietyLetterheadInfo({
    required this.name,
    this.letterheadUrl,
    this.letterheadStoragePath,
    this.letterheadMode = 'auto',
    this.topMm = 40,
    this.bottomMm = 18,
    this.leftMm = kPdfMarginMm,
    this.rightMm = kPdfMarginMm,
    this.defaultReportFormat = 'letterhead',
  });

  final String name;
  final String? letterheadUrl;
  final String? letterheadStoragePath;
  final String letterheadMode;
  final double topMm;
  final double bottomMm;
  final double leftMm;
  final double rightMm;

  /// `letterhead` | `plain`
  final String defaultReportFormat;

  bool get hasLetterhead =>
      (letterheadUrl ?? '').isNotEmpty ||
      (letterheadStoragePath ?? '').isNotEmpty;

  /// Web `normalizeSocietyRow`.
  factory SocietyLetterheadInfo.fromRow(Map<String, dynamic> d) {
    double mm(Object? v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    final fmt = (d['default_report_format'] ?? 'letterhead').toString();
    final mode = d['letterhead_mode']?.toString();
    return SocietyLetterheadInfo(
      name: (d['name']?.toString().isNotEmpty ?? false)
          ? d['name'].toString()
          : 'Society',
      letterheadUrl: d['letterhead_url']?.toString(),
      letterheadStoragePath: d['letterhead_storage_path']?.toString(),
      letterheadMode: (mode == null || mode.isEmpty) ? 'auto' : mode,
      topMm: mm(d['letterhead_top_mm'], 40),
      bottomMm: mm(d['letterhead_bottom_mm'], 18),
      leftMm: mm(d['letterhead_left_mm'], kPdfMarginMm),
      rightMm: mm(d['letterhead_right_mm'], kPdfMarginMm),
      defaultReportFormat: fmt == 'plain' ? 'plain' : 'letterhead',
    );
  }
}

/// Report settings patch (web `onSaveSettings`).
Map<String, dynamic> buildReportSettingsPatch({
  required String defaultFormat,
  required String top,
  required String bottom,
  required String left,
  required String right,
  required SocietyLetterheadInfo? current,
  String? resolvedLetterheadUrl,
}) {
  return {
    'default_report_format': defaultFormat,
    'letterhead_top_mm': parseLayoutMm(top, 45),
    'letterhead_bottom_mm': parseLayoutMm(bottom, 22),
    'letterhead_left_mm': parseLayoutMm(left, kPdfMarginMm),
    'letterhead_right_mm': parseLayoutMm(right, kPdfMarginMm),
    'letterhead_mode': letterheadModeForSave(
      letterheadUrl: resolvedLetterheadUrl ?? current?.letterheadUrl,
      storagePath: current?.letterheadStoragePath,
      currentMode: current?.letterheadMode,
    ),
  };
}

/// Formats a mm value for the layout inputs (`String(45)` → `45`, `19.05` stays).
String formatMm(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

/// Society address update (web `SocietyAddressPanel.onSave`): trimmed, blanks → null.
Map<String, dynamic> buildAddressPatch({
  required String address,
  required String city,
  required String state,
  required String pincode,
}) {
  String? clean(String v) => v.trim().isEmpty ? null : v.trim();
  return {
    'address': clean(address),
    'city': clean(city),
    'state': clean(state),
    'pincode': clean(pincode),
  };
}

// ---------------------------------------------------------------------------
// Society bank account
// ---------------------------------------------------------------------------

class SocietyBankAccountRow {
  const SocietyBankAccountRow({
    required this.id,
    required this.societyId,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifsc,
    this.branchName,
    this.branchAddress,
    this.micr,
    this.accountType,
    this.currency = 'INR',
    this.upiVpa,
    this.customerId,
    this.isPrimary = true,
    this.isActive = true,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
  });

  final String id;
  final String societyId;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifsc;
  final String? branchName;
  final String? branchAddress;
  final String? micr;
  final String? accountType;
  final String currency;
  final String? upiVpa;
  final String? customerId;
  final bool isPrimary;
  final bool isActive;
  final String? effectiveFrom;
  final String? effectiveTo;
  final String? notes;

  factory SocietyBankAccountRow.fromRow(Map<String, dynamic> r) =>
      SocietyBankAccountRow(
        id: r['id']?.toString() ?? '',
        societyId: r['society_id']?.toString() ?? '',
        bankName: r['bank_name']?.toString() ?? '',
        accountHolderName: r['account_holder_name']?.toString() ?? '',
        accountNumber: r['account_number']?.toString() ?? '',
        ifsc: r['ifsc']?.toString() ?? '',
        branchName: r['branch_name']?.toString(),
        branchAddress: r['branch_address']?.toString(),
        micr: r['micr']?.toString(),
        accountType: r['account_type']?.toString(),
        currency: (r['currency']?.toString().isNotEmpty ?? false)
            ? r['currency'].toString()
            : 'INR',
        upiVpa: r['upi_vpa']?.toString(),
        customerId: r['customer_id']?.toString(),
        isPrimary: r['is_primary'] == true,
        isActive: r['is_active'] == true,
        effectiveFrom: r['effective_from']?.toString(),
        effectiveTo: r['effective_to']?.toString(),
        notes: r['notes']?.toString(),
      );
}

/// Editable form state (web `SocietyBankAccountInput`).
class BankAccountInput {
  const BankAccountInput({
    this.bankName = '',
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.branchName = '',
    this.branchAddress = '',
    this.micr = '',
    this.accountType = '',
    this.currency = 'INR',
    this.upiVpa = '',
    this.customerId = '',
    this.isPrimary = true,
    this.isActive = true,
    this.effectiveFrom = '',
    this.effectiveTo = '',
    this.notes = '',
  });

  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifsc;
  final String branchName;
  final String branchAddress;
  final String micr;
  final String accountType;
  final String currency;
  final String upiVpa;
  final String customerId;
  final bool isPrimary;
  final bool isActive;
  final String effectiveFrom;
  final String effectiveTo;
  final String notes;

  /// Web `load()` → form from the primary account.
  factory BankAccountInput.fromAccount(SocietyBankAccountRow a) =>
      BankAccountInput(
        bankName: a.bankName,
        accountHolderName: a.accountHolderName,
        accountNumber: a.accountNumber,
        ifsc: a.ifsc,
        branchName: a.branchName ?? '',
        branchAddress: a.branchAddress ?? '',
        micr: a.micr ?? '',
        accountType: a.accountType ?? '',
        currency: a.currency.isNotEmpty ? a.currency : 'INR',
        upiVpa: a.upiVpa ?? '',
        customerId: a.customerId ?? '',
        isPrimary: a.isPrimary,
        isActive: a.isActive,
        effectiveFrom: (a.effectiveFrom ?? '').length >= 10
            ? a.effectiveFrom!.substring(0, 10)
            : (a.effectiveFrom ?? ''),
        notes: a.notes ?? '',
      );
}

/// Web `save()` validation: bank, holder, account number and IFSC are required.
bool bankAccountInputComplete(BankAccountInput i) =>
    i.bankName.trim().isNotEmpty &&
    i.accountHolderName.trim().isNotEmpty &&
    i.accountNumber.trim().isNotEmpty &&
    i.ifsc.trim().isNotEmpty;

/// Web `upsertSocietyBankAccount` payload.
Map<String, dynamic> buildBankAccountPayload(
    String societyId, BankAccountInput i) {
  String? opt(String v) => v.trim().isEmpty ? null : v.trim();
  return {
    'society_id': societyId,
    'bank_name': i.bankName.trim(),
    'account_holder_name': i.accountHolderName.trim(),
    'account_number': i.accountNumber.replaceAll(RegExp(r'\s+'), ''),
    'ifsc': i.ifsc.trim().toUpperCase(),
    'branch_name': opt(i.branchName),
    'branch_address': opt(i.branchAddress),
    'micr': opt(i.micr),
    'account_type': opt(i.accountType),
    'currency': i.currency.trim().isEmpty ? 'INR' : i.currency.trim(),
    'upi_vpa': opt(i.upiVpa),
    'customer_id': opt(i.customerId),
    'is_primary': i.isPrimary,
    'is_active': i.isActive,
    'effective_from': i.effectiveFrom.isEmpty ? null : i.effectiveFrom,
    'effective_to': i.effectiveTo.isEmpty ? null : i.effectiveTo,
    'notes': opt(i.notes),
  };
}

/// Web `copyableBankDetails`.
String copyableBankDetails(SocietyBankAccountRow a) {
  final lines = [
    'Account name: ${a.accountHolderName}',
    'Bank: ${a.bankName}',
    'Account number: ${a.accountNumber}',
    'IFSC: ${a.ifsc}',
  ];
  if ((a.branchName ?? '').isNotEmpty) lines.add('Branch: ${a.branchName}');
  if ((a.upiVpa ?? '').isNotEmpty) lines.add('UPI: ${a.upiVpa}');
  return lines.join('\n');
}

/// Web `maskAccountNumber`.
String maskAccountNumber(String accountNumber) {
  final digits = accountNumber.replaceAll(RegExp(r'\s+'), '');
  if (digits.length <= 4) return digits;
  return '${'•' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
}

// ---------------------------------------------------------------------------
// Dashboard banners
// ---------------------------------------------------------------------------

/// Next `sort_order` for a new banner (web: max existing + 1).
int nextBannerSortOrder(List<Map<String, dynamic>> banners) {
  var maxSort = 0;
  for (final b in banners) {
    final v = b['sort_order'];
    final n = v is num ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;
    if (n > maxSort) maxSort = n;
  }
  return maxSort + 1;
}

/// Neighbour to swap with when moving a banner (web `moveBanner`), or null at the edges.
int? bannerSwapIndex(int index, int direction, int length) {
  if (index < 0) return null;
  final other = index + direction;
  if (other < 0 || other >= length) return null;
  return other;
}
