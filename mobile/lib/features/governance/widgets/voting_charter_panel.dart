import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../data/gov_letterhead.dart';
import '../logic/voting_charter.dart';
import 'gov_widgets.dart';
import 'voting_charter_pdf.dart';

/// Port of web `VotingCharterPanel.tsx`: society letterhead band, bye-law summary,
/// step-by-step member program; admins also get Hindi / English PDF and WhatsApp share.
class VotingCharterPanel extends StatefulWidget {
  const VotingCharterPanel({super.key, required this.societyId, this.societyName, this.isAdmin = false});

  final String societyId;
  final String? societyName;
  final bool isAdmin;

  @override
  State<VotingCharterPanel> createState() => _VotingCharterPanelState();
}

class _VotingCharterPanelState extends State<VotingCharterPanel> {
  bool _open = true;
  bool _programOpen = true;
  GovLetterhead? _lh;
  String? _busyLang;

  @override
  void initState() {
    super.initState();
    _loadLetterhead();
  }

  Future<void> _loadLetterhead() async {
    final lh = await GovLetterhead.fetch(widget.societyId);
    if (!mounted) return;
    setState(() => _lh = lh ?? GovLetterhead(name: (widget.societyName ?? '').trim().isEmpty ? 'Society' : widget.societyName!.trim()));
  }

  String get _displayName {
    final n = (_lh?.name ?? widget.societyName ?? '').trim();
    return n.isEmpty ? 'Society' : n;
  }

  Future<void> _pdf(String lang, {bool whatsapp = false}) async {
    if (_busyLang != null) return;
    setState(() => _busyLang = lang);
    final hi = lang == 'hi';
    try {
      final lh = _lh ?? await GovLetterhead.fetch(widget.societyId) ?? GovLetterhead(name: _displayName);
      if (!mounted) return;
      final bytes = await buildVotingCharterPdf(context, letterhead: lh, hi: hi);
      if (bytes.length < 100) throw StateError('PDF was empty');
      await ExportKit.sharePdf(
        bytes,
        votingCharterPdfFilename(_displayName, hi: hi),
        text: whatsapp ? charterText('votingCharter.shareMessage', hi: hi) : null,
      );
      if (!mounted) return;
      if (!whatsapp) {
        GovToast.ok(context, hi ? 'नियमपत्र पीडीएफ सहेजें / साझा करें' : 'Use Share to save the charter PDF');
      }
    } catch (e) {
      if (mounted) {
        GovToast.error(
          context,
          hi ? 'हिंदी पीडीएफ प्राप्त नहीं हो सका — कृपया पुनः प्रयास करें' : 'Could not download English PDF — please try again',
        );
      }
    } finally {
      if (mounted) setState(() => _busyLang = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.accent;
    final lh = _lh;
    final hiUi = context.lang == AppLang.hi;
    Widget letterheadBand() {
      final img = lh?.hasPageImage == true ? lh!.letterheadBytes : null;
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.background, 0.5),
          border: Border(bottom: BorderSide(color: AppTokens.tint(c, 0.2))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (img != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96),
                child: Image.memory(img, fit: BoxFit.contain, alignment: Alignment.centerLeft),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTokens.tint(c, 0.1),
                      border: Border.all(color: AppTokens.tint(c, 0.25)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: lh?.logoBytes != null
                        ? Image.memory(lh!.logoBytes!, fit: BoxFit.contain)
                        : Text(_displayName.characters.first.toUpperCase(),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          (lh?.addressLine ?? '').isNotEmpty ? lh!.addressLine : context.t('votingCharter.summary.title'),
                          style: AppText.caption(context).copyWith(fontSize: 11),
                        ),
                        if ((lh?.contactLine ?? '').isNotEmpty)
                          Text(lh!.contactLine, style: AppText.caption(context).copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Container(height: 2, color: AppTokens.tint(c, 0.8)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTokens.tint(c, 0.05),
        border: Border.all(color: AppTokens.tint(c, 0.3)),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.history_edu_outlined, size: 16, color: c),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.t(votingCharterTitleKey),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c)),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: t.mutedForeground),
                ],
              ),
            ),
          ),
          if (_open) ...[
            letterheadBand(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isAdmin) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        MiniButton(
                          label: _busyLang == 'hi' ? 'तैयार हो रहा है…' : 'हिंदी पीडीएफ',
                          icon: Icons.download_outlined,
                          busy: _busyLang == 'hi',
                          onPressed: _busyLang != null ? null : () => _pdf('hi'),
                        ),
                        MiniButton(
                          label: _busyLang == 'en' ? 'Preparing…' : 'English PDF',
                          icon: Icons.download_outlined,
                          busy: _busyLang == 'en',
                          onPressed: _busyLang != null ? null : () => _pdf('en'),
                        ),
                        MiniButton(
                          label: context.t('votingCharter.shareWhatsApp'),
                          icon: Icons.share_outlined,
                          variant: MiniVariant.success,
                          onPressed: _busyLang != null ? null : () => _pdf(hiUi ? 'hi' : 'en', whatsapp: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.tint(t.background, 0.6),
                      border: Border.all(color: AppTokens.tint(c, 0.25)),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t(VotingCharterSummary.titleKey),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c)),
                        const SizedBox(height: 4),
                        Text(context.t(VotingCharterSummary.postsKey), style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        for (final k in VotingCharterSummary.pointKeys)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(context.t(k), style: AppText.caption(context)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTokens.tint(t.background, 0.4),
                      border: Border.all(color: AppTokens.tint(c, 0.2)),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _programOpen = !_programOpen),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(context.t('votingCharter.program.heading'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                                Icon(_programOpen ? Icons.expand_less : Icons.expand_more, size: 16, color: t.mutedForeground),
                              ],
                            ),
                          ),
                        ),
                        if (_programOpen)
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTokens.tint(c, 0.15)))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(context.t('votingCharter.program.intro'), style: AppText.caption(context).copyWith(fontSize: 11)),
                                const SizedBox(height: 10),
                                for (final (i, step) in electionProgramSteps.indexed)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          margin: const EdgeInsets.only(top: 2),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(color: AppTokens.tint(c, 0.15), shape: BoxShape.circle),
                                          child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(context.t(step.stepKey), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 4),
                                              Text(context.t(step.detailKey), style: AppText.caption(context)),
                                              const SizedBox(height: 4),
                                              for (final k in step.pointKeys)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 3, left: 4),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('•  ', style: TextStyle(fontSize: 12)),
                                                      Expanded(child: Text(context.t(k), style: const TextStyle(fontSize: 12))),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
