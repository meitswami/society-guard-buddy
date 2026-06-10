import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.residentName,
    required this.societyName,
    this.notificationCount = 0,
    this.onNotificationsTap,
  });

  final String residentName;
  final String societyName;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName {
    final parts = residentName.trim().split(' ');
    return parts.isEmpty ? residentName : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LogoMark(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kutumbika',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: KutumbikaColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '— parivaar jaisi society —',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KutumbikaColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onNotificationsTap,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, size: 26),
                  if (notificationCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: KutumbikaColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '$_greeting, $_firstName! 👋',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: KutumbikaColors.textSecondary,
            ),
            children: [
              const TextSpan(text: 'Welcome to '),
              TextSpan(
                text: societyName,
                style: const TextStyle(
                  color: KutumbikaColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: KutumbikaColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.home_rounded,
          color: KutumbikaColors.primary,
          size: 26,
        ),
      ),
    );
  }
}
