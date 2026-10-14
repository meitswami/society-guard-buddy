import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/notification_compose.dart';
import '../data/notification_media_storage.dart';
import '../data/notification_sound_player.dart';
import '../data/settings_repository.dart';
import '../widgets/comms_ui.dart';

/// Port of web `SocietyAppFeaturesPanel`: resident self-service photo ID switch and the
/// society signature tune (`societies.admin_push_sound_url`).
class AppFeaturesPanel extends StatefulWidget {
  const AppFeaturesPanel({super.key, required this.societyId});

  final String societyId;

  @override
  State<AppFeaturesPanel> createState() => _AppFeaturesPanelState();
}

class _AppFeaturesPanelState extends State<AppFeaturesPanel> {
  final _repo = const SettingsRepository();
  bool _selfId = false;
  bool _selfIdSaving = false;
  String? _soundUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final f = await _repo.loadAppFeatures(widget.societyId);
      if (!mounted) return;
      setState(() {
        _selfId = f.selfIdEnabled;
        _soundUrl = f.soundUrl;
      });
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  Future<void> _toggleSelfId(bool on) async {
    setState(() => _selfIdSaving = true);
    try {
      await _repo.setSelfIdUpload(widget.societyId, on);
      if (!mounted) return;
      setState(() => _selfId = on);
      AppFeedback.toast(
          context, context.t(on ? 'settings.selfIdOn' : 'settings.selfIdOff'),
          tone: BadgeTone.success);
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _selfIdSaving = false);
    }
  }

  Future<void> _upload() async {
    final res =
        await FilePicker.pickFiles(type: FileType.audio, withData: true);
    final f = res?.files.firstOrNull;
    if (f == null || !mounted) return;
    if (!isAudioFile(fileName: f.name)) {
      AppFeedback.toast(context, context.t('settings.signatureTuneInvalid'),
          tone: BadgeTone.alert);
      return;
    }
    if (f.size > kMaxSocietySoundBytes) {
      AppFeedback.toast(context, context.t('settings.signatureTuneTooLarge'),
          tone: BadgeTone.alert);
      return;
    }
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final url = await _repo.uploadSocietySound(
          widget.societyId, bytes, f.name,
          contentType: guessContentType(f.name));
      if (!mounted) return;
      setState(() => _soundUrl = url);
      unawaited(playNotificationAlert('custom', url));
      AppFeedback.toast(context, context.t('settings.signatureTuneSaved'),
          tone: BadgeTone.success);
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _clear() async {
    try {
      await _repo.clearSocietySound(widget.societyId);
      if (!mounted) return;
      setState(() => _soundUrl = null);
      AppFeedback.toast(context, context.t('settings.signatureTuneRemoved'),
          tone: BadgeTone.success);
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final url = _soundUrl;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('settings.appFeatures'),
              style: AppText.sectionTitle(context)),
          const SizedBox(height: 4),
          Text(context.t('settings.appFeaturesHint'),
              style: AppText.tiny(context).copyWith(height: 1.4)),
          const SizedBox(height: 12),
          MutedBox(
            color: AppTokens.tint(t.card, 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: t.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('settings.selfId'),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(context.t('settings.selfIdHint'),
                          style: AppText.tiny(context)),
                    ],
                  ),
                ),
                Switch(
                    value: _selfId,
                    onChanged: _selfIdSaving ? null : _toggleSelfId),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MutedBox(
            color: AppTokens.tint(t.card, 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.music_note_outlined, size: 16, color: t.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.t('settings.signatureTune'),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(context.t('settings.signatureTuneHint'),
                              style: AppText.tiny(context)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinePill(
                      icon: Icons.upload_outlined,
                      busy: _uploading,
                      label: _uploading
                          ? context.t('settings.bannerUploading')
                          : context.t('settings.signatureTuneUpload'),
                      onTap: _upload,
                    ),
                    if (url != null) ...[
                      OutlinePill(
                        icon: Icons.volume_up_outlined,
                        label: context.t('settings.signatureTunePreview'),
                        onTap: () => playNotificationAlert('custom', url),
                      ),
                      LinkText(context.t('settings.signatureTuneRemove'),
                          color: t.destructive, onTap: _clear),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  url == null
                      ? context.t('settings.signatureTuneEmpty')
                      : (url.length > 56
                          ? url.substring(url.length - 56)
                          : url),
                  style: AppText.tiny(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
