import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_settings.dart';
import 'providers/finance_provider.dart';
import 'screens/main_shell.dart';
import 'screens/intro_screen.dart';
import 'services/screen_security.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('en_US');
  final preferences = await SharedPreferences.getInstance();
  final languageCode = preferences.getString('language_code') ?? 'id';
  Intl.defaultLocale = languageCode == 'en' ? 'en_US' : 'id_ID';
  await ScreenSecurity.setEnabled(
    preferences.getBool('secure_screen_enabled') ?? false,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings(preferences)),
        ChangeNotifierProxyProvider<AppSettings, FinanceProvider>(
          create: (_) => FinanceProvider()..load(),
          update: (_, settings, finance) => finance!
            ..applySettings(
              budgetWarnPercent: settings.budgetWarnPercent,
              defaultAccountId: settings.defaultAccountId,
            ),
        ),
      ],
      child: const FlowlyApp(),
    ),
  );
}

class FlowlyApp extends StatelessWidget {
  const FlowlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return MaterialApp(
      title: 'Flowly',
      locale: settings.locale,
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      themeAnimationDuration: Duration.zero,
      home: settings.introCompleted
          ? const AppLockGate(child: MainShell())
          : IntroScreen(
              onComplete: () async {
                await settings.setIntroCompleted(true);
              },
            ),
    );
  }
}
