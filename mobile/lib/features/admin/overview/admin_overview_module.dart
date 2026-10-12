import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/admin_module.dart';
import '../core/admin_navigation.dart';
import 'admin_overview_service.dart';

/// Admin home — port of the `default:` branch of `AdminDashboard.tsx` `renderContent`.
class AdminOverviewModule extends StatefulWidget {
  const AdminOverviewModule({super.key, required this.ctx, this.onLogout, this.visibleTabs = const []});

  final AdminModuleContext ctx;
  final VoidCallback? onLogout;
  /// Modules this admin may open (for quick access).
  final List<AdminTabDef> visibleTabs;

  @override
  State<AdminOverviewModule> createState() => _AdminOverviewModuleState();
}

class _AdminOverviewModuleState extends State<AdminOverviewModule> {
  final _service = AdminOverviewService();
  AdminOverviewStats _stats = const AdminOverviewStats();
  List<KycPendingGuard> _kyc = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final sid = widget.ctx.societyId;
      final results = await Future.wait([_service.loadStats(sid), _service.loadKycPending(sid)]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminOverviewStats;
        _kyc = results[1] as List<KycPendingGuard>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _go(AdminTab tab, {String? subTab}) => widget.ctx.goTo(tab, subTab: subTab);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _stats;
    final usage = AdminTabUsage.read(widget.ctx.societyId);
    final last = AdminTabUsage.lastTab(widget.ctx.societyId);
    final quick = computeQuickAccessTabs(widget.visibleTabs, usage, last, context.t);

    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          title: context.t('admin.panel'),
          subtitle: '${widget.ctx.adminName} (${widget.ctx.session.admin.adminId})',
          icon: Icons.shield_outlined,
          iconColor: t.destructive,
          actions: [
            if (widget.onLogout != null)
              IconPillButton(
                icon: Icons.logout,
                color: t.destructive,
                background: AppTokens.tint(t.destructive, 0.10),
                onPressed: widget.onLogout,
              ),
          ],
          bottomSpacing: 16,
        ),
        if (_failed) ErrorView(onRetry: _load),
        if (_loading && !_failed)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        const SizedBox(height: 8),
        DescriptiveStatCard(
          title: 'Meetings held',
          description:
              'Number of society meetings recorded in the Meetings module (published or saved with minutes). Used for governance tracking.',
          howCalculated: 'Count of meeting records for this society in the meetings table.',
          icon: Icons.description_outlined,
          iconColor: const Color(0xFF6366F1),
          value: '${s.meetingsHeld}',
          onNavigate: () => _go(AdminTab.meetings),
          navigateLabel: 'Open Meetings',
        ),
        const SizedBox(height: 12),
        DescriptiveStatCard(
          title: 'Total collection (verified)',
          description:
              'Sum of all verified maintenance and society receipt payments — money recorded as collected from flat owners or outsiders.',
          howCalculated:
              'Adds amounts from maintenance_payments where payment_status = verified, for charges linked to this society.',
          icon: Icons.currency_rupee,
          iconColor: t.success,
          value: Fmt.inr(s.maintenanceCollected),
          onNavigate: _openCollectionMonthly,
          navigateLabel: 'Monthly breakdown',
        ),
        const SizedBox(height: 12),
        DescriptiveStatCard(
          title: 'Total expenses (active)',
          description:
              'Sum of all active society expenses — event food/catering bills and general payment heads (salary, O&M, assets, etc.). Tap to open category breakdown.',
          howCalculated:
              'Sums expenses.total_amount where record_status = active for all expense groups in this society (food and payment categories).',
          icon: Icons.call_split,
          iconColor: t.primary,
          value: Fmt.inr(s.expenseTotal),
          onNavigate: _openExpenseBuckets,
          navigateLabel: 'Expense breakdown',
        ),
        const SizedBox(height: 12),
        StatGrid(
          children: [
            _withRows(
              DescriptiveStatCard(
                title: 'Total visitors',
                description: 'All visitor log entries (guests and servicemen) recorded by guards or admins.',
                howCalculated: 'Count of rows in visitors for this society.',
                icon: Icons.people_outline,
                iconColor: const Color(0xFF3B82F6),
                value: '${s.visitors}',
                onNavigate: () => _go(AdminTab.visitor),
                navigateLabel: 'Open Visitor log',
              ),
              [('Guest visitors', s.visitorsGuest), ('Serviceman', s.visitorsService)],
            ),
            _withRows(
              DescriptiveStatCard(
                title: 'Resident vehicles',
                description: 'Vehicles registered to flats in the society.',
                howCalculated: 'Count of resident_vehicles (or equivalent) for this society.',
                icon: Icons.directions_car_outlined,
                iconColor: const Color(0xFFF97316),
                value: '${s.vehicles}',
                onNavigate: () => _go(AdminTab.vehicle),
                navigateLabel: 'Open Vehicles',
              ),
              [('Cars', s.vehiclesCars), ('Two-wheelers', s.vehiclesTwoWheelers)],
            ),
            _withRows(
              DescriptiveStatCard(
                title: 'Flats',
                description: 'Total flat units defined in the society layout.',
                howCalculated: 'Count of flats for this society_id.',
                icon: Icons.home_outlined,
                iconColor: const Color(0xFFA855F7),
                value: '${s.flats}',
                onNavigate: () => _go(AdminTab.residents),
                navigateLabel: 'Open Residents',
              ),
              [('Members registered', s.members)],
            ),
            _withRows(
              DescriptiveStatCard(
                title: 'Guards',
                description: 'Security staff profiles active in the system.',
                howCalculated: 'Count of guard records for this society.',
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF22C55E),
                value: '${s.guards}',
                onNavigate: () => _go(AdminTab.guards),
                navigateLabel: 'Open Guards',
              ),
              [('Blacklist', s.blacklist)],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_kyc.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.tint(t.warning, 0.10),
              border: Border.all(color: AppTokens.tint(t.warning, 0.30)),
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: t.warning),
                  const SizedBox(width: 8),
                  Text('Guard KYC Pending (${_kyc.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.warning)),
                ]),
                const SizedBox(height: 6),
                for (final g in _kyc)
                  InkWell(
                    onTap: () => _go(AdminTab.guards),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
                      child: Text('• ${g.name} (${g.guardId}) - Police verification overdue', style: TextStyle(fontSize: 12, color: t.warning)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(context.t('adminNav.quickAccess').toUpperCase(), style: AppText.fieldLabel(context)),
        const SizedBox(height: 2),
        Text(context.tr('Six most used modules plus your last visit', 'सबसे ज़्यादा उपयोग किए गए छह खंड और आपका पिछला खंड'), style: AppText.tiny(context)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: [
            for (final q in quick)
              Stack(
                children: [
                  Positioned.fill(
                    child: CardSection(
                      padding: const EdgeInsets.all(10),
                      onTap: () => _go(q.tab),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(q.icon, size: 20, color: t.primary),
                          const SizedBox(height: 4),
                          Text(
                            context.t(q.labelKey),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: t.mutedForeground, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (q.tab == last)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.10), borderRadius: BorderRadius.circular(4)),
                        child: Text('LAST', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: t.primary)),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// Card with the small breakdown rows the web renders as card children.
  Widget _withRows(DescriptiveStatCard card, List<(String, int)> rows) {
    return Builder(builder: (context) {
      final t = context.tokens;
      return DescriptiveStatCard(
        title: card.title,
        value: card.value,
        description: card.description,
        howCalculated: card.howCalculated,
        icon: card.icon,
        iconColor: card.iconColor,
        onNavigate: card.onNavigate,
        navigateLabel: card.navigateLabel,
        footer: Column(
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Expanded(child: Text(r.$1, style: TextStyle(fontSize: 10, color: t.mutedForeground))),
                    Text('${r.$2}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.foreground)),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _openCollectionMonthly() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BreakdownSheet<MonthTotal>(
        title: 'Total Collection — Monthly',
        icon: Icons.currency_rupee,
        hint: 'Verified payments and ledger entries grouped by transaction month',
        load: () => _service.loadCollectionByMonth(widget.ctx.societyId),
        emptyText: 'No verified payments found',
        firstColumn: 'Month',
        labelOf: (m) => formatMonthLabel(m.month),
        countOf: (m) => m.count,
        totalOf: (m) => m.total,
        warnCount: (m) => m.count > 29,
        footerLabel: 'Go to Finance',
        onFooter: () {
          Navigator.pop(ctx);
          _go(AdminTab.finance);
        },
      ),
    );
  }

  Future<void> _openExpenseBuckets() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExpenseBucketsSheet(
        load: () => _service.loadExpenseBuckets(widget.ctx.societyId),
        onGoEvents: () {
          Navigator.pop(ctx);
          _go(AdminTab.events);
        },
        onGoPayments: () {
          Navigator.pop(ctx);
          _go(AdminTab.finance, subTab: 'payments');
        },
      ),
    );
  }
}

class _BreakdownSheet<T> extends StatelessWidget {
  const _BreakdownSheet({
    required this.title,
    required this.icon,
    required this.hint,
    required this.load,
    required this.emptyText,
    required this.firstColumn,
    required this.labelOf,
    required this.countOf,
    required this.totalOf,
    required this.footerLabel,
    required this.onFooter,
    this.warnCount,
    this.onRowTap,
  });

  final String title;
  final IconData icon;
  final String hint;
  final Future<List<T>> Function() load;
  final String emptyText;
  final String firstColumn;
  final String Function(T) labelOf;
  final int Function(T) countOf;
  final double Function(T) totalOf;
  final bool Function(T)? warnCount;
  final void Function(T)? onRowTap;
  final String footerLabel;
  final VoidCallback onFooter;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: t.success),
                const SizedBox(width: 8),
                Text(title, style: AppText.sectionTitle(context)),
              ]),
              const SizedBox(height: 4),
              Text(hint, style: AppText.tiny(context)),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<List<T>>(
                  future: load(),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const LoadingView();
                    final rows = snap.data ?? const [];
                    if (rows.isEmpty) return EmptyView(message: emptyText);
                    final total = rows.fold<double>(0, (s, r) => s + totalOf(r));
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        _row(context, firstColumn.toUpperCase(), 'COUNT', 'AMOUNT', header: true),
                        for (final r in rows)
                          InkWell(
                            onTap: onRowTap == null ? null : () => onRowTap!(r),
                            child: _row(
                              context,
                              labelOf(r),
                              '${countOf(r)}${warnCount?.call(r) == true ? ' ⚠' : ''}',
                              Fmt.inr(totalOf(r)),
                              warn: warnCount?.call(r) == true,
                              chevron: onRowTap != null,
                            ),
                          ),
                        Divider(color: t.border),
                        _row(context, 'Total', '', Fmt.inr(total), bold: true),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              AppButton.secondary(label: footerLabel, onPressed: onFooter, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _row(BuildContext context, String a, String b, String c,
    {bool header = false, bool bold = false, bool warn = false, bool chevron = false}) {
  final t = context.tokens;
  final base = TextStyle(
    fontSize: header ? 10 : 12,
    fontWeight: header || bold ? FontWeight.w600 : FontWeight.w500,
    color: header ? t.mutedForeground : t.foreground,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(a, style: base, overflow: TextOverflow.ellipsis)),
        SizedBox(
          width: 56,
          child: Text(b, textAlign: TextAlign.right, style: base.copyWith(color: warn ? t.destructive : (header ? t.mutedForeground : t.mutedForeground))),
        ),
        SizedBox(
          width: 100,
          child: Text(c, textAlign: TextAlign.right, style: header ? base : AppText.mono(context, size: 12, weight: FontWeight.w600)),
        ),
        if (chevron) Icon(Icons.chevron_right, size: 14, color: t.mutedForeground) else const SizedBox(width: 14),
      ],
    ),
  );
}

class _ExpenseBucketsSheet extends StatefulWidget {
  const _ExpenseBucketsSheet({required this.load, required this.onGoEvents, required this.onGoPayments});

  final Future<List<ExpenseBucket>> Function() load;
  final VoidCallback onGoEvents;
  final VoidCallback onGoPayments;

  @override
  State<_ExpenseBucketsSheet> createState() => _ExpenseBucketsSheetState();
}

class _ExpenseBucketsSheetState extends State<_ExpenseBucketsSheet> {
  late final Future<List<ExpenseBucket>> _future = widget.load();
  ExpenseBucket? _selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sel = _selected;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                if (sel != null)
                  InkWell(onTap: () => setState(() => _selected = null), child: Icon(Icons.chevron_left, size: 18, color: t.mutedForeground))
                else
                  Icon(Icons.call_split, size: 16, color: t.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(sel?.label ?? 'Total expenses', style: AppText.sectionTitle(context), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Text(
                sel != null ? 'Monthly breakdown — tap a month or open the module below' : 'Active expenses by category — tap a row to go inside',
                style: AppText.tiny(context),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<List<ExpenseBucket>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const LoadingView();
                    final buckets = snap.data ?? const [];
                    if (buckets.isEmpty) return const EmptyView(message: 'No active expenses found');
                    if (sel != null) {
                      return ListView(shrinkWrap: true, children: [
                        _row(context, 'MONTH', 'COUNT', 'AMOUNT', header: true),
                        for (final m in sel.months)
                          InkWell(
                            onTap: sel.isEventFood ? widget.onGoEvents : widget.onGoPayments,
                            child: _row(context, formatMonthLabel(m.month), '${m.count}', Fmt.inr(m.total), chevron: true),
                          ),
                        Divider(color: t.border),
                        _row(context, 'Total', '', Fmt.inr(sel.total), bold: true),
                      ]);
                    }
                    final total = buckets.fold<double>(0, (s, b) => s + b.total);
                    return ListView(shrinkWrap: true, children: [
                      _row(context, 'CATEGORY', 'COUNT', 'AMOUNT', header: true),
                      for (final b in buckets)
                        InkWell(
                          onTap: () => setState(() => _selected = b),
                          child: _row(context, b.label, '${b.count}', Fmt.inr(b.total), chevron: true),
                        ),
                      Divider(color: t.border),
                      _row(context, 'Total', '', Fmt.inr(total), bold: true),
                    ]);
                  },
                ),
              ),
              const SizedBox(height: 8),
              AppButton.secondary(
                label: sel == null
                    ? 'Go to Finance — Payments'
                    : (sel.isEventFood ? 'Go to Events & food' : 'Go to Finance — Payments'),
                onPressed: sel != null && sel.isEventFood ? widget.onGoEvents : widget.onGoPayments,
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
