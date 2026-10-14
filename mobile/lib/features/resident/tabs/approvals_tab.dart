import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/resident_models.dart';
import '../state/resident_controllers.dart';
import '../widgets/resident_widgets.dart';

/// Approvals tab — web `tab === 'approvals'` (pending visitor requests from the gate,
/// approve / reject, history).
class ResidentApprovalsTab extends StatelessWidget {
  const ResidentApprovalsTab({super.key, required this.controller});

  final ResidentApprovalsController controller;

  Future<void> _respond(BuildContext context, ApprovalRequestRow req, String status) async {
    final label = status == 'approved' ? context.t('resident.approve') : context.t('resident.reject');
    final ok = await AppFeedback.confirm(
      context,
      title: '$label?',
      message: context.t('resident.confirmApprovalText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: status == 'rejected',
    );
    if (!ok || !context.mounted) return;
    try {
      await controller.respond(req.id, status);
      if (!context.mounted) return;
      await AppFeedback.success(
        context,
        title: context.t('swal.success'),
        message: status == 'approved' ? context.t('resident.approved') : context.t('resident.rejected'),
      );
    } catch (e) {
      if (context.mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = context.tokens;
        final pending = controller.pending;
        final history = controller.history;
        return PageContainer(
          onRefresh: controller.load,
          children: [
            PageHeader(
              title: context.t('resident.approvals'),
              subtitle: context.tr(
                  'Visitors waiting at the gate for your approval', 'गेट पर आपकी अनुमति की प्रतीक्षा में आगंतुक'),
              icon: Icons.notifications_outlined,
            ),
            if (controller.loading && controller.requests.isEmpty) const LoadingView(),
            if (controller.failed) ErrorView(onRetry: controller.load),
            if (pending.isNotEmpty)
              CardSection(
                borderColor: AppTokens.tint(t.warning, 0.3),
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('🔔 ${context.t('resident.pendingApprovals')}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.warning)),
                    const SizedBox(height: 12),
                    for (final req in pending) _PendingCard(req: req, onRespond: (s) => _respond(context, req, s)),
                  ],
                ),
              ),
            ListLabel(context.t('resident.history')),
            if (!controller.loading && history.isEmpty) EmptyView(message: context.t('resident.noHistory')),
            for (final req in history)
              CardSection(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(req.visitorName, style: AppText.bodyMedium(context)),
                      Text(Fmt.dateTime(req.createdAt), style: AppText.caption(context)),
                    ]),
                  ),
                  ToneBadge(
                    req.status == 'approved' ? context.t('resident.approved') : context.t('resident.rejected'),
                    tone: req.status == 'approved' ? BadgeTone.success : BadgeTone.alert,
                  ),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.req, required this.onRespond});

  final ApprovalRequestRow req;
  final ValueChanged<String> onRespond;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.background,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((req.visitorPhoto ?? '').isNotEmpty) ...[
              ResidentThumb(src: req.visitorPhoto!, size: 44, circle: true),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(req.visitorName, style: AppText.sectionTitle(context)),
                if ((req.visitorPhone ?? '').isNotEmpty)
                  Text(req.visitorPhone!, style: AppText.mono(context, size: 12, color: t.mutedForeground)),
                if ((req.purpose ?? '').isNotEmpty) Text(req.purpose!, style: AppText.caption(context)),
              ]),
            ),
            Text(Fmt.dateTime(req.createdAt), style: AppText.tiny(context)),
          ]),
          const SizedBox(height: 8),
          Text('${context.t('logs.guard')}: ${req.guardName}', style: AppText.caption(context)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: AppButton(
                label: context.t('resident.approve'),
                icon: Icons.check,
                variant: AppButtonVariant.success,
                dense: true,
                onPressed: () => onRespond('approved'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton.destructive(
                label: context.t('resident.reject'),
                icon: Icons.close,
                dense: true,
                onPressed: () => onRespond('rejected'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
