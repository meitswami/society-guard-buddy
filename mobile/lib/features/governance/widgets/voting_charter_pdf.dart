import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/export/export_kit.dart';
import '../../../core/format/formatters.dart';
import '../../../core/i18n/i18n.dart' show TranslationsStore;
import '../data/gov_letterhead.dart';
import '../logic/voting_charter.dart';
import 'offscreen_render.dart';

/// Charter copy for an explicit language (web `charterText`: static translations only).
String charterText(String key, {required bool hi}) =>
    charterTextFromRow(TranslationsStore.row(key), key, hi: hi);

// Document colours (paper output, identical in light / dark app themes — web HTML palette).
const _ink = Color(0xFF111827);
const _body = Color(0xFF1F2937);
const _muted = Color(0xFF4B5563);
const _meta = Color(0xFF6B7280);
const _indigo = Color(0xFF312E81);
const _indigoSoft = Color(0xFFC7D2FE);
const _badgeBg = Color(0xFFE0E7FF);
const _badgeFg = Color(0xFF3730A3);
const _paper = Color(0xFFFFFFFF);

const double _pageWidthPx =
    816; // Letter at ~96 dpi (web PDF_LETTER_CONTENT_WIDTH_PX)
const double _pxToPt = 612 / _pageWidthPx;
const double _mmToPt = 72 / 25.4;

TextStyle _ts(bool hi, double size, Color color,
        {FontWeight weight = FontWeight.w400, double height = 1.55}) =>
    TextStyle(
      fontFamily: hi ? 'NotoSansDevanagari' : 'NotoSans',
      fontFamilyFallback:
          hi ? const ['NotoSans'] : const ['NotoSansDevanagari'],
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
    );

/// Charter body (web `buildCharterHtml`, society line omitted — it sits in the letterhead).
Widget _charterBody({required bool hi, required double sideMarginPx}) {
  String t(String k) => charterText(k, hi: hi);
  Widget bullet(String s, {double size = 12}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: _ts(hi, size, _body)),
            Expanded(child: Text(s, style: _ts(hi, size, _body))),
          ],
        ),
      );
  final generated = Fmt.dateTimeFull(DateTime.now());
  return Container(
    color: _paper,
    padding: EdgeInsets.fromLTRB(sideMarginPx, 4, sideMarginPx, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t(votingCharterTitleKey),
            style: _ts(hi, 22, _ink, weight: FontWeight.w700, height: 1.35)),
        const SizedBox(height: 6),
        Text(
          '${hi ? 'तैयार' : 'Generated'}: $generated  ·  ${hi ? 'भाषा' : 'Language'}: ${hi ? 'हिन्दी' : 'English'}',
          style: _ts(hi, 11, _meta),
        ),
        const SizedBox(height: 12),
        Container(height: 1.5, color: _indigoSoft),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: _indigoSoft),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(VotingCharterSummary.titleKey),
                  style: _ts(hi, 16, _indigo, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(t(VotingCharterSummary.postsKey), style: _ts(hi, 13, _body)),
              const SizedBox(height: 8),
              for (final k in VotingCharterSummary.pointKeys)
                bullet(t(k), size: 12.5),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(t('votingCharter.program.heading'),
            style: _ts(hi, 16, _indigo, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(height: 1.5, color: _badgeBg),
        const SizedBox(height: 10),
        Text(t('votingCharter.program.intro'), style: _ts(hi, 13, _muted)),
        const SizedBox(height: 12),
        for (final (i, step) in electionProgramSteps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: _badgeBg, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: _ts(false, 11, _badgeFg,
                          weight: FontWeight.w700, height: 1)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(step.stepKey),
                          style: _ts(hi, 14, _ink, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(t(step.detailKey), style: _ts(hi, 12.5, _muted)),
                      const SizedBox(height: 6),
                      for (final k in step.pointKeys) bullet(t(k)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Auto letterhead band: logo · name · address · contact · indigo rule.
Widget _headerBand(GovLetterhead lh, ui.Image? logo, double sidePx) {
  final hiName = RegExp(r'[ऀ-ॿ]').hasMatch(lh.name);
  return Container(
    color: _paper,
    padding: EdgeInsets.fromLTRB(sidePx, 0, sidePx, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              SizedBox(
                  width: 53,
                  height: 53,
                  child: RawImage(image: logo, fit: BoxFit.contain)),
              const SizedBox(width: 13),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lh.name,
                      style: _ts(hiName, 20, _ink,
                          weight: FontWeight.w700, height: 1.3)),
                  if (lh.addressLine.isNotEmpty)
                    Text(lh.addressLine,
                        style: _ts(hiName, 10.5, _muted, height: 1.4)),
                  if (lh.contactLine.isNotEmpty)
                    Text(lh.contactLine,
                        style: _ts(false, 10.5, _muted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(height: 3, color: const Color(0xFF374178)),
      ],
    ),
  );
}

Widget _footerName(GovLetterhead lh) {
  final hiName = RegExp(r'[ऀ-ॿ]').hasMatch(lh.name);
  return Container(
      color: _paper,
      child: Text(lh.name,
          style: _ts(hiName, 12, _ink, weight: FontWeight.w700, height: 1.2)));
}

/// Build the Voting Charter PDF (web `buildVotingCharterPdfBlob`): rasterised body on
/// Letter pages with the society letterhead on every page and `n/N` page numbers.
Future<Uint8List> buildVotingCharterPdf(BuildContext context,
    {required GovLetterhead letterhead, required bool hi}) async {
  const pixelRatio = 1.75;
  final sidePx = letterhead.leftMm * _mmToPt / _pxToPt;
  final bodyImage = await renderWidgetToImage(
      context, _charterBody(hi: hi, sideMarginPx: sidePx),
      width: _pageWidthPx, pixelRatio: pixelRatio);
  if (!context.mounted) throw StateError('cancelled');

  ui.Image? headerImage;
  ui.Image? footerImage;
  if (!letterhead.hasPageImage) {
    final logo = await decodeImageBytes(letterhead.logoBytes);
    if (!context.mounted) throw StateError('cancelled');
    headerImage = await renderWidgetToImage(
        context, _headerBand(letterhead, logo, sidePx),
        width: _pageWidthPx, pixelRatio: pixelRatio);
    if (!context.mounted) throw StateError('cancelled');
    footerImage = await renderWidgetToImage(context, _footerName(letterhead),
        width: 500, pixelRatio: pixelRatio);
  }

  const pageW = 612.0;
  const pageH = 792.0;
  final left = letterhead.leftMm * _mmToPt;
  final right = letterhead.rightMm * _mmToPt;
  final topReserve = (letterhead.topMm < letterhead.leftMm
          ? letterhead.leftMm
          : letterhead.topMm) *
      _mmToPt;
  final bottomReserve =
      (letterhead.bottomMm < 14 ? 14 : letterhead.bottomMm) * _mmToPt;
  final headerTop = left - 2 * _mmToPt;
  final headerHeightPt =
      headerImage == null ? 0.0 : headerImage.height / pixelRatio * _pxToPt;
  final contentTop = headerImage == null
      ? topReserve
      : [headerTop + headerHeightPt + 6 * _mmToPt, topReserve]
          .reduce((a, b) => a > b ? a : b);
  final contentBottom = pageH - bottomReserve;
  final contentHeightPt = contentBottom - contentTop;
  final slicePx = (contentHeightPt / _pxToPt * pixelRatio).floor();

  final slices = await pageSlices(bodyImage, slicePx);
  final pages = <Uint8List>[];
  for (final s in slices) {
    pages.add(await cropToPng(bodyImage, s.$1, s.$2));
  }
  final headerPng = headerImage == null ? null : await imageToPng(headerImage);
  final footerPng = footerImage == null ? null : await imageToPng(footerImage);
  final footerW =
      footerImage == null ? 0.0 : footerImage.width / pixelRatio * _pxToPt;
  final footerH =
      footerImage == null ? 0.0 : footerImage.height / pixelRatio * _pxToPt;
  bodyImage.dispose();
  headerImage?.dispose();
  footerImage?.dispose();

  final doc =
      await ExportKit.newPdf(title: charterText(votingCharterTitleKey, hi: hi));
  final pageBg = letterhead.hasPageImage
      ? pw.MemoryImage(letterhead.letterheadBytes!)
      : null;
  final header = headerPng == null ? null : pw.MemoryImage(headerPng);
  final footer = footerPng == null ? null : pw.MemoryImage(footerPng);
  const metaColor = PdfColor.fromInt(0xFF4B5563);
  const ruleColor = PdfColor.fromInt(0xFF787D87);
  for (final (i, png) in pages.indexed) {
    final img = pw.MemoryImage(png);
    final slice = slices[i];
    final heightPt = slice.$2 / pixelRatio * _pxToPt;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        children: [
          if (pageBg != null)
            pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Image(pageBg,
                    width: pageW, height: pageH, fit: pw.BoxFit.fill)),
          pw.Positioned(
              left: 0,
              top: contentTop,
              child: pw.Image(img, width: pageW, height: heightPt)),
          if (header != null)
            pw.Positioned(
                left: 0,
                top: headerTop,
                child: pw.Image(header, width: pageW, height: headerHeightPt)),
          if (footer != null) ...[
            pw.Positioned(
              left: left,
              top: contentBottom,
              child: pw.Container(
                  width: pageW - left - right, height: 0.7, color: ruleColor),
            ),
            pw.Positioned(
                left: left,
                top: contentBottom + 3 * _mmToPt,
                child: pw.Image(footer, width: footerW, height: footerH)),
          ],
          pw.Positioned(
            right: right,
            top: contentBottom + 3.5 * _mmToPt,
            child: pw.Text('${i + 1}/${pages.length}',
                style: const pw.TextStyle(fontSize: 9, color: metaColor)),
          ),
        ],
      ),
    ));
  }
  return doc.save();
}
