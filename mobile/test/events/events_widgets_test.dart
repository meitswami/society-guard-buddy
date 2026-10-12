import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/i18n/extra/events_strings.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/core/theme/app_tokens.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module.dart';
import 'package:kutumbika_mobile/features/admin/events/admin_donations_module.dart';
import 'package:kutumbika_mobile/features/admin/events/admin_events_module.dart';
import 'package:kutumbika_mobile/features/admin/events/admin_splits_module.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/cash_bank_channel.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/flat_options.dart';
import 'package:kutumbika_mobile/features/admin/events/widgets/cash_bank_breakdown.dart';
import 'package:kutumbika_mobile/features/admin/events/widgets/flat_multi_select.dart';
import 'package:kutumbika_mobile/models/admin_user.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {AppLang lang = AppLang.en}) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTokens.light]),
        builder: (context, c) => I18nScope(translator: Translator(lang), child: c!),
        home: Scaffold(body: child),
      ),
    );

final List<(AdminTab, String?, String?)> _navigations = [];

AdminModuleContext _ctx({String? query}) => AdminModuleContext(
      session: const SessionAdmin(
        societyId: 's1',
        societyName: 'Green Park',
        admin: AdminUser(id: 'a1', name: 'Admin', adminId: 'ADMIN', societyId: 's1', permissions: AdminPanelPermissions.full),
      ),
      goTo: (tab, {query, subTab}) => _navigations.add((tab, query, subTab)),
      initialQuery: query,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'app-lang': 'en'});
    await AppPrefs.init();
    await TranslationsStore.load();
  });

  testWidgets('events module renders all three sections without a backend', (tester) async {
    await tester.pumpWidget(_host(AdminEventsModule(ctx: _ctx(query: 'Holi'))));
    await tester.pumpAndSettle();
    expect(find.text('Events & food expenses'), findsOneWidget);
    expect(find.text('Holi'), findsOneWidget); // search pre-filled from ctx.initialQuery
    expect(find.text('Events — record contribution receipts'), findsOneWidget);
    expect(find.text('Create Event'), findsOneWidget);
    await tester.tap(find.text('Create Event'));
    await tester.pumpAndSettle();
    expect(find.text('Create Event'), findsNWidgets(2)); // form opened
    await tester.scrollUntilVisible(find.text('New food expense group'), 300);
    expect(find.text('New food expense group'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No event receipts recorded yet.'), 300);
    expect(find.text('No event receipts recorded yet.'), findsOneWidget);
  });

  testWidgets('splits module = Finance → Record payment splitter', (tester) async {
    _navigations.clear();
    await tester.pumpWidget(_host(AdminSplitsModule(ctx: _ctx(query: 'Electricity'))));
    await tester.pumpAndSettle();
    expect(find.text('Record payment'), findsOneWidget);
    expect(find.text('Electricity'), findsOneWidget); // head search pre-filled
    await tester.tap(find.text('New expense head'));
    await tester.pumpAndSettle();
    expect(find.text('MAJOR HEAD'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Head fund reconciliation (Finance)'), 300);
    await tester.tap(find.text('Head fund reconciliation (Finance)'));
    expect(_navigations.single, (AdminTab.finance, null, 'record_payment'));
  });

  testWidgets('donations module renders in Hindi', (tester) async {
    await tester.pumpWidget(_host(AdminDonationsModule(ctx: _ctx()), lang: AppLang.hi));
    await tester.pumpAndSettle();
    expect(find.text('दान संग्रह'), findsOneWidget);
    await tester.tap(find.text('नया अभियान'));
    await tester.pumpAndSettle();
    expect(find.text('अभियान बनाएँ'), findsOneWidget);
  });

  testWidgets('flat multi-select search / all visible / clear visible', (tester) async {
    var selected = <String>[];
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => FlatMultiSelect(
        flats: const [
          FlatOption(id: '1', flatNumber: '101', subtitle: 'Ravi'),
          FlatOption(id: '2', flatNumber: '102', subtitle: 'Asha'),
          FlatOption(id: '3', flatNumber: '201'),
        ],
        selected: selected,
        onChanged: (v) => setState(() => selected = v),
      ),
    )));
    await tester.tap(find.text('All visible'));
    await tester.pump();
    expect(selected, ['101', '102', '201']);
    await tester.enterText(find.byType(TextField), 'asha');
    await tester.pump();
    expect(find.text('101'), findsNothing);
    await tester.tap(find.text('Clear visible'));
    await tester.pump();
    expect(selected, ['101', '201']);
    await tester.tap(find.text('102'));
    await tester.pump();
    expect(selected, ['101', '201', '102']);
  });

  testWidgets('cash / bank breakdown variants render', (tester) async {
    final r = ChannelTotals(cash: 1500, bank: 700);
    final p = ChannelTotals(cash: 2000, other: 10);
    for (final v in CashBankVariant.values) {
      await tester.pumpWidget(_host(SingleChildScrollView(child: CashBankBreakdown(receipts: r, payments: p, variant: v))));
      expect(tester.takeException(), isNull);
    }
    expect(find.textContaining('₹2,200'), findsWidgets);
  });

  test('every string key used by the module exists with en + hi text', () {
    final used = <String>{};
    final re = RegExp(r"'((?:evc|evm|efr|fer|spl|don|cem|fem|fms|cbb|sum|met|pm|sk|st|att|rdb)\.[A-Za-z0-9_.]+)'");
    for (final f in Directory('lib/features/admin/events').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      used.addAll(re.allMatches(f.readAsStringSync()).map((m) => m.group(1)!));
    }
    final missing = used.where((k) => !kEventsStrings.containsKey(k)).toList();
    expect(missing, isEmpty);
    for (final e in kEventsStrings.entries) {
      expect(e.value['en']?.trim().isNotEmpty, isTrue, reason: e.key);
      expect(e.value['hi']?.trim().isNotEmpty, isTrue, reason: e.key);
      final vars = RegExp(r'\{(\w+)\}');
      expect(vars.allMatches(e.value['hi']!).map((m) => m.group(1)).toSet(),
          vars.allMatches(e.value['en']!).map((m) => m.group(1)).toSet(),
          reason: 'placeholders differ for ${e.key}');
    }
  });
}
