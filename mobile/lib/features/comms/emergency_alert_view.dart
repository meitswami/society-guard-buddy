import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ui/ui.dart';
import 'core/comms_i18n.dart';
import 'data/emergency_alert_service.dart';
import 'data/notification_compose.dart';
import 'widgets/comms_ui.dart';

/// Port of web `EmergencyAlertPanel` (full page mode) — guard "Alert" tab, resident and
/// admin senders. Calls the `send-emergency-alert` edge function.
class EmergencyAlertView extends StatelessWidget {
  const EmergencyAlertView({
    super.key,
    required this.societyId,
    required this.senderName,
    required this.senderRole,
    this.flatNumber,
  });

  final String societyId;
  final String senderName;

  /// `guard` | `resident` | `admin`
  final String senderRole;
  final String? flatNumber;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      children: [
        BadgedPageHeader(
          title: context.ct('comms.emergency.title'),
          subtitle: context.ct('comms.emergency.subtitle'),
          icon: Icons.campaign,
          iconColor: t.destructive,
          titleColor: t.destructive,
          iconSize: 48,
        ),
        CardSection(
          child: EmergencyAlertForm(
            societyId: societyId,
            senderName: senderName,
            senderRole: senderRole,
            flatNumber: flatNumber,
          ),
        ),
      ],
    );
  }
}

/// Web `EmergencyAlertPanel compact`: red outlined button that opens the form in a sheet.
class EmergencyAlertButton extends StatelessWidget {
  const EmergencyAlertButton({
    super.key,
    required this.societyId,
    required this.senderName,
    required this.senderRole,
    this.flatNumber,
  });

  final String societyId;
  final String senderName;
  final String senderRole;
  final String? flatNumber;

  Future<void> _open(BuildContext context) {
    return showCommsSheet<void>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign, color: t.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(ctx.ct('comms.emergency.modeTitle'),
                        style: AppText.pageTitle(ctx)
                            .copyWith(fontSize: 18, color: t.destructive)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(ctx.ct('comms.emergency.modeDesc'),
                  style: AppText.caption(ctx)),
              const SizedBox(height: 14),
              EmergencyAlertForm(
                societyId: societyId,
                senderName: senderName,
                senderRole: senderRole,
                flatNumber: flatNumber,
                onSent: () => Navigator.of(ctx).maybePop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppTokens.tint(t.destructive, 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: AppTokens.tint(t.destructive, 0.5), width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulsingIcon(icon: Icons.campaign, color: t.destructive),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.ct('comms.emergency.compactButton'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: t.destructive),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: Icon(widget.icon, size: 20, color: widget.color),
      );
}

/// The emergency form body (shared by the page and the compact sheet).
class EmergencyAlertForm extends StatefulWidget {
  const EmergencyAlertForm({
    super.key,
    required this.societyId,
    required this.senderName,
    required this.senderRole,
    this.flatNumber,
    this.onSent,
  });

  final String societyId;
  final String senderName;
  final String senderRole;
  final String? flatNumber;
  final VoidCallback? onSent;

  @override
  State<EmergencyAlertForm> createState() => _EmergencyAlertFormState();
}

class _EmergencyAlertFormState extends State<EmergencyAlertForm> {
  final _service = const EmergencyAlertService();
  final _title = TextEditingController(text: kEmergencyDefaultTitle);
  final _message = TextEditingController();

  /// Camera captures (compressed like web `PhotoCapture`).
  final List<EmergencyImage> _photos = [];

  /// Picked image files (sent as-is, ≤ 12 MB).
  final List<EmergencyImage> _files = [];
  bool _sending = false;

  int get _total => _photos.length + _files.length;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_total >= kEmergencyMaxPhotos) {
      AppFeedback.toast(context, context.ct('comms.emergency.maxPhotos'),
          tone: BadgeTone.warning);
      return;
    }
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera);
      if (x == null) return;
      final compressed = await compressPhoto(await x.readAsBytes());
      if (!mounted) return;
      setState(() => _photos.add(EmergencyImage(
            bytes: compressed,
            fileName:
                'emergency_${DateTime.now().millisecondsSinceEpoch}_${_photos.length}.jpg',
            mimeType: 'image/jpeg',
          )));
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _pickFiles() async {
    final room = kEmergencyMaxPhotos - _total;
    if (room <= 0) {
      AppFeedback.toast(context, context.ct('comms.emergency.maxPhotos'),
          tone: BadgeTone.warning);
      return;
    }
    try {
      final picked = room >= 2
          ? await ImagePicker().pickMultiImage(limit: room)
          : [await ImagePicker().pickImage(source: ImageSource.gallery)];
      final next = <EmergencyImage>[];
      for (final x in picked) {
        if (x == null) continue;
        if (fileMediaKind(mimeType: x.mimeType, fileName: x.name) != 'image') {
          continue;
        }
        if (next.length + _total >= kEmergencyMaxPhotos) break;
        next.add(EmergencyImage(
            bytes: await x.readAsBytes(),
            fileName: x.name,
            mimeType: x.mimeType));
      }
      if (!mounted || next.isEmpty) return;
      setState(() => _files.addAll(next));
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      AppFeedback.toast(context, context.ct('comms.emergency.describe'),
          tone: BadgeTone.alert);
      return;
    }
    if (!kEmergencySenderRoles.contains(widget.senderRole)) {
      AppFeedback.toast(context, context.ct('comms.emergency.invalidRole'),
          tone: BadgeTone.alert);
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: context.ct('comms.emergency.confirmTitle'),
      message: context.ct('comms.emergency.confirmText'),
      confirmLabel: context.ct('comms.emergency.confirmYes'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      final title = _title.text.trim();
      final result = await _service.send(
        societyId: widget.societyId,
        title: title.isEmpty ? kEmergencyDefaultTitle : title,
        message: _message.text.trim(),
        senderRole: widget.senderRole,
        senderName: widget.senderName,
        senderFlatNumber: widget.flatNumber,
        // Web order: picked files first, then camera captures.
        images: [..._files, ..._photos],
      );
      if (!mounted) return;
      if (!result.success) {
        AppFeedback.toast(
            context, result.error ?? context.ct('comms.emergency.failed'),
            tone: BadgeTone.alert);
        return;
      }
      AppFeedback.toast(
        context,
        emergencySentSummary(
          result,
          sentLabel: context.ct('comms.emergency.sent'),
          waNotConfigured: context.ct('comms.emergency.waNotConfigured'),
        ),
        tone: BadgeTone.success,
        duration: const Duration(seconds: 6),
      );
      setState(() {
        _message.clear();
        _photos.clear();
        _files.clear();
        _title.text = kEmergencyDefaultTitle;
      });
      widget.onSent?.call();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MutedBox(
          color: AppTokens.tint(t.destructive, 0.05),
          borderColor: AppTokens.tint(t.destructive, 0.4),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: t.destructive),
              const SizedBox(width: 6),
              Expanded(
                child: Text(context.ct('comms.emergency.banner'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: t.destructive)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppTextField(
            controller: _title,
            hint: context.ct('comms.emergency.titlePh'),
            caps: false),
        const SizedBox(height: 12),
        AppTextField(
          controller: _message,
          hint: context.ct('comms.emergency.messagePh'),
          caps: false,
          minLines: 4,
          maxLines: 8,
        ),
        const SizedBox(height: 12),
        Text(context.ct('comms.emergency.photos'),
            style:
                AppText.caption(context).copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        if (_photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        child: Image.memory(_photos[i].bytes,
                            width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: InkWell(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: t.destructive,
                            child: Icon(Icons.close,
                                size: 13, color: t.destructiveForeground),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinePill(
                icon: Icons.photo_camera_outlined,
                label: context.ct('comms.emergency.takePhoto'),
                onTap: _sending ? null : _takePhoto),
            OutlinePill(
                icon: Icons.attach_file,
                label: context.ct('comms.emergency.addImage'),
                onTap: _sending ? null : _pickFiles),
            for (var i = 0; i < _files.length; i++)
              FileChip(
                  label: attachmentChipLabel(_files[i].fileName, max: 16),
                  onRemove: () => setState(() => _files.removeAt(i))),
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: t.destructive,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            onTap: _sending ? null : _send,
            child: Opacity(
              opacity: _sending ? 0.6 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_sending)
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: t.destructiveForeground))
                    else
                      Icon(Icons.send,
                          size: 16, color: t.destructiveForeground),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _sending
                            ? context.ct('comms.emergency.sending')
                            : context.ct('comms.emergency.send'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.destructiveForeground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.ct('comms.emergency.sender', {
            'name': widget.flatNumber == null || widget.flatNumber!.isEmpty
                ? widget.senderName
                : '${widget.senderName} · ${context.t('common.flat')} ${widget.flatNumber}'
          }),
          textAlign: TextAlign.center,
          style: AppText.tiny(context),
        ),
      ],
    );
  }
}
