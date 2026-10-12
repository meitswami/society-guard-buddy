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
import 'package:kutumbika_mobile/features/governance/data/poll_repository.dart';
import 'package:kutumbika_mobile/features/governance/models/poll_models.dart';
import 'package:kutumbika_mobile/features/governance/polls/election_section.dart';
import 'package:kutumbika_mobile/features/governance/polls/general_polls_section.dart';
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
            id: 'a1',
            name: 'Admin',
            adminId: 'ADM1',
            societyId: 's1',
            permissions: AdminPanelPermissions.full),
      ),
      goTo: (tab, {query, subTab}) {},
      subTab: subTab,
    );

const _resident = SessionResident(
  societyId: 's1',
  societyName: 'Green Park',
  resident: ResidentUser(
      id: 'r1',
      name: 'Ravi',
      phone: '9876543210',
      flatId: 'f1',
      flatNumber: 'A-101'),
);

Widget _host(Widget child, AppLang lang, {bool dark = false}) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          extensions: [dark ? AppTokens.dark : AppTokens.light],
        ),
        builder: (context, nav) => I18nScope(
            translator: Translator(lang), child: nav ?? const SizedBox()),
        home: Scaffold(body: child),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget w, AppLang lang) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  await tester.pumpWidget(_host(w, lang, dark: lang == AppLang.hi));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

String _l(AppLang lang, String en, String hi) => lang == AppLang.hi ? hi : en;

PollsBundle _bundle() {
  final now = DateTime.now().toUtc();
  String iso(Duration d) => now.add(d).toIso8601String();
  Map<String, dynamic> poll(String id, String phase,
          {bool active = true,
          Map<String, dynamic>? results,
          String? method}) =>
      {
        'id': id,
        'society_id': 's1',
        'question': 'Managing Committee 2026 ($phase)',
        'description': 'Seven member MC election',
        'poll_kind': 'election',
        'is_active': active,
        'election_phase': phase,
        'nomination_starts_at': iso(const Duration(days: -1)),
        'nomination_ends_at': iso(const Duration(days: 1)),
        'voting_starts_at': iso(const Duration(days: -1)),
        'voting_ends_at': iso(const Duration(days: 1)),
        'voting_method': method,
        'election_quorum_required': 23,
        'member_count_at_election': 30,
        'target_committee_size': 7,
        'election_committee_seats': 3,
        'election_results': results,
      };
  final opts = <PollOptionRow>[];
  for (final pid in ['p1', 'p2', 'p3', 'p4']) {
    var i = 0;
    for (final post in [
      'president',
      'vice_president',
      'secretary',
      'treasurer',
      'committee',
      'committee'
    ]) {
      opts.add(PollOptionRow.fromJson({
        'id': '$pid-o${i++}',
        'poll_id': pid,
        'option_text': 'Candidate with a fairly long name $i',
        'election_post': post,
        'votes_count': 0,
        'flat_number': 'B-${100 + i}',
        'nomination_statement':
            'I will work for transparent accounts and better maintenance for every resident.',
      }));
    }
  }
  final results = {
    'president': {
      'option_id': 'p3-o0',
      'name': 'Candidate with a fairly long name 1',
      'score': 12
    },
    'vice_president': null,
    'secretary': {'option_id': 'p3-o2', 'name': 'Candidate 3', 'score': 9},
    'treasurer': null,
    'committee': [
      {'option_id': 'p3-o4', 'name': 'Candidate 5', 'score': 7},
    ],
    'formation': {
      'selected_runner_up_ids': [],
      'voluntary': [
        {
          'key': 'v1',
          'name': 'Volunteer One',
          'flat_number': 'C-3',
          'source': 'voluntary'
        },
      ],
      'executive_proposed': [],
    },
    'tallied_at': now.toIso8601String(),
  };
  return PollsBundle(
    polls: [
      PollRow(poll('p1', 'nomination')),
      PollRow(poll('p2', 'voting', method: 'secret_ballot')),
      PollRow(poll('p3', 'closed', active: false, results: results)),
      PollRow(poll('p4', 'applied', active: false, results: results)),
      PollRow({
        'id': 'g1',
        'question': 'Should we repaint the building this year?',
        'poll_kind': 'standard',
        'is_active': true
      }),
    ],
    options: [
      ...opts,
      PollOptionRow.fromJson({
        'id': 'g1-a',
        'poll_id': 'g1',
        'option_text': 'Yes',
        'votes_count': 3
      }),
      PollOptionRow.fromJson({
        'id': 'g1-b',
        'poll_id': 'g1',
        'option_text': 'No',
        'votes_count': 1
      }),
    ],
    ballots: [
      BallotRow.fromJson({
        'id': 'b1',
        'poll_id': 'p2',
        'voter_id': 'someone',
        'flat_number': 'A-1',
        'choices': {}
      })
    ],
    documents: [
      PollDocumentRow.fromJson({
        'id': 'd1',
        'poll_id': 'p1',
        'title': 'Election circular',
        'doc_kind': 'circular',
        'file_url': 'https://x/y.pdf'
      }),
    ],
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await TranslationsStore.load();
  });

  for (final lang in AppLang.values) {
    testWidgets('admin meetings + new notice sheet (${lang.name})',
        (tester) async {
      await _pump(tester, AdminMeetingsModule(ctx: _ctx()), lang);
      expect(find.text(_l(lang, 'No meetings yet.', 'अभी कोई बैठक नहीं।')),
          findsOneWidget);
      await tester.tap(find.text(_l(lang, 'New meeting', 'नई बैठक')));
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'New meeting notice', 'नई बैठक सूचना')),
          findsOneWidget);
      expect(find.text(_l(lang, 'Create & notify', 'बनाएँ व सूचित करें')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final resident in [false, true]) {
      testWidgets(
          'meeting detail renders every session section (${lang.name}, resident: $resident)',
          (tester) async {
        final meeting = MeetingRow.fromJson({
          'id': '12345678-aaaa',
          'society_id': 's1',
          'title': 'AGM 2026',
          'description': 'Annual general meeting',
          'meeting_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
          'location': 'Club house',
          'meeting_kind': 'annual',
          'status': 'scheduled',
          'published': true,
        });
        {
          await _pump(
            tester,
            MeetingDetailPage(
              viewer: MeetingViewer(
                  societyId: 's1', isResident: resident, adminName: 'Admin'),
              repo: const MeetingRepository('s1'),
              initial: meeting,
            ),
            lang,
          );
          expect(
              find.text(_l(lang, 'Session audio', 'सत्र ऑडियो'),
                  skipOffstage: false),
              findsOneWidget);
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('resident meetings view (${lang.name})', (tester) async {
      await _pump(tester, const ResidentMeetingsView(session: _resident), lang);
      expect(find.text(_l(lang, 'Society meetings', 'सोसायटी बैठकें')),
          findsOneWidget);
    });

    testWidgets('documents admin upload card + resident view (${lang.name})',
        (tester) async {
      await _pump(tester, AdminDocumentsModule(ctx: _ctx()), lang);
      await tester.tap(find.text(_l(lang, 'Add', 'जोड़ें')));
      await tester.pumpAndSettle();
      expect(
          find.text(_l(
              lang, 'PDF or image (max 15 MB)', 'PDF या चित्र (अधिकतम 15 MB)')),
          findsOneWidget);
      await _pump(
          tester, const ResidentDocumentsView(session: _resident), lang);
      expect(
          find.text(_l(lang, 'No documents published yet.',
              'अभी कोई दस्तावेज़ प्रकाशित नहीं।')),
          findsOneWidget);
    });

    testWidgets('committee admin: duties editor + member form (${lang.name})',
        (tester) async {
      await _pump(tester, AdminCommitteeModule(ctx: _ctx()), lang);
      await tester.tap(find.text(_l(lang, 'Create', 'बनाएँ')));
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'Save chart', 'चार्ट सहेजें')), findsOneWidget);
      await tester.tap(find.text(_l(lang, 'Add', 'जोड़ें')).first);
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'Add committee member', 'समिति सदस्य जोड़ें')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resident committee view (${lang.name})', (tester) async {
      await _pump(
          tester, const ResidentCommitteeView(session: _resident), lang);
      expect(
          find.text(_l(lang, 'No duties chart published yet.',
              'अभी कोई कर्तव्य चार्ट प्रकाशित नहीं।')),
          findsOneWidget);
    });

    testWidgets(
        'polls admin: election form, charter, general polls (${lang.name})',
        (tester) async {
      await _pump(tester, AdminPollsModule(ctx: _ctx()), lang);
      expect(find.text(lang == AppLang.hi ? 'हिंदी पीडीएफ' : 'English PDF'),
          findsOneWidget);
      await tester.ensureVisible(
          find.text(_l(lang, 'New society election', 'नया सोसायटी चुनाव')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(_l(lang, 'New society election', 'नया सोसायटी चुनाव')));
      await tester.pumpAndSettle();
      expect(
          find.text(
              _l(lang, 'Create election (nomination phase)',
                  'चुनाव बनाएँ (नामांकन चरण)'),
              skipOffstage: false),
          findsOneWidget);
      await tester
          .ensureVisible(find.text(_l(lang, 'General Polls', 'सामान्य मतदान')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l(lang, 'General Polls', 'सामान्य मतदान')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text(_l(lang, 'New general poll', 'नया सामान्य मतदान')));
      await tester.pumpAndSettle();
      expect(find.text(_l(lang, 'Create poll', 'मतदान बनाएँ')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _pump(tester, AdminPollsModule(ctx: _ctx(subTab: 'polls')), lang);
      expect(
          find.text(
              _l(lang, 'No general polls yet.', 'अभी कोई सामान्य मतदान नहीं।')),
          findsOneWidget);
    });

    for (final resident in [false, true]) {
      testWidgets(
          'election cards in every phase (${lang.name}, resident: $resident)',
          (tester) async {
        final viewer = resident
            ? const PollViewer(
                isResident: true,
                voterId: 'r1',
                memberId: 'm1',
                memberName: 'Ravi',
                flatId: 'f1',
                flatNumber: 'A-101')
            : const PollViewer(isResident: false, adminName: 'Admin');
        final b = _bundle();
        await _pump(
          tester,
          SingleChildScrollView(
            child: Column(children: [
              ElectionSection(
                  repo: const PollRepository('s1'),
                  viewer: viewer,
                  bundle: b,
                  onReload: () async {}),
              GeneralPollsSection(
                  repo: const PollRepository('s1'),
                  viewer: viewer,
                  bundle: b,
                  onReload: () async {},
                  onGoToElections: () {}),
            ]),
          ),
          lang,
        );
        expect(
            find.textContaining('Managing Committee 2026', skipOffstage: false),
            findsNWidgets(4));
        if (resident) {
          await tester.ensureVisible(find.text(
              _l(lang, 'Submit ballot (final)', 'मतपत्र जमा करें (अंतिम)')));
          await tester.pumpAndSettle();
          await tester.tap(
              find.textContaining('Candidate with a fairly long name 1').at(1));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('resident polls view (${lang.name})', (tester) async {
      await _pump(tester, const ResidentPollsView(session: _resident), lang);
      expect(
          find.text(_l(lang, 'No society elections yet.',
              'अभी कोई सोसायटी चुनाव नहीं।')),
          findsOneWidget);
    });
  }

  testWidgets('voting charter PDF renders through the offscreen pipeline',
      (tester) async {
    await tester.pumpWidget(_host(const SizedBox(), AppLang.hi));
    final context = tester.element(find.byType(SizedBox));
    for (final hi in [true, false]) {
      final bytes = await tester.runAsync(
        () => buildVotingCharterPdf(context,
            letterhead: const GovLetterhead(
                name: 'Green Park CHS', address: 'Sector 5'),
            hi: hi),
      );
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });
}
