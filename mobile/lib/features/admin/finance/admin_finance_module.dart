// Admin → Finance — port of `src/components/FinanceManager.tsx` (+ FinanceSubTabNav).

import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/admin_module.dart';
import 'data/finance_repository.dart';
import 'state/finance_controller.dart';
import 'state/finance_forms.dart';
import 'tabs/finance_heads_tabs.dart';
import 'tabs/finance_record_payment_tab.dart';
import 'tabs/finance_record_receipt_tab.dart';
import 'tabs/finance_reminders_panel.dart';
import 'tabs/finance_totals_tab.dart';
import 'tabs/finance_transactions_tab.dart';
import 'widgets/fin_kit.dart';
import 'widgets/finance_widgets.dart';

/// Admin finance module entry (contract: `AdminFinanceModule({super.key, required this.ctx})`).
class AdminFinanceModule extends StatelessWidget {
  const AdminFinanceModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  Widget build(BuildContext context) =>
      FinanceManagerView(ctx: ctx, repository: SupabaseFinanceRepository());
}

/// The finance page with an injectable repository (widget tests use a fake).
class FinanceManagerView extends StatefulWidget {
  const FinanceManagerView(
      {super.key, required this.ctx, required this.repository});

  final AdminModuleContext ctx;
  final FinanceRepository repository;

  @override
  State<FinanceManagerView> createState() => _FinanceManagerViewState();
}

class _FinanceManagerViewState extends State<FinanceManagerView> {
  late final FinanceController c = FinanceController(
      repo: widget.repository,
      societyId: widget.ctx.societyId,
      adminName: widget.ctx.adminName);
  final chargeForm = ChargeFormModel();
  final headForm = PaymentHeadFormModel();
  final receiptForm = RecordReceiptFormModel();
  final filters = TransactionsFilterModel();
  final _scroll = ScrollController();
  FinanceSubTab _tab = FinanceSubTab.maintenance;
  bool _showReminders = false;
  bool _includeVacant = false;

  @override
  void initState() {
    super.initState();
    _applyCtx(widget.ctx);
    c.load();
  }

  @override
  void didUpdateWidget(FinanceManagerView old) {
    super.didUpdateWidget(old);
    if (old.ctx.subTab != widget.ctx.subTab ||
        old.ctx.initialQuery != widget.ctx.initialQuery) {
      _applyCtx(widget.ctx);
    }
  }

  /// Web `initialSubTab` / `initialSearchQuery` effects.
  void _applyCtx(AdminModuleContext ctx) {
    final sub = financeSubTabFromWire(ctx.subTab);
    if (sub != null) {
      _tab = sub;
      if (sub == FinanceSubTab.payments) receiptForm.showPaymentForm = true;
    }
    final q = ctx.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      filters.search.text = q;
      _tab = FinanceSubTab.receipts;
    }
  }

  @override
  void dispose() {
    c.dispose();
    chargeForm.dispose();
    headForm.dispose();
    receiptForm.dispose();
    filters.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(FinanceSubTab tab) {
    setState(() {
      _tab = tab;
      if (tab == FinanceSubTab.payments) receiptForm.showPaymentForm = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _tabLabel(FinanceSubTab t) => switch (t) {
        FinanceSubTab.maintenance => context.fin('fin.tab.maintenance'),
        FinanceSubTab.createPayment => context.fin('fin.tab.createPayment'),
        FinanceSubTab.payments => context.fin('fin.tab.payments'),
        FinanceSubTab.recordPayment => context.fin('fin.tab.recordPayment'),
        FinanceSubTab.receipts => context.fin('fin.tab.receipts'),
        FinanceSubTab.totals => context.fin('fin.tab.totals'),
      };

  Widget _nav(BuildContext context) {
    final t = context.tokens;
    Widget dropdown(String label, List<FinanceSubTab> items) {
      final active = items.contains(_tab);
      return PopupMenuButton<FinanceSubTab>(
        onSelected: _go,
        itemBuilder: (_) => [
          for (final i in items)
            PopupMenuItem(
                value: i,
                child: Text(_tabLabel(i), style: const TextStyle(fontSize: 13)))
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: active ? t.primary : t.secondary,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                active ? '$label: ${_tabLabel(_tab)}' : label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        active ? t.primaryForeground : t.secondaryForeground),
              ),
              Icon(Icons.expand_more,
                  size: 14,
                  color: active ? t.primaryForeground : t.secondaryForeground),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            dropdown(context.fin('fin.tab.create'),
                const [FinanceSubTab.maintenance, FinanceSubTab.createPayment]),
            const SizedBox(width: 4),
            dropdown(context.fin('fin.tab.record'),
                const [FinanceSubTab.payments, FinanceSubTab.recordPayment]),
            const SizedBox(width: 4),
            for (final tab in const [
              FinanceSubTab.receipts,
              FinanceSubTab.totals
            ]) ...[
              PillChoice(
                  label: _tabLabel(tab),
                  selected: _tab == tab,
                  onTap: () => _go(tab)),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 8),
            Material(
              color: _showReminders
                  ? AppTokens.tint(t.warning, 0.15)
                  : t.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                side: _showReminders
                    ? BorderSide(color: AppTokens.tint(t.warning, 0.3))
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                onTap: () => setState(() => _showReminders = !_showReminders),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_none,
                          size: 14,
                          color: _showReminders
                              ? t.warning
                              : t.secondaryForeground),
                      const SizedBox(width: 4),
                      Text(
                        _showReminders
                            ? context.fin('fin.tab.hideReminders')
                            : context.fin('fin.tab.reminders'),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _showReminders
                                ? t.warning
                                : t.secondaryForeground),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() => switch (_tab) {
        FinanceSubTab.maintenance =>
          FinanceMaintenanceTab(c: c, form: chargeForm),
        FinanceSubTab.createPayment =>
          FinanceCreatePaymentTab(c: c, form: headForm),
        FinanceSubTab.payments =>
          FinanceRecordReceiptTab(c: c, form: receiptForm),
        FinanceSubTab.recordPayment => FinanceRecordPaymentTab(
            c: c,
            ctx: widget.ctx,
            onOpenRecordReceipt: () => _go(FinanceSubTab.payments)),
        FinanceSubTab.receipts => FinanceTransactionsTab(
            c: c, filters: filters, includeVacantFlats: _includeVacant),
        FinanceSubTab.totals => FinanceTotalsTab(c: c),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final t = context.tokens;
        final d = c.data;
        if (c.loading && !c.hasData) {
          return PageContainer(children: [
            CardSection(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                      context.tr(
                          'Loading finance data…', 'वित्त डेटा लोड हो रहा है…'),
                      style: AppText.bodyMedium(context)),
                  Text(
                      context.tr(
                          'Fetching receipts, ledger entries, and flat records.',
                          'रसीदें, खाता प्रविष्टियाँ और फ्लैट रिकॉर्ड लाए जा रहे हैं।'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(context)),
                ],
              ),
            ),
          ]);
        }
        if (c.error != null && !c.hasData) {
          return PageContainer(onRefresh: c.load, children: [
            CardSection(
              color:
                  Color.alphaBlend(AppTokens.tint(t.destructive, 0.05), t.card),
              borderColor: AppTokens.tint(t.destructive, 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      context.tr('Finance module could not load',
                          'वित्त खंड लोड नहीं हो सका'),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.destructive)),
                  const SizedBox(height: 6),
                  Text(
                      financeErrorMessage(
                          c.error!, 'Could not load finance data'),
                      style: AppText.caption(context)),
                  const SizedBox(height: 12),
                  AppButton(
                      label: context.tr('Try again', 'फिर से कोशिश करें'),
                      onPressed: c.load),
                ],
              ),
            ),
          ]);
        }
        return PageContainer(
          controller: _scroll,
          onRefresh: c.invalidateAll,
          children: [
            PageHeader(
              icon: Icons.currency_rupee,
              iconColor: t.success,
              title: context.fin('fin.title'),
              subtitle: context.tr(
                '${d.charges.length} receipt types · ${d.payments.length} receipts · ${d.ledgerEntries.length} ledger entries',
                '${d.charges.length} रसीद प्रकार · ${d.payments.length} रसीदें · ${d.ledgerEntries.length} खाता प्रविष्टियाँ',
              ),
              bottomSpacing: 16,
              actions: [
                IconPillButton(
                  icon: Icons.info_outline,
                  onPressed: () => AppFeedback.info(
                    context,
                    title: context.fin('fin.title'),
                    description: context.tr(
                        'Quick counts for this society’s finance module scope.',
                        'इस सोसाइटी के वित्त खंड की त्वरित गिनती।'),
                    howCalculated: context.tr(
                      'Receipt types = maintenance_charges rows. Receipts = maintenance_payments. Ledger entries = finance_entries (pool, direct, event mirror).',
                      'रसीद प्रकार = maintenance_charges पंक्तियाँ। रसीदें = maintenance_payments। खाता प्रविष्टियाँ = finance_entries (पूल, सीधा, कार्यक्रम प्रतिबिंब)।',
                    ),
                  ),
                ),
              ],
            ),
            const RecordingDateBanner(),
            const SizedBox(height: 16),
            if (c.fetching)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                    context.tr('Refreshing finance data…',
                        'वित्त डेटा ताज़ा हो रहा है…'),
                    textAlign: TextAlign.center,
                    style: AppText.tiny(context)),
              ),
            _nav(context),
            if (_showReminders)
              FinanceRemindersPanel(
                c: c,
                includeVacant: _includeVacant,
                onIncludeVacantChanged: (v) =>
                    setState(() => _includeVacant = v),
              ),
            KeyedSubtree(key: ValueKey(_tab), child: _content()),
          ],
        );
      },
    );
  }
}
