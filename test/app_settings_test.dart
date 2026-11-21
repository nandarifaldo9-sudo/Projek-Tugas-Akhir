import 'package:flutter_test/flutter_test.dart';
import 'package:projek_tugas_akhir/providers/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('app lock state is persisted before notifying listeners', () async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    var notifications = 0;
    settings.addListener(() => notifications++);

    expect(await settings.setAppLockEnabled(true), isTrue);
    expect(settings.appLockEnabled, isTrue);
    expect(preferences.getBool('app_lock_enabled'), isTrue);
    expect(notifications, 1);
    settings.dispose();
  });

  test('nilai pengaturan tidak valid kembali ke default', () async {
    SharedPreferences.setMockInitialValues({
      'budget_warn_percent': 55,
      'lock_timeout_seconds': 999,
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);

    expect(settings.budgetWarnPercent, 80);
    expect(settings.lockTimeoutSeconds, 60);
    expect(settings.hideBalance, isFalse);
    expect(settings.defaultAccountId, isNull);
    settings.dispose();
  });

  test('pengaturan baru tersimpan dan memberi tahu listener', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    var notifications = 0;
    settings.addListener(() => notifications++);

    expect(await settings.setBudgetWarnPercent(90), isTrue);
    expect(await settings.setLockTimeoutSeconds(300), isTrue);
    expect(await settings.setHideBalance(true), isTrue);
    expect(await settings.setDefaultAccountId(2), isTrue);
    expect(await settings.setBudgetWarnPercent(55), isFalse);

    expect(preferences.getInt('budget_warn_percent'), 90);
    expect(preferences.getInt('lock_timeout_seconds'), 300);
    expect(preferences.getBool('hide_balance'), isTrue);
    expect(preferences.getInt('default_account_id'), 2);
    expect(notifications, 4);

    expect(await settings.setDefaultAccountId(null), isTrue);
    expect(preferences.containsKey('default_account_id'), isFalse);
    settings.dispose();
  });

  test('bahasa, layar aman, intro, dan tanggal backup tersimpan', () async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'en',
      'secure_screen_enabled': true,
      'intro_completed': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);

    expect(settings.languageCode, 'en');
    expect(settings.locale.languageCode, 'en');
    expect(settings.secureScreenEnabled, isTrue);
    expect(settings.introCompleted, isTrue);
    expect(settings.lastBackupAt, isNull);

    expect(await settings.setLanguageCode('id'), isTrue);
    expect(await settings.setSecureScreenEnabled(false), isTrue);
    expect(await settings.setIntroCompleted(false), isTrue);
    expect(await settings.markBackupNow(), isTrue);

    expect(settings.languageCode, 'id');
    expect(settings.secureScreenEnabled, isFalse);
    expect(settings.introCompleted, isFalse);
    expect(settings.lastBackupAt, isNotNull);
    settings.dispose();
  });
}
