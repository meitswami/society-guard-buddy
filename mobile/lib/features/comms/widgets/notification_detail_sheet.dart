import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/supabase/db.dart';
import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';
import 'comms_ui.dart';

/// Port of web `NotificationDetailModal`: full message, image / video carousel and the
/// realtime discussion thread (`notification_comments`).
class NotificationDetailSheet extends StatefulWidget {
  const NotificationDetailSheet({
    super.key,
    required this.notification,
    required this.isResident,
    this.resident,
    this.adminName = 'Admin',
  });

  final AppNotification notification;
  final bool isResident;
  final ResidentRef? resident;
  final String adminName;

  static Future<void> show(
    BuildContext context, {
    required AppNotification notification,
    required bool isResident,
    ResidentRef? resident,
    String adminName = 'Admin',
  }) {
    return showCommsSheet<void>(
      context,
      fullHeight: true,
      builder: (_) => NotificationDetailSheet(
        notification: notification,
        isResident: isResident,
        resident: resident,
        adminName: adminName,
      ),
    );
  }

  @override
  State<NotificationDetailSheet> createState() =>
      _NotificationDetailSheetState();
}

class _NotificationDetailSheetState extends State<NotificationDetailSheet> {
  final _repo = const NotificationRepository();
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _pages = PageController();
  List<NotificationComment> _comments = const [];
  RealtimeChannel? _channel;
  int _mediaIndex = 0;
  bool _sending = false;

  AppNotification get n => widget.notification;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _channel = _repo.subscribeComments(n.id, _loadComments);
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) unawaited(db.removeChannel(ch));
    _draft.dispose();
    _scroll.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (!dbReady) return;
    try {
      final c = await _repo.loadComments(n.id);
      if (mounted) setState(() => _comments = c);
    } catch (_) {
      // Web ignores comment load errors.
    }
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    if (widget.isResident && widget.resident == null) {
      AppFeedback.toast(context, context.ct('comms.detail.notResident'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.addComment(buildCommentRow(
        notificationId: n.id,
        body: text,
        isResident: widget.isResident,
        resident: widget.resident,
        adminName: widget.adminName,
      ));
      _draft.clear();
      await _loadComments();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.ct('comms.detail.sendFailed'),
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _step(int dir) {
    final len = n.media.length;
    if (len < 2) return;
    final next = (_mediaIndex + dir + len) % len;
    _pages.animateToPage(next,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title,
                        style: AppText.bodyMedium(context).copyWith(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(Fmt.dateTimeFull(n.createdAt),
                        style: AppText.caption(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.t('mobile.close'),
                icon: Icon(Icons.close, color: t.mutedForeground),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: SelectableText(n.message,
                    style: AppText.body(context)
                        .copyWith(color: t.mutedForeground)),
              ),
              if (n.media.isNotEmpty) _mediaCarousel(context),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.muted, 0.4),
                  border:
                      Border.symmetric(horizontal: BorderSide(color: t.border)),
                ),
                child: Text(
                  widget.isResident
                      ? context.ct('comms.detail.threadResident')
                      : context.ct('comms.detail.threadAdmin'),
                  style: AppText.caption(context)
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _comments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(context.ct('comms.detail.noMessages'),
                            textAlign: TextAlign.center,
                            style: AppText.caption(context)),
                      )
                    : Column(children: [
                        for (final c in _comments) _bubble(context, c)
                      ]),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: t.border))),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: widget.isResident
                          ? context.ct('comms.detail.replyResident')
                          : context.ct('comms.detail.replyAdmin'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: context.ct('comms.detail.send'),
                  style: IconButton.styleFrom(
                      backgroundColor: t.primary,
                      foregroundColor: t.primaryForeground),
                  onPressed:
                      (_sending || _draft.text.trim().isEmpty) ? null : _send,
                  icon: _sending
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: t.primaryForeground))
                      : const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mediaCarousel(BuildContext context) {
    final t = context.tokens;
    final media = n.media;
    final backdrop = t.isDark ? t.background : t.foreground;
    final maxH = MediaQuery.sizeOf(context).height * 0.38;
    return Container(
      color: backdrop,
      constraints: BoxConstraints(maxHeight: maxH),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: media.length,
              onPageChanged: (i) => setState(() => _mediaIndex = i),
              itemBuilder: (context, i) {
                final m = media[i];
                if (m.isVideo) {
                  return InkWell(
                    onTap: () => ExportKit.openUrl(m.url),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_fill,
                              size: 56, color: t.primaryForeground),
                          const SizedBox(height: 6),
                          Text(context.ct('comms.detail.openVideo'),
                              style: TextStyle(
                                  fontSize: 12, color: t.primaryForeground)),
                        ],
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => _openImage(context, m.url),
                  child: CachedNetworkImage(
                    imageUrl: m.url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => Center(
                      child: Text(context.ct('comms.detail.imageFailed'),
                          style: TextStyle(
                              color: t.primaryForeground, fontSize: 12)),
                    ),
                  ),
                );
              },
            ),
            if (media.length > 1) ...[
              Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: _roundNav(Icons.chevron_left, () => _step(-1),
                          'comms.detail.previous'))),
              Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: _roundNav(Icons.chevron_right, () => _step(1),
                          'comms.detail.next'))),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTokens.tint(t.background, 0.8),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text('${_mediaIndex + 1} / ${media.length}',
                        style: TextStyle(fontSize: 12, color: t.foreground)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roundNav(IconData icon, VoidCallback onTap, String tipKey) {
    final t = context.tokens;
    return Material(
      color: AppTokens.tint(t.background, 0.9),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: context.ct(tipKey),
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 20, color: t.foreground)),
        ),
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    final t = context.tokens;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        backgroundColor: t.isDark ? t.background : t.foreground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: t.isDark ? t.foreground : t.background,
          title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
        ),
      ),
    ));
  }

  Widget _bubble(BuildContext context, NotificationComment c) {
    final t = context.tokens;
    final admin = c.isAdmin;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
          bottom: 12, left: admin ? 16 : 0, right: admin ? 0 : 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: admin ? AppTokens.tint(t.primary, 0.10) : t.muted,
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(c.authorName, style: AppText.sectionTitle(context)),
              if ((c.authorFlatNumber ?? '').isNotEmpty)
                Text(
                    context
                        .ct('comms.detail.flat', {'flat': c.authorFlatNumber}),
                    style: AppText.tiny(context)),
              if (admin)
                Text(context.ct('comms.detail.admin'),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: t.primary)),
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(c.body,
              style: AppText.body(context)
                  .copyWith(color: AppTokens.tint(t.foreground, 0.9))),
          const SizedBox(height: 4),
          Text(Fmt.dateTimeFull(c.createdAt), style: AppText.tiny(context)),
        ],
      ),
    );
  }
}
