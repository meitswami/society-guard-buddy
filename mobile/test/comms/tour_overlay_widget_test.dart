import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/theme/app_tokens.dart';
import 'package:kutumbika_mobile/features/comms/tour/tour_guide.dart';
import 'package:kutumbika_mobile/features/comms/tour/tour_guide_first_login.dart';
import 'package:kutumbika_mobile/features/comms/tour/tour_guide_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget Function(BuildContext) onTap) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTokens.light]),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () => onTap(context),
                    child: const Text('open'))),
          ),
        ),
      ),
    );

void main() {
  testWidgets('overlay steps through Next and resolves true on Done',
      (tester) async {
    bool? result;
    await tester.pumpWidget(_app((ctx) {
      TourGuideOverlay.show(ctx, steps: getFirstLoginSteps('guard'))
          .then((v) => result = v);
      return const SizedBox();
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('tour.next'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.text('tour.done'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('skip does not persist unless persistOnSkip', (tester) async {
    bool? result;
    await tester.pumpWidget(_app((ctx) {
      TourGuideOverlay.show(ctx, steps: getFirstLoginSteps('resident'))
          .then((v) => result = v);
      return const SizedBox();
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tour.skip'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('first-login tour shows once and is stored under the web key',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app((ctx) {
      TourGuideFirstLogin.maybeShow(ctx, role: 'guard', userId: 'G001');
      return const SizedBox();
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('tour.skip'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sgb.tour.v1.done:guard:G001'), '1');
    expect(await TourGuideStore.isCompleted('guard', 'G001'), isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsNothing, reason: 'already completed');
  });
}
