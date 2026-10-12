import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/supabase/db.dart';
import '../../core/ui/ui.dart';
import '../admin/core/admin_module.dart';
import 'core/comms_i18n.dart';
import 'data/flat_options.dart';
import 'data/notification_compose.dart';
import 'data/notification_media_storage.dart';
import 'data/notification_models.dart';
import 'data/notification_repository.dart';
import 'data/notification_sound_player.dart';
import 'data/notification_sounds.dart';
import 'data/push_health_check.dart';
import 'data/settings_repository.dart';
import 'emergency_alert_view.dart';
import 'widgets/comms_ui.dart';
import 'widgets/flat_multi_select.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_detail_sheet.dart';

/// Admin → Notify. Port of web `NotificationCenter` (admin mode): compose with audience
/// targeting, alert sound presets + society custom sound, image / video attachments,
/// directory channels, push health check, history with read state and threads.
class AdminNotificationsModule extends StatefulWidget {
  const AdminNotificationsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminNotificationsModule> createState() =>
      _AdminNotificationsModuleState();
}

class _PendingMedia {
  const _PendingMedia(
      {required this.file, required this.kind, required this.size});

  final XFile file;
  final String kind;
  final int size;
}

class _AdminNotificationsModuleState extends State<AdminNotificationsModule> {
  final _repo = const NotificationRepository();
  final _settings = const SettingsRepository();
  final _title = TextEditingController();
  final _message = TextEditingController();

  List<AppNotification> _items = const [];
  bool _loading = true;
  bool _failed = false;
  RealtimeChannel? _channel;

  bool _showForm = false;
  String _type = 'general';
  String _soundKey = 'digital';
  String? _societySoundUrl;
  bool _uploadingSound = false;
  final List<_PendingMedia> _pending = [];
  NotificationTargetMode _mode = NotificationTargetMode.all;
  List<String> _selectedFlats = [];
  final List<SelectedResident> _selectedResidents = [];
  NotificationTargets? _targets;
  List<FlatOption> _flatOptions = const [];
  String _residentQuery = '';
  bool _whatsapp = false;
  bool _email = false;
  bool _sending = false;
  bool _checkingHealth = false;

  String get _sid => widget.ctx.societyId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTargets();
    _loadSound();
    _channel = _repo.subscribeInserts(
        'notifications-dashboard-admin-${widget.ctx.adminId}',
        _sid,
        (_) => _load(silent: true));
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) unawaited(db.removeChannel(ch));
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final items = await _repo.loadNotifications(societyId: _sid);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _items.isEmpty;
      });
      AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    }
  }

  Future<void> _loadTargets() async {
    if (!dbReady) return;
    try {
      final t = await _repo.loadTargets(_sid);
      if (!mounted) return;
      setState(() {
        _targets = t;
        _flatOptions = flatOptionsWithPrimaryLabel(t.flats, t.primaryByFlatId);
      });
    } catch (_) {}
  }

  Future<void> _loadSound() async {
    try {
      final url = await _repo.fetchSocietySoundUrl(_sid);
      if (!mounted) return;
      setState(() {
        _societySoundUrl = url;
        if (url != null) _soundKey = 'custom';
      });
    } catch (_) {}
  }

  int get _unread => _items.where((n) => !n.isRead).length;

  Future<void> _markAllRead() async {
    try {
      await _repo.markSocietyRead(_sid);
      if (!mounted) return;
      AppFeedback.toast(context, context.ct('comms.notif.allMarkedRead'),
          tone: BadgeTone.success);
      await _load(silent: true);
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      unawaited(_repo
          .markRead(n.id)
          .then((_) => _load(silent: true))
          .catchError((_) {}));
    }
    await NotificationDetailSheet.show(context,
        notification: n, isResident: false, adminName: widget.ctx.adminName);
  }

  // ---- Sound ------------------------------------------------------------------------

  Future<void> _uploadSound() async {
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
    setState(() => _uploadingSound = true);
    try {
      final url = await _settings.uploadSocietySound(_sid, bytes, f.name,
          contentType: guessContentType(f.name));
      if (!mounted) return;
      setState(() {
        _societySoundUrl = url;
        _soundKey = 'custom';
      });
      unawaited(playNotificationAlert('custom', url));
      AppFeedback.toast(context, context.t('settings.signatureTuneSaved'),
          tone: BadgeTone.success);
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _uploadingSound = false);
    }
  }

  // ---- Attachments ------------------------------------------------------------------

  Future<void> _pickMedia() async {
    final room = kMaxNotificationAttachments - _pending.length;
    if (room <= 0) {
      AppFeedback.toast(
          context,
          context.ct('comms.notif.maxAttachments',
              {'max': kMaxNotificationAttachments}),
          tone: BadgeTone.alert);
      return;
    }
    List<XFile> picked;
    try {
      if (room >= 2) {
        picked = await ImagePicker().pickMultipleMedia(limit: room);
      } else {
        final one = await ImagePicker().pickMedia();
        picked = one == null ? const [] : [one];
      }
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
      return;
    }
    final next = <_PendingMedia>[];
    for (final f in picked) {
      final kind = fileMediaKind(mimeType: f.mimeType, fileName: f.name);
      if (!mounted) return;
      if (kind == null) {
        AppFeedback.toast(
            context, context.ct('comms.notif.mediaInvalid', {'name': f.name}),
            tone: BadgeTone.alert);
        continue;
      }
      if (_pending.length + next.length >= kMaxNotificationAttachments) {
        AppFeedback.toast(
            context,
            context.ct('comms.notif.maxAttachments',
                {'max': kMaxNotificationAttachments}),
            tone: BadgeTone.alert);
        break;
      }
      next.add(_PendingMedia(file: f, kind: kind, size: await f.length()));
    }
    if (mounted && next.isNotEmpty) setState(() => _pending.addAll(next));
  }

  /// Web `uploadNotificationMedia`: size checks + `{uuid}/{ts}_{name}` paths.
  Future<List<NotificationMediaItem>> _uploadMedia() async {
    final items = <NotificationMediaItem>[];
    for (final p in _pending) {
      final name = p.file.name;
      final violation = mediaSizeViolation(p.kind, p.size);
      if (violation != null) {
        if (mounted) {
          AppFeedback.toast(
            context,
            violation == 'image'
                ? context.ct('comms.notif.imageTooLarge', {
                    'mb': kMaxNotificationImageBytes ~/ (1024 * 1024),
                    'name': name
                  })
                : context.ct('comms.notif.videoTooLarge', {
                    'mb': kMaxNotificationVideoBytes ~/ (1024 * 1024),
                    'name': name
                  }),
            tone: BadgeTone.alert,
          );
        }
        continue;
      }
      final path =
          '${const Uuid().v4()}/${DateTime.now().millisecondsSinceEpoch}_${sanitizeStorageFileName(name)}';
      try {
        final url = await uploadToNotificationMedia(
            path, await p.file.readAsBytes(),
            contentType: guessContentType(name, mimeType: p.file.mimeType));
        items.add(NotificationMediaItem(url: url, kind: p.kind));
      } catch (_) {
        if (mounted)
          AppFeedback.toast(
              context, context.ct('comms.notif.uploadFailed', {'name': name}),
              tone: BadgeTone.alert);
      }
    }
    return items;
  }

  // ---- Send -------------------------------------------------------------------------

  Future<void> _send() async {
    final title = _title.text;
    final message = _message.text;
    final err = validateCompose(
      title: title.trim(),
      message: message.trim(),
      mode: _mode,
      selectedFlats: _selectedFlats.length,
      selectedResidents: _selectedResidents.length,
      alertSoundKey: _soundKey,
      societyCustomSoundUrl: _societySoundUrl,
    );
    if (err != null) {
      AppFeedback.toast(context, context.ct(err), tone: BadgeTone.alert);
      return;
    }
    setState(() => _sending = true);
    final whatsapp = _whatsapp;
    final email = _email;
    try {
      List<NotificationMediaItem> media = const [];
      if (_pending.isNotEmpty) {
        try {
          media = await _uploadMedia();
        } catch (_) {
          if (mounted)
            AppFeedback.toast(
                context, context.ct('comms.notif.mediaUploadFailed'),
                tone: BadgeTone.alert);
          return;
        }
      }
      final plan = buildNotificationSendPlan(
        title: title,
        message: message,
        type: _type,
        adminName: widget.ctx.adminName,
        societyId: _sid,
        mode: _mode,
        selectedFlats: _selectedFlats,
        selectedResidents: _selectedResidents,
        media: media,
        alertSoundKey: _soundKey,
        societyCustomSoundUrl: _societySoundUrl,
      );
      try {
        await _repo.insertNotifications(plan.rows);
      } catch (e) {
        if (mounted)
          AppFeedback.toast(
              context,
              context.ct(
                  'comms.notif.sendFailed', {'error': commsErrorMessage(e)}),
              tone: BadgeTone.alert);
        return;
      }
      try {
        await _repo.invokePush(plan.pushBody);
      } catch (e) {
        debugPrint('Push notification failed (may not be configured): $e');
      }
      if (whatsapp || email) {
        final image =
            media.where((m) => m.isImage).map((m) => m.url).firstOrNull;
        await _repo.dispatchDirectoryChannels(
          societyId: _sid,
          title: title,
          message: message,
          whatsapp: whatsapp,
          email: email,
          target: _mode,
          flatNumbers: plan.targetFlatNumbers,
          residentUserIds: plan.targetUserIds,
          imageUrl: image,
        );
      }
      if (!mounted) return;
      setState(() {
        _title.clear();
        _message.clear();
        _type = 'general';
        _whatsapp = false;
        _email = false;
        _soundKey = 'digital';
        _showForm = false;
        _selectedFlats = [];
        _selectedResidents.clear();
        _mode = NotificationTargetMode.all;
        _pending.clear();
      });
      AppFeedback.toast(
        context,
        context.ct(whatsapp || email
            ? 'comms.notif.sentPushDirectory'
            : 'comms.notif.sentPush'),
        tone: BadgeTone.success,
      );
      await _load(silent: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ---- Health check -----------------------------------------------------------------

  Future<void> _runHealthCheck() async {
    if (widget.ctx.adminId.isEmpty) {
      AppFeedback.toast(context, 'Admin ID missing for health check',
          tone: BadgeTone.alert);
      return;
    }
    final steps = ValueNotifier<List<HealthStep>>(const []);
    final summary = ValueNotifier<String>('');
    setState(() => _checkingHealth = true);
    final sheet = showCommsSheet<void>(context,
        builder: (ctx) =>
            _HealthSheet(steps: steps, summary: summary, ctx: widget.ctx));
    final outcome = await const PushHealthCheck()
        .run(widget.ctx.session, onStep: (s) => steps.value = s);
    steps.value = outcome.steps;
    summary.value = outcome.summary;
    if (mounted) {
      setState(() => _checkingHealth = false);
      AppFeedback.toast(
        context,
        outcome.passed
            ? '${context.ct('comms.health.toastOk')}\n${outcome.okNotes.join(' | ')}'
            : '${context.ct('comms.health.toastFail')}\n${outcome.issues.join(' | ')}',
        tone: outcome.passed ? BadgeTone.success : BadgeTone.alert,
        duration: const Duration(seconds: 6),
      );
    }
    await sheet;
    steps.dispose();
    summary.dispose();
  }

  // ---- UI ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      onRefresh: () async {
        await Future.wait([_load(silent: true), _loadTargets(), _loadSound()]);
      },
      children: [
        BadgedPageHeader(
          title: context.ct('comms.notif.title'),
          subtitle: context.ct('comms.notif.subtitleAdmin', {'count': _unread}),
          icon: Icons.notifications_none,
          badge: _unread,
          trailing: _unread > 0
              ? LinkText(context.ct('comms.notif.markAllRead'),
                  onTap: _markAllRead)
              : null,
        ),
        EmergencyAlertButton(
            societyId: _sid,
            senderName: widget.ctx.adminName,
            senderRole: 'admin'),
        AppButton(
          icon: _showForm ? Icons.close : Icons.add,
          label: _showForm
              ? context.ct('comms.notif.closeForm')
              : context.ct('comms.notif.sendPush'),
          onPressed: () => setState(() => _showForm = !_showForm),
        ),
        const SizedBox(height: 12),
        AppButton.secondary(
          dense: true,
          icon: Icons.health_and_safety_outlined,
          label: _checkingHealth
              ? context.ct('comms.notif.healthRunning')
              : context.ct('comms.notif.healthCheck'),
          loading: _checkingHealth,
          onPressed: _checkingHealth ? null : _runHealthCheck,
        ),
        const SizedBox(height: 16),
        if (_showForm) ...[_composeForm(context), const SizedBox(height: 16)],
        if (_loading && _items.isEmpty)
          const LoadingView()
        else if (_failed)
          ErrorView(onRetry: _load)
        else if (_items.isEmpty)
          EmptyView(
              message: context.ct('comms.notif.empty'),
              icon: Icons.notifications_off_outlined)
        else
          for (final n in _items)
            NotificationCard(
                notification: n, isResident: false, onTap: () => _open(n)),
        if (_loading && _items.isNotEmpty)
          LinearProgressIndicator(minHeight: 2, color: t.primary),
      ],
    );
  }

  Widget _composeForm(BuildContext context) {
    final t = context.tokens;
    final residents = _targets?.residents ?? const [];
    final q = _residentQuery.trim().toLowerCase();
    final visibleResidents = q.isEmpty
        ? residents
        : residents
            .where((r) =>
                (r['name']?.toString().toLowerCase().contains(q) ?? false) ||
                (r['flat_number']?.toString().toLowerCase().contains(q) ??
                    false))
            .toList();
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
              controller: _title,
              hint: context.ct('comms.notif.titlePh'),
              caps: false),
          const SizedBox(height: 12),
          AppTextField(
              controller: _message,
              hint: context.ct('comms.notif.messagePh'),
              caps: false,
              minLines: 3,
              maxLines: 8),
          const SizedBox(height: 12),
          AppDropdown<String>(
            items: kComposeNotificationTypes,
            value: _type,
            labelOf: (v) => context.ct('comms.compose.type.$v'),
            onChanged: (v) => setState(() => _type = v ?? 'general'),
          ),
          const SizedBox(height: 12),
          MutedBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.ct('comms.notif.soundTitle'),
                    style: AppText.caption(context)
                        .copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(context.ct('comms.notif.soundHint'),
                    style: AppText.tiny(context).copyWith(height: 1.4)),
                const SizedBox(height: 8),
                AppDropdown<String>(
                  items: [for (final p in kNotificationSoundPresets) p.id],
                  value: _soundKey,
                  labelOf: (id) => context.ct(kNotificationSoundPresets
                      .firstWhere((p) => p.id == id)
                      .labelKey),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _soundKey = v);
                    unawaited(playNotificationAlert(v, _societySoundUrl));
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinePill(
                      icon: Icons.music_note_outlined,
                      busy: _uploadingSound,
                      label: _uploadingSound
                          ? context.ct('comms.notif.uploading')
                          : context.ct('comms.notif.uploadSound'),
                      onTap: _uploadSound,
                    ),
                    if (_societySoundUrl != null)
                      OutlinePill(
                        icon: Icons.volume_up_outlined,
                        label: context.ct('comms.notif.preview'),
                        onTap: () =>
                            playNotificationAlert('custom', _societySoundUrl),
                      ),
                  ],
                ),
                if (_societySoundUrl != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.ct('comms.notif.currentFile', {
                      'file': _societySoundUrl!.length > 48
                          ? _societySoundUrl!
                              .substring(_societySoundUrl!.length - 48)
                          : _societySoundUrl
                    }),
                    style: AppText.tiny(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(context.ct('comms.notif.attachments'),
              style: AppText.caption(context)
                  .copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
              context.ct('comms.notif.attachmentsHint',
                  {'max': kMaxNotificationAttachments}),
              style: AppText.tiny(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinePill(
                  icon: Icons.attach_file,
                  label: context.ct('comms.notif.addMedia'),
                  onTap: _pickMedia),
              for (var i = 0; i < _pending.length; i++)
                FileChip(
                  label:
                      '${_pending[i].kind == 'video' ? '🎬 ' : ''}${attachmentChipLabel(_pending[i].file.name)}',
                  onRemove: () => setState(() => _pending.removeAt(i)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(context.ct('comms.notif.sendTo'),
              style: AppText.caption(context)
                  .copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (mode, icon, key) in [
                (
                  NotificationTargetMode.all,
                  Icons.groups_outlined,
                  'comms.notif.target.all'
                ),
                (
                  NotificationTargetMode.flat,
                  Icons.home_outlined,
                  'comms.notif.target.flat'
                ),
                (
                  NotificationTargetMode.user,
                  Icons.person_outline,
                  'comms.notif.target.user'
                ),
              ]) ...[
                if (mode != NotificationTargetMode.all)
                  const SizedBox(width: 8),
                Expanded(
                    child: _targetOption(context, mode, icon, context.ct(key))),
              ],
            ],
          ),
          if (_mode == NotificationTargetMode.flat) ...[
            const SizedBox(height: 12),
            if (_targets == null)
              Text(context.ct('comms.notif.flatsLoading'),
                  style: AppText.caption(context))
            else
              FlatMultiSelect(
                flats: _flatOptions,
                selected: _selectedFlats,
                onChanged: (v) => setState(() => _selectedFlats = v),
                label: context.ct('comms.notif.selectFlats'),
              ),
          ],
          if (_mode == NotificationTargetMode.user) ...[
            const SizedBox(height: 12),
            Text(
                context.ct('comms.notif.selectResidents',
                    {'count': _selectedResidents.length}),
                style: AppText.caption(context)),
            const SizedBox(height: 6),
            TextField(
              onChanged: (v) => setState(() => _residentQuery = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.ct('comms.notif.searchResidents'),
                prefixIcon:
                    Icon(Icons.search, size: 18, color: t.mutedForeground),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 200,
              child: visibleResidents.isEmpty
                  ? Text(context.ct('comms.notif.noResidents'),
                      style: AppText.caption(context))
                  : ListView.builder(
                      itemCount: visibleResidents.length,
                      itemBuilder: (context, i) {
                        final r = visibleResidents[i];
                        final id = r['id']?.toString() ?? '';
                        final on = _selectedResidents.any((s) => s.id == id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color:
                                on ? AppTokens.tint(t.primary, 0.10) : t.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side:
                                  BorderSide(color: on ? t.primary : t.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => setState(() {
                                if (on) {
                                  _selectedResidents
                                      .removeWhere((s) => s.id == id);
                                } else {
                                  _selectedResidents.add(SelectedResident(
                                    id: id,
                                    name: r['name']?.toString() ?? '',
                                    flatNumber:
                                        r['flat_number']?.toString() ?? '',
                                  ));
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text(r['name']?.toString() ?? '',
                                            style:
                                                const TextStyle(fontSize: 12))),
                                    Text(
                                        '${context.t('common.flat')} ${r['flat_number'] ?? ''}',
                                        style: AppText.caption(context)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
          const SizedBox(height: 12),
          MutedBox(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.ct('comms.notif.directoryTitle'),
                    style: AppText.caption(context)
                        .copyWith(fontWeight: FontWeight.w500)),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _whatsapp,
                  onChanged: (v) => setState(() => _whatsapp = v ?? false),
                  title: Text(context.ct('comms.notif.channelWhatsapp'),
                      style: const TextStyle(fontSize: 12)),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _email,
                  onChanged: (v) => setState(() => _email = v ?? false),
                  title: Text(context.ct('comms.notif.channelEmail'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            icon: Icons.send,
            loading: _sending,
            label: _sending
                ? context.ct('comms.notif.sending')
                : context.ct('comms.notif.send'),
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }

  Widget _targetOption(BuildContext context, NotificationTargetMode mode,
      IconData icon, String label) {
    final t = context.tokens;
    final on = _mode == mode;
    final fg = on ? t.primary : t.mutedForeground;
    return Material(
      color: on ? AppTokens.tint(t.primary, 0.10) : Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: on ? t.primary : t.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: () => setState(() => _mode = mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthSheet extends StatelessWidget {
  const _HealthSheet(
      {required this.steps, required this.summary, required this.ctx});

  final ValueNotifier<List<HealthStep>> steps;
  final ValueNotifier<String> summary;
  final AdminModuleContext ctx;

  String _summaryText(BuildContext context, String s) => switch (s) {
        kHealthSummaryOk => context.ct('comms.health.ok'),
        kHealthSummaryFail => context.ct('comms.health.fail'),
        kHealthSummaryCrash => context.ct('comms.health.crash'),
        _ => context.ct('comms.health.running'),
      };

  Future<void> _copy(BuildContext context) async {
    final report = buildPushHealthReport(
      time: DateTime.now(),
      adminName: ctx.adminName,
      adminId: ctx.adminId,
      societyId: ctx.societyId,
      summary: summary.value,
      steps: steps.value,
    );
    final ok = await copyToClipboard(report);
    if (!context.mounted) return;
    AppFeedback.toast(context,
        context.ct(ok ? 'comms.health.copied' : 'comms.health.copyFailed'),
        tone: ok ? BadgeTone.success : BadgeTone.alert);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: AnimatedBuilder(
          animation: Listenable.merge([steps, summary]),
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.ct('comms.health.title'),
                  style: AppText.pageTitle(context)),
              const SizedBox(height: 4),
              Text(_summaryText(context, summary.value),
                  style: AppText.caption(context)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: steps.value.isEmpty ? null : () => _copy(context),
                  icon: const Icon(Icons.copy, size: 14),
                  label: Text(context.ct('comms.health.copy'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (steps.value.isEmpty)
                      Text(context.ct('comms.health.checking'),
                          style: AppText.body(context)
                              .copyWith(color: t.mutedForeground)),
                    for (final s in steps.value)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            border: Border.all(color: t.border),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusSm)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.ok ? '✅' : '❌'} ${s.label}',
                                style: AppText.bodyMedium(context)),
                            const SizedBox(height: 2),
                            Text(s.detail, style: AppText.caption(context)),
                          ],
                        ),
                      ),
                    if (summary.value.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(8),
                          child: LinearProgressIndicator(minHeight: 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
