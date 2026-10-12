import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/db.dart';
import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import 'data/notification_audience.dart';
import 'data/notification_repository.dart';
import 'data/notification_sound_player.dart';

/// Web `useNotificationsRealtimeRevision(..., { onNotificationInsert })` in
/// `ResidentDashboard.tsx`: while the resident area is open, every new notification for
/// this flat / person shows an in-app toast (title + first 200 chars, 8 s) and plays its
/// alert sound. Wrap the resident shell body with it.
class ResidentNotificationAlertListener extends StatefulWidget {
  const ResidentNotificationAlertListener({super.key, required this.session, required this.child, this.onInsert});

  final SessionResident session;
  final Widget child;

  /// Called for every visible insert (e.g. to bump an unread badge).
  final VoidCallback? onInsert;

  @override
  State<ResidentNotificationAlertListener> createState() => _ResidentNotificationAlertListenerState();
}

class _ResidentNotificationAlertListenerState extends State<ResidentNotificationAlertListener> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ResidentNotificationAlertListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.resident.id != widget.session.resident.id || oldWidget.session.societyId != widget.session.societyId) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    final s = widget.session;
    _channel = const NotificationRepository().subscribeInserts('notifications-dashboard-resident-${s.resident.id}', s.societyId, _onRow);
  }

  void _unsubscribe() {
    final ch = _channel;
    _channel = null;
    if (ch != null) unawaited(db.removeChannel(ch));
  }

  void _onRow(Map<String, dynamic> row) {
    final s = widget.session;
    if (!notificationRowVisibleToResident(row,
        residentId: s.resident.id, residentName: s.resident.name, flatNumber: s.resident.flatNumber)) {
      return;
    }
    widget.onInsert?.call();
    if (!mounted) return;
    final title = (row['title'] ?? 'Alert').toString();
    final message = (row['message'] ?? '').toString();
    final body = message.length > 200 ? message.substring(0, 200) : message;
    AppFeedback.toast(context, body.isEmpty ? title : '$title\n$body', duration: const Duration(seconds: 8));
    unawaited(playNotificationAlert(row['sound_key']?.toString() ?? 'digital', row['sound_custom_url']?.toString()));
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
