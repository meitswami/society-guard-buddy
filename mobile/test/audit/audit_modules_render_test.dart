import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/core/theme/app_tokens.dart';
import 'package:kutumbika_mobile/features/admin/audit/admin_audit_module.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module.dart';
import 'package:kutumbika_mobile/features/admin/fixed_assets/admin_fixed_assets_module.dart';
import 'package:kutumbika_mobile/models/admin_user.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';

AdminModuleContext _ctx() => AdminModuleContext(
      session: const SessionAdmin(
        societyId: 's1',
        societyName: 'Green Park',
        admin: AdminUser(
            id: 'a1',
            name: 'Admin',
            adminId: 'ADM1',
            societyId: 's1',
            permissions: AdminPanelPermissions.full),
      ),
      goTo: (tab, {query, subTab}) {},
      initialQuery: 'ravi',
    );

Widget _host(Widget child, AppLang lang, {bool dark = false}) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            extensions: [dark ? AppTokens.dark : AppTokens.light]),
        home: I18nScope(
            translator: Translator(lang), child: Scaffold(body: child)),
      ),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await TranslationsStore.load();
  });

  for (final lang in AppLang.values) {
    testWidgets('audit module renders on a phone (${lang.name})',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          _host(AdminAuditModule(ctx: _ctx()), lang, dark: lang == AppLang.hi));
      await tester.pumpAndSettle();
      expect(find.byType(AdminAuditModule), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Expand a governance section and scroll through the page.
      final principal =
          find.text(lang == AppLang.hi ? 'प्रधान (शासी निकाय)' : 'Principal');
      await tester.ensureVisible(principal);
      await tester.pumpAndSettle();
      await tester.tap(principal);
      await tester.pumpAndSettle();
      expect(
          find.text(
              lang == AppLang.hi ? 'शासी प्राधिकरण' : 'Governing Authority'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fixed assets module renders (${lang.name})', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(AdminFixedAssetsModule(ctx: _ctx()), lang));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(lang == AppLang.hi ? 'रिपोर्ट' : 'Reports'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
          find.text(lang == AppLang.hi ? 'संपत्ति रजिस्टर' : 'Asset register'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(
          lang == AppLang.hi ? 'पहली संपत्ति जोड़ें' : 'Add first asset'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
