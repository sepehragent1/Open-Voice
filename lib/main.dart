import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'services/app_settings.dart';
import 'services/signaling_service.dart';
import 'services/sound_effects_service.dart';
import 'services/system_notification_service.dart';
import 'route_observer.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final soundEffects = SoundEffectsService();
  final notifications = SystemNotificationService();
  try {
    await notifications.initialize();
  } catch (error, stackTrace) {
    SystemNotificationService.reportInitializationError(error, stackTrace);
  }
  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: Provider<SystemNotificationService>.value(
        value: notifications,
        child: Provider<SoundEffectsService>(
          create: (_) => soundEffects,
          dispose: (_, soundEffects) => unawaited(soundEffects.dispose()),
          child: Builder(
            builder: (context) => ChangeNotifierProvider(
              create: (_) => SignalingService(
                soundEffects: context.read<SoundEffectsService>(),
                notifications: context.read<SystemNotificationService>(),
                appSettings: context.read<AppSettings>(),
              ),
              child: const OpenVoiceApp(),
            ),
          ),
        ),
      ),
    ),
  );
}

class OpenVoiceApp extends StatelessWidget {
  const OpenVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF536DFE),
      brightness: Brightness.light,
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF536DFE),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Open Voice',
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings.themeMode,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      navigatorObservers: [appRouteObserver],
      home: const HomeScreen(),
    );
  }
}
