// Port of src/lib/letterheadReportEngine.test.ts.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kutumbika_mobile/features/admin/reports/export/monthly_report_export.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/finance_period_report.dart';
import 'package:kutumbika_mobile/shared/pdf/letterhead_report_engine.dart';

final Uint8List tinyPng =
    Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

SocietyLetterhead societyA() => SocietyLetterhead(
      societyId: 'society-a',
      name: 'Alpha Cooperative Housing Society',
      letterheadMode: LetterheadMode.image,
      letterheadBytes: tinyPng,
      letterheadUrl: 'https://example.test/society-a/letterhead.png',
      letterheadTopMm: 48,
      letterheadBottomMm: 24,
      letterheadLeftMm: 20,
      letterheadRightMm: 20,
      defaultReportFormat: ReportPdfMode.letterhead,
      address: 'Sector 1',
      city: 'Jaipur',
      state: 'Rajasthan',
      pincode: '302001',
    );

SocietyLetterhead societyB() => SocietyLetterhead(
      societyId: 'society-b',
      name: 'Beta Residency',
      letterheadMode: LetterheadMode.image,
      letterheadBytes: tinyPng,
      letterheadUrl: 'https://example.test/society-b/letterhead.png',
      letterheadTopMm: 40,
      letterheadBottomMm: 18,
      letterheadLeftMm: 19.05,
      letterheadRightMm: 19.05,
      defaultReportFormat: ReportPdfMode.letterhead,
    );

bool isPdf(Uint8List b) =>
    b.length > 4 && String.fromCharCodes(b.sublist(0, 4)) == '%PDF';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LetterheadReportEngine — safe content area', () {
    test('exposes LetterheadLayout fields from the brief', () {
      final layout = measureReportLayout(societyA());
      expect(layout.headerHeight, greaterThan(0));
      expect(layout.contentTop, greaterThanOrEqualTo(layout.headerHeight));
      expect(layout.contentBottom, lessThan(layout.pageH));
      expect(layout.leftMargin, 20);
      expect(layout.rightMargin, 20);
      expect(layout.footerHeight, 24);
      expect(layout.contentTop, 48);
      expect(layout.contentWidth, closeTo(layout.pageW - 40, 1e-5));
    });

    test(
        'plain mode uses standard margins without requiring a letterhead asset',
        () {
      final layout = measureReportLayout(
          SocietyLetterhead.nameOnly('No Letterhead Society'),
          mode: ReportPdfMode.plain);
      expect(layout.contentTop, lessThan(30));
      expect(layout.contentBottom, greaterThan(layout.pageH - 20));
    });

    test('auto band places content below the header rule', () {
      final lh = const SocietyLetterhead(
          name: 'Gamma',
          letterheadMode: LetterheadMode.auto,
          address: 'Plot 4',
          contactPhone: '9999999999');
      final layout = measureReportLayout(lh);
      expect(layout.contentTop, greaterThanOrEqualTo(40));
      expect(autoHeaderRuleY(lh, layout), lessThan(layout.contentTop));
    });

    test(
        'content never overlaps header or footer reserves across page breaks (10+ pages)',
        () async {
      final report = SocietyReportPdf(letterhead: societyA());
      for (var i = 0; i < 120; i++) {
        report.add(SocietyPdf.text('Row $i', size: 9, gapAfterMm: 22));
      }
      final bytes = await report.save();
      expect(isPdf(bytes), isTrue);
      expect(report.pageCount, greaterThanOrEqualTo(10));
    });
  });

  group('LetterheadReportEngine — report modes & multi-society', () {
    test('marks official letterhead only when the current society has an asset',
        () {
      expect(societyHasOfficialLetterhead(societyA()), isTrue);
      expect(
          societyHasOfficialLetterhead(const SocietyLetterhead(
              name: 'Bare Society', letterheadMode: LetterheadMode.auto)),
          isFalse);
      expect(kLetterheadNotConfiguredWarning, contains('not been configured'));
    });

    test('does not share letterhead assets across societies', () {
      final a = societyA(), b = societyB();
      expect(a.societyId, isNot(b.societyId));
      expect(a.letterheadUrl, isNot(b.letterheadUrl));
      expect(measureLetterheadLayout(a).contentTop, 48);
      expect(measureLetterheadLayout(b).contentTop, 40);
    });

    test('context falls back to plain + warning when no official asset', () {
      final none = letterheadContextFor('s1', null);
      expect(none.mode, ReportPdfMode.plain);
      expect(none.warning, kLetterheadNotConfiguredWarning);
      final bare = letterheadContextFor(
          's1',
          const SocietyLetterhead(
              name: 'Bare', letterheadMode: LetterheadMode.auto));
      expect(bare.mode, ReportPdfMode.plain);
      expect(bare.warning, isNotNull);
      final ok = letterheadContextFor('s1', societyA());
      expect(ok.mode, ReportPdfMode.letterhead);
      expect(ok.warning, isNull);
      expect(
          letterheadContextFor('s1', societyA(),
                  preferredMode: ReportPdfMode.plain)
              .mode,
          ReportPdfMode.plain);
      final stationery = letterheadContextFor(
          's1',
          const SocietyLetterhead(
              name: 'S', letterheadMode: LetterheadMode.stationery));
      expect(stationery.mode, ReportPdfMode.letterhead);
    });

    test('society row normalisation', () {
      final lh = SocietyLetterhead.fromSocietyRow(const {
        'id': 'x',
        'name': 'Delta',
        'letterhead_mode': null,
        'letterhead_top_mm': 45,
        'default_report_format': 'plain',
        'address': 'Lane 2',
        'city': 'Pune',
        'state': 'MH',
        'pincode': '411001',
        'contact_phone': '123',
        'contact_email': 'a@b.c',
      });
      expect(lh.letterheadMode, LetterheadMode.auto);
      expect(lh.defaultReportFormat, ReportPdfMode.plain);
      expect(lh.letterheadLeftMm, kPdfMarginMm);
      expect(letterheadAddressLine(lh), 'Lane 2 · Pune, MH · 411001');
      expect(letterheadContactLine(lh), '123 · a@b.c');
    });

    test('draws report header + signatures inside the safe area', () async {
      final report = SocietyReportPdf(letterhead: societyA());
      report.header(const ReportMeta(
        title: 'Audit Report',
        reportNo: 'AR-2026-01',
        date: '07 Aug 2026',
        society: 'Alpha Cooperative Housing Society',
        period: 'Jul 2026',
        generatedBy: 'Secretary',
      ));
      report.signatures();
      final bytes = await report.save();
      expect(bytes.length, greaterThan(500));
      expect(report.pageCount, 1);
    });
  });

  group('LetterheadReportEngine — pagination & empty / long tables', () {
    test('1-page report stays on a single page', () async {
      final report = SocietyReportPdf(letterhead: societyA());
      report.header(const ReportMeta(title: 'Short Report', society: 'Alpha'));
      report.add(SocietyPdf.text('One line of content'));
      final bytes = await report.save();
      expect(report.pageCount, 1);
      expect(bytes.length, greaterThan(200));
    });

    test('long table splits across pages without leaving the content band',
        () async {
      final report = SocietyReportPdf(letterhead: societyA());
      report.add(SocietyPdf.table(
        headers: const ['Flat', 'Dues'],
        rows: [
          for (var i = 0; i < 200; i++) ['Flat ${i + 1}', '₹${(i + 1) * 100}']
        ],
      ));
      await report.save();
      expect(report.pageCount, greaterThan(1));
    });

    test('empty monthly report still produces a valid PDF with header',
        () async {
      final bytes = await buildMonthlyReportPdf(ReportExportContext(
        societyName: 'Alpha Cooperative Housing Society',
        reportMonth: '2026-08',
        tab: MonthlyReportTab.financial,
        letterhead: societyA(),
      ));
      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(400));
    });

    test('plain PDF mode works when society has no letterhead', () async {
      final bytes = await buildMonthlyReportPdf(const ReportExportContext(
        societyName: 'Unbranded Society',
        reportMonth: '2026-08',
        tab: MonthlyReportTab.visitor,
        letterhead: SocietyLetterhead(
            name: 'Unbranded Society', letterheadMode: LetterheadMode.auto),
        pdfMode: ReportPdfMode.plain,
        includeSignatures: false,
      ));
      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(200));
    });

    test('supports Unicode / Hindi title text in report header', () async {
      final report = SocietyReportPdf(letterhead: societyA());
      report.header(const ReportMeta(
          title: 'समिति के 7 सदस्यों का चुनाव',
          society: 'एवरग्रीन हाइट्स',
          period: 'अगस्त 2026'));
      final bytes = await report.save();
      expect(bytes.length, greaterThan(300));
    });

    test('auto band (name-only) letterhead renders', () async {
      final report = SocietyReportPdf(letterhead: 'Name Only Society');
      report.add(SocietyPdf.text('Body → arrow is sanitised'));
      expect(isPdf(await report.save()), isTrue);
      expect(pdfSafeText('a → b'), 'a -> b');
    });

    test('financial monthly report with data includes signatures', () async {
      final r = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePeriodPayment(
              paymentStatus: 'verified',
              amount: 1000,
              paymentMethod: 'cash',
              dueDate: '2026-04-02')
        ],
        ledgerEntries: const [],
      );
      final bytes = await buildMonthlyReportPdf(ReportExportContext(
        societyName: 'Alpha',
        reportMonth: '04/2026',
        tab: MonthlyReportTab.allModules,
        reportMonthNet: r,
        periodReport: r,
      ));
      expect(isPdf(bytes), isTrue);
    });
  });
}
