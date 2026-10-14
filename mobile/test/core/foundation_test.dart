import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/format/formatters.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_navigation.dart';
import 'package:kutumbika_mobile/features/admin/overview/admin_overview_service.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';

void main() {
  group('AdminPanelPermissions (web adminPermissions.ts)', () {
    test('null permissions → full access', () {
      final p = AdminPanelPermissions.fromJson(null);
      expect(p.finance && p.fixedAssets && p.documents && p.settings, isTrue);
    });

    test('object without booleans → locked-down custom role', () {
      final p = AdminPanelPermissions.fromJson({'note': 'x'});
      expect(p.finance, isTrue);
      expect(p.directory, isTrue);
      expect(p.residentsRw, isFalse);
      expect(p.fixedAssets, isFalse);
      expect(p.password && p.biometric, isTrue);
    });

    test('stored booleans override full access; missing keys stay true', () {
      final p = AdminPanelPermissions.fromJson({'finance': false, 'audit': false});
      expect(p.finance, isFalse);
      expect(p.audit, isFalse);
      expect(p.residentsRw, isTrue);
      expect(p.documents, isTrue);
    });

    test('admins without role_id get full access', () {
      final p = AdminPanelPermissions.fromAdminJoin({'role_id': null});
      expect(p.toJson().values.every((v) => v), isTrue);
    });

    test('role join reads society_roles.permissions (list or object)', () {
      final row = {
        'role_id': 'r1',
        'society_roles': [
          {'permissions': {'finance': false}},
        ],
      };
      expect(AdminPanelPermissions.fromAdminJoin(row).finance, isFalse);
    });

    test('toJson round-trips through fromJson', () {
      const p = AdminPanelPermissions.newCustomRole;
      final back = AdminPanelPermissions.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
    });
  });

  group('admin navigation (web adminNavigation.ts)', () {
    test('splits allowed when events or splits permission', () {
      const noEvents = AdminPanelPermissions(events: false, splits: false);
      expect(isAdminTabAllowed(AdminTab.splits, noEvents), isFalse);
      expect(isAdminTabAllowed(AdminTab.splits, const AdminPanelPermissions(events: false)), isTrue);
      expect(isAdminTabAllowed(AdminTab.overview, noEvents), isTrue);
    });

    test('search ranks residents first for a flat number', () {
      final allowed = AdminTab.values.toSet();
      final routes = searchRoutesForQuery('604', allowed);
      expect(routes.first.tab, anyOf(AdminTab.residents, AdminTab.directory));
    });

    test('search finds finance for payment words and respects permissions', () {
      expect(searchRoutesForQuery('receipt', AdminTab.values.toSet()).first.tab, AdminTab.finance);
      final noFinance = AdminTab.values.toSet()..remove(AdminTab.finance);
      expect(searchRoutesForQuery('receipt', noFinance).any((r) => r.tab == AdminTab.finance), isFalse);
    });

    test('quick access: six most used plus last visited', () {
      final visible = kAdminTabs;
      final usage = {
        for (var i = 0; i < 8; i++) visible[i + 1].tab.name: 100 - i,
      };
      final last = AdminTab.tour;
      final picked = computeQuickAccessTabs(visible, usage, last, (k) => k);
      expect(picked.length, 7);
      expect(picked.first.tab, visible[1].tab);
      expect(picked.last.tab, AdminTab.tour);
      expect(picked.any((t) => t.tab == AdminTab.overview), isFalse);
    });
  });

  group('admin overview helpers (AdminDashboard.tsx)', () {
    final now = DateTime(2026, 10, 12);
    test('extractMonthFromTitle', () {
      expect(extractMonthFromTitle('Maintenance February 2026', now: now), '2026-02');
      expect(extractMonthFromTitle('Feb 26 Maintenance', now: now), '2026-02');
      expect(extractMonthFromTitle('Maintenance Dec', now: now), '2026-12');
      expect(extractMonthFromTitle('Corpus fund', now: now), isNull);
    });

    test('formatMonthLabel', () {
      expect(formatMonthLabel('2026-02'), 'Feb 2026');
      expect(formatMonthLabel('Unknown'), 'Unknown');
    });

    test('major head inference', () {
      expect(inferMajorHeadFromGroupName('Security guard salary'), 'SALARY & WAGES');
      expect(inferMajorHeadFromGroupName('Lift AMC'), 'OPERATION & MAINTENANCE');
      expect(inferMajorHeadFromGroupName('Corpus legal'), 'CORPUS FUND (LEGAL)');
      expect(inferMajorHeadFromGroupName('Office chairs'), 'FIXED ASSETS');
      expect(inferMajorHeadFromGroupName(''), 'MISCELLANEOUS');
      expect(resolveGroupMajorHead('anything', 'BANK'), 'BANK');
      expect(resolveGroupMajorHead('Diesel', 'NOT A HEAD'), 'OPERATION & MAINTENANCE');
    });
  });

  group('Fmt (web dateFormat.ts)', () {
    test('dates', () {
      expect(Fmt.date('2026-03-05T10:00:00'), '05/03/2026');
      expect(Fmt.isoToDisplay('2026-03-05'), '05/03/2026');
      expect(Fmt.displayToIso('5/3/2026'), '2026-03-05');
      expect(Fmt.displayToIso('31/02/2026'), isNull);
      expect(Fmt.displayToIso('2026-03-05'), '2026-03-05');
      expect(Fmt.date(null), '');
    });

    test('Indian money grouping', () {
      expect(Fmt.inr(1234567), '₹12,34,567');
      expect(Fmt.inr2(1500.5), '₹1,500.50');
      expect(asDouble('12.5'), 12.5);
      expect(asInt(null), 0);
    });
  });

  group('Translator (web LanguageContext.t)', () {
    test('override wins, then static, then other language, then key', () {
      const tr = Translator(AppLang.hi, {
        'x.override': {'en': 'EN override', 'hi': ''},
      });
      // Hindi override empty → falls back to English override (static has no key).
      expect(tr.t('x.override'), 'EN override');
      expect(tr.t('missing.key'), 'missing.key');
    });

    test('vars are applied', () {
      expect(applyVars('Hello {name}, flat {flat}', {'name': 'Asha', 'flat': 'A-604'}), 'Hello Asha, flat A-604');
      expect(applyVars('Keep {unknown}', {'name': 'x'}), 'Keep {unknown}');
    });
  });
}
