import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../shared/widgets/biometric_enrollment_prompt.dart';
import 'core/admin_module.dart';
import 'core/admin_module_registry.dart';
import 'core/admin_navigation.dart';
import 'overview/admin_overview_module.dart';

/// Admin panel — port of `AdminDashboard.tsx` layout: floating top actions
/// (language, global search, display size), slide-out module drawer from the left
/// edge, module body, and the 4-tab bottom nav (Home, Audit, Finance, Reports).
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  AdminTab _tab = AdminTab.overview;
  String? _query;
  String? _subTab;
  /// Bumps when the same module is re-opened with a new query / sub-tab so it rebuilds fresh.
  int _visit = 0;
  bool _drawerOpen = false;
  DateTime? _lastBack;

  void _goTo(AdminTab tab, {String? query, String? subTab}) {
    final session = ref.read(sessionProvider).value;
    if (session is! SessionAdmin) return;
    // Web: `splits` is part of Events / Finance record-payment; keep its own module here.
    if (!isAdminTabAllowed(tab, session.admin.permissions)) tab = AdminTab.overview;
    AdminTabUsage.record(session.societyId, tab);
    setState(() {
      _tab = tab;
      _query = query;
      _subTab = subTab;
      _visit++;
      _drawerOpen = false;
    });
  }

  Future<void> _logout() async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmLogoutUser'),
      message: context.t('swal.confirmLogoutUserText'),
    );
    if (ok) await ref.read(sessionProvider.notifier).logout();
  }

  void _onBack() {
    if (_drawerOpen) {
      setState(() => _drawerOpen = false);
      return;
    }
    if (_tab != AdminTab.overview) {
      _goTo(AdminTab.overview);
      AppFeedback.toast(context, context.tr('Press back again to exit', 'बाहर जाने के लिए फिर से बैक दबाएँ'));
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    AppFeedback.toast(context, context.tr('Press back again to exit', 'बाहर जाने के लिए फिर से बैक दबाएँ'));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session is! SessionAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = context.tokens;
    final perms = session.admin.permissions;
    final visible = kAdminTabs.where((d) => isAdminTabAllowed(d.tab, perms)).toList();
    final bottom = [
      for (final id in kAdminBottomNavTabs)
        ...visible.where((d) => d.tab == id),
    ];
    final drawerTabs = visible.where((d) => !kAdminBottomNavTabs.contains(d.tab)).toList();
    final ctx = AdminModuleContext(session: session, goTo: _goTo, initialQuery: _query, subTab: _subTab);

    final body = _tab == AdminTab.overview
        ? AdminOverviewModule(key: ValueKey('overview-$_visit'), ctx: ctx, onLogout: _logout, visibleTabs: visible)
        : KeyedSubtree(key: ValueKey('${_tab.name}-$_visit'), child: buildAdminModule(_tab, ctx));

    return BiometricEnrollmentPrompt(
      session: session,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Room for the floating actions, like the web `pt-[max(2.75rem,…)]`.
                Padding(padding: const EdgeInsets.only(top: 40), child: body),
                Positioned(
                  top: 6,
                  right: 12,
                  child: Row(
                    children: [
                      const LanguageToggle(),
                      const SizedBox(width: 6),
                      IconPillButton(
                        icon: Icons.search,
                        tooltip: context.t('adminNav.search'),
                        color: t.primaryForeground,
                        background: t.primary,
                        onPressed: () => _openSearch(visible),
                      ),
                      const SizedBox(width: 6),
                      IconPillButton(icon: Icons.desktop_windows_outlined, tooltip: 'Display size', onPressed: _showDisplaySize),
                    ],
                  ),
                ),
                if (drawerTabs.isNotEmpty) ...[
                  if (_drawerOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _drawerOpen = false),
                        child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _ModuleDrawer(
                      open: _drawerOpen,
                      tabs: drawerTabs,
                      active: _tab,
                      onToggle: () => setState(() => _drawerOpen = !_drawerOpen),
                      onSelect: (tab) => _goTo(tab),
                    ),
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: ScrollableBottomNav<AdminTab>(
            items: [for (final d in bottom) NavItem(id: d.tab, label: context.t(d.labelKey), icon: d.icon)],
            active: _tab,
            onTap: (tab) => _goTo(tab),
          ),
        ),
      ),
    );
  }

  Future<void> _openSearch(List<AdminTabDef> visible) async {
    final allowed = {for (final d in visible) d.tab};
    final picked = await showModalBottomSheet<(AdminTab, String)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GlobalSearchSheet(allowed: allowed),
    );
    if (picked != null) _goTo(picked.$1, query: picked.$2);
  }

  void _showDisplaySize() {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final px = size * mq.devicePixelRatio;
    AppFeedback.info(
      context,
      title: 'Display size',
      description: 'Viewport: ${size.width.round()} × ${size.height.round()} dp\n'
          'Screen: ${px.width.round()} × ${px.height.round()} px\n'
          'Pixel ratio: ${mq.devicePixelRatio.toStringAsFixed(2)}\n'
          'Orientation: ${size.width >= size.height ? 'Landscape' : 'Portrait'}',
    );
  }
}

/// Web `AdminModuleDrawer`: slim primary edge tab; tap to slide the module list out.
class _ModuleDrawer extends StatefulWidget {
  const _ModuleDrawer({required this.open, required this.tabs, required this.active, required this.onToggle, required this.onSelect});

  final bool open;
  final List<AdminTabDef> tabs;
  final AdminTab active;
  final VoidCallback onToggle;
  final ValueChanged<AdminTab> onSelect;

  @override
  State<_ModuleDrawer> createState() => _ModuleDrawerState();
}

class _ModuleDrawerState extends State<_ModuleDrawer> {
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.open ? 256 : 0,
          decoration: BoxDecoration(
            color: t.card,
            border: Border(right: BorderSide(color: t.border)),
            boxShadow: widget.open ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16)] : null,
          ),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 256,
              maxWidth: 256,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t('adminNav.allModules').toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: t.primary),
                          ),
                        ),
                        SegmentedPills<bool>(
                          options: const [false, true],
                          value: _grid,
                          onChanged: (v) => setState(() => _grid = v),
                          labelOf: (v) => v ? '▦' : '☰',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: t.border),
                  Expanded(
                    child: _grid
                        ? GridView.count(
                            crossAxisCount: 2,
                            padding: const EdgeInsets.all(8),
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1.5,
                            children: [for (final d in widget.tabs) _gridItem(context, d)],
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            children: [for (final d in widget.tabs) _listItem(context, d)],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: widget.open ? t.primary : AppTokens.tint(t.primary, 0.55),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
            ),
            child: Center(
              child: AnimatedRotation(
                turns: widget.open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.chevron_right, size: 16, color: t.primaryForeground),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listItem(BuildContext context, AdminTabDef d) {
    final t = context.tokens;
    final active = d.tab == widget.active;
    return Material(
      color: active ? AppTokens.tint(t.primary, 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: () => widget.onSelect(d.tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(d.icon, size: 18, color: active ? t.primary : t.mutedForeground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t(d.labelKey),
                  style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? t.primary : t.foreground),
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: t.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridItem(BuildContext context, AdminTabDef d) {
    final t = context.tokens;
    final active = d.tab == widget.active;
    return Material(
      color: active ? AppTokens.tint(t.primary, 0.15) : AppTokens.tint(t.muted, 0.6),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: () => widget.onSelect(d.tab),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(d.icon, size: 20, color: active ? t.primary : t.mutedForeground),
            const SizedBox(height: 4),
            Text(
              context.t(d.labelKey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: active ? t.primary : t.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web `AdminGlobalSearch`: type a query, pick the module to search in.
class _GlobalSearchSheet extends StatefulWidget {
  const _GlobalSearchSheet({required this.allowed});

  final Set<AdminTab> allowed;

  @override
  State<_GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<_GlobalSearchSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final q = _ctrl.text;
    final matches = searchRoutesForQuery(q, widget.allowed);
    final all = kAdminSearchRoutes.where((r) => widget.allowed.contains(r.tab)).toList();
    final list = q.trim().isEmpty ? all : matches;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.t('adminNav.search'), style: AppText.sectionTitle(context)),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) {
                    if (matches.isNotEmpty) Navigator.pop(context, (matches.first.tab, v.trim()));
                  },
                  decoration: InputDecoration(prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground), hintText: context.t('mobile.search')),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: list.isEmpty
                      ? EmptyView(message: context.tr('No matching module', 'कोई मिलता-जुलता खंड नहीं'))
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final r in list)
                              ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                leading: Icon(Icons.manage_search, color: t.primary),
                                title: Text(context.t(r.labelKey)),
                                subtitle: Text(r.hint),
                                trailing: Icon(Icons.chevron_right, color: t.mutedForeground),
                                onTap: () => Navigator.pop(context, (r.tab, q.trim())),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
