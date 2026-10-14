import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/admin_module.dart';
import 'data/expense_repository.dart';
import 'views/expense_splitter_view.dart';
import 'widgets/ev_fields.dart';
import 'widgets/ev_i18n.dart';
import 'widgets/ev_ui.dart';

/// Admin tab `splits`. On the web this tab opens Finance → Record payment, which renders
/// `ExpenseSplitter paymentOnly embedded` (`FinanceRecordPaymentTab`). The same splitter is
/// shown here (expense heads, splits across flats / society fund, settlements, ledger rows),
/// with a shortcut to the Finance module for head-fund reconciliation.
class AdminSplitsModule extends StatefulWidget {
  const AdminSplitsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminSplitsModule> createState() => _AdminSplitsModuleState();
}

class _AdminSplitsModuleState extends State<AdminSplitsModule> {
  final _hub = EvReloadHub();

  void _openFinance() => widget.ctx.goTo(AdminTab.finance, subTab: 'record_payment');

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    return PageContainer(
      onRefresh: _hub.reloadAll,
      children: [
        PageHeader(
          icon: Icons.call_split,
          title: context.ev('spl.title.payment'),
          subtitle: context.ev('spl.sub.payment'),
          bottomSpacing: 12,
          actions: [
            IconPillButton(icon: Icons.account_balance_wallet_outlined, tooltip: context.ev('spl.openFinance'), onPressed: _openFinance)
          ],
        ),
        EvRichHint(context.ev('spl.recordPaymentIntro'), size: 12),
        const SizedBox(height: 12),
        ExpenseSplitterView(
          societyId: ctx.societyId,
          adminName: ctx.adminName,
          mode: SplitterMode.payment,
          embedded: true,
          hub: _hub,
          initialHeadQuery: ctx.initialQuery,
        ),
        const SizedBox(height: 16),
        Divider(color: context.tokens.border),
        const SizedBox(height: 8),
        AppButton.secondary(icon: Icons.balance, label: context.ev('spl.headFundRecon'), onPressed: _openFinance),
      ],
    );
  }
}
