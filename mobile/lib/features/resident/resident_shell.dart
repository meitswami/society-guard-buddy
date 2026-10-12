import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/db.dart';
import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../../services/society_sound_service.dart';
import '../home/resident_login_banners.dart';
import 'data/alert_sounds.dart';
import 'data/notification_audience.dart';
import 'data/resident_models.dart';
import 'data/resident_repository.dart';
import 'resident_external_views.dart';
import 'state/resident_controllers.dart';
import 'tabs/approvals_tab.dart';
import 'tabs/family_tab.dart';
import 'tabs/feedback_tab.dart';
import 'tabs/passes_tab.dart';
import 'tabs/payments_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/vehicles_tab.dart';
import 'widgets/mandatory_password_dialog.dart';
import 'widgets/resident_i18n.dart';

/// Resident tabs in the web `ResidentDashboard` order.
enum ResidentTab {
  approvals,
  passes,
  family,
  vehicles,
  directory,
  notifications,
  polls,
  meetings,
  documents,
  committee,
  payments,
  profile,
  tour,
  feedback;

  /// Tabs implemented in this module (kept alive like the web dashboard state).
  static const owned = [approvals, passes, family, vehicles, payments, profile, feedback];

  bool get isOwned => owned.contains(this);
}

/// Login onboarding flag (web `sessionStorage.sgb_open_family_tab`): open Family + Add.
const kOpenFamilyTabPrefKey = 'sgb_open_family_tab';

/// Whole resident area — port of web `src/pages/ResidentDashboard.tsx`.
class ResidentShell extends ConsumerStatefulWidget {
  const ResidentShell({super.key});

  @override
  ConsumerState<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends ConsumerState<ResidentShell> {
  final _sounds = ResidentAlertSounds();
  final _familyKey = GlobalKey<ResidentFamilyTabState>();
  final _vehiclesKey = GlobalKey<ResidentVehiclesTabState>();
  final Set<ResidentTab> _visited = {ResidentTab.approvals};
  ResidentTab _tab = ResidentTab.approvals;
  DateTime? _lastBack;

  SessionResident? _session;
  ResidentApprovalsController? _approvals;
  ResidentHousehold? _household;
  RealtimeChannel? _notifChannel;
  SocietySoundService? _signature;

  /// Web plays the society signature tune once per tab session.
  static final Set<String> _tunePlayed = {};

  @override
  void dispose() {
    _unbind();
    unawaited(_sounds.dispose());
    super.dispose();
  }

  void _unbind() {
    final ch = _notifChannel;
    if (ch != null) unawaited(db.removeChannel(ch));
    _notifChannel = null;
    _approvals?.dispose();
    _household?.dispose();
    _approvals = null;
    _household = null;
    final sig = _signature;
    _signature = null;
    if (sig != null) unawaited(sig.dispose());
  }

  void _bind(SessionResident s) {
    if (_session?.resident.id == s.resident.id && _session?.societyId == s.societyId) return;
    _unbind();
    _session = s;
    _tab = ResidentTab.approvals;
    _visited
      ..clear()
      ..add(ResidentTab.approvals);
    _approvals = ResidentApprovalsController(session: s, sounds: _sounds)
      ..load()
      ..subscribe();
    _household = ResidentHousehold(session: s);
    _subscribeNotifications(s);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup(s));
  }

  /// Web `useNotificationsRealtimeRevision` → toast + alert sound on any tab.
  void _subscribeNotifications(SessionResident s) {
    if (!dbReady) return;
    _notifChannel = db
        .channel('notifications-dashboard-resident-${s.resident.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final row = payload.newRecord;
            if (!notificationRowForResident(row,
                societyId: s.societyId,
                residentId: s.resident.id,
                residentName: s.resident.name,
                flatNumber: s.resident.flatNumber)) {
              return;
            }
            _showNotificationToast(row);
            unawaited(_sounds.playNotificationAlert(row['sound_key']?.toString(), row['sound_custom_url']?.toString()));
          },
        )
        .subscribe();
  }

  void _showNotificationToast(Map<String, dynamic> row) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final t = context.tokens;
    final title = (row['title'] ?? 'Alert').toString();
    var message = (row['message'] ?? '').toString();
    if (message.length > 200) message = message.substring(0, 200);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.notifications_active_outlined, size: 18, color: t.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: t.background)),
              if (message.isNotEmpty) Text(message, style: TextStyle(fontSize: 12, color: t.background)),
            ]),
          ),
        ]),
        action:
            SnackBarAction(label: context.t('resident.alerts'), onPressed: () => _select(ResidentTab.notifications)),
      ));
  }

  /// Mandatory password → banners → first-login tour → onboarding family flag
  /// (web effects order; the tour only shows when no mandatory password is pending).
  Future<void> _startup(SessionResident s) async {
    final h = _household;
    if (h == null) return;
    if (!_tunePlayed.contains(s.societyId)) {
      _tunePlayed.add(s.societyId);
      _signature = SocietySoundService();
      unawaited(_signature!.playSignatureTuneOnOpen(s.societyId, force: true).catchError((_) {}));
    }
    await h.loadAll();
    if (!mounted || _session != s) return;
    if (h.selfLogin?.mustChangePassword ?? false) {
      await showMandatoryPasswordDialog(context, s);
      await h.loadFlatmates();
      if (!mounted || _session != s) return;
    }
    await ResidentLoginBanners.maybeShow(context, s.societyId);
    if (!mounted || _session != s) return;
    try {
      await ResidentExternalViews.maybeShowFirstLoginTour(context, s);
    } catch (_) {}
    if (!mounted || _session != s) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(kOpenFamilyTabPrefKey) == '1') {
        await prefs.remove(kOpenFamilyTabPrefKey);
        if (!mounted) return;
        _select(ResidentTab.family);
        WidgetsBinding.instance.addPostFrameCallback((_) => _familyKey.currentState?.openAdd());
      }
    } catch (_) {}
  }

  void _select(ResidentTab tab) {
    if (!mounted) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  /// Profile → "Edit profile & photo" (web `setTab('family'); startEditMember(...)`).
  void _editFromProfile(HouseholdMember m) {
    _select(ResidentTab.family);
    WidgetsBinding.instance.addPostFrameCallback((_) => _familyKey.currentState?.startEdit(m));
  }

  /// Web popstate trap: back → Approvals, then double back within 2 s exits.
  void _handleBack() {
    final msg = context.rt('resident.m.pressBackAgain');
    if (_tab != ResidentTab.approvals) {
      _select(ResidentTab.approvals);
      AppFeedback.toast(context, msg, duration: const Duration(seconds: 2));
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    AppFeedback.toast(context, msg, duration: const Duration(seconds: 2));
  }

  Future<void> _logout(SessionResident s) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmLogoutUser'),
      message: context.t('swal.confirmLogoutUserText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok) return;
    unawaited(const ResidentRepository()
        .auditLogout(societyId: s.societyId, userId: s.resident.id, userName: s.resident.name));
    await ref.read(sessionProvider.notifier).logout();
  }

  Future<void> _openFlat360(SessionResident s) async {
    try {
      await ResidentExternalViews.showFlat360(context, s);
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('mobile.loadFailed'), tone: BadgeTone.alert);
    }
  }

  String _navLabel(ResidentTab tab) => switch (tab) {
        ResidentTab.approvals => context.t('resident.approvals'),
        ResidentTab.passes => context.rt('resident.m.navPasses'),
        ResidentTab.family => context.t('resident.family'),
        ResidentTab.vehicles => context.t('resident.vehicles'),
        ResidentTab.directory => context.t('resident.directory'),
        ResidentTab.notifications => context.t('resident.alerts'),
        ResidentTab.polls => context.t('resident.polls'),
        ResidentTab.meetings => context.t('resident.meetings'),
        ResidentTab.documents => context.t('resident.documents'),
        ResidentTab.committee => context.t('resident.committee'),
        ResidentTab.payments => context.t('resident.payments'),
        ResidentTab.profile => context.rt('resident.m.navProfile'),
        ResidentTab.tour => context.t('nav.tour'),
        ResidentTab.feedback => context.t('resident.feedback'),
      };

  static IconData _icon(ResidentTab tab) => switch (tab) {
        ResidentTab.approvals => Icons.notifications_outlined,
        ResidentTab.passes => Icons.key_outlined,
        ResidentTab.family => Icons.groups_outlined,
        ResidentTab.vehicles => Icons.directions_car_outlined,
        ResidentTab.directory => Icons.contacts_outlined,
        ResidentTab.notifications => Icons.notifications_active_outlined,
        ResidentTab.polls => Icons.how_to_vote_outlined,
        ResidentTab.meetings => Icons.receipt_long_outlined,
        ResidentTab.documents => Icons.folder_outlined,
        ResidentTab.committee => Icons.account_balance_outlined,
        ResidentTab.payments => Icons.currency_rupee,
        ResidentTab.profile => Icons.person_outline,
        ResidentTab.tour => Icons.auto_awesome_outlined,
        ResidentTab.feedback => Icons.chat_bubble_outline,
      };

  Widget _ownedTab(ResidentTab tab, SessionResident s) {
    if (!_visited.contains(tab)) return const SizedBox.shrink();
    final h = _household!;
    return switch (tab) {
      ResidentTab.approvals => ResidentApprovalsTab(controller: _approvals!),
      ResidentTab.passes => ResidentPassesTab(session: s),
      ResidentTab.family => ResidentFamilyTab(
          key: _familyKey,
          session: s,
          household: h,
          onChanged: () => _vehiclesKey.currentState?.reload(),
        ),
      ResidentTab.vehicles => ResidentVehiclesTab(key: _vehiclesKey, session: s),
      ResidentTab.payments => ResidentPaymentsTab(session: s),
      ResidentTab.profile => ResidentProfileTab(
          session: s,
          household: h,
          onEditMember: _editFromProfile,
          onOpenFlat360: () => _openFlat360(s),
          onLogout: () => _logout(s),
        ),
      ResidentTab.feedback => ResidentFeedbackTab(session: s),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _externalTab(ResidentTab tab, SessionResident s) => switch (tab) {
        ResidentTab.directory => ResidentExternalViews.directory(
            s,
            onOpenFamily: () => _select(ResidentTab.family),
            onOpenVehicles: () => _select(ResidentTab.vehicles),
          ),
        ResidentTab.notifications => _AlertsTab(session: s),
        ResidentTab.polls => ResidentExternalViews.polls(s),
        ResidentTab.meetings => ResidentExternalViews.meetings(s),
        ResidentTab.documents => ResidentExternalViews.documents(s),
        ResidentTab.committee => ResidentExternalViews.committee(s),
        ResidentTab.tour => ResidentExternalViews.tour(s),
        _ => const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session is! SessionResident) {
      return const Scaffold(body: LoadingView());
    }
    _bind(session);
    final t = context.tokens;
    final approvals = _approvals!;
    final ownedIndex = ResidentTab.owned.indexOf(_tab);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: t.background,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            ListenableBuilder(
              listenable: approvals,
              builder: (context, _) => _ResidentHeader(
                session: session,
                pendingCount: approvals.pendingCount,
                onLogout: () => _logout(session),
              ),
            ),
            Expanded(
              child: Stack(children: [
                Offstage(
                  offstage: !_tab.isOwned,
                  child: TickerMode(
                    enabled: _tab.isOwned,
                    child: IndexedStack(
                      index: ownedIndex < 0 ? 0 : ownedIndex,
                      children: [for (final tab in ResidentTab.owned) _ownedTab(tab, session)],
                    ),
                  ),
                ),
                if (!_tab.isOwned)
                  Positioned.fill(child: KeyedSubtree(key: ValueKey(_tab), child: _externalTab(_tab, session))),
              ]),
            ),
          ]),
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: approvals,
          builder: (context, _) => ScrollableBottomNav<ResidentTab>(
            items: [
              for (final tab in ResidentTab.values)
                NavItem(
                  id: tab,
                  label: _navLabel(tab),
                  icon: _icon(tab),
                  badge: tab == ResidentTab.approvals ? approvals.pendingCount : 0,
                ),
            ],
            active: _tab,
            onTap: _select,
          ),
        ),
      ),
    );
  }
}

/// Web header: home icon, resident name, flat (+ society), pending ping, language / theme
/// toggles, logout. Narrow phones move the toggles to a second row.
class _ResidentHeader extends StatelessWidget {
  const _ResidentHeader({required this.session, required this.pendingCount, required this.onLogout});

  final SessionResident session;
  final int pendingCount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = session.resident;
    final identity = Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration:
            BoxDecoration(color: AppTokens.tint(t.primary, 0.1), borderRadius: BorderRadius.circular(AppTokens.radius)),
        child: Icon(Icons.home_outlined, size: 20, color: t.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(r.name, style: AppText.sectionTitle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            '${context.t('common.flat')} ${r.flatNumber}${session.societyName.isEmpty ? '' : ' · ${session.societyName}'}',
            style: AppText.caption(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    ]);
    final logout = IconButton(
      tooltip: context.t('swal.confirmLogoutUser'),
      icon: Icon(Icons.logout, size: 18, color: t.mutedForeground),
      onPressed: onLogout,
    );
    final ping = pendingCount > 0
        ? const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: _PingDot())
        : const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(color: t.card, border: Border(bottom: BorderSide(color: t.border))),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 480) {
          return Row(children: [
            Expanded(child: identity),
            ping,
            const LanguageToggle(),
            const SizedBox(width: 8),
            const ThemeToggle(),
            logout,
          ]);
        }
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: identity), ping, logout]),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [LanguageToggle(), SizedBox(width: 8), ThemeToggle()]),
          ),
        ]);
      }),
    );
  }
}

/// Web `animate-ping` red dot shown while approvals are pending.
class _PingDot extends StatefulWidget {
  const _PingDot();

  @override
  State<_PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<_PingDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.destructive;
    return SizedBox(
      width: 12,
      height: 12,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(alignment: Alignment.center, children: [
          Transform.scale(
            scale: 1 + _c.value,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTokens.tint(color, 0.75 * (1 - _c.value))),
            ),
          ),
          Container(decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        ]),
      ),
    );
  }
}

/// Alerts tab — web compact `EmergencyAlertPanel` button above `NotificationCenter`.
class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.session});

  final SessionResident session;

  void _openEmergency(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(ctx.tr('Emergency / Alert mode', 'आपात / अलर्ट मोड'))),
        body: ResidentExternalViews.emergency(session),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: AppTokens.tint(t.destructive, 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius),
                side: BorderSide(color: AppTokens.tint(t.destructive, 0.5), width: 2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radius),
                onTap: () => _openEmergency(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.campaign_outlined, size: 20, color: t.destructive),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tr('Emergency or Alert — notify everyone', 'आपात या अलर्ट — सभी को सूचित करें'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: t.destructive),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      Expanded(child: ResidentExternalViews.notifications(session)),
    ]);
  }
}
