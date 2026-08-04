import 'package:flutter/material.dart';

import '../core/theme/kutumbika_brand_theme.dart';
import '../core/theme/kutumbika_colors.dart';
import '../utils/voting_charter.dart';
import '../utils/voting_charter_pdf.dart';

/// Expandable voting charter with EN/HI view, PDF share sheet, and WhatsApp text.
class VotingCharterCard extends StatefulWidget {
  const VotingCharterCard({
    super.key,
    this.societyName,
    this.initiallyExpanded = true,
  });

  final String? societyName;
  final bool initiallyExpanded;

  @override
  State<VotingCharterCard> createState() => _VotingCharterCardState();
}

class _VotingCharterCardState extends State<VotingCharterCard> {
  CharterLang _viewLang = CharterLang.en;
  CharterLang? _pdfBusyLang;

  @override
  void initState() {
    super.initState();
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (code == 'hi') _viewLang = CharterLang.hi;
  }

  Future<void> _shareCharterText() async {
    final lang = _viewLang;
    final ok = await shareVotingCharterOnWhatsApp(
      societyName: widget.societyName,
      lang: lang,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (lang == CharterLang.hi ? 'WhatsApp खुल रहा है…' : 'Opening WhatsApp…')
              : (lang == CharterLang.hi ? 'WhatsApp नहीं खुल सका' : 'Could not open WhatsApp'),
        ),
      ),
    );
  }

  Future<void> _downloadCharterPdf(CharterLang lang) async {
    if (_pdfBusyLang != null) return;
    setState(() => _pdfBusyLang = lang);
    try {
      final result = await downloadOrShareVotingCharterPdf(
        societyName: widget.societyName,
        lang: lang,
      );
      if (!mounted) return;
      if (result == CharterPdfShareResult.dismissed) return;
      final msg = switch (result) {
        CharterPdfShareResult.shared => lang == CharterLang.hi
            ? 'चार्टर PDF साझा / सेव हो गया'
            : 'Charter PDF shared or saved',
        CharterPdfShareResult.failed => lang == CharterLang.hi
            ? 'शेयर उपलब्ध नहीं — कृपया पुनः प्रयास करें'
            : 'Share unavailable — please try again',
        CharterPdfShareResult.dismissed => '',
      };
      if (msg.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == CharterLang.hi
                ? 'PDF नहीं बन सका: ${e.toString().replaceFirst('Bad state: ', '')}'
                : 'PDF failed: ${e.toString().replaceFirst('Bad state: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfBusyLang = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    final content = votingCharterContent(_viewLang);
    final busy = _pdfBusyLang != null;
    final isHiView = _viewLang == CharterLang.hi;

    Widget pdfButton(CharterLang lang, String idleLabel, String busyLabel) {
      final thisBusy = _pdfBusyLang == lang;
      return FilledButton.tonalIcon(
        onPressed: busy ? null : () => _downloadCharterPdf(lang),
        icon: thisBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download, size: 18),
        label: Text(thisBusy ? busyLabel : idleLabel),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        leading: Icon(Icons.menu_book_outlined, color: brand.primary),
        title: Text(content.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          isHiView ? 'PDF डाउनलोड · WhatsApp साझा करें' : 'Download PDF · WhatsApp share',
          style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<CharterLang>(
                  segments: const [
                    ButtonSegment(value: CharterLang.hi, label: Text('हिंदी'), icon: Icon(Icons.translate, size: 16)),
                    ButtonSegment(value: CharterLang.en, label: Text('English'), icon: Icon(Icons.translate, size: 16)),
                  ],
                  selected: {_viewLang},
                  onSelectionChanged: (s) => setState(() => _viewLang = s.first),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    pdfButton(CharterLang.hi, 'हिंदी PDF', 'तैयार हो रहा है…'),
                    pdfButton(CharterLang.en, 'English PDF', 'Preparing…'),
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : _shareCharterText,
                      icon: const Icon(Icons.chat, size: 18),
                      label: Text(isHiView ? 'WhatsApp पाठ' : 'WhatsApp text'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isHiView
                      ? 'PDF शेयर शीट खोलता है — Save to Files / Downloads या WhatsApp चुनें। देवनागरी फ़ॉन्ट एम्बेड है।'
                      : 'PDF opens the share sheet — choose Save to Files / Downloads or WhatsApp. Devanagari font is embedded.',
                  style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                ),
                const SizedBox(height: 12),
                Text(
                  content.programHeading,
                  style: TextStyle(fontWeight: FontWeight.w600, color: brand.primary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(content.programIntro, style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted)),
                const SizedBox(height: 10),
                for (var i = 0; i < content.steps.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: brand.primary.withValues(alpha: 0.15),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: brand.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(content.steps[i].title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              content.steps[i].detail,
                              style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(content.rulesHeading, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                for (final sec in content.sections) ...[
                  Text(sec.heading, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (final p in sec.points)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text('• $p', style: const TextStyle(fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
