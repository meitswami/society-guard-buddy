import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_prefs.dart';
import '../../../core/ui/ui.dart';

/// Settings → Appearance (web `SettingsPage`): theme, language and the CAPS-entry switch.
class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(entryCapsProvider);
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('settings.appearance'),
              style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: Text(context.t('settings.theme'),
                      style: AppText.caption(context))),
              const ThemeToggle(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: Text(context.t('settings.language'),
                      style: AppText.caption(context))),
              const LanguageToggle(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('settings.autoCaps'),
                        style: AppText.caption(context)),
                    const SizedBox(height: 2),
                    Text(context.t('settings.autoCapsHint'),
                        style: AppText.tiny(context).copyWith(
                            color: AppTokens.tint(
                                context.tokens.mutedForeground, 0.8))),
                  ],
                ),
              ),
              Switch(
                  value: caps,
                  onChanged: (v) =>
                      ref.read(entryCapsProvider.notifier).set(v)),
            ],
          ),
        ],
      ),
    );
  }
}
