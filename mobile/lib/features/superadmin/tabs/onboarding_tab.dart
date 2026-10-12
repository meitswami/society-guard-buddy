import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/superadmin_models.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import '../widgets/sa_widgets.dart';
import 'tab_page.dart';

/// Badge tone for `society_orders.status` / `society_signups.status`.
BadgeTone onboardingTone(String? status) => switch ((status ?? '').toLowerCase()) {
      'success' || 'paid' || 'provisioned' => BadgeTone.success,
      'failed' || 'cancelled' => BadgeTone.alert,
      'created' || 'redirected' || 'pending' => BadgeTone.warning,
      _ => BadgeTone.neutral,
    };

/// Web "Payments (onboarding)" tab: latest 200 `society_orders` with their signups
/// (society, signup status, order status, amount, phone, merchant order) — reloaded each
/// time the tab is opened.
class OnboardingTab extends StatefulWidget {
  const OnboardingTab({super.key, required this.ctx, required this.active});

  final SuperadminTabContext ctx;
  final bool active;

  @override
  State<OnboardingTab> createState() => _OnboardingTabState();
}

class _OnboardingTabState extends State<OnboardingTab> {
  List<OnboardingRow> _rows = const [];
  bool _loading = false;
  String? _error;
  String _status = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(OnboardingTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SuperadminScope.read(context).repo.loadOnboarding();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _details(OnboardingRow r) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(r.societyName ?? '—', style: AppText.pageTitle(ctx)),
              const SizedBox(height: 12),
              KeyValueRow(ctx.st('sa.pay.signupStatus'), r.signupStatus ?? '—'),
              KeyValueRow(ctx.st('sa.pay.orderStatus'), r.orderStatus),
              KeyValueRow(ctx.st('sa.pay.amount'), '${Fmt.inr(r.amountInr)} ${r.currency}'),
              KeyValueRow(ctx.st('sa.pay.provider'), r.provider),
              KeyValueRow(ctx.t('superadmin.contactPerson'), r.contactPerson ?? ''),
              KeyValueRow(ctx.t('common.phone'), r.contactPhone ?? '', mono: true),
              KeyValueRow(ctx.st('sa.pay.referralUsed'), r.referralCodeUsed ?? ''),
              KeyValueRow(ctx.st('sa.pay.merchantOrder'), r.merchantTransactionId, mono: true),
              KeyValueRow(ctx.st('sa.details.created'), Fmt.dateTimeFull(r.createdAt)),
              KeyValueRow(ctx.st('sa.pay.signupCreated'), Fmt.dateTimeFull(r.signup?['created_at'])),
              const SizedBox(height: 12),
              AppButton.secondary(
                label: ctx.st('sa.pay.copyOrder'),
                icon: Icons.content_copy,
                onPressed: () => saCopy(ctx, r.merchantTransactionId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final statuses = {for (final r in _rows) r.orderStatus};
    final list = _rows.where((r) => (_status == 'all' || r.orderStatus == _status) && r.matches(_query)).toList();
    final paid = _rows.where((r) => r.orderStatus == 'success').toList();
    final collected = paid.fold<num>(0, (sum, r) => sum + r.amountInr);
    return SuperadminTabPage(
      ctx: widget.ctx,
      onRefresh: _load,
      children: [
        SaTabTitle(
          context.st('sa.pay.title'),
          icon: Icons.credit_card_outlined,
          actions: [
            AppButton.secondary(
              label: _loading ? '…' : context.st('sa.refresh'),
              dense: true,
              expand: false,
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        if (_rows.isNotEmpty) ...[
          StatGrid(
            children: [
              DescriptiveStatCard(
                title: context.st('sa.pay.orders'),
                value: Fmt.number(_rows.length),
                description: context.st('sa.pay.ordersInfo'),
                icon: Icons.receipt_long_outlined,
                compact: true,
              ),
              DescriptiveStatCard(
                title: context.st('sa.pay.collected'),
                value: Fmt.inr(collected),
                caption: '${context.st('sa.pay.collected')} (${paid.length})',
                description: context.st('sa.pay.collectedInfo'),
                icon: Icons.payments_outlined,
                iconColor: t.success,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            hint: context.st('sa.pay.search'),
            prefixIcon: Icons.search,
            caps: false,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChoice(label: context.st('sa.filter.all'), selected: _status == 'all', onTap: () => setState(() => _status = 'all')),
              for (final s in statuses) PillChoice(label: s, selected: _status == s, onTap: () => setState(() => _status = s)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_loading && _rows.isEmpty)
          LoadingView(message: context.st('sa.loading'))
        else if (_error != null && _rows.isEmpty)
          ErrorView(onRetry: _load)
        else if (_rows.isEmpty)
          EmptyView(message: context.st('sa.pay.empty'), icon: Icons.credit_card_outlined)
        else if (list.isEmpty)
          EmptyView(message: context.st('sa.noMatches'))
        else
          for (final r in list)
            CardSection(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () => _details(r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.societyName ?? '—', style: AppText.bodyMedium(context))),
                      Text(Fmt.inr(r.amountInr), style: AppText.mono(context, size: 14, weight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusBadge('${context.st('sa.pay.signup')}: ${r.signupStatus ?? '—'}', tone: onboardingTone(r.signupStatus)),
                      StatusBadge('${context.st('sa.pay.order')}: ${r.orderStatus}', tone: onboardingTone(r.orderStatus)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${r.contactPhone ?? '—'} · ${Fmt.dateTime(r.createdAt)}',
                    style: AppText.mono(context, size: 11, color: t.mutedForeground),
                  ),
                  Text(r.merchantTransactionId, style: AppText.mono(context, size: 10, color: t.mutedForeground)),
                ],
              ),
            ),
      ],
    );
  }
}
