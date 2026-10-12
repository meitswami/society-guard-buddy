import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/i18n.dart';
import '../prefs/app_prefs.dart';
import '../theme/app_tokens.dart';

class NavItem<T> {
  const NavItem({required this.id, required this.label, required this.icon, this.badge = 0});

  final T id;
  final String label;
  final IconData icon;
  final int badge;
}

/// Web `BottomNav`: horizontally scrollable tab bar with arrow hints when it overflows,
/// active tab in primary, and the copyright footer line underneath.
class ScrollableBottomNav<T> extends StatefulWidget {
  const ScrollableBottomNav({super.key, required this.items, required this.active, required this.onTap, this.showFooter = true});

  final List<NavItem<T>> items;
  final T active;
  final ValueChanged<T> onTap;
  final bool showFooter;

  @override
  State<ScrollableBottomNav<T>> createState() => _ScrollableBottomNavState<T>();
}

class _ScrollableBottomNavState<T> extends State<ScrollableBottomNav<T>> {
  final _scroll = ScrollController();
  bool _left = false;
  bool _right = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _update() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final left = p.pixels > 8;
    final right = p.pixels < p.maxScrollExtent - 8;
    if (left != _left || right != _right) setState(() { _left = left; _right = right; });
  }

  void _step(int dir) {
    if (!_scroll.hasClients) return;
    final w = _scroll.position.viewportDimension;
    _scroll.animateTo(
      (_scroll.offset + dir * (w * 0.45).clamp(120, 400)).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Material(
      color: t.card,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset - 4 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 60,
              child: LayoutBuilder(
                builder: (context, c) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _update());
                  final minItem = 68.0;
                  final itemWidth = (c.maxWidth / widget.items.length).clamp(minItem, 140.0);
                  return Stack(
                    children: [
                      ListView(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        children: [
                          for (final item in widget.items)
                            SizedBox(width: itemWidth, child: _NavButton(item: item, active: item.id == widget.active, onTap: () => widget.onTap(item.id))),
                        ],
                      ),
                      if (_left) Positioned(left: 0, top: 14, child: _Arrow(icon: Icons.chevron_left, onTap: () => _step(-1))),
                      if (_right) Positioned(right: 0, top: 14, child: _Arrow(icon: Icons.chevron_right, onTap: () => _step(1))),
                    ],
                  );
                },
              ),
            ),
            if (widget.showFooter)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(context.t('app.footer'), style: TextStyle(fontSize: 8, color: t.mutedForeground)),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton<T> extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final NavItem<T> item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? t.primary : t.mutedForeground;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge(
            isLabelVisible: item.badge > 0,
            label: Text(item.badge > 99 ? '99+' : '${item.badge}'),
            backgroundColor: t.destructive,
            child: Icon(item.icon, size: 20, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.1, color: color),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: AppTokens.tint(t.card, 0.95),
      shape: CircleBorder(side: BorderSide(color: t.border)),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 22, color: t.foreground)),
      ),
    );
  }
}

/// Web `LanguageToggle` (हिंदी | English segmented control).
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final lang = ref.watch(languageProvider);
    Widget opt(AppLang l, String label) {
      final active = lang == l;
      return GestureDetector(
        onTap: () => ref.read(languageProvider.notifier).set(l),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: active ? t.primary : Colors.transparent, borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? t.primaryForeground : t.secondaryForeground),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: t.secondary, borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [opt(AppLang.hi, 'हिंदी'), opt(AppLang.en, 'English')]),
    );
  }
}

/// Web `ThemeToggle` (sun / monitor / moon).
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final mode = ref.watch(themeModeProvider);
    Widget opt(ThemeMode m, IconData icon) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).set(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: active ? t.primary : Colors.transparent, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: active ? t.primaryForeground : t.mutedForeground),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: t.secondary, borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          opt(ThemeMode.light, Icons.light_mode_outlined),
          opt(ThemeMode.system, Icons.desktop_windows_outlined),
          opt(ThemeMode.dark, Icons.dark_mode_outlined),
        ],
      ),
    );
  }
}
