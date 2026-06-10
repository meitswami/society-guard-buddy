import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_colors.dart';

enum HomeNavTab { home, directory, bookings, more }

class KutumbikaBottomNav extends StatelessWidget {
  const KutumbikaBottomNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onCenterTap,
  });

  final HomeNavTab selected;
  final ValueChanged<HomeNavTab> onSelected;
  final VoidCallback? onCenterTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: KutumbikaColors.surface,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavItem(
                  label: 'Home',
                  icon: Icons.home_rounded,
                  selected: selected == HomeNavTab.home,
                  onTap: () => onSelected(HomeNavTab.home),
                ),
                _NavItem(
                  label: 'Directory',
                  icon: Icons.people_outline_rounded,
                  selected: selected == HomeNavTab.directory,
                  onTap: () => onSelected(HomeNavTab.directory),
                ),
                const Expanded(child: SizedBox()),
                _NavItem(
                  label: 'Bookings',
                  icon: Icons.calendar_month_outlined,
                  selected: selected == HomeNavTab.bookings,
                  onTap: () => onSelected(HomeNavTab.bookings),
                ),
                _NavItem(
                  label: 'More',
                  icon: Icons.more_horiz_rounded,
                  selected: selected == HomeNavTab.more,
                  onTap: () => onSelected(HomeNavTab.more),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: FloatingActionButton(
              onPressed: onCenterTap,
              elevation: 4,
              child: const Icon(Icons.add, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? KutumbikaColors.primary : KutumbikaColors.navInactive;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
