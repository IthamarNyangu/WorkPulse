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
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'workpulse_reminders',
      'WorkPulse reminders',
      channelDescription: 'Attendance and leave reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id: notification.id.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.message,
      notificationDetails: const NotificationDetails(android: android),
      payload: notification.id,
    );
  }
}
