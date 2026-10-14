import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../widgets/sa_widgets.dart';

/// What every Superadmin tab needs from the shell.
class SuperadminTabContext {
  const SuperadminTabContext({required this.session, required this.onLogout});

  final SessionSuperadmin session;
  final VoidCallback onLogout;
}

/// Tab body: web page container with the dashboard header (and the society select
/// on tabs where the selection matters), then the tab content.
class SuperadminTabPage extends StatelessWidget {
  const SuperadminTabPage({
    super.key,
    required this.ctx,
    required this.children,
    this.showSocietySelector = false,
    this.onRefresh,
  });

  final SuperadminTabContext ctx;
  final List<Widget> children;
  final bool showSocietySelector;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      onRefresh: onRefresh,
      children: [
        SuperadminHeader(
            name: ctx.session.name, onLogout: ctx.onLogout, bottomSpacing: 24),
        if (showSocietySelector) const SocietySelector(),
        ...children,
      ],
    );
  }
}

/// Web tab heading row (`font-semibold` title + optional action buttons).
class SaTabTitle extends StatelessWidget {
  const SaTabTitle(this.title, {super.key, this.icon, this.actions = const []});

  final String title;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: t.primary),
            const SizedBox(width: 8)
          ],
          Expanded(
              child: Text(title,
                  style: AppText.sectionTitle(context).copyWith(fontSize: 16))),
          ...actions,
        ],
      ),
    );
  }
}

/// Web `p-2 rounded-lg bg-primary/10 text-primary` icon button.
class SaTintButton extends StatelessWidget {
  const SaTintButton(
      {super.key,
      required this.icon,
      required this.onPressed,
      this.tooltip,
      this.color});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    return IconPillButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        color: c,
        background: AppTokens.tint(c, 0.10));
  }
}
