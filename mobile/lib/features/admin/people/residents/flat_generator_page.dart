import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../../../utils/society_flat_layout.dart';
import '../data/flat_layout_service.dart';
import '../widgets/sensitive_verify.dart';

/// Bulk flat generation from the society layout (floors × flat series × blocks) —
/// same model and messages as the web superadmin society editor
/// (`trimSocietyFlatsToConfiguredRange` + `upsertSocietyFlatsFromLayout`, and
/// "Reset flats from this layout"). Pops `true` when flats changed.
class FlatGeneratorPage extends StatefulWidget {
  const FlatGeneratorPage(
      {super.key,
      required this.societyId,
      required this.adminId,
      required this.adminName});

  final String societyId;
  final String adminId;
  final String adminName;

  @override
  State<FlatGeneratorPage> createState() => _FlatGeneratorPageState();
}

class _FlatGeneratorPageState extends State<FlatGeneratorPage> {
  final _service = FlatLayoutService();
  final _floors = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _blocks = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_floors, _from, _to, _blocks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await _service.fetchLayout(widget.societyId);
      if (l != null) {
        _floors.text = l.totalFloors?.toString() ?? '';
        _from.text = l.flatSeriesStart ?? '';
        _to.text = l.flatSeriesEnd ?? '';
        _blocks.text = (l.blockNames ?? const []).join(', ');
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  SocietyFlatRangeInput get _layout {
    final blocks = parseBlockNamesCsv(_blocks.text);
    return SocietyFlatRangeInput(
      totalFloors: int.tryParse(_floors.text.trim()),
      flatSeriesStart: _from.text.trim().isEmpty ? null : _from.text.trim(),
      flatSeriesEnd: _to.text.trim().isEmpty ? null : _to.text.trim(),
      blockNames: blocks.isEmpty ? null : blocks,
    );
  }

  Future<bool> _verify(String title, String action) => SensitiveVerify.confirm(
        context,
        societyId: widget.societyId,
        adminId: widget.adminId,
        adminName: widget.adminName,
        title: title,
        actionLabel: action,
      );

  Future<void> _saveAndGenerate() async {
    final layout = _layout;
    if (canTrimFlatsFromSocietyRow(layout) == null) {
      AppFeedback.toast(
          context,
          context.tr(kInvalidLayoutError,
              'अमान्य फ्लैट विन्यास (मंज़िलें ≥ 1 और एक सौ-बैंड में मान्य सीमा, जैसे 101–111)।'),
          tone: BadgeTone.alert);
      return;
    }
    if (!await _verify(
        context.tr('Generate flats from layout', 'विन्यास से फ्लैट बनाएँ'),
        'generate_flats')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _service.saveLayout(widget.societyId, layout);
      final trimmed =
          await _service.trimToConfiguredRange(widget.societyId, layout);
      if (trimmed > 0 && mounted) {
        AppFeedback.toast(
            context, context.t('superadmin.flatsTrimmed', {'count': trimmed}));
        _changed = true;
      }
      final res = await _service.upsertFromLayout(widget.societyId, layout);
      if (!mounted) return;
      if (res.error != null) {
        AppFeedback.toast(context, res.error!, tone: BadgeTone.alert);
      } else {
        if (res.created > 0) _changed = true;
        AppFeedback.toast(
          context,
          context.t('superadmin.flatsGenerated',
              {'created': res.created, 'skipped': res.skipped}),
          tone: BadgeTone.success,
        );
      }
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('superadmin.resetFlatsConfirmTitle'),
      message: context.t('superadmin.resetFlatsConfirmText'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (!await _verify(context.t('superadmin.resetFlatsButton'), 'reset_flats'))
      return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final layout = _layout;
      await _service.saveLayout(widget.societyId, layout);
      final res = await _service.resetAndRegenerate(widget.societyId, layout);
      _changed = true;
      if (!mounted) return;
      if (res.error != null) {
        AppFeedback.toast(context, res.error!, tone: BadgeTone.alert);
      } else {
        AppFeedback.toast(
            context,
            context.t('superadmin.flatsRegenerated',
                {'created': res.created, 'skipped': res.skipped}),
            tone: BadgeTone.success);
      }
    } catch (_) {
      if (mounted)
        AppFeedback.toast(context, context.t('superadmin.flatResetFailed'),
            tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = canTrimFlatsFromSocietyRow(_layout);
    final wings = layoutWings(_layout.blockNames).length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar:
            AppBar(title: Text(context.tr('Generate flats', 'फ्लैट बनाएँ'))),
        body: _loading
            ? const LoadingView()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  CardSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionTitle(context.t('superadmin.flatNumbering'),
                            icon: Icons.apartment_outlined),
                        Text(context.t('superadmin.flatSeriesHelp'),
                            style: AppText.caption(context)),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: context.t('superadmin.totalFloors'),
                          controller: _floors,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: AppTextField(
                              label: context.t('superadmin.flatSeriesFrom'),
                              controller: _from,
                              keyboardType: TextInputType.number,
                              mono: true,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: context.t('superadmin.flatSeriesTo'),
                              controller: _to,
                              keyboardType: TextInputType.number,
                              mono: true,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: context.t('superadmin.blocksPlaceholder'),
                          controller: _blocks,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 4),
                        Text(context.t('superadmin.blocksHint'),
                            style: AppText.tiny(context)),
                        const SizedBox(height: 12),
                        NoticeBanner(
                          tone: range == null
                              ? BadgeTone.warning
                              : BadgeTone.info,
                          icon: range == null
                              ? Icons.warning_amber_rounded
                              : Icons.grid_view_outlined,
                          message: range == null
                              ? context.tr(kInvalidLayoutError,
                                  'अमान्य फ्लैट विन्यास (मंज़िलें ≥ 1 और एक सौ-बैंड में मान्य सीमा, जैसे 101–111)।')
                              : context.tr(
                                  '${range.valid.length * wings} flats (${range.valid.length} per wing × $wings): ${range.sortedNumbers.first}–${range.sortedNumbers.last}',
                                  '${range.valid.length * wings} फ्लैट (${range.valid.length} प्रति विंग × $wings): ${range.sortedNumbers.first}–${range.sortedNumbers.last}',
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(context.t('superadmin.flatGenerateHint'),
                            style: AppText.tiny(context)),
                        const SizedBox(height: 6),
                        Text(context.t('superadmin.flatTrimHint'),
                            style: AppText.tiny(context)),
                        const SizedBox(height: 16),
                        AppButton(
                          label: context.tr('Save layout & generate flats',
                              'विन्यास सहेजें और फ्लैट बनाएँ'),
                          icon: Icons.playlist_add,
                          loading: _busy,
                          onPressed: _saveAndGenerate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CardSection(
                    borderColor:
                        AppTokens.tint(context.tokens.destructive, 0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.t('superadmin.resetFlatsHint'),
                            style: AppText.caption(context)),
                        const SizedBox(height: 12),
                        AppButton.destructive(
                          label: context.t('superadmin.resetFlatsButton'),
                          icon: Icons.restart_alt,
                          onPressed: _busy ? null : _reset,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
