import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/admin_module.dart';
import 'data/expense_repository.dart';
import 'views/event_food_reconciliation_view.dart';
import 'views/event_manager_view.dart';
import 'views/expense_splitter_view.dart';
import 'widgets/ev_fields.dart';
import 'widgets/ev_i18n.dart';
import 'widgets/ev_ui.dart';

/// Admin tab `events` — port of `src/components/EventsModule.tsx`:
/// calendar events + contribution receipts, food bills (ExpenseSplitter `foodOnly`)
/// and the receipts reconciliation, all reloading together.
class AdminEventsModule extends StatefulWidget {
  const AdminEventsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminEventsModule> createState() => _AdminEventsModuleState();
}

class _AdminEventsModuleState extends State<AdminEventsModule> {
  final _hub = EvReloadHub();
  late String _query = widget.ctx.initialQuery?.trim() ?? '';

  void _openFinance() => widget.ctx.goTo(AdminTab.finance, subTab: 'record_payment');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ctx = widget.ctx;
    return PageContainer(
      onRefresh: _hub.reloadAll,
      children: [
        PageHeader(
          icon: Icons.calendar_month,
          iconColor: t.accent,
          title: context.ev('evm.moduleTitle'),
          subtitle: context.ev('evm.moduleSubtitle'),
          bottomSpacing: 12,
        ),
        AppTextField(
          hint: context.ev('evm.searchHint'),
          initialValue: _query,
          caps: false,
          prefixIcon: Icons.search,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        CardSection(
          padding: const EdgeInsets.all(12),
          color: AppTokens.tint(t.primary, 0.05),
          borderColor: AppTokens.tint(t.primary, 0.2),
          child: EvRichHint(
            context.ev('evm.recordIntro'),
            size: 12,
            onLinkTap: _openFinance,
            leading: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.restaurant, size: 14, color: t.primary)),
          ),
        ),
        const SizedBox(height: 16),
        EvSectionHeading(icon: Icons.calendar_month, color: t.accent, title: context.ev('evm.sec1')),
        EvRichHint(context.ev('evm.sec1Hint')),
        const SizedBox(height: 12),
        EventManagerView(
          societyId: ctx.societyId,
          adminName: ctx.adminName,
          embedded: true,
          hub: _hub,
          query: _query,
          onRecordsChanged: _hub.reloadAll,
        ),
        const SizedBox(height: 24),
        EvSectionHeading(icon: Icons.restaurant, color: t.warning, title: context.ev('evm.sec2')),
        EvRichHint(context.ev('evm.sec2Hint')),
        const SizedBox(height: 12),
        ExpenseSplitterView(
          societyId: ctx.societyId,
          adminName: ctx.adminName,
          mode: SplitterMode.food,
          embedded: true,
          hub: _hub,
          query: _query,
          onRecordsChanged: _hub.reloadAll,
          onOpenFinance: _openFinance,
        ),
        const SizedBox(height: 24),
        EvSectionHeading(icon: Icons.balance, color: t.success, title: context.ev('evm.sec3')),
        EvRichHint(context.ev('evm.sec3Hint')),
        const SizedBox(height: 12),
        EventFoodReconciliationView(
          societyId: ctx.societyId,
          adminName: ctx.adminName,
          hub: _hub,
          query: _query,
          onRecordsChanged: _hub.reloadAll,
        ),
      ],
    );
  }
}
