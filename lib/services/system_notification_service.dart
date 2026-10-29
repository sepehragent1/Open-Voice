import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

class SystemNotificationService {
  final FlutterLocalNotificationsPlugin _androidNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (Platform.isWindows) {
      await windowManager.ensureInitialized();
      await localNotifier.setup(appName: 'Open Voice');
      _initialized = true;
      return;
    }
    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _androidNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (_) {},
    );
    final androidPlugin = _androidNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> show({required String title, required String body}) async {
    if (!_initialized) {
      throw StateError('System notifications have not been initialized.');
    }

    if (Platform.isWindows) {
      final notification = LocalNotification(title: title, body: body);
      notification.onClick = () async {
        try {
          if (await windowManager.isMinimized()) {
            await windowManager.restore();
          }
          await windowManager.show();
          await windowManager.focus();
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'Open Voice notifications',
              context: ErrorDescription(
                'while bringing the app forward from a Windows notification',
              ),
            ),
          );
        }
      };
      notification.show();
      return;
    }
    if (!Platform.isAndroid) return;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'open_voice_room_events',
        'Room events',
        channelDescription: 'Join request and room status notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _androidNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      notificationDetails,
    );
  }

  static void reportInitializationError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Open Voice notifications',
        context: ErrorDescription('while initializing system notifications'),
      ),
    );
  }
}
