import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kutumbika_mobile/app.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/providers/session_provider.dart';

void main() {
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

    expect(find.text('Sign in'), findsOneWidget);
  });
}

class _FakeSessionNotifier extends SessionNotifier {
  @override
  Future<AppSessionState> build() async => const SessionUnauthenticated();
}
