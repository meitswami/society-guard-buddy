// Port of `src/lib/headFundMatch.ts` (Record payment → Head fund reconciliation).

/// Normalise expense-head names for fuzzy matching (Water Softner / Softener / Installation).
String normalizeHeadToken(String s) => s
    .toLowerCase()
    .replaceAll('softener', 'softner')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

bool headNamesMatch(String a, String b) {
  final na = normalizeHeadToken(a);
  final nb = normalizeHeadToken(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (na.contains(nb) || nb.contains(na)) return true;
  final wa = na.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
  final wb = nb.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
  return wa.any(wb.contains);
}

bool expenseMatchesHead(String headName,
    {String? title, String? vendorOrService, String? groupName}) {
  final blob = [title, vendorOrService, groupName]
      .where((v) => v != null && v.isNotEmpty)
      .join(' ');
  return headNamesMatch(headName, blob);
}

bool isHeadContributionLedgerTitle(String? title) =>
    RegExp(r'^head contribution\s*[—–-]', caseSensitive: false)
        .hasMatch((title ?? '').trim());

bool isHeadAdjustmentLedgerTitle(String? title) =>
    RegExp(r'^head adjustment\s*[—–-]', caseSensitive: false)
        .hasMatch((title ?? '').trim());

/// `head_fund_adjustments.source_type` values → English label (web) / Hindi label.
const Map<String, String> kHeadAdjustmentSourceLabels = {
  'member_advance': 'Member advance / top-up',
  'maintenance_pool': 'Society maintenance collections',
  'corpus': 'Corpus fund',
};

const Map<String, String> kHeadAdjustmentSourceLabelsHi = {
  'member_advance': 'सदस्य अग्रिम / टॉप-अप',
  'maintenance_pool': 'सोसाइटी रखरखाव संग्रह',
  'corpus': 'कॉर्पस निधि',
};
