import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../config/env.dart';
import '../prefs/app_prefs.dart';
import '../supabase/supabase_bootstrap.dart';
import 'extra_strings.dart';

/// UI language. Hindi is the default, as on the web app.
enum AppLang { en, hi }

AppLang _parseLang(String? raw) => raw == 'en' ? AppLang.en : AppLang.hi;

/// Static strings: `assets/i18n/translations.json` is generated from the web app's
/// `src/i18n/translations.ts` (`node mobile/tool/sync_translations.mjs`), plus
/// mobile-only keys from `extra_strings.dart`.
abstract final class TranslationsStore {
  static Map<String, Map<String, String>> _strings = const {};

  static Future<void> load() async {
    final merged = <String, Map<String, String>>{};
    try {
      final raw = await rootBundle.loadString('assets/i18n/translations.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        final row = value as Map<String, dynamic>;
        merged[key] = {'en': (row['en'] ?? '') as String, 'hi': (row['hi'] ?? '') as String};
      });
    } catch (_) {
      // Missing asset only in broken builds; keys then render as-is.
    }
    kExtraStrings.forEach((key, row) => merged.putIfAbsent(key, () => row));
    _strings = merged;
  }

  static Map<String, String>? row(String key) => _strings[key];
}

/// Replace `{name}` placeholders (same rule as web `applyVars`).
String applyVars(String template, Map<String, Object?>? vars) {
  if (vars == null || vars.isEmpty) return template;
  return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
    final v = vars[m.group(1)];
    return v == null ? m.group(0)! : '$v';
  });
}

/// Resolves keys the same way as the web `LanguageContext.t`:
/// society override (current lang) → static (current lang) → English → Hindi → key.
class Translator {
  const Translator(this.lang, [this.overrides = const {}]);

  final AppLang lang;
  final Map<String, Map<String, String>> overrides;

  bool get isHindi => lang == AppLang.hi;

  String t(String key, [Map<String, Object?>? vars]) {
    final l = lang.name;
    String? pick(Map<String, String>? row, String code) {
      final v = row?[code]?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final override = overrides[key];
    final stat = TranslationsStore.row(key);
    final raw = pick(override, l) ??
        pick(stat, l) ??
        (l != 'en' ? pick(override, 'en') ?? pick(stat, 'en') : null) ??
        (l != 'hi' ? pick(override, 'hi') ?? pick(stat, 'hi') : null) ??
        key;
    return applyVars(raw, vars);
  }

  /// Inline bilingual text for strings that have no key: `tr.pick('Save', 'सहेजें')`.
  String pick(String en, String hi) => lang == AppLang.hi ? hi : en;
}

class LanguageNotifier extends Notifier<AppLang> {
  @override
  AppLang build() => _parseLang(AppPrefs.instance.getString(AppPrefKeys.lang));

  void set(AppLang lang) {
    state = lang;
    AppPrefs.instance.setString(AppPrefKeys.lang, lang.name);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLang>(LanguageNotifier.new);

/// Society whose `society_content_translations` overrides apply (the logged-in society).
final contentSocietyIdProvider = Provider<String?>((ref) {
  final s = ref.watch(sessionProvider).value;
  return switch (s) {
    SessionResident(:final societyId) => societyId,
    SessionGuard(:final societyId) => societyId,
    SessionAdmin(:final societyId) => societyId,
    _ => null,
  };
});

/// Society-specific copy edited by admins (web `SocietyContentEditor`).
final contentOverridesProvider = FutureProvider<Map<String, Map<String, String>>>((ref) async {
  final sid = ref.watch(contentSocietyIdProvider);
  if (sid == null || !Env.isConfigured) return const {};
  try {
    final rows = await SupabaseBootstrap.client
        .from('society_content_translations')
        .select('content_key, text_en, text_hi')
        .eq('society_id', sid);
    final out = <String, Map<String, String>>{};
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      out[m['content_key'] as String] = {
        'en': (m['text_en'] as String?) ?? '',
        'hi': (m['text_hi'] as String?) ?? '',
      };
    }
    return out;
  } catch (_) {
    return const {};
  }
});

final translatorProvider = Provider<Translator>((ref) {
  final lang = ref.watch(languageProvider);
  final overrides = ref.watch(contentOverridesProvider).valueOrNull ?? const {};
  return Translator(lang, overrides);
});

/// Makes the translator reachable from any `BuildContext` below `MaterialApp`.
class I18nScope extends InheritedWidget {
  const I18nScope({super.key, required this.translator, required super.child});

  final Translator translator;

  static Translator of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<I18nScope>();
    return scope?.translator ?? const Translator(AppLang.hi);
  }

  @override
  bool updateShouldNotify(I18nScope oldWidget) =>
      oldWidget.translator.lang != translator.lang || !identical(oldWidget.translator.overrides, translator.overrides);
}

extension I18nContextX on BuildContext {
  /// `context.t('visitor.title')` — same keys as the web app.
  String t(String key, [Map<String, Object?>? vars]) => I18nScope.of(this).t(key, vars);

  /// Inline bilingual copy: `context.tr('Save', 'सहेजें')`.
  String tr(String en, String hi) => I18nScope.of(this).pick(en, hi);

  AppLang get lang => I18nScope.of(this).lang;
}
