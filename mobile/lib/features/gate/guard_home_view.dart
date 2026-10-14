import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../guard/guard_header.dart';
import 'data/gate_logic.dart';
import 'data/gate_models.dart';
import 'data/gate_store.dart';
import 'data/guard_duty_service.dart';
import 'gate_i18n.dart';
import 'widgets/biometric_setup_card.dart';

/// Guard home dashboard — web `src/pages/DashboardPage.tsx`: header, Today / Yesterday / older
/// day switcher, four descriptive stat cards that filter the list, 3+ visit alerts, the
/// latest entries (tap an entry inside to mark its exit) and the biometric setup card.
class GuardHomeView extends StatefulWidget {
  const GuardHomeView({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardHomeView> createState() => _GuardHomeViewState();
}

class _GuardHomeViewState extends State<GuardHomeView> {
  late final GateStore _store = GateStore.of(widget.session.societyId);
  int _dayOffset = 0;
  DashboardFilter _filter = DashboardFilter.all;
  String? _guardDbId;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded().then((_) => _store.refreshVisitorsIfStale());
    _resolveGuardDbId();
  }

  Future<void> _resolveGuardDbId() async {
    try {
      final id = await const GuardDutyService().resolveGuardUuid(
          widget.session.guard.guardId, widget.session.societyId);
      if (mounted) setState(() => _guardDbId = id);
    } catch (_) {}
  }

  void _toggleFilter(DashboardFilter f) =>
      setState(() => _filter = toggleDashboardFilter(_filter, f));

  Future<void> _markExit(GateVisitor v) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.gt('gate.markExitTitle'),
      message: context.gt('gate.markExitText', {'name': v.name}),
      confirmLabel: context.gt('gate.markExitConfirm'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    try {
      await _store.markExit(v.id);
      if (!mounted) return;
      await AppFeedback.success(context,
          title: context.gt('gate.exitRecorded'),
          message: context.gt('gate.exitRecordedText', {'name': v.name}));
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.gt('gate.exitFailed'),
            tone: BadgeTone.alert);
      }
    }
  }

  String _filterLabel(DashboardFilter f) => switch (f) {
        DashboardFilter.visitor => context.t('dashboard.visitors'),
        DashboardFilter.vehicle => context.t('dashboard.vehicles'),
        DashboardFilter.delivery => context.t('dashboard.deliveries'),
        DashboardFilter.inside => context.t('dashboard.insideNow'),
        DashboardFilter.all => context.t('dashboard.all'),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final t = context.tokens;
        final now = DateTime.now();
        final day =
            visitorsOnDay(_store.visitors, dayIsoForOffset(now, _dayOffset));
        final stats = dashboardStats(day);
        final entries = filterDashboardEntries(day, _filter);
        final alerts = repeatVisitAlerts(day);
        final loading = !_store.visitorsLoaded;
        final failed = _store.visitorsError != null && _store.visitors.isEmpty;

        return PageContainer(
          onRefresh: () =>
              Future.wait([_store.loadVisitors(), _store.loadBlacklist()]),
          children: [
            GuardHeader(session: widget.session),
            _DaySwitcher(
              offset: _dayOffset,
              onChanged: (o) => setState(() => _dayOffset = o),
            ),
            if (_dayOffset > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  Fmt.date(DateTime(now.year, now.month, now.day - _dayOffset)),
                  textAlign: TextAlign.center,
                  style: AppText.caption(context),
                ),
              ),
            StatGrid(
              children: [
                DescriptiveStatCard(
                  title: context.t('dashboard.visitors'),
                  caption: context.t('dashboard.visitors'),
                  description: context.gt('gate.stat.visitors.desc'),
                  howCalculated: context.gt('gate.stat.visitors.how'),
                  icon: Icons.people_outline,
                  value: '${stats.totalVisitors}',
                  onNavigate: () => _toggleFilter(DashboardFilter.visitor),
                  navigateLabel: context.gt('gate.filterList'),
                  highlighted: _filter == DashboardFilter.visitor,
                ),
                DescriptiveStatCard(
                  title: context.t('dashboard.vehicles'),
                  caption: context.t('dashboard.vehicles'),
                  description: context.gt('gate.stat.vehicles.desc'),
                  howCalculated: context.gt('gate.stat.vehicles.how'),
                  icon: Icons.directions_car_outlined,
                  value: '${stats.totalVehicles}',
                  onNavigate: () => _toggleFilter(DashboardFilter.vehicle),
                  navigateLabel: context.gt('gate.filterList'),
                  highlighted: _filter == DashboardFilter.vehicle,
                ),
                DescriptiveStatCard(
                  title: context.t('dashboard.deliveries'),
                  caption: context.t('dashboard.deliveries'),
                  description: context.gt('gate.stat.deliveries.desc'),
                  howCalculated: context.gt('gate.stat.deliveries.how'),
                  icon: Icons.local_shipping_outlined,
                  value: '${stats.totalDeliveries}',
                  onNavigate: () => _toggleFilter(DashboardFilter.delivery),
                  navigateLabel: context.gt('gate.filterList'),
                  highlighted: _filter == DashboardFilter.delivery,
                ),
                DescriptiveStatCard(
                  title: context.t('dashboard.insideNow'),
                  caption: context.t('dashboard.insideNow'),
                  description: context.gt('gate.stat.inside.desc'),
                  howCalculated: context.gt('gate.stat.inside.how'),
                  icon: Icons.login,
                  iconColor: t.primary,
                  valueColor: t.primary,
                  borderColor: AppTokens.tint(t.primary, 0.3),
                  value: '${stats.currentlyInside}',
                  onNavigate: () => _toggleFilter(DashboardFilter.inside),
                  navigateLabel: context.gt('gate.filterList'),
                  highlighted: _filter == DashboardFilter.inside,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_filter != DashboardFilter.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_filterLabel(_filter)} (${entries.length})',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: t.primary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _filter = DashboardFilter.all),
                      child: Text(
                        context.t('dashboard.all'),
                        style: TextStyle(
                          fontSize: 10,
                          color: t.mutedForeground,
                          decoration: TextDecoration.underline,
                          decorationColor: t.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (alerts.isNotEmpty && _filter == DashboardFilter.all) ...[
              SectionTitle(context.t('dashboard.alerts'),
                  icon: Icons.gpp_maybe_outlined, iconColor: t.destructive),
              for (final a in alerts)
                CardSection(
                  margin: const EdgeInsets.only(bottom: 8),
                  borderColor: AppTokens.tint(t.destructive, 0.3),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: AppTokens.tint(t.destructive, 0.2),
                            shape: BoxShape.circle),
                        child: Icon(Icons.gpp_maybe_outlined,
                            size: 16, color: t.destructive),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, style: AppText.bodyMedium(context)),
                            Text.rich(
                              TextSpan(
                                style: AppText.caption(context),
                                children: [
                                  TextSpan(
                                      text:
                                          '${a.phone} — ${context.t('dashboard.enteredXToday')} '),
                                  TextSpan(
                                    text: '${a.count}x',
                                    style: TextStyle(
                                        color: t.destructive,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                      text: ' ${context.t('dashboard.today')}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
            if (_filter == DashboardFilter.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(context.t('dashboard.recentEntries'),
                    style: AppText.sectionTitle(context)),
              ),
            if (loading)
              const LoadingView()
            else if (failed)
              ErrorView(onRetry: _store.loadVisitors)
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  context.t('dashboard.noEntries'),
                  textAlign: TextAlign.center,
                  style:
                      AppText.body(context).copyWith(color: t.mutedForeground),
                ),
              )
            else
              for (final v in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EntryCard(
                      visitor: v,
                      onExit: v.isInside ? () => _markExit(v) : null),
                ),
            if (_guardDbId != null) ...[
              const SizedBox(height: 16),
              BiometricSetupCard(
                  session: widget.session,
                  role: 'guard',
                  userDbId: _guardDbId!),
            ],
          ],
        );
      },
    );
  }
}

class _DaySwitcher extends StatelessWidget {
  const _DaySwitcher({required this.offset, required this.onChanged});

  final int offset;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconPillButton(
              icon: Icons.chevron_left,
              onPressed: () => onChanged(olderDayOffset(offset))),
          const SizedBox(width: 12),
          PillChoice(
              label: context.t('dashboard.todayLabel'),
              selected: offset == 0,
              onTap: () => onChanged(0)),
          const SizedBox(width: 6),
          PillChoice(
              label: context.t('dashboard.yesterday'),
              selected: offset == 1,
              onTap: () => onChanged(1)),
          const SizedBox(width: 12),
          IconPillButton(
              icon: Icons.chevron_right,
              onPressed: () => onChanged(newerDayOffset(offset))),
        ],
      ),
    );
  }
}

String gateCategoryLabel(BuildContext context, String category) =>
    switch (category) {
      'visitor' => context.t('blacklist.visitor'),
      'delivery' => context.t('delivery.tab.delivery'),
      'service' => context.t('delivery.tab.service'),
      _ => category,
    };

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.visitor, this.onExit});

  final GateVisitor visitor;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = visitor;
    final parts = <String>[
      '${context.t('common.flat')} ${v.flatNumber}',
      gateCategoryLabel(context, v.category),
      Fmt.time(v.entryAt),
      if (v.hasVehicle) v.vehicleNumber!,
    ];
    return CardSection(
      onTap: onExit,
      child: Row(
        children: [
          if (v.isInside)
            const PulseDot()
          else
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: t.mutedForeground, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMedium(context)),
                Text(parts.join(' · '), style: AppText.caption(context)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (v.isInside)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTokens.tint(t.primary, 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.door_front_door_outlined,
                      size: 12, color: t.primary),
                  const SizedBox(width: 4),
                  Text(context.gt('gate.exitBadge'),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: t.primary)),
                ],
              ),
            )
          else
            Text(Fmt.time(v.exitAt), style: AppText.tiny(context)),
        ],
      ),
    );
  }
}

/// Green "inside" dot with the Tailwind `animate-pulse` fade.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.size = 8});

  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 1, end: 0.5)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
            color: context.tokens.success, shape: BoxShape.circle),
      ),
    );
  }
}
