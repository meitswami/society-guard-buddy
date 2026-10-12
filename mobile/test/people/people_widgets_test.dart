import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/core/theme/app_tokens.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module.dart';
import 'package:kutumbika_mobile/features/admin/people/admin_directory_module.dart';
import 'package:kutumbika_mobile/features/admin/people/admin_guards_module.dart';
import 'package:kutumbika_mobile/features/admin/people/admin_parking_module.dart';
import 'package:kutumbika_mobile/features/admin/people/admin_residents_module.dart';
import 'package:kutumbika_mobile/features/admin/people/export/residents_pdf.dart';
import 'package:kutumbika_mobile/features/admin/people/export/society_letterhead.dart';
import 'package:kutumbika_mobile/features/admin/people/flat360/flat360_models.dart';
import 'package:kutumbika_mobile/features/admin/people/flat360/flat360_panel.dart';
import 'package:kutumbika_mobile/features/shared/directory/directory_models.dart';
import 'package:kutumbika_mobile/features/shared/directory/directory_view.dart';
import 'package:kutumbika_mobile/features/shared/directory/person_avatar.dart';
import 'package:kutumbika_mobile/models/admin_user.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTokens.light]),
        builder: (context, c) => I18nScope(translator: const Translator(AppLang.en), child: c!),
        home: Scaffold(body: child),
      ),
    );

AdminModuleContext _ctx({String? query, String? subTab}) => AdminModuleContext(
      session: const SessionAdmin(
        societyId: 's1',
        societyName: 'Green Park',
        admin: AdminUser(id: 'a1', name: 'Admin', adminId: 'ADMIN', societyId: 's1', permissions: AdminPanelPermissions.full),
      ),
      goTo: (tab, {query, subTab}) {},
      initialQuery: query,
      subTab: subTab,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'app-lang': 'en'});
    await AppPrefs.init();
    await TranslationsStore.load();
  });

  testWidgets('admin people modules render without a backend', (tester) async {
    await tester.pumpWidget(_host(AdminResidentsModule(ctx: _ctx(query: '101'))));
    await tester.pumpAndSettle();
    expect(find.text('Residents'), findsOneWidget);
    expect(find.text('No flats found'), findsOneWidget);
    expect(find.text('0 Logins'), findsOneWidget);
    expect(find.text('101'), findsOneWidget); // search pre-filled from ctx.initialQuery

    await tester.tap(find.text('Add Flat').first);
    await tester.pumpAndSettle();
    expect(find.text('Add New Flat'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '305');
    await tester.pump();
    expect(find.text('3rd Floor'), findsOneWidget); // floor auto-suggestion

    await tester.pumpWidget(_host(AdminGuardsModule(ctx: _ctx())));
    await tester.pumpAndSettle();
    expect(find.text('Guards'), findsOneWidget);
    expect(find.text('0 guards registered'), findsOneWidget);

    await tester.pumpWidget(_host(AdminParkingModule(ctx: _ctx())));
    await tester.pumpAndSettle();
    expect(find.text('Parking Management'), findsOneWidget);
    expect(find.text('0 allocated · 0 available'), findsOneWidget);

    await tester.pumpWidget(_host(AdminDirectoryModule(ctx: _ctx())));
    await tester.pumpAndSettle();
    expect(find.text('Flats & Members'), findsOneWidget);
    expect(find.textContaining('Tap '), findsOneWidget);
  });

  testWidgets('resident directory variant', (tester) async {
    await tester.pumpWidget(_host(const DirectoryView(societyId: 's1', viewerRole: 'resident', viewerName: 'Asha', viewerFlatId: 'f1')));
    await tester.pumpAndSettle();
    expect(find.text('Flats & Members'), findsNothing);
    expect(find.textContaining('to manage your household'), findsOneWidget);
  });

  testWidgets('person avatar falls back to the initial', (tester) async {
    await tester.pumpWidget(_host(const PersonAvatar(name: 'ravi', size: PersonAvatarSize.lg)));
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('flat 360 panel without backend shows the empty profile', (tester) async {
    await tester.pumpWidget(_host(const SingleChildScrollView(
      child: Flat360ProfilePanel(params: Flat360FetchParams(societyId: 's1', flatId: 'f1', flatNumber: '101')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Member 360°'), findsOneWidget);
    expect(find.text('No pending dues'), findsOneWidget);
    expect(find.text('No activity in the last 12 months'), findsOneWidget);
  });

  test('residents PDF helpers', () {
    expect(residentsDirectoryPdfFilename('Green  Park Society', now: DateTime.utc(2026, 10, 12)), 'Green_Park_Society_residents_2026-10-12.pdf');
    expect(residentsDirectoryPdfFilename(''), startsWith('society_residents_'));
    final m = PeopleMember.fromJson({
      'id': 'm', 'flat_id': 'f', 'name': 'N', 'relation': 'tenant', 'phone': '9', 'age': 30, 'spouse_name': 'S',
      'police_verification': 'verified', 'date_joining': '2026-01-05',
    });
    expect(residentPdfMemberLines(m), [
      'Relation: tenant',
      'Phone: 9',
      'Age: 30',
      'Spouse: S',
      'Police verification: verified',
      'Joined: 05/01/2026',
    ]);
    expect(residentPdfFlatMeta(PeopleFlat.fromJson({'id': 'f', 'flat_number': '101', 'owner_name': 'R', 'floor': '1st Floor', 'wing': 'A'})),
        'Owner: R · 1st Floor · Wing A');
    final lh = SocietyLetterhead(name: 'X', address: 'Road 1', city: 'Pune', state: 'MH', pincode: '411001', contactEmail: 'a@b.c');
    expect(lh.addressLine, 'Road 1 · Pune, MH · 411001');
    expect(lh.contactLine, 'a@b.c');
    expect(lh.brandMode, 'auto');
  });

  testWidgets('residents PDF builds (plain mode)', (tester) async {
    final bytes = await tester.runAsync(() => buildResidentsDirectoryPdf(
          flats: [PeopleFlat.fromJson({'id': 'f1', 'flat_number': '102'}), PeopleFlat.fromJson({'id': 'f2', 'flat_number': '101', 'owner_name': 'राम'})],
          members: [PeopleMember.fromJson({'id': 'm', 'flat_id': 'f2', 'name': 'राम कुमार', 'relation': 'owner', 'is_primary': true})],
          letterhead: LetterheadContext(letterhead: SocietyLetterhead(name: 'Green Park'), plain: true),
        ));
    expect(bytes, isNotNull);
    expect(String.fromCharCodes(bytes!.take(4)), '%PDF');
  });
}
