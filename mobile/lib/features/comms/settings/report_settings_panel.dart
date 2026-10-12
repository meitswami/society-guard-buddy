import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/notification_compose.dart';
import '../data/notification_media_storage.dart';
import '../data/settings_repository.dart';
import '../data/society_settings_logic.dart';
import '../widgets/comms_ui.dart';

/// Port of web `SocietyReportSettingsPanel`: official letterhead upload to the private
/// `society-documents` bucket, default PDF format and the safe content area (mm).
class ReportSettingsPanel extends StatefulWidget {
  const ReportSettingsPanel({super.key, required this.societyId});

  final String societyId;

  @override
  State<ReportSettingsPanel> createState() => _ReportSettingsPanelState();
}

class _ReportSettingsPanelState extends State<ReportSettingsPanel> {
  final _repo = const SettingsRepository();
  final _top = TextEditingController(text: '45');
  final _bottom = TextEditingController(text: '22');
  final _left = TextEditingController(text: '19.05');
  final _right = TextEditingController(text: '19.05');
  SocietyLetterheadInfo? _lh;
  String? _resolvedUrl;
  String? _previewUrl;
  String _format = 'letterhead';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final c in [_top, _bottom, _left, _right]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final lh = await _repo.loadLetterhead(widget.societyId);
      String? url = lh?.letterheadUrl;
      if ((url == null || url.isEmpty) && lh?.letterheadStoragePath != null) {
        url = await _repo.signedDocumentUrl(lh!.letterheadStoragePath);
      }
      if (!mounted) return;
      setState(() {
        _lh = lh;
        _resolvedUrl = url;
        _previewUrl = url;
        _format = lh?.defaultReportFormat == 'plain' ? 'plain' : 'letterhead';
        _top.text = formatMm(lh?.topMm ?? 45);
        _bottom.text = formatMm(lh?.bottomMm ?? 22);
        _left.text = formatMm(lh?.leftMm ?? kPdfMarginMm);
        _right.text = formatMm(lh?.rightMm ?? kPdfMarginMm);
      });
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _persist(Map<String, dynamic> patch) async {
    try {
      await _repo.updateSociety(widget.societyId, patch);
      return true;
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      return false;
    }
  }

  Future<void> _upload() async {
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
      return;
    }
    if (x == null || !mounted) return;
    final type = guessContentType(x.name, mimeType: x.mimeType);
    if (fileMediaKind(mimeType: type, fileName: x.name) != 'image') {
      AppFeedback.toast(context, context.t('settings.letterheadInvalidType'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _saving = true);
    try {
      final uploaded = await _repo.uploadLetterhead(
          widget.societyId, await x.readAsBytes(), x.name,
          contentType: type);
      if (!mounted) return;
      setState(() => _previewUrl = uploaded.signedUrl);
      final previous = _lh?.letterheadStoragePath;
      if (previous != null && previous.isNotEmpty && previous != uploaded.path)
        await _repo.removeDocument(previous);
      final ok = await _persist({
        'letterhead_storage_path': uploaded.path,
        'letterhead_url': null,
        'letterhead_mode': 'image',
        'default_report_format': _format,
      });
      if (ok && mounted) {
        AppFeedback.toast(context, context.t('settings.letterheadSaved'),
            tone: BadgeTone.success);
        await _reload();
      }
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    try {
      final path = _lh?.letterheadStoragePath;
      if (path != null && path.isNotEmpty) await _repo.removeDocument(path);
      final ok = await _persist({
        'letterhead_storage_path': null,
        'letterhead_url': null,
        'letterhead_mode': 'auto'
      });
      if (ok && mounted) {
        AppFeedback.toast(context, context.t('settings.letterheadRemoved'),
            tone: BadgeTone.success);
        await _reload();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final ok = await _persist(buildReportSettingsPatch(
        defaultFormat: _format,
        top: _top.text,
        bottom: _bottom.text,
        left: _left.text,
        right: _right.text,
        current: _lh,
        resolvedLetterheadUrl: _resolvedUrl,
      ));
      if (ok && mounted) {
        AppFeedback.toast(context, context.t('settings.reportSettingsSaved'),
            tone: BadgeTone.success);
        await _reload();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final has = (_lh?.hasLetterhead ?? false) || (_previewUrl ?? '').isNotEmpty;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('settings.reportSettings'),
              style: AppText.sectionTitle(context)),
          const SizedBox(height: 4),
          Text(context.t('settings.reportSettingsHint'),
              style: AppText.tiny(context).copyWith(height: 1.4)),
          const SizedBox(height: 12),
          if (_loading)
            Text('…', style: AppText.caption(context))
          else ...[
            if (!has) ...[
              NoticeBanner(
                  message: context.ct('comms.settings.letterheadWarning'),
                  tone: BadgeTone.warning),
              const SizedBox(height: 16),
            ],
            Text(context.t('settings.societyLetterhead'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: Container(
                height: (_previewUrl ?? '').isNotEmpty ? 192 : 112,
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.secondary, 0.2),
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                alignment: Alignment.center,
                child: (_previewUrl ?? '').isNotEmpty
                    ? Container(
                        color: t.card,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: _previewUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Icon(
                              Icons.image_not_supported_outlined,
                              color: t.mutedForeground),
                        ),
                      )
                    : Icon(Icons.image_outlined,
                        size: 24, color: t.mutedForeground),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton.secondary(
                  expand: false,
                  dense: true,
                  icon: Icons.upload_outlined,
                  label: has
                      ? context.t('settings.replaceLetterhead')
                      : context.t('settings.uploadLetterhead'),
                  onPressed: _saving ? null : _upload,
                ),
                if (has)
                  OutlinePill(
                    icon: Icons.delete_outline,
                    color: t.destructive,
                    label: context.t('settings.removeLetterhead'),
                    onTap: _saving ? null : _remove,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(context.t('settings.letterheadUploadHint'),
                style: AppText.tiny(context)),
            const SizedBox(height: 16),
            Text(context.t('settings.defaultReportFormat'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            RadioGroup<String>(
              groupValue: _format,
              onChanged: (v) => setState(() => _format = v ?? 'letterhead'),
              child: Column(
                children: [
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: 'letterhead',
                    title: Text(context.t('settings.formatOfficialLetterhead'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: 'plain',
                    title: Text(context.t('settings.formatPlainPdf'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(context.t('settings.safeContentArea'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _mm(context, 'settings.layoutTop', _top)),
                const SizedBox(width: 8),
                Expanded(child: _mm(context, 'settings.layoutBottom', _bottom)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _mm(context, 'settings.layoutLeft', _left)),
                const SizedBox(width: 8),
                Expanded(child: _mm(context, 'settings.layoutRight', _right)),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              loading: _saving,
              label: _saving ? '…' : context.t('settings.saveReportSettings'),
              onPressed: _saving ? null : _saveSettings,
            ),
          ],
        ],
      ),
    );
  }

  Widget _mm(BuildContext context, String key, TextEditingController c) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t(key), style: AppText.tiny(context)),
          const SizedBox(height: 4),
          AppTextField(
              controller: c,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              caps: false),
        ],
      );
}
