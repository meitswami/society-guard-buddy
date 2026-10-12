import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/content_translation_catalog.dart';
import '../data/notification_media_storage.dart';
import '../data/settings_repository.dart';

/// Port of web `SocietyContentEditor`: per-society English / Hindi overrides for the
/// member-facing keys in [kContentTranslationGroups] (`society_content_translations`).
class SocietyContentEditor extends ConsumerStatefulWidget {
  const SocietyContentEditor({super.key, required this.societyId});

  final String societyId;

  @override
  ConsumerState<SocietyContentEditor> createState() =>
      _SocietyContentEditorState();
}

class _SocietyContentEditorState extends ConsumerState<SocietyContentEditor> {
  final _repo = const SettingsRepository();
  final Map<String, TextEditingController> _en = {};
  final Map<String, TextEditingController> _hi = {};
  bool _loading = true;
  bool _saving = false;
  String _group = kContentTranslationGroups.first.id;

  @override
  void initState() {
    super.initState();
    for (final k in kAllEditableContentKeys) {
      _en[k] = TextEditingController();
      _hi[k] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._en.values, ..._hi.values]) {
      c.dispose();
    }
    super.dispose();
  }

  ContentDraft _defaults(String key) {
    final row = TranslationsStore.row(key);
    return ContentDraft(en: row?['en'] ?? '', hi: row?['hi'] ?? '');
  }

  void _apply(Map<String, ContentDraft> drafts) {
    drafts.forEach((k, d) {
      _en[k]?.text = d.en;
      _hi[k]?.text = d.hi;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.loadContentTranslations(widget.societyId);
      _apply(mergeContentDrafts(
          keys: kAllEditableContentKeys,
          defaultsFor: _defaults,
          savedRows: rows));
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final drafts = {
        for (final k in kAllEditableContentKeys)
          k: ContentDraft(en: _en[k]!.text, hi: _hi[k]!.text),
      };
      await _repo.upsertContentTranslations(buildContentUpsertRows(
        societyId: widget.societyId,
        keys: kAllEditableContentKeys,
        drafts: drafts,
        defaultsFor: _defaults,
      ));
      ref.invalidate(contentOverridesProvider);
      if (mounted)
        AppFeedback.toast(context, context.t('contentEditor.saved'),
            tone: BadgeTone.success);
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('contentEditor.resetDefaults'),
      message: context.ct('comms.settings.contentResetText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
    );
    if (!ok || !mounted) return;
    try {
      await _repo.deleteContentTranslations(
          widget.societyId, kAllEditableContentKeys);
      _apply({for (final k in kAllEditableContentKeys) k: _defaults(k)});
      ref.invalidate(contentOverridesProvider);
      if (mounted)
        AppFeedback.toast(context, context.t('contentEditor.saved'),
            tone: BadgeTone.success);
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    }
  }

  Widget _input(TextEditingController c, bool multiline) => TextField(
        controller: c,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 6 : 1,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hindi = context.lang == AppLang.hi;
    final group = kContentTranslationGroups.firstWhere((g) => g.id == _group,
        orElse: () => kContentTranslationGroups.first);
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppTokens.tint(t.primary, 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.translate, size: 16, color: t.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('contentEditor.title'),
                        style: AppText.sectionTitle(context)),
                    const SizedBox(height: 2),
                    Text(context.t('contentEditor.subtitle'),
                        style: AppText.tiny(context).copyWith(height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in kContentTranslationGroups)
                PillChoice(
                    label: hindi ? g.titleHi : g.titleEn,
                    selected: g.id == group.id,
                    onTap: () => setState(() => _group = g.id)),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(context.t('app.loading'),
                    style: AppText.caption(context)))
          else ...[
            Text(hindi ? group.descriptionHi : group.descriptionEn,
                style: AppText.tiny(context).copyWith(height: 1.4)),
            const SizedBox(height: 10),
            for (final f in group.fields)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTokens.tint(t.border, 0.7)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(hindi ? f.labelHi : f.labelEn,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(context.t('contentEditor.english').toUpperCase(),
                        style: AppText.tiny(context)
                            .copyWith(fontSize: 9, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    _input(_en[f.key]!, f.multiline),
                    const SizedBox(height: 8),
                    Text(context.t('contentEditor.hindi').toUpperCase(),
                        style: AppText.tiny(context)
                            .copyWith(fontSize: 9, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    _input(_hi[f.key]!, f.multiline),
                    const SizedBox(height: 6),
                    Text(
                      '${context.t('contentEditor.defaultHint')}: ${contentDefaultHint(_defaults(f.key), hindi: hindi)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(context,
                          size: 9,
                          color: AppTokens.tint(t.mutedForeground, 0.8)),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                expand: false,
                dense: true,
                icon: Icons.save_outlined,
                loading: _saving,
                label: _saving
                    ? context.t('app.loading')
                    : context.t('contentEditor.save'),
                onPressed: _saving ? null : _save,
              ),
              AppButton.secondary(
                expand: false,
                dense: true,
                icon: Icons.restart_alt,
                label: context.t('contentEditor.resetDefaults'),
                onPressed: _reset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
