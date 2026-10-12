import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/session/gate_actor.dart';
import '../../../core/ui/ui.dart';
import '../../../services/approval_service.dart';
import '../gate_i18n.dart';

enum ApprovalOutcome { approved, rejected, timeout, cancelled, failed }

enum _Stage { sending, waiting, approved, rejected }

/// Web `ApprovalRequestModal`: sends an `approval_requests` row to the flat, waits for the
/// resident's answer over realtime (with a 5 s polling fallback) and gives up after 2 minutes.
class ApprovalRequestDialog extends StatefulWidget {
  const ApprovalRequestDialog({
    super.key,
    required this.actor,
    required this.visitorName,
    required this.visitorPhone,
    required this.flatNumber,
    required this.purpose,
    this.timeoutSeconds = 120,
  });

  final GateActor actor;
  final String visitorName;
  final String visitorPhone;
  final String flatNumber;
  final String purpose;
  final int timeoutSeconds;

  static Future<ApprovalOutcome> show(
    BuildContext context, {
    required GateActor actor,
    required String visitorName,
    required String visitorPhone,
    required String flatNumber,
    required String purpose,
  }) async {
    final res = await showDialog<ApprovalOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApprovalRequestDialog(
        actor: actor,
        visitorName: visitorName,
        visitorPhone: visitorPhone,
        flatNumber: flatNumber,
        purpose: purpose,
      ),
    );
    return res ?? ApprovalOutcome.cancelled;
  }

  @override
  State<ApprovalRequestDialog> createState() => _ApprovalRequestDialogState();
}

class _ApprovalRequestDialogState extends State<ApprovalRequestDialog> {
  final _service = ApprovalService();
  _Stage _stage = _Stage.sending;
  late int _left = widget.timeoutSeconds;
  RealtimeChannel? _channel;
  Timer? _tick;
  Timer? _poll;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _send();
  }

  Future<void> _send() async {
    String? id;
    try {
      id = await _service.createVisitorRequest(
        societyId: widget.actor.societyId,
        flatNumber: widget.flatNumber,
        visitorName: widget.visitorName,
        visitorPhone: widget.visitorPhone,
        guardId: widget.actor.actorId,
        guardName: widget.actor.actorName,
        purpose: widget.purpose,
      );
    } catch (_) {
      if (!mounted) return;
      AppFeedback.toast(context, context.gt('gate.approval.failed'), tone: BadgeTone.alert);
      _close(ApprovalOutcome.failed);
      return;
    }
    if (!mounted) return;
    if (id == null) {
      AppFeedback.toast(context, context.gt('gate.approval.flatNotFound', {'flat': widget.flatNumber}), tone: BadgeTone.alert);
      _close(ApprovalOutcome.failed);
      return;
    }
    final requestId = id;
    setState(() => _stage = _Stage.waiting);
    _channel = _service.watchRequest(requestId, _onStatus);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final s = await _service.fetchRequestStatus(requestId);
        if (s != null) _onStatus(s);
      } catch (_) {}
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _stage != _Stage.waiting) return;
      setState(() => _left -= 1);
      if (_left <= 0) {
        AppFeedback.toast(context, context.t('approval.timeout'), tone: BadgeTone.warning);
        _close(ApprovalOutcome.timeout);
      }
    });
  }

  void _onStatus(String status) {
    if (!mounted || _stage != _Stage.waiting) return;
    if (status != 'approved' && status != 'rejected') return;
    _stopWatching();
    setState(() => _stage = status == 'approved' ? _Stage.approved : _Stage.rejected);
    Future.delayed(const Duration(milliseconds: 1500), () {
      _close(status == 'approved' ? ApprovalOutcome.approved : ApprovalOutcome.rejected);
    });
  }

  void _stopWatching() {
    _tick?.cancel();
    _poll?.cancel();
    final ch = _channel;
    _channel = null;
    if (ch != null) unawaited(_service.stopWatching(ch));
  }

  void _close(ApprovalOutcome outcome) {
    if (_finished || !mounted) return;
    _finished = true;
    _stopWatching();
    Navigator.of(context).pop(outcome);
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mm = (_left ~/ 60).toString();
    final ss = (_left % 60).toString().padLeft(2, '0');

    Widget circle(IconData icon, Color color, {double size = 64}) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: AppTokens.tint(color, 0.15), shape: BoxShape.circle),
          child: Icon(icon, size: size * 0.45, color: color),
        );

    final body = switch (_stage) {
      _Stage.sending => [
          SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: t.primary)),
          const SizedBox(height: 16),
          Text(context.t('approval.sending'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
        ],
      _Stage.waiting => [
          Stack(
            clipBehavior: Clip.none,
            children: [
              circle(Icons.send_rounded, t.primary),
              Positioned(
                top: -4,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: t.warning, borderRadius: BorderRadius.circular(99)),
                  child: Text('$mm:$ss', style: AppText.mono(context, size: 12, color: t.warningForeground)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(context.t('approval.waitingTitle'), style: AppText.sectionTitle(context).copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('${context.t('approval.waitingFor')} ${widget.flatNumber}', style: AppText.caption(context), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('${widget.visitorName} · ${widget.purpose}', style: AppText.caption(context), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppButton.secondary(label: context.t('common.cancel'), onPressed: () => _close(ApprovalOutcome.cancelled)),
        ],
      _Stage.approved => [
          circle(Icons.check_rounded, t.success),
          const SizedBox(height: 16),
          Text(context.t('approval.approved'), style: AppText.sectionTitle(context).copyWith(fontSize: 16, color: t.success)),
        ],
      _Stage.rejected => [
          circle(Icons.close_rounded, t.destructive),
          const SizedBox(height: 16),
          Text(context.t('approval.rejected'), style: AppText.sectionTitle(context).copyWith(fontSize: 16, color: t.destructive)),
        ],
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage != _Stage.approved && _stage != _Stage.rejected) _close(ApprovalOutcome.cancelled);
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusXl), side: BorderSide(color: t.border)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: body),
          ),
        ),
      ),
    );
  }
}
