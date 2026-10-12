import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/auth/data/login_logic.dart';
import 'package:kutumbika_mobile/features/auth/data/login_societies_controller.dart';
import 'package:kutumbika_mobile/services/society_service.dart';

void main() {
  group('fetchListWithRetry (web fetchActiveSocietiesWithRetry)', () {
    late List<Duration> waits;
    Future<void> wait(Duration d) async => waits.add(d);
    setUp(() => waits = []);

    test('backoff is 800 ms × 2^i', () {
      expect([for (var i = 0; i < 4; i++) societyRetryDelay(i).inMilliseconds], [800, 1600, 3200, 6400]);
    });

    test('returns rows on first success without waiting', () async {
      final rows = await fetchListWithRetry<int>(() async => [1, 2], wait: wait);
      expect(rows, [1, 2]);
      expect(waits, isEmpty);
    });

    test('retries empty results, then returns rows', () async {
      var calls = 0;
      final rows = await fetchListWithRetry<int>(() async => ++calls < 3 ? <int>[] : [7], wait: wait);
      expect(rows, [7]);
      expect(calls, 3);
      expect(waits.map((d) => d.inMilliseconds), [800, 1600]);
    });

    test('retries errors, then succeeds', () async {
      var calls = 0;
      final rows = await fetchListWithRetry<int>(() async {
        calls++;
        if (calls < 2) throw Exception('network');
        return [1];
      }, wait: wait);
      expect(rows, [1]);
    });

    test('empty on the last attempt resolves to an empty list', () async {
      final rows = await fetchListWithRetry<int>(() async => <int>[], wait: wait);
      expect(rows, isEmpty);
      expect(waits.length, 3);
    });

    test('throws the last error when every attempt fails (after the final wait)', () async {
      var calls = 0;
      await expectLater(
        fetchListWithRetry<int>(() async => throw StateError('fail ${++calls}'), wait: wait),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'fail 4')),
      );
      expect(waits.length, 4);
    });
  });

  group('LoginSocietiesController (web useLoginSocieties)', () {
    test('loads, exposes error and retries when empty', () async {
      var calls = 0;
      final ctrl = LoginSocietiesController(
        fetch: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return const [SocietyRow(id: 'a', name: 'A')];
        },
        probe: null,
      );
      expect(ctrl.loading, isTrue);
      await ctrl.reload();
      expect(ctrl.error, isNotNull);
      expect(ctrl.loading, isFalse);
      ctrl.retryIfEmpty();
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.societies.single.name, 'A');
      expect(ctrl.error, isNull);
      ctrl.retryIfEmpty(); // not empty anymore → no reload
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      ctrl.dispose();
    });
  });

  group('SocietyListStatus rule', () {
    test('hidden while loading or when societies loaded', () {
      expect(societyListStatusKey(loading: true, error: 'x', count: 0), isNull);
      expect(societyListStatusKey(loading: false, error: null, count: 3), isNull);
    });
    test('error vs empty message', () {
      expect(societyListStatusKey(loading: false, error: 'x', count: 0), 'login.societiesLoadFailed');
      expect(societyListStatusKey(loading: false, error: null, count: 0), 'login.societiesEmpty');
    });
  });
}
