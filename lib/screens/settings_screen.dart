import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings.dart';
import '../theme/app_theme.dart';
import '../utils/auth_error_message.dart';
import '../widgets/app_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleLock(
    BuildContext context,
    AppSettings settings,
    bool enabled,
  ) async {
    if (enabled) {
      try {
        final authenticated = await LocalAuthentication().authenticate(
          localizedReason: 'Verifikasi untuk mengaktifkan kunci Flowly',
          biometricOnly: false,
        );
        if (!authenticated || !context.mounted) return;
      } on LocalAuthException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Autentikasi gagal: ${authErrorMessage(error)}'),
          ),
        );
        return;
      }
    }
    await settings.setAppLockEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Tampilan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          AppCard(
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
              ],
              selected: {
                settings.themeMode == ThemeMode.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
              },
              onSelectionChanged: (value) => settings.setThemeMode(value.first),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Privasi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: settings.appLockEnabled,
              onChanged: (value) => _toggleLock(context, settings, value),
              title: const Text('Kunci aplikasi'),
              subtitle: const Text(
                'Gunakan biometrik atau kunci layar perangkat. '
                'Aplikasi terkunci kembali setelah 1 menit di latar belakang.',
              ),
              activeTrackColor: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}
