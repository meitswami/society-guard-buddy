import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/db.dart';
import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import 'core/comms_i18n.dart';
import 'data/notification_audience.dart';
import 'data/notification_media_storage.dart';
import 'data/notification_models.dart';
import 'data/notification_repository.dart';
import 'emergency_alert_view.dart';
import 'widgets/comms_ui.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_detail_sheet.dart';

/// Resident → Alerts. Port of the resident tab in `ResidentDashboard.tsx`:
/// compact `EmergencyAlertPanel` + `NotificationCenter isResident` (inbox filtered to the
/// flat / person, dismissals, "Mark all as seen", "Clear till date", detail + thread).
class NotificationsInboxView extends StatefulWidget {
  const NotificationsInboxView(
      {super.key, required this.session, this.showEmergencyButton = false});

  final SessionResident session;

  /// Show the compact "Emergency or Alert" button above the inbox (web order). Off by
  /// default because `ResidentShell` already renders that button above this view.
  final bool showEmergencyButton;

  @override
  State<NotificationsInboxView> createState() => _NotificationsInboxViewState();
}

class _NotificationsInboxViewState extends State<NotificationsInboxView> {
  final _repo = const NotificationRepository();
  List<AppNotification> _items = const [];
  Set<String> _dismissed = const {};
  bool _loading = true;
  bool _failed = false;
  RealtimeChannel? _channel;

  SessionResident get s => widget.session;
  ResidentRef get _ref => ResidentRef(
      id: s.resident.id,
      name: s.resident.name,
      flatNumber: s.resident.flatNumber);

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.subscribeInserts(
        'notifications-inbox-resident-${s.resident.id}',
        s.societyId,
        (_) => _load(silent: true));
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) unawaited(db.removeChannel(ch));
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final dismissed = await _repo.loadDismissedIds(s.resident.id);
      final rows = await _repo.loadNotifications(societyId: s.societyId);
      final visible = rows
          .where((n) => !dismissed.contains(n.id))
          .where((n) => notificationVisibleToResident(
                targetType: n.targetType,
                targetId: n.targetId,
                residentId: s.resident.id,
                residentName: s.resident.name,
                flatNumber: s.resident.flatNumber,
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _dismissed = dismissed;
        _items = visible;
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

  int get _unread => _items.where((n) => !n.isRead).length;

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      unawaited(_repo
          .markRead(n.id)
          .then((_) => _load(silent: true))
          .catchError((_) {}));
    }
    await NotificationDetailSheet.show(context,
        notification: n, isResident: true, resident: _ref);
  }

  Future<void> _markAllSeen() async {
    final ids = _items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (ids.isEmpty) return;
    try {
      await _repo.markIdsRead(ids);
      if (!mounted) return;
      AppFeedback.toast(context, context.ct('comms.notif.allMarkedRead'),
          tone: BadgeTone.success);
      await _load(silent: true);
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    }
  }

  Future<void> _openClearDialog() async {
    await showCommsSheet<void>(
      context,
      builder: (ctx) =>
          _ClearTillDateSheet(onClear: (date) => _clearTill(ctx, date)),
    );
  }

  /// Web `clearAllTillDate`. Returns true when the sheet should close.
  Future<bool> _clearTill(BuildContext sheetContext, DateTime date) async {
    final label = Fmt.date(date);
    final ok = await AppFeedback.confirm(
      sheetContext,
      title: sheetContext.ct('comms.inbox.clearConfirmTitle'),
      message: sheetContext.ct('comms.inbox.clearConfirmText', {'date': label}),
      confirmLabel: sheetContext.ct('comms.inbox.clearYes'),
      cancelLabel: sheetContext.t('common.cancel'),
      destructive: true,
    );
    if (!ok) return false;
    try {
      final cutoff = endOfLocalDay(date).toUtc().toIso8601String();
      final rows = await _repo.loadForClear(s.societyId, cutoff);
      final ids = idsToDismiss(
        rows,
        alreadyDismissed: _dismissed,
        residentId: s.resident.id,
        residentName: s.resident.name,
        flatNumber: s.resident.flatNumber,
      );
      if (!mounted) return true;
      if (ids.isEmpty) {
        AppFeedback.toast(context, context.ct('comms.inbox.nothingToClear'));
        return true;
      }
      await _repo.dismiss(ids, s.resident.id);
      if (!mounted) return true;
      AppFeedback.toast(
        context,
        context.ct(
            ids.length == 1
                ? 'comms.inbox.clearedOne'
                : 'comms.inbox.clearedMany',
            {'count': ids.length, 'date': label}),
        tone: BadgeTone.success,
      );
      await _load(silent: true);
      return true;
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      onRefresh: () => _load(silent: true),
      children: [
        if (widget.showEmergencyButton)
          EmergencyAlertButton(
            societyId: s.societyId,
            senderName: s.resident.name,
            senderRole: 'resident',
            flatNumber: s.resident.flatNumber,
          ),
        BadgedPageHeader(
          title: context.t('resident.alerts'),
          subtitle: _unread > 0
              ? context.ct('comms.inbox.subtitleNew', {'count': _unread})
              : context.ct('comms.inbox.subtitleCaughtUp'),
          icon: Icons.notifications_none,
          badge: _unread,
          trailing: (_unread > 0 || _items.isNotEmpty)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_unread > 0)
                      LinkText(context.ct('comms.inbox.markAllSeen'),
                          onTap: _markAllSeen),
                    if (_items.isNotEmpty)
                      LinkText(
                        context.ct('comms.inbox.clearTillDate'),
                        icon: Icons.delete_outline,
                        color: t.destructive,
                        onTap: _openClearDialog,
                      ),
                  ],
                )
              : null,
        ),
        MutedBox(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(context.ct('comms.inbox.info'),
              style: AppText.caption(context).copyWith(height: 1.45)),
        ),
        const SizedBox(height: 16),
        if (_loading && _items.isEmpty)
          const LoadingView()
        else if (_failed)
          ErrorView(onRetry: _load)
        else if (_items.isEmpty)
          EmptyView(
              message: context.ct('comms.inbox.empty'),
              icon: Icons.notifications_off_outlined)
        else
          for (final n in _items)
            NotificationCard(
                notification: n, isResident: true, onTap: () => _open(n)),
      ],
    );
  }
}

class _ClearTillDateSheet extends StatefulWidget {
  const _ClearTillDateSheet({required this.onClear});

  final Future<bool> Function(DateTime date) onClear;

  @override
  State<_ClearTillDateSheet> createState() => _ClearTillDateSheetState();
}

class _ClearTillDateSheetState extends State<_ClearTillDateSheet> {
  DateTime _date = DateTime.now();
  bool _clearing = false;

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.ct('comms.inbox.clearTitle'),
              style: AppText.pageTitle(context).copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(context.ct('comms.inbox.clearDesc'),
              style: AppText.caption(context)),
          const SizedBox(height: 16),
          FieldLabel(context.ct('comms.inbox.tillDate')),
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: InputDecorator(
              decoration: InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined,
                      size: 18, color: t.mutedForeground)),
              child: Text(DateFormat('dd/MM/yyyy').format(_date),
                  style: AppText.mono(context, size: 14)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                    label: context.t('common.cancel'),
                    onPressed: () => Navigator.of(context).maybePop()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.destructive(
                  label: _clearing
                      ? context.ct('comms.inbox.clearing')
                      : context.ct('comms.inbox.clearAlerts'),
                  loading: _clearing,
                  onPressed: _clearing
                      ? null
                      : () async {
                          setState(() => _clearing = true);
                          final close = await widget.onClear(_date);
                          if (!context.mounted) return;
                          setState(() => _clearing = false);
                          if (close) Navigator.of(context).maybePop();
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
