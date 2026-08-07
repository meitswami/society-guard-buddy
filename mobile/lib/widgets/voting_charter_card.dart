import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../core/theme/kutumbika_brand_theme.dart';
import '../core/theme/kutumbika_colors.dart';
import '../utils/voting_charter.dart';
import '../utils/voting_charter_pdf.dart';

/// Expandable voting charter with EN/HI view, PDF share sheet, and WhatsApp text.
class VotingCharterCard extends StatefulWidget {
  const VotingCharterCard({
    super.key,
    this.societyId,
    this.societyName,
    this.initiallyExpanded = true,
  });

  final String? societyId;
  final String? societyName;
  final bool initiallyExpanded;

  @override
  State<VotingCharterCard> createState() => _VotingCharterCardState();
}

class _VotingCharterCardState extends State<VotingCharterCard> {
  CharterLang _viewLang = CharterLang.en;
  CharterLang? _pdfBusyLang;
  String _displayName = '';
  String _addressLine = '';
  String _contactLine = '';
  Uint8List? _logoBytes;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (code == 'hi') _viewLang = CharterLang.hi;
    _displayName = widget.societyName?.trim() ?? '';
    _loadLetterhead();
  }

  @override
  void didUpdateWidget(covariant VotingCharterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.societyId != widget.societyId || oldWidget.societyName != widget.societyName) {
      _displayName = widget.societyName?.trim() ?? _displayName;
      _loadLetterhead();
    }
  }

  Future<void> _loadLetterhead() async {
    final sid = widget.societyId;
    if (sid == null || sid.isEmpty || !Env.isConfigured) {
      if (!mounted) return;
      setState(() {
        if (_displayName.isEmpty) _displayName = 'Society';
      });
      return;
    }
    try {
      final row = await SupabaseBootstrap.client.from('societies').select(
            'name, logo_url, address, city, state, pincode, contact_phone, contact_email',
          ).eq('id', sid).maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() {
          if (_displayName.isEmpty) _displayName = widget.societyName?.trim() ?? 'Society';
        });
        return;
      }
      final name = (row['name'] as String?)?.trim();
      final address = (row['address'] as String?)?.trim();
      final city = (row['city'] as String?)?.trim();
      final state = (row['state'] as String?)?.trim();
      final pincode = (row['pincode'] as String?)?.trim();
      final phone = (row['contact_phone'] as String?)?.trim();
      final email = (row['contact_email'] as String?)?.trim();
      final logoUrl = (row['logo_url'] as String?)?.trim();
      final cityState = [if (city != null && city.isNotEmpty) city, if (state != null && state.isNotEmpty) state].join(', ');
      final addrParts = <String>[
        if (address != null && address.isNotEmpty) address,
        if (cityState.isNotEmpty) cityState,
        if (pincode != null && pincode.isNotEmpty) pincode,
      ];
      final contactParts = <String>[
        if (phone != null && phone.isNotEmpty) phone,
        if (email != null && email.isNotEmpty) email,
      ];

      Uint8List? logoBytes;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          final client = HttpClient();
          final req = await client.getUrl(Uri.parse(logoUrl));
          final res = await req.close();
          if (res.statusCode == 200) {
            logoBytes = await consolidateHttpClientResponseBytes(res);
            if (logoBytes.isEmpty) logoBytes = null;
          }
          client.close(force: true);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _displayName = (name != null && name.isNotEmpty) ? name : (widget.societyName?.trim() ?? 'Society');
        _addressLine = addrParts.join(' · ');
        _contactLine = contactParts.join(' · ');
        _logoUrl = logoUrl;
        _logoBytes = logoBytes;
      });
    } catch (e) {
      debugPrint('[VotingCharterCard] letterhead load failed: $e');
      if (!mounted) return;
      setState(() {
        if (_displayName.isEmpty) _displayName = widget.societyName?.trim() ?? 'Society';
      });
    }
  }

  Future<void> _shareCharterText() async {
    final lang = _viewLang;
    final ok = await shareVotingCharterOnWhatsApp(
      societyName: _displayName.isNotEmpty ? _displayName : widget.societyName,
      lang: lang,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (lang == CharterLang.hi ? 'व्हाट्सऐप खुल रहा है…' : 'Opening WhatsApp…')
              : (lang == CharterLang.hi ? 'व्हाट्सऐप नहीं खुल सका' : 'Could not open WhatsApp'),
        ),
      ),
    );
  }

  Future<void> _downloadCharterPdf(CharterLang lang) async {
    if (_pdfBusyLang != null) return;
    setState(() => _pdfBusyLang = lang);
    try {
      final result = await downloadOrShareVotingCharterPdf(
        societyName: _displayName.isNotEmpty ? _displayName : widget.societyName,
        addressLine: _addressLine.isNotEmpty ? _addressLine : null,
        contactLine: _contactLine.isNotEmpty ? _contactLine : null,
        logoBytes: _logoBytes,
        lang: lang,
      );
      if (!mounted) return;
      if (result == CharterPdfShareResult.dismissed) return;
      final msg = switch (result) {
        CharterPdfShareResult.shared => lang == CharterLang.hi
            ? 'नियमपत्र पीडीएफ साझा / सहेजा गया'
            : 'Charter PDF shared or saved',
        CharterPdfShareResult.failed => lang == CharterLang.hi
            ? 'साझा करना उपलब्ध नहीं — कृपया पुनः प्रयास करें'
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
                ? 'पीडीएफ नहीं बन सका: ${e.toString().replaceFirst('Bad state: ', '')}'
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
    final name = _displayName.isNotEmpty ? _displayName : (widget.societyName?.trim() ?? 'Society');

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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Always-visible society letterhead band
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  decoration: BoxDecoration(
                    color: brand.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: brand.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_logoBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(_logoBytes!, width: 40, height: 40, fit: BoxFit.contain),
                            )
                          else if (_logoUrl != null && _logoUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                _logoUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _InitialAvatar(name: name, color: brand.primary),
                              ),
                            )
                          else
                            _InitialAvatar(name: name, color: brand.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: brand.primary,
                                  ),
                                ),
                                if (_addressLine.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _addressLine,
                                    style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                                  ),
                                ],
                                if (_contactLine.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    _contactLine,
                                    style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, thickness: 1, color: brand.primary.withValues(alpha: 0.35)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                    pdfButton(CharterLang.hi, 'हिंदी पीडीएफ', 'तैयार हो रहा है…'),
                    pdfButton(CharterLang.en, 'English PDF', 'Preparing…'),
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : _shareCharterText,
                      icon: const Icon(Icons.chat, size: 18),
                      label: Text(isHiView ? 'व्हाट्सऐप पाठ' : 'WhatsApp text'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: brand.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: brand.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.summaryTitle,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brand.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(content.summaryPosts, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      for (final p in content.summaryPoints)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(p, style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted)),
                        ),
                    ],
                  ),
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
                            if (content.steps[i].points.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              for (final p in content.steps[i].points)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2, bottom: 4),
                                  child: Text('• $p', style: const TextStyle(fontSize: 12)),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(initial, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    );
  }
}
