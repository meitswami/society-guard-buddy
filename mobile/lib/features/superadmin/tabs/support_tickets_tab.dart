import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/supabase/db.dart';
import '../../../core/ui/ui.dart';
import '../data/superadmin_models.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import '../widgets/sa_widgets.dart';
import '../widgets/voice_player.dart';
import 'tab_page.dart';

String ticketStatusLabel(BuildContext context, String s) => switch (s) {
      'resolved' => context.st('sa.tickets.resolved'),
      'future_update' => context.st('sa.tickets.futureUpdate'),
      _ => context.st('sa.tickets.pending'),
    };

BadgeTone ticketTone(String s) => switch (s) {
      'resolved' => BadgeTone.success,
      'future_update' => BadgeTone.info,
      _ => BadgeTone.warning,
    };

/// Port of `SuperadminSupportTickets.tsx`: tickets newest first, status select, message /
/// voice / media, last reply, and "Send reply" (ticket update + targeted in-app
/// notification + push). Live refresh via Realtime (`support_tickets` is published).
class SupportTicketsTab extends StatefulWidget {
  const SupportTicketsTab({super.key, required this.ctx, required this.active});

  final SuperadminTabContext ctx;
  final bool active;

  @override
  State<SupportTicketsTab> createState() => _SupportTicketsTabState();
}

class _SupportTicketsTabState extends State<SupportTicketsTab> {
  List<SupportTicket> _tickets = const [];
  bool _loading = true;
  final Map<String, TextEditingController> _replies = {};
  String? _sendingId;
  String _filter = 'all';
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    if (dbReady) {
      _channel = db
          .channel('superadmin-support-tickets')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'support_tickets',
            callback: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 600), () {
                if (mounted) _load(silent: true);
              });
            },
          )
          .subscribe();
    }
  }

  @override
  void didUpdateWidget(SupportTicketsTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load(silent: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final ch = _channel;
    if (ch != null) db.removeChannel(ch);
    for (final c in _replies.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _reply(String id) => _replies.putIfAbsent(id, TextEditingController.new);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rows = await SuperadminScope.read(context).repo.loadTickets();
      if (mounted) setState(() => _tickets = rows);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, e is PostgrestException ? e.message : '$e', tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(SupportTicket t, String status) async {
    try {
      await SuperadminScope.read(context).repo.setTicketStatus(t.id, status);
      if (mounted) AppFeedback.toast(context, context.st('sa.tickets.statusUpdated'), tone: BadgeTone.success);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, e is PostgrestException ? e.message : '$e', tone: BadgeTone.alert);
      return;
    }
    await _load(silent: true);
  }

  Future<void> _send(SupportTicket t) async {
    final body = _reply(t.id).text.trim();
    if (body.isEmpty) {
      AppFeedback.toast(context, context.st('sa.tickets.enterReply'), tone: BadgeTone.alert);
      return;
    }
    if ((t.societyId ?? '').isEmpty || t.submitterResidentId.isEmpty) {
      AppFeedback.toast(context, context.st('sa.tickets.missingTarget'), tone: BadgeTone.alert);
      return;
    }
    setState(() => _sendingId = t.id);
    final err = await SuperadminScope.read(context).repo.replyToTicket(
          ticket: t,
          body: body,
          superadminId: widget.ctx.session.id,
          superadminName: widget.ctx.session.name,
        );
    if (!mounted) return;
    setState(() => _sendingId = null);
    if (err != null) {
      AppFeedback.toast(context, err, tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(context, context.st('sa.tickets.replySent'), tone: BadgeTone.success);
    _reply(t.id).clear();
    await _load(silent: true);
  }

  void _openImage(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => ExportKit.openUrl(url))]),
        body: InteractiveViewer(child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain))),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final counts = {for (final s in kTicketStatuses) s: _tickets.where((x) => x.status == s).length};
    final list = _filter == 'all' ? _tickets : _tickets.where((x) => x.status == _filter).toList();
    return SuperadminTabPage(
      ctx: widget.ctx,
      onRefresh: _load,
      children: [
        SaTabTitle(
          context.st('sa.tickets.title'),
          icon: Icons.headset_mic_outlined,
          actions: [SaLinkButton(label: context.st('sa.refresh'), color: t.primary, onTap: _load)],
        ),
        Text(context.st('sa.tickets.intro'), style: AppText.caption(context)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PillChoice(
              label: '${context.st('sa.filter.all')} (${_tickets.length})',
              selected: _filter == 'all',
              onTap: () => setState(() => _filter = 'all'),
            ),
            for (final s in kTicketStatuses)
              PillChoice(
                label: '${ticketStatusLabel(context, s)} (${counts[s]})',
                selected: _filter == s,
                onTap: () => setState(() => _filter = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && _tickets.isEmpty)
          LoadingView(message: context.st('sa.loading'))
        else if (_tickets.isEmpty)
          EmptyView(message: context.st('sa.tickets.empty'), icon: Icons.headset_mic_outlined)
        else if (list.isEmpty)
          EmptyView(message: context.st('sa.noMatches'))
        else
          for (final tk in list)
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${tk.ticketNumber}', style: AppText.sectionTitle(context)),
                            Text(
                              '${tk.societyName ?? '—'} · ${context.t('common.flat')} ${tk.flatNumber} · ${tk.submitterName}',
                              style: AppText.caption(context),
                            ),
                            Text(Fmt.dateTimeFull(tk.createdAt), style: AppText.mono(context, size: 10, color: t.mutedForeground)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 150,
                        child: AppDropdown<String>(
                          label: context.st('sa.tickets.status'),
                          items: kTicketStatuses,
                          value: tk.status,
                          labelOf: (s) => ticketStatusLabel(context, s),
                          onChanged: (v) {
                            if (v != null && v != tk.status) _setStatus(tk, v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(context.st('sa.tickets.message').toUpperCase(), style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  SelectableText(tk.message, style: AppText.body(context)),
                  if ((tk.audioUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(context.st('sa.tickets.voice').toUpperCase(), style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    VoiceNotePlayer(url: tk.audioUrl!),
                  ],
                  if (tk.media.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(context.st('sa.tickets.media').toUpperCase(), style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in tk.media)
                          if (m.kind == 'image')
                            InkWell(onTap: () => _openImage(m.url), child: SaNetImage(m.url, width: 64, height: 64))
                          else
                            ActionChip(
                              avatar: Icon(m.kind == 'video' ? Icons.videocam_outlined : Icons.open_in_new, size: 16, color: t.primary),
                              label: Text(m.kind ?? 'file', style: TextStyle(color: t.primary, fontSize: 12)),
                              onPressed: () => ExportKit.openUrl(m.url),
                            ),
                      ],
                    ),
                  ],
                  if ((tk.superadminReply ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTokens.tint(t.secondary, 0.4),
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.st('sa.tickets.lastReply'),
                              style: AppText.caption(context).copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          SelectableText(tk.superadminReply!, style: const TextStyle(fontSize: 12)),
                          if ((tk.repliedAt ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(Fmt.dateTimeFull(tk.repliedAt), style: AppText.tiny(context)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: t.border),
                  const SizedBox(height: 12),
                  Text(context.st('sa.tickets.replyLabel'), style: AppText.caption(context)),
                  const SizedBox(height: 6),
                  AppTextField(
                    controller: _reply(tk.id),
                    hint: context.st('sa.tickets.replyHint'),
                    maxLines: 4,
                    minLines: 3,
                    caps: false,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: _sendingId == tk.id ? context.st('sa.tickets.sending') : context.st('sa.tickets.send'),
                      icon: Icons.send_outlined,
                      expand: false,
                      dense: true,
                      loading: _sendingId == tk.id,
                      onPressed: _sendingId == tk.id ? null : () => _send(tk),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
