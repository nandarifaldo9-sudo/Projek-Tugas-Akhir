import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._preferences)
    : _themeMode = _readThemeMode(_preferences),
      _appLockEnabled = _preferences.getBool(_lockKey) ?? true,
      _hideBalance = _preferences.getBool(_hideBalanceKey) ?? false,
      _lockTimeoutSeconds = _readChoice(
        _preferences.getInt(_lockTimeoutKey),
        lockTimeoutOptions,
        60,
      ),
      _budgetWarnPercent = _readChoice(
        _preferences.getInt(_budgetWarnKey),
        budgetWarnOptions,
        80,
      ),
      _defaultAccountId = _preferences.getInt(_defaultAccountKey),
      _secureScreenEnabled = _preferences.getBool(_secureScreenKey) ?? false,
      _languageCode = _readLanguage(_preferences),
      _introCompleted = _preferences.getBool(_introCompletedKey) ?? false,
      _lastBackupAt = _readLastBackupAt(_preferences);

  static const _themeKey = 'theme_mode';
  static const _lockKey = 'app_lock_enabled';
  static const _hideBalanceKey = 'hide_balance';
  static const _lockTimeoutKey = 'lock_timeout_seconds';
  static const _budgetWarnKey = 'budget_warn_percent';
  static const _defaultAccountKey = 'default_account_id';
  static const _secureScreenKey = 'secure_screen_enabled';
  static const _languageKey = 'language_code';
  static const _introCompletedKey = 'intro_completed';
  static const _lastBackupKey = 'last_backup_at';
  static const lockTimeoutOptions = [30, 60, 300];
  static const budgetWarnOptions = [70, 80, 90];

  final SharedPreferences _preferences;
  ThemeMode _themeMode;
  bool _appLockEnabled;
  bool _hideBalance;
  int _lockTimeoutSeconds;
  int _budgetWarnPercent;
  int? _defaultAccountId;
  bool _secureScreenEnabled;
  String _languageCode;
  bool _introCompleted;
  DateTime? _lastBackupAt;

  ThemeMode get themeMode => _themeMode;
  bool get appLockEnabled => _appLockEnabled;
  bool get hideBalance => _hideBalance;
  int get lockTimeoutSeconds => _lockTimeoutSeconds;
  int get budgetWarnPercent => _budgetWarnPercent;
  int? get defaultAccountId => _defaultAccountId;
  bool get secureScreenEnabled => _secureScreenEnabled;
  String get languageCode => _languageCode;
  bool get introCompleted => _introCompleted;
  DateTime? get lastBackupAt => _lastBackupAt;
  Locale get locale =>
      Locale(_languageCode, _languageCode == 'id' ? 'ID' : 'US');

  static ThemeMode _readThemeMode(SharedPreferences preferences) {
    return switch (preferences.getString(_themeKey)) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  static int _readChoice(int? value, List<int> options, int fallback) {
    return value != null && options.contains(value) ? value : fallback;
  }

  static String _readLanguage(SharedPreferences preferences) {
    final value = preferences.getString(_languageKey);
    return value == 'en' ? 'en' : 'id';
  }

  static DateTime? _readLastBackupAt(SharedPreferences preferences) {
    final value = preferences.getString(_lastBackupKey);
    return value == null ? null : DateTime.tryParse(value);
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

  Future<bool> setHideBalance(bool value) async {
    final saved = await _preferences.setBool(_hideBalanceKey, value);
    if (!saved) return false;
    _hideBalance = value;
    notifyListeners();
    return true;
  }

  Future<bool> setLockTimeoutSeconds(int seconds) async {
    if (!lockTimeoutOptions.contains(seconds)) return false;
    final saved = await _preferences.setInt(_lockTimeoutKey, seconds);
    if (!saved) return false;
    _lockTimeoutSeconds = seconds;
    notifyListeners();
    return true;
  }

  Future<bool> setBudgetWarnPercent(int percent) async {
    if (!budgetWarnOptions.contains(percent)) return false;
    final saved = await _preferences.setInt(_budgetWarnKey, percent);
    if (!saved) return false;
    _budgetWarnPercent = percent;
    notifyListeners();
    return true;
  }

  Future<bool> setDefaultAccountId(int? id) async {
    final saved = id == null
        ? await _preferences.remove(_defaultAccountKey)
        : await _preferences.setInt(_defaultAccountKey, id);
    if (!saved) return false;
    _defaultAccountId = id;
    notifyListeners();
    return true;
  }

  Future<bool> setSecureScreenEnabled(bool enabled) async {
    final saved = await _preferences.setBool(_secureScreenKey, enabled);
    if (!saved) return false;
    _secureScreenEnabled = enabled;
    notifyListeners();
    return true;
  }

  Future<bool> setLanguageCode(String languageCode) async {
    if (languageCode != 'id' && languageCode != 'en') return false;
    final saved = await _preferences.setString(_languageKey, languageCode);
    if (!saved) return false;
    _languageCode = languageCode;
    Intl.defaultLocale = languageCode == 'en' ? 'en_US' : 'id_ID';
    notifyListeners();
    return true;
  }

  Future<bool> setIntroCompleted(bool completed) async {
    final saved = await _preferences.setBool(_introCompletedKey, completed);
    if (!saved) return false;
    _introCompleted = completed;
    notifyListeners();
    return true;
  }

  Future<bool> markBackupNow() async {
    final now = DateTime.now();
    final saved = await _preferences.setString(
      _lastBackupKey,
      now.toIso8601String(),
    );
    if (!saved) return false;
    _lastBackupAt = now;
    notifyListeners();
    return true;
  }
}
