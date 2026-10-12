import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/core/theme/app_tokens.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module.dart';
import 'package:kutumbika_mobile/features/governance/admin_committee_module.dart';
import 'package:kutumbika_mobile/features/governance/admin_documents_module.dart';
import 'package:kutumbika_mobile/features/governance/admin_meetings_module.dart';
import 'package:kutumbika_mobile/features/governance/admin_polls_module.dart';
import 'package:kutumbika_mobile/features/governance/data/gov_letterhead.dart';
import 'package:kutumbika_mobile/features/governance/data/meeting_repository.dart';
import 'package:kutumbika_mobile/features/governance/meetings/meeting_detail_page.dart';
import 'package:kutumbika_mobile/features/governance/meetings/meetings_page.dart';
import 'package:kutumbika_mobile/features/governance/models/meeting_models.dart';
import 'package:kutumbika_mobile/features/governance/resident_committee_view.dart';
import 'package:kutumbika_mobile/features/governance/resident_documents_view.dart';
import 'package:kutumbika_mobile/features/governance/resident_meetings_view.dart';
import 'package:kutumbika_mobile/features/governance/resident_polls_view.dart';
import 'package:kutumbika_mobile/features/governance/widgets/voting_charter_pdf.dart';
import 'package:kutumbika_mobile/models/admin_user.dart';
import 'package:kutumbika_mobile/models/resident_user.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';

AdminModuleContext _ctx({String? subTab}) => AdminModuleContext(
      session: const SessionAdmin(
        societyId: 's1',
        societyName: 'Green Park',
        admin: AdminUser(
            id: 'a1', name: 'Admin', adminId: 'ADM1', societyId: 's1', permissions: AdminPanelPermissions.full),
      ),
      goTo: (tab, {query, subTab}) {},
      subTab: subTab,
    );

const _resident = SessionResident(
  societyId: 's1',
  societyName: 'Green Park',
  resident: ResidentUser(id: 'r1', name: 'Ravi', phone: '9876543210', flatId: 'f1', flatNumber: 'A-101'),
);

Widget _host(Widget child, AppLang lang, {bool dark = false}) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          extensions: [dark ? AppTokens.dark : AppTokens.light],
        ),
        builder: (context, nav) => I18nScope(translator: Translator(lang), child: nav ?? const SizedBox()),
        home: Scaffold(body: child),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget w, AppLang lang) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(w, lang, dark: lang == AppLang.hi));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

String _l(AppLang lang, String en, String hi) => lang == AppLang.hi ? hi : en;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await TranslationsStore.load();
  });

  for (final lang in AppLang.values) {
    testWidgets('admin meetings + new notice sheet (${lang.name})', (tester) async {
      await _pump(tester, AdminMeetingsModule(ctx: _ctx()), lang);
      expect(find.text(_l(lang, 'No meetings yet.', 'अभी कोई बैठक नहीं।')), findsOneWidget);
      await tester.tap(find.text(_l(lang, 'New meeting', 'नई बैठक')));
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'New meeting notice', 'नई बैठक सूचना')), findsOneWidget);
      expect(find.text(_l(lang, 'Create & notify', 'बनाएँ व सूचित करें')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final resident in [false, true]) {
      testWidgets('meeting detail renders every session section (${lang.name}, resident: $resident)', (tester) async {
        final meeting = MeetingRow.fromJson({
          'id': '12345678-aaaa',
          'society_id': 's1',
          'title': 'AGM 2026',
          'description': 'Annual general meeting',
          'meeting_at': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
          'location': 'Club house',
          'meeting_kind': 'annual',
          'status': 'scheduled',
          'published': true,
        });
        {
          await _pump(
            tester,
            MeetingDetailPage(
              viewer: MeetingViewer(societyId: 's1', isResident: resident, adminName: 'Admin'),
              repo: const MeetingRepository('s1'),
              initial: meeting,
            ),
            lang,
          );
          expect(find.text(_l(lang, 'Session audio', 'सत्र ऑडियो'), skipOffstage: false), findsOneWidget);
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('resident meetings view (${lang.name})', (tester) async {
      await _pump(tester, const ResidentMeetingsView(session: _resident), lang);
      expect(find.text(_l(lang, 'Society meetings', 'सोसायटी बैठकें')), findsOneWidget);
    });

    testWidgets('documents admin upload card + resident view (${lang.name})', (tester) async {
      await _pump(tester, AdminDocumentsModule(ctx: _ctx()), lang);
      await tester.tap(find.text(_l(lang, 'Add', 'जोड़ें')));
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'PDF or image (max 15 MB)', 'PDF या चित्र (अधिकतम 15 MB)')), findsOneWidget);
      await _pump(tester, const ResidentDocumentsView(session: _resident), lang);
      expect(find.text(_l(lang, 'No documents published yet.', 'अभी कोई दस्तावेज़ प्रकाशित नहीं।')), findsOneWidget);
    });

    testWidgets('committee admin: duties editor + member form (${lang.name})', (tester) async {
      await _pump(tester, AdminCommitteeModule(ctx: _ctx()), lang);
      await tester.tap(find.text(_l(lang, 'Create', 'बनाएँ')));
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'Save chart', 'चार्ट सहेजें')), findsOneWidget);
      await tester.tap(find.text(_l(lang, 'Add', 'जोड़ें')).first);
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'Add committee member', 'समिति सदस्य जोड़ें')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resident committee view (${lang.name})', (tester) async {
      await _pump(tester, const ResidentCommitteeView(session: _resident), lang);
      expect(find.text(_l(lang, 'No duties chart published yet.', 'अभी कोई कर्तव्य चार्ट प्रकाशित नहीं।')),
          findsOneWidget);
    });

    testWidgets('polls admin: election form, charter, general polls (${lang.name})', (tester) async {
      await _pump(tester, AdminPollsModule(ctx: _ctx()), lang);
      expect(find.text(lang == AppLang.hi ? 'हिंदी पीडीएफ' : 'English PDF'), findsOneWidget);
      await tester.ensureVisible(find.text(_l(lang, 'New society election', 'नया सोसायटी चुनाव')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l(lang, 'New society election', 'नया सोसायटी चुनाव')));
      await tester.pumpAndSettle();
      expect(
          find.text(_l(lang, 'Create election (nomination phase)', 'चुनाव बनाएँ (नामांकन चरण)'), skipOffstage: false),
          findsOneWidget);
      await tester.dragUntilVisible(
          find.text(_l(lang, 'General Polls', 'सामान्य मतदान')), find.byType(Scrollable).first, const Offset(0, 300));
      await tester.tap(find.text(_l(lang, 'General Polls', 'सामान्य मतदान')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l(lang, 'New general poll', 'नया सामान्य मतदान')));
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'Create poll', 'मतदान बनाएँ')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _pump(tester, AdminPollsModule(ctx: _ctx(subTab: 'polls')), lang);
      expect(find.text(_l(lang, 'No general polls yet.', 'अभी कोई सामान्य मतदान नहीं।')), findsOneWidget);
    });

    testWidgets('resident polls view (${lang.name})', (tester) async {
      await _pump(tester, const ResidentPollsView(session: _resident), lang);
      expect(find.text(_l(lang, 'No society elections yet.', 'अभी कोई सोसायटी चुनाव नहीं।')), findsOneWidget);
    });
  }

  testWidgets('voting charter PDF renders through the offscreen pipeline', (tester) async {
    await tester.pumpWidget(_host(const SizedBox(), AppLang.hi));
    final context = tester.element(find.byType(SizedBox));
    for (final hi in [true, false]) {
      final bytes = await tester.runAsync(
        () => buildVotingCharterPdf(context,
            letterhead: const GovLetterhead(name: 'Green Park CHS', address: 'Sector 5'), hi: hi),
      );
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });
}
