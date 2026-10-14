import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/prefs/app_prefs.dart';
import '../../../services/admin_permissions.dart';
import 'admin_module.dart';

/// Port of `src/lib/adminNavigation.ts` + the tab list in `AdminDashboard.tsx`.
class AdminTabDef {
  const AdminTabDef(this.tab, this.labelKey, this.icon, this.group);

  final AdminTab tab;
  final String labelKey;
  final IconData icon;
  final String group;
}

const List<AdminTabDef> kAdminTabs = [
  AdminTabDef(AdminTab.overview, 'adminNav.home', Icons.home_outlined, 'main'),
  AdminTabDef(AdminTab.guards, 'adminNav.guards', Icons.shield_outlined, 'manage'),
  AdminTabDef(AdminTab.residents, 'adminNav.residents', Icons.how_to_reg_outlined, 'manage'),
  AdminTabDef(AdminTab.geofence, 'adminNav.geofence', Icons.location_on_outlined, 'manage'),
  AdminTabDef(AdminTab.finance, 'adminNav.finance', Icons.currency_rupee, 'finance'),
  AdminTabDef(AdminTab.fixedAssets, 'adminNav.fixedAssets', Icons.apartment_outlined, 'finance'),
  AdminTabDef(AdminTab.meetings, 'adminNav.meetings', Icons.description_outlined, 'meetings'),
  AdminTabDef(AdminTab.documents, 'adminNav.documents', Icons.folder_special_outlined, 'meetings'),
  AdminTabDef(AdminTab.committee, 'adminNav.committee', Icons.account_balance_outlined, 'meetings'),
  AdminTabDef(AdminTab.donations, 'adminNav.donations', Icons.favorite_border, 'finance'),
  AdminTabDef(AdminTab.events, 'adminNav.events', Icons.calendar_month_outlined, 'community'),
  AdminTabDef(AdminTab.polls, 'adminNav.polls', Icons.how_to_vote_outlined, 'community'),
  AdminTabDef(AdminTab.notifications, 'adminNav.notify', Icons.notifications_none, 'community'),
  AdminTabDef(AdminTab.parking, 'adminNav.parking', Icons.local_parking_outlined, 'community'),
  AdminTabDef(AdminTab.visitor, 'adminNav.visitor', Icons.person_add_alt_1_outlined, 'ops'),
  AdminTabDef(AdminTab.delivery, 'adminNav.delivery', Icons.local_shipping_outlined, 'ops'),
  AdminTabDef(AdminTab.vehicle, 'adminNav.vehicles', Icons.directions_car_outlined, 'ops'),
  AdminTabDef(AdminTab.blacklist, 'adminNav.blacklist', Icons.gpp_maybe_outlined, 'ops'),
  AdminTabDef(AdminTab.directory, 'adminNav.directory', Icons.contacts_outlined, 'ops'),
  AdminTabDef(AdminTab.quick, 'adminNav.quick', Icons.bolt_outlined, 'ops'),
  AdminTabDef(AdminTab.report, 'adminNav.reports', Icons.bar_chart_outlined, 'system'),
  AdminTabDef(AdminTab.logs, 'adminNav.logs', Icons.article_outlined, 'system'),
  AdminTabDef(AdminTab.audit, 'adminNav.audit', Icons.assignment_outlined, 'system'),
  AdminTabDef(AdminTab.password, 'adminNav.password', Icons.lock_outline, 'system'),
  AdminTabDef(AdminTab.biometric, 'adminNav.biometric', Icons.fingerprint, 'system'),
  AdminTabDef(AdminTab.settings, 'adminNav.settings', Icons.settings_outlined, 'system'),
  AdminTabDef(AdminTab.tour, 'adminNav.tour', Icons.auto_awesome_outlined, 'system'),
];

/// Web `ADMIN_BOTTOM_NAV_TABS`.
const List<AdminTab> kAdminBottomNavTabs = [AdminTab.overview, AdminTab.audit, AdminTab.finance, AdminTab.report];

/// Web `isAdminTabAllowed`.
bool isAdminTabAllowed(AdminTab tab, AdminPanelPermissions p) {
  switch (tab) {
    case AdminTab.overview:
    case AdminTab.tour:
      return true;
    case AdminTab.splits:
      return p.events || p.splits;
    case AdminTab.guards:
      return p.guardsRw;
    case AdminTab.residents:
      return p.residentsRw;
    case AdminTab.geofence:
      return p.geofenceRw;
    case AdminTab.password:
      return p.password;
    case AdminTab.biometric:
      return p.biometric;
    case AdminTab.audit:
      return p.audit;
    case AdminTab.finance:
      return p.finance;
    case AdminTab.fixedAssets:
      return p.fixedAssets;
    case AdminTab.donations:
      return p.donations;
    case AdminTab.events:
      return p.events;
    case AdminTab.meetings:
      return p.meetings;
    case AdminTab.documents:
      return p.documents;
    case AdminTab.committee:
      return p.committee;
    case AdminTab.polls:
      return p.polls;
    case AdminTab.parking:
      return p.parking;
    case AdminTab.notifications:
      return p.notifications;
    case AdminTab.visitor:
      return p.visitor;
    case AdminTab.delivery:
      return p.delivery;
    case AdminTab.vehicle:
      return p.vehicle;
    case AdminTab.blacklist:
      return p.blacklist;
    case AdminTab.directory:
      return p.directory;
    case AdminTab.quick:
      return p.quick;
    case AdminTab.report:
      return p.report;
    case AdminTab.logs:
      return p.logs;
    case AdminTab.settings:
      return p.settings;
  }
}

class AdminSearchRoute {
  const AdminSearchRoute(this.tab, this.labelKey, this.keywords, this.hint);

  final AdminTab tab;
  final String labelKey;
  final List<String> keywords;
  final String hint;
}

/// Web `ADMIN_SEARCH_ROUTES`.
const List<AdminSearchRoute> kAdminSearchRoutes = [
  AdminSearchRoute(AdminTab.residents, 'adminNav.residents', ['flat', 'owner', 'phone', 'member', 'resident', 'निवासी'], 'Flat, owner, phone'),
  AdminSearchRoute(AdminTab.directory, 'adminNav.directory', ['directory', 'contact', 'flat', 'phone', 'निर्देशिका'], 'Flat, name, phone'),
  AdminSearchRoute(AdminTab.finance, 'adminNav.finance', ['payment', 'receipt', 'maintenance', 'charge', 'ledger', 'txn', 'वित्त'], 'Flat, charge, txn'),
  AdminSearchRoute(AdminTab.fixedAssets, 'adminNav.fixedAssets', ['asset', 'fixed', 'dg', 'lift', 'gym', 'warranty', 'amc', 'equipment'], 'Asset register'),
  AdminSearchRoute(AdminTab.report, 'adminNav.reports', ['report', 'visitor', 'vehicle', 'ledger', 'shift', 'रिपोर्ट'], 'Cross-report search'),
  AdminSearchRoute(AdminTab.audit, 'adminNav.audit', ['audit', 'login', 'ip', 'log', 'ऑडिट'], 'Name, ID, IP'),
  AdminSearchRoute(AdminTab.guards, 'adminNav.guards', ['guard', 'kyc', 'security', 'गार्ड'], 'Guard name or ID'),
  AdminSearchRoute(AdminTab.vehicle, 'adminNav.vehicles', ['vehicle', 'car', 'bike', 'number plate', 'वाहन'], 'Plate or owner'),
  AdminSearchRoute(AdminTab.visitor, 'adminNav.visitor', ['visitor', 'guest', 'entry', 'विज़िटर'], 'Visitor name or flat'),
  AdminSearchRoute(AdminTab.delivery, 'adminNav.delivery', ['delivery', 'courier', 'parcel', 'डिलीवरी'], 'Delivery entry'),
  AdminSearchRoute(AdminTab.blacklist, 'adminNav.blacklist', ['blacklist', 'blocked', 'ब्लैकलिस्ट'], 'Name or reason'),
  AdminSearchRoute(AdminTab.logs, 'adminNav.logs', ['log', 'shift', 'guard log', 'लॉग'], 'Guard or shift'),
  AdminSearchRoute(AdminTab.quick, 'adminNav.quick', ['quick', 'entry', 'क्विक'], 'Quick log search'),
  AdminSearchRoute(AdminTab.committee, 'adminNav.committee', ['committee', 'mc', 'member', 'समिति'], 'Flat or owner'),
  AdminSearchRoute(AdminTab.events, 'adminNav.events', ['event', 'food', 'catering', 'split', 'इवेंट'], 'Event expenses'),
  AdminSearchRoute(AdminTab.meetings, 'adminNav.meetings', ['meeting', 'minutes', 'agenda', 'मीटिंग'], 'Meeting records'),
  AdminSearchRoute(AdminTab.documents, 'adminNav.documents', ['document', 'file', 'society doc', 'दस्तावेज़'], 'Society documents'),
  AdminSearchRoute(AdminTab.polls, 'adminNav.polls', ['poll', 'election', 'vote', 'पोल', 'चुनाव'], 'Polls'),
  AdminSearchRoute(AdminTab.parking, 'adminNav.parking', ['parking', 'slot', 'sticker', 'पार्किंग'], 'Parking slots'),
  AdminSearchRoute(AdminTab.notifications, 'adminNav.notify', ['notify', 'notification', 'broadcast', 'सूचना'], 'Notifications'),
  AdminSearchRoute(AdminTab.donations, 'adminNav.donations', ['donation', 'charity', 'दान'], 'Donations'),
  AdminSearchRoute(AdminTab.geofence, 'adminNav.geofence', ['geofence', 'location', 'gps', 'जियोफ़ेंस'], 'Geofence setup'),
  AdminSearchRoute(AdminTab.settings, 'adminNav.settings', ['settings', 'theme', 'language', 'सेटिंग', 'भाषा'], 'App settings'),
];

/// Web `scoreSearchRoute`.
int scoreSearchRoute(AdminSearchRoute route, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  var score = 0;
  if (route.labelKey.toLowerCase().contains(q)) score += 4;
  final labelHint = route.labelKey.replaceFirst(RegExp(r'^adminNav\.'), '').toLowerCase();
  if (labelHint.contains(q) || q.contains(labelHint)) score += 6;
  for (final kw in route.keywords) {
    if (kw.contains(q) || q.contains(kw)) score += 4;
    if (kw.startsWith(q) || q.startsWith(kw)) score += 2;
  }
  const digitTabs = {AdminTab.residents, AdminTab.directory, AdminTab.finance, AdminTab.report};
  if (RegExp(r'\d').hasMatch(q) && digitTabs.contains(route.tab)) score += 3;
  if (RegExp(r'^\d{1,3}[a-z]?$', caseSensitive: false).hasMatch(q) &&
      (route.tab == AdminTab.residents || route.tab == AdminTab.directory)) {
    score += 5;
  }
  return score;
}

/// Web `searchRoutesForQuery`: allowed routes ranked by score (best first).
List<AdminSearchRoute> searchRoutesForQuery(String query, Set<AdminTab> allowed) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final scored = <(AdminSearchRoute, int)>[];
  for (final r in kAdminSearchRoutes) {
    if (!allowed.contains(r.tab)) continue;
    final s = scoreSearchRoute(r, q);
    if (s > 0) scored.add((r, s));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored) s.$1];
}

/// Usage counters + last tab (web localStorage keys `sgb_admin_tab_use_<sid>` / `sgb_admin_last_tab_<sid>`).
abstract final class AdminTabUsage {
  static String _usageKey(String sid) => 'sgb_admin_tab_use_$sid';
  static String _lastKey(String sid) => 'sgb_admin_last_tab_$sid';

  static Map<String, int> read(String sid) {
    try {
      final raw = AppPrefs.instance.getString(_usageKey(sid));
      if (raw == null) return {};
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static void record(String sid, AdminTab tab) {
    if (tab == AdminTab.overview) return;
    final m = read(sid);
    m[tab.name] = (m[tab.name] ?? 0) + 1;
    AppPrefs.instance.setString(_usageKey(sid), jsonEncode(m));
    AppPrefs.instance.setString(_lastKey(sid), tab.name);
  }

  static AdminTab? lastTab(String sid) {
    final raw = AppPrefs.instance.getString(_lastKey(sid));
    if (raw == null) return null;
    for (final t in AdminTab.values) {
      if (t.name == raw) return t;
    }
    return null;
  }
}

/// Web `computeQuickAccessTabs`: six most-used modules plus the last visited one.
List<AdminTabDef> computeQuickAccessTabs(List<AdminTabDef> visible, Map<String, int> usage, AdminTab? last, String Function(String) label) {
  final candidates = visible.where((t) => t.tab != AdminTab.overview).toList()
    ..sort((a, b) {
      final diff = (usage[b.tab.name] ?? 0) - (usage[a.tab.name] ?? 0);
      if (diff != 0) return diff;
      return label(a.labelKey).toLowerCase().compareTo(label(b.labelKey).toLowerCase());
    });
  final picked = <AdminTabDef>[];
  for (final t in candidates) {
    if (picked.length >= 6) break;
    picked.add(t);
  }
  if (last != null && last != AdminTab.overview && !picked.any((t) => t.tab == last)) {
    final def = visible.where((t) => t.tab == last);
    if (def.isNotEmpty) picked.add(def.first);
  }
  return picked;
}
