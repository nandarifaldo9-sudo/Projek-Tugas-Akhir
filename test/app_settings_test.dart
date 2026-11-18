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
}
