import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/notifications/data/device_token_service.dart';
import 'package:pulseclock/features/notifications/data/local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> workPulseFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}

class WorkPulsePushService {
  WorkPulsePushService._();

  static final WorkPulsePushService instance = WorkPulsePushService._();

  final StreamController<String> _taps = StreamController<String>.broadcast();
  final StreamController<void> _updates = StreamController<void>.broadcast();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  DeviceTokenService? _deviceTokens;
  bool _initialized = false;
  bool _configured = false;
  bool _activating = false;
  String? _activeUserId;
  String? _registeredToken;
  String? _initialNotificationId;

  Stream<String> get taps => _taps.stream;
  Stream<void> get updates => _updates.stream;
  bool get isConfigured => _configured;

  Future<void> initialize() async {
    if (_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _initialized = true;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        workPulseFirebaseMessagingBackgroundHandler,
      );
      _configured = true;
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      _initialNotificationId = _notificationIdFor(initialMessage);
    } catch (error, stackTrace) {
      _configured = false;
      developer.log(
        'Firebase Messaging is not configured. Add android/app/google-services.json to enable push notifications.',
        name: 'workpulse.push',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> activateForUser(String userId) async {
    if (!_configured || !SupabaseBootstrap.isInitialized) {
      return;
    }
    if (_activeUserId == userId &&
        (_registeredToken != null || _activating)) {
      return;
    }
    _activeUserId = userId;
    _activating = true;
    _deviceTokens ??= DeviceTokenService();

    try {
      await FirebaseMessaging.instance.requestPermission();
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (String refreshedToken) => _registerToken(refreshedToken),
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'Unable to refresh the Firebase device token',
            name: 'workpulse.push',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Unable to register this device for WorkPulse push notifications',
        name: 'workpulse.push',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _activating = false;
    }
  }

  Future<void> deactivate() async {
    final String? token = _registeredToken;
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _activeUserId = null;
    _activating = false;
    _registeredToken = null;
    if (token == null ||
        !SupabaseBootstrap.isInitialized ||
        SupabaseBootstrap.client.auth.currentUser == null) {
      return;
    }
    try {
      _deviceTokens ??= DeviceTokenService();
      await _deviceTokens!.unregisterToken(token);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to deactivate the WorkPulse device token during logout',
        name: 'workpulse.push',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String? takeInitialNotificationId() {
    final String? value = _initialNotificationId;
    _initialNotificationId = null;
    return value;
  }

  Future<void> _registerToken(String token) async {
    if (_activeUserId == null) {
      return;
    }
    await _deviceTokens!.registerAndroidToken(token);
    _registeredToken = token;
  }

  Future<void> _handleForegroundMessage(RemoteMessage remote) async {
    final String? notificationId = _notificationIdFor(remote);
    if (notificationId == null) {
      developer.log(
        'Ignoring a push message without a WorkPulse notification ID',
        name: 'workpulse.push',
      );
      return;
    }
    final String title =
        remote.notification?.title ?? remote.data['title'] ?? 'WorkPulse';
    final String message =
        remote.notification?.body ?? remote.data['message'] ?? '';
    if (title.trim().isEmpty || message.trim().isEmpty) {
      developer.log(
        'Ignoring an incomplete WorkPulse push notification',
        name: 'workpulse.push',
      );
      return;
    }
    await WorkPulseLocalNotificationService.instance.showRemote(
      notificationId: notificationId,
      title: title,
      message: message,
    );
    _updates.add(null);
  }

  void _handleOpenedMessage(RemoteMessage remote) {
    final String? id = _notificationIdFor(remote);
    if (id != null) {
      _taps.add(id);
    }
    _updates.add(null);
  }

  String? _notificationIdFor(RemoteMessage? remote) {
    if (remote == null) {
      return null;
    }
    final String? id = remote.data['notification_id'];
    return id == null || id.isEmpty ? null : id;
  }
}
