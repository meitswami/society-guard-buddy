import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preferences shared with the web app's localStorage keys
/// (`gate-theme`, `app-lang`, `entry-caps-mode`).
abstract final class AppPrefKeys {
  static const theme = 'gate-theme';
  static const lang = 'app-lang';
  static const entryCaps = 'entry-caps-mode';
}

/// Loaded once in `main()` so the first frame already has the right theme / language.
class AppPrefs {
  AppPrefs._(this._prefs);

  final SharedPreferences _prefs;
  static AppPrefs? _instance;

  static Future<AppPrefs> init() async {
    _instance ??= AppPrefs._(await SharedPreferences.getInstance());
    return _instance!;
  }

  static AppPrefs get instance {
    final i = _instance;
    if (i == null) throw StateError('AppPrefs.init() must run before use');
    return i;
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
}

ThemeMode _parseTheme(String? raw) => switch (raw) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

String _themeKey(ThemeMode m) => switch (m) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _parseTheme(AppPrefs.instance.getString(AppPrefKeys.theme));

  void set(ThemeMode mode) {
    state = mode;
    AppPrefs.instance.setString(AppPrefKeys.theme, _themeKey(mode));
  }
}

/// Light / dark / system — default `system`, like the web app.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class EntryCapsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final raw = AppPrefs.instance.getString(AppPrefKeys.entryCaps);
    return raw == null || raw == 'on';
  }

  void set(bool on) {
    state = on;
    AppPrefs.instance.setString(AppPrefKeys.entryCaps, on ? 'on' : 'off');
  }
}

/// "CAPS entry" mode from web Settings: text typed into entry forms is upper-cased.
final entryCapsProvider = NotifierProvider<EntryCapsNotifier, bool>(EntryCapsNotifier.new);
