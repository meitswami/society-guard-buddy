import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kutumbika_mobile/app.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/providers/session_provider.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'app-lang': 'en'});
    await AppPrefs.init();
    await TranslationsStore.load();
  });

  testWidgets('shows login when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionNotifier()),
        ],
        child: const KutumbikaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Unified login (web UnifiedLoginPage): brand header, society picker, register CTA, footer.
    expect(find.text('Kutumbika'), findsOneWidget);
    expect(find.text('SELECT YOUR SOCIETY'), findsOneWidget);
    expect(find.text('Register a new society'), findsOneWidget);
    expect(find.text('Select a society to sign in.'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });
}

class _FakeSessionNotifier extends SessionNotifier {
  @override
  Future<AppSessionState> build() async => const SessionUnauthenticated();
}
