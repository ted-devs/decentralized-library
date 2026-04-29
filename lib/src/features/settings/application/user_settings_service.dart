import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userSettingsServiceProvider = Provider((ref) => UserSettingsService());

class UserSettingsService {
  static const _themeKey = 'theme_mode';

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themeKey);
    if (name == null) return ThemeMode.system;
    
    return ThemeMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ThemeMode.system,
    );
  }
}

/// A Notifier to manage the theme mode with persistent storage.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // We return a default immediately, and load the real value asynchronously.
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final mode = await ref.read(userSettingsServiceProvider).getThemeMode();
    state = mode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(userSettingsServiceProvider).setThemeMode(mode);
  }

  Future<void> toggleTheme(Brightness currentBrightness) async {
    // If system mode is active, resolve to the opposite of what's currently shown
    final next = currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}
