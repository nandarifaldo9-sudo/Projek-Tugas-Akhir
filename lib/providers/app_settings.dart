import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._preferences)
    : _themeMode = _readThemeMode(_preferences),
      _appLockEnabled = _preferences.getBool(_lockKey) ?? true;

  static const _themeKey = 'theme_mode';
  static const _lockKey = 'app_lock_enabled';

  final SharedPreferences _preferences;
  ThemeMode _themeMode;
  bool _appLockEnabled;

  ThemeMode get themeMode => _themeMode;
  bool get appLockEnabled => _appLockEnabled;

  static ThemeMode _readThemeMode(SharedPreferences preferences) {
    return switch (preferences.getString(_themeKey)) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _preferences.setString(_themeKey, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    });
    notifyListeners();
  }

  Future<bool> setAppLockEnabled(bool enabled) async {
    final saved = await _preferences.setBool(_lockKey, enabled);
    if (!saved) return false;
    _appLockEnabled = enabled;
    notifyListeners();
    return true;
  }
}
