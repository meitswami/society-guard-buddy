import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../gate/data/gate_store.dart';

/// Ends the guard shift after the web confirmation (`swal.confirmLogoutGuard`).
Future<void> confirmGuardLogout(BuildContext context, WidgetRef ref, SessionGuard session) async {
  final ok = await AppFeedback.confirm(
    context,
    title: context.t('swal.confirmLogoutGuard'),
    message: context.t('swal.confirmLogoutGuardText'),
    confirmLabel: context.t('swal.yes'),
    cancelLabel: context.t('swal.no'),
    destructive: true,
  );
  if (!ok) return;
  GateStore.clear(session.societyId);
  await ref.read(sessionProvider.notifier).logout(guardShiftId: session.shiftId);
}

/// Guard header from web `DashboardPage`: app name, tagline, live clock, guard code + name,
/// language toggle, theme toggle and the end-shift (logout) button.
class GuardHeader extends ConsumerStatefulWidget {
  const GuardHeader({super.key, required this.session});

  final SessionGuard session;

  @override
  ConsumerState<GuardHeader> createState() => _GuardHeaderState();
}

class _GuardHeaderState extends ConsumerState<GuardHeader> {
  late String _clock = Fmt.dateTime(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = Fmt.dateTime(DateTime.now());
      if (next != _clock && mounted) setState(() => _clock = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final g = widget.session.guard;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.t('app.name'), style: AppText.pageTitle(context)),
        const SizedBox(height: 2),
        Text(context.t('app.tagline'), style: TextStyle(fontSize: 10, color: AppTokens.tint(t.mutedForeground, 0.8))),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: t.mutedForeground),
            const SizedBox(width: 4),
            Flexible(child: Text(_clock, style: AppText.caption(context))),
          ],
        ),
      ],
    );

    final guardInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(g.guardId, style: AppText.mono(context, size: 12, color: t.primary)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(context)),
        ),
      ],
    );

    final logout = IconPillButton(
      icon: Icons.logout,
      tooltip: context.t('swal.confirmLogoutGuard'),
      onPressed: () => confirmGuardLogout(context, ref, widget.session),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 420) {
            return Row(
              children: [
                Expanded(child: title),
                guardInfo,
                const SizedBox(width: 8),
                const LanguageToggle(),
                const SizedBox(width: 8),
                const ThemeToggle(),
                const SizedBox(width: 8),
                logout,
              ],
            );
          }
          // Narrow phones: same controls, toggles on a second line so nothing overflows.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  guardInfo,
                  const SizedBox(width: 8),
                  logout,
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [LanguageToggle(), SizedBox(width: 8), ThemeToggle()],
              ),
            ],
          );
        },
      ),
    );
  }
}
