import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';

class WorkPulseLocalNotificationService {
  WorkPulseLocalNotificationService._();

  static final WorkPulseLocalNotificationService instance =
      WorkPulseLocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController<String>.broadcast();
  bool _initialized = false;
  String? _initialPayload;

  Stream<String> get taps => _taps.stream;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_workpulse'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _taps.add(payload);
        }
      },
    );
    final NotificationAppLaunchDetails? launchDetails = await _plugin
        .getNotificationAppLaunchDetails();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'workpulse_reminders',
            'WorkPulse reminders',
            description: 'Attendance and leave reminders',
            importance: Importance.high,
          ),
        );
    _initialPayload = launchDetails?.notificationResponse?.payload;
    _initialized = true;
  }

  Future<void> requestPermission() async {
    if (!_initialized || kIsWeb) {
      return;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  String? takeInitialPayload() {
    final String? payload = _initialPayload;
    _initialPayload = null;
    return payload;
  }

  Future<void> show(WorkPulseNotification notification) async {
    if (!_initialized || kIsWeb) {
      return;
    }
    final String title = notification.title.trim();
    final String message = notification.message.trim();
    if (title.isEmpty || message.isEmpty) {
      return;
    }
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'workpulse_reminders',
      'WorkPulse reminders',
      channelDescription: 'Attendance and leave reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id: notification.id.hashCode & 0x7fffffff,
      title: title,
      body: message,
      notificationDetails: const NotificationDetails(android: android),
      payload: notification.id,
    );
  }

  Future<void> showRemote({
    required String notificationId,
    required String title,
    required String message,
  }) async {
    if (!_initialized || kIsWeb) {
      return;
    }
    final String safeTitle = title.trim();
    final String safeMessage = message.trim();
    if (safeTitle.isEmpty || safeMessage.isEmpty) {
      return;
    }
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'workpulse_reminders',
      'WorkPulse reminders',
      channelDescription: 'Attendance and leave reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id: notificationId.hashCode & 0x7fffffff,
      title: safeTitle,
      body: safeMessage,
      notificationDetails: const NotificationDetails(android: android),
      payload: notificationId,
    );
  }
}
