// Opens every tab of every role against a fake Supabase backend filled with schema-shaped
// rows, and fails if a tab throws, shows an error view, or is still loading after a few
// seconds. Catches "tab is stuck / shows nothing" regressions that unit tests miss.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/core/theme/kutumbika_theme.dart';
import 'package:kutumbika_mobile/core/ui/ui.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module_registry.dart';
import 'package:kutumbika_mobile/features/guard/guard_shell.dart';
import 'package:kutumbika_mobile/features/resident/resident_shell.dart';
import 'package:kutumbika_mobile/features/superadmin/superadmin_shell.dart';
import 'package:kutumbika_mobile/models/admin_user.dart';
import 'package:kutumbika_mobile/models/guard_session.dart';
import 'package:kutumbika_mobile/models/resident_user.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/providers/session_provider.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';

import 'fake_backend.dart';

final _societyId = FakeSupabaseBackend.uuid(1);

final _resident = SessionResident(
  societyId: _societyId,
  societyName: 'Test Society',
  resident: ResidentUser(
    id: FakeSupabaseBackend.uuid(1),
    name: 'Test Resident',
    phone: '9876543211',
    flatId: FakeSupabaseBackend.uuid(1),
    flatNumber: 'A-101',
  ),
);

final _guard = SessionGuard(
  societyId: _societyId,
  societyName: 'Test Society',
  guard: const GuardSession(guardId: 'G1', name: 'Test Guard', password: 'x'),
  shiftId: FakeSupabaseBackend.uuid(1),
);

final _admin = SessionAdmin(
  societyId: _societyId,
  societyName: 'Test Society',
  admin: AdminUser(
    id: FakeSupabaseBackend.uuid(1),
    name: 'Test Admin',
    adminId: 'ADM1',
    societyId: _societyId,
    permissions: AdminPanelPermissions.fromJson(null),
  ),
);

final _superadmin = SessionSuperadmin(id: FakeSupabaseBackend.uuid(1), name: 'Super', username: 'super');

class _FixedSession extends SessionNotifier {
  _FixedSession(this.session);
  final AppSessionState session;
  @override
  Future<AppSessionState> build() async => session;
}

/// Errors that come from the test environment, not the app (no network images, no
/// platform plugins, no Firebase).
bool _isEnvironmentNoise(String s) =>
    s.contains('HTTP request failed') ||
    s.contains('NetworkImageLoadException') ||
    s.contains('MissingPluginException') ||
    s.contains('No Firebase App') ||
    s.contains('[core/no-app]') ||
    s.contains('WebSocket') ||
    s.contains('RealtimeSubscribeException');

/// Collects real (non-environment) Flutter errors for the whole test body. Install with
/// [install] at the start of a test and call [uninstall] before its expectations.
class _Probe {
  final errors = <String>[];
  void Function(FlutterErrorDetails)? _old;

  void install() {
    _old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.toString();
      if (!_isEnvironmentNoise(s)) errors.add(s.split('\n').take(12).join('\n'));
    };
  }

  void uninstall() => FlutterError.onError = _old;

  /// Start of one tab: forget errors of the previous tab.
  void start() => errors.clear();

  void stop() {}
}

Widget _app(AppSessionState session, Widget home) => ProviderScope(
      overrides: [sessionProvider.overrideWith(() => _FixedSession(session))],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: KutumbikaTheme.light(null),
          builder: (context, child) =>
              I18nScope(translator: ref.watch(translatorProvider), child: child ?? const SizedBox.shrink()),
          home: home,
        ),
      ),
    );

/// Lets the fake backend answer and the screen settle (real time, real futures).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Dismiss first-login popups (tour, banners, biometric offers) that cover the tab.
  for (var i = 0; i < 3; i++) {
    final dialogs = find.byType(Dialog);
    if (dialogs.evaluate().isEmpty) break;
    final nav = Navigator.of(dialogs.evaluate().first, rootNavigator: true);
    nav.pop();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

String? _problem(WidgetTester tester, _Probe probe) {
  if (probe.errors.isNotEmpty) return 'EXCEPTION:\n${probe.errors.first}';
  if (find.byType(ErrorView).evaluate().isNotEmpty) return 'shows ErrorView (load failed)';
  if (find.byType(LoadingView).evaluate().isNotEmpty) return 'stuck on LoadingView';
  final spinners = find.byType(CircularProgressIndicator).evaluate().where((e) {
    final w = e.widget as CircularProgressIndicator;
    return w.value == null; // indeterminate only
  });
  if (spinners.isNotEmpty) return 'stuck: indeterminate spinner still showing';
  return null;
}

/// Taps every item of the screen's ScrollableBottomNav and checks each tab.
Future<Map<String, String>> _walkNav(WidgetTester tester, _Probe probe) async {
  final results = <String, String>{};
  final navFinder = find.byWidgetPredicate((w) => w is ScrollableBottomNav);
  expect(navFinder, findsOneWidget);
  final nav = tester.widget(navFinder) as dynamic;
  final items = (nav.items as List).cast<dynamic>();
  for (final item in items) {
    probe.start();
    (tester.widget(navFinder) as dynamic).onTap(item.id);
    await tester.pump();
    await _settle(tester);
    var p = _problem(tester, probe);
    // The kiosk waits for the camera / microphone, which the test machine does not have.
    if ('${item.id}'.endsWith('.kiosk') && p != null && p.startsWith('stuck')) p = null;
    probe.stop();
    results['${item.id}'] = p ?? 'OK';
    // Full-screen routes (guard kiosk) cover the shell: close them before the next tab.
    while (navFinder.evaluate().isEmpty) {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  return results;
}

void _report(String role, Map<String, String> results) {
  final bad = results.entries.where((e) => e.value != 'OK').toList();
  // ignore: avoid_print
  print('=== $role: ${results.length - bad.length}/${results.length} OK');
  for (final e in results.entries) {
    // ignore: avoid_print
    print('  ${e.value == 'OK' ? 'ok  ' : 'FAIL'} ${e.key}${e.value == 'OK' ? '' : ' -> ${e.value}'}');
  }
}

void main() {
  late FakeSupabaseBackend backend;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => Directory.systemTemp.path);
    for (final ch in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'com.llfbandit.record/messages',
      'plugins.flutter.io/camera_android',
      'flutter_tts',
      'plugin.csdcorp.com/speech_to_text',
      'wakelock_plus',
      'dev.fluttercommunity.plus/package_info',
      'plugins.flutter.io/local_auth_android',
      'plugins.flutter.io/firebase_core',
      'plugins.flutter.io/firebase_messaging',
      'dexterous.com/flutter/local_notifications',
      'flutter.baseflow.com/geolocator_android',
      'flutter.baseflow.com/geolocator_updates_android',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
    SharedPreferences.setMockInitialValues({'app-lang': 'en'});
    await AppPrefs.init();
    await TranslationsStore.load();
    dotenv.testLoad(fileInput: 'SUPABASE_URL=https://fake.supabase.co\nSUPABASE_ANON_KEY=fake-key\n');
    backend = FakeSupabaseBackend(societyId: _societyId);
    await Supabase.initialize(
      url: 'https://fake.supabase.co',
      publishableKey: 'fake-key',
      httpClient: backend,
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false),
      debug: false,
    );
  });

  final all = <String, Map<String, String>>{};

  tearDownAll(() {
    for (final e in all.entries) {
      _report(e.key, e.value);
    }
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Unmounts the screen and stops realtime so no retry timers outlive the test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
    });
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets('resident: every tab loads', (tester) async {
    await phone(tester);
    final probe = _Probe()..install();
    await tester.pumpWidget(_app(_resident, const ResidentShell()));
    await _settle(tester);
    final r = await _walkNav(tester, probe);
    await finish(tester);
    probe.uninstall();
    all['RESIDENT'] = r;
    expect(r.values.where((v) => v != 'OK'), isEmpty, reason: r.toString());
  });

  testWidgets('guard: every tab loads', (tester) async {
    await phone(tester);
    final probe = _Probe()..install();
    await tester.pumpWidget(_app(_guard, const GuardShell()));
    await _settle(tester);
    final r = await _walkNav(tester, probe);
    await finish(tester);
    probe.uninstall();
    all['GUARD'] = r;
    expect(r.values.where((v) => v != 'OK'), isEmpty, reason: r.toString());
  });

  testWidgets('superadmin: every tab loads', (tester) async {
    await phone(tester);
    final probe = _Probe()..install();
    await tester.pumpWidget(_app(_superadmin, const SuperadminShell()));
    await _settle(tester);
    final r = await _walkNav(tester, probe);
    await finish(tester);
    probe.uninstall();
    all['SUPERADMIN'] = r;
    expect(r.values.where((v) => v != 'OK'), isEmpty, reason: r.toString());
  });

  test('society-wide lists never download photo columns up front', () {
    const heavy = {
      'members': ['photo', 'id_photo_front', 'id_photo_back'],
      'visitors': ['visitor_photos', 'document_photo', 'vehicle_photo'],
      'resident_vehicles': ['vehicle_photo'],
    };
    final offenders = <String>{};
    for (final r in backend.requests) {
      if (!r.startsWith('GET ')) continue;
      final uri = Uri.parse(r.substring(4));
      final table = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final cols = heavy[table];
      if (cols == null) continue;
      final select = uri.queryParameters['select'] ?? '*';
      final wantsPhoto = select == '*' || cols.any(select.split(',').map((c) => c.trim()).contains);
      if (!wantsPhoto) continue;
      // Allowed: one row (`id=eq.`), one flat (`flat_id=eq.`), a lazy batch (`id=in.`), or
      // a handful of flats (e.g. the committee roster's flats) — never the whole society.
      final q = uri.queryParameters;
      final flatIn = q['flat_id'] ?? '';
      final fewFlats = flatIn.startsWith('in.') && ','.allMatches(flatIn).length < 30;
      final scoped = (q['id'] ?? '').startsWith('eq.') ||
          (q['id'] ?? '').startsWith('in.') ||
          (q['flat_id'] ?? '').startsWith('eq.') ||
          fewFlats ||
          (q['member_id'] ?? '').startsWith('eq.') ||
          q['limit'] == '1';
      if (!scoped) offenders.add('$table?select=$select&${q.keys.where((k) => k != 'select').join('&')}');
    }
    expect(offenders, isEmpty, reason: 'Unscoped photo downloads:\n${offenders.join('\n')}');
  });

  testWidgets('admin: every module loads', (tester) async {
    await phone(tester);
    final probe = _Probe()..install();
    final r = <String, String>{};
    for (final tab in AdminTab.values.where((t) => t != AdminTab.overview)) {
      probe.start();
      final ctx = AdminModuleContext(session: _admin, goTo: (_, {query, subTab}) {});
      await tester.pumpWidget(_app(
        _admin,
        Scaffold(body: SafeArea(child: KeyedSubtree(key: ValueKey(tab), child: buildAdminModule(tab, ctx)))),
      ));
      await _settle(tester);
      r[tab.name] = _problem(tester, probe) ?? 'OK';
      probe.stop();
    }
    await finish(tester);
    probe.uninstall();
    all['ADMIN'] = r;
    expect(r.values.where((v) => v != 'OK'), isEmpty, reason: r.toString());
  });
}
