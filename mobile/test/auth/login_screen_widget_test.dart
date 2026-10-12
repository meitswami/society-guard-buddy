import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/core/theme/kutumbika_theme.dart';
import 'package:kutumbika_mobile/features/auth/data/login_logic.dart';
import 'package:kutumbika_mobile/features/auth/login_screen.dart';
import 'package:kutumbika_mobile/features/auth/password_reset_screen.dart';
import 'package:kutumbika_mobile/features/public/about_screen.dart';
import 'package:kutumbika_mobile/features/public/privacy_policy_screen.dart';
import 'package:kutumbika_mobile/features/public/society_signup_screen.dart';
import 'package:kutumbika_mobile/features/public/society_signup_status_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget home, {AppLang lang = AppLang.en}) => ProviderScope(
      child: MaterialApp(
        theme: KutumbikaTheme.light(),
        builder: (context, child) => I18nScope(translator: Translator(lang), child: child!),
        home: home,
      ),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'app-lang': 'en'});
    await AppPrefs.init();
    await TranslationsStore.load();
  });

  testWidgets('unified login shows society picker, register CTA and footer', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Kutumbika'), findsOneWidget);
    expect(find.text('SELECT YOUR SOCIETY'), findsOneWidget);
    expect(find.text('No active societies found.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Register a new society'), findsOneWidget);
    expect(find.text('Select a society to sign in.'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    // Superadmin entry is desktop-only (≥ 1024 wide); the default test surface is 800.
    expect(find.text('Platform superadmin login'), findsNothing);
  });

  testWidgets('footer opens the privacy policy and the CTA opens signup', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('1. Information we collect'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register a new society'));
    await tester.pumpAndSettle();
    expect(find.text('Create your society'), findsOneWidget);
  });

  testWidgets('phone width (360dp): login, signup, reset and legal pages lay out without overflow', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(_host(const LoginScreen(), lang: AppLang.hi));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const SocietySignupScreen(), lang: AppLang.hi));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const SocietySignupScreen()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const PasswordResetScreen(userType: ResetUserType.guard, societyId: 's')));
    await tester.pumpAndSettle();
    expect(find.text('Guard ID / Phone'), findsOneWidget);
    await tester.pumpWidget(_host(const AboutScreen(), lang: AppLang.hi));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const SocietySignupStatusScreen()));
    await tester.pumpAndSettle();
    expect(find.text('FAILED'), findsOneWidget);
  });

  testWidgets('public pages render in Hindi', (tester) async {
    await tester.pumpWidget(_host(const AboutScreen(), lang: AppLang.hi));
    await tester.pumpAndSettle();
    expect(find.text('हमारी दृष्टि'), findsOneWidget);
    await tester.pumpWidget(_host(const PrivacyPolicyScreen(), lang: AppLang.hi));
    await tester.pumpAndSettle();
    expect(find.text('गोपनीयता नीति'), findsOneWidget);
    await tester.pumpWidget(_host(const SocietySignupScreen(), lang: AppLang.hi));
    await tester.pumpAndSettle();
    expect(find.text('अपनी सोसाइटी बनाएं'), findsOneWidget);
  });
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
