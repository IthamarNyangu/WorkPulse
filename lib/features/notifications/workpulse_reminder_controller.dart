import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/location/workpulse_location_service.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/features/notifications/data/local_notification_service.dart';
import 'package:pulseclock/features/notifications/data/background_geofence_service.dart';
import 'package:pulseclock/features/notifications/data/notification_preferences_service.dart';
import 'package:pulseclock/features/notifications/data/workpulse_notification_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';

class WorkPulseReminderController extends ChangeNotifier {
  WorkPulseReminderController._();

  static final WorkPulseReminderController instance =
      WorkPulseReminderController._();

  static const Duration _monitorInterval = Duration(seconds: 30);
  static const Duration _attendanceRefreshInterval = Duration(minutes: 1);
  static const double _exitBufferMeters = 35;

  AttendanceService? _attendanceService;
  final WorkPulseLocationService _locationService = WorkPulseLocationService();
  WorkPulseNotificationService? _notificationService;
  final WorkPulseLocalNotificationService _localNotifications =
      WorkPulseLocalNotificationService.instance;
  BackgroundGeofenceService? _backgroundGeofences;
  NotificationPreferencesService? _preferencesService;

  List<WorkPulseNotification> _notifications = const <WorkPulseNotification>[];
  Timer? _monitorTimer;
  String? _activeUserId;
  SupabaseAttendanceRecord? _todayAttendance;
  DateTime? _lastAttendanceRefresh;
  DateTime? _lastNotificationRefresh;
  bool _tickRunning = false;
  bool _started = false;
  String? _insideOfficeId;
  String? _insideOfficeName;
  String? _candidateOfficeId;
  int _candidateInsideSamples = 0;
  int _outsideSamples = 0;
  bool _presenceSynced = false;
  bool _backgroundLocationReady = false;
  bool _backgroundLocationPermissionRequired = false;
  int _registeredBackgroundOffices = 0;
  NotificationPreferences _preferences = const NotificationPreferences();

  List<WorkPulseNotification> get notifications =>
      List<WorkPulseNotification>.unmodifiable(_notifications);
  int get unreadCount =>
      _notifications.where((WorkPulseNotification item) => !item.isRead).length;
  bool get isStarted => _started;
  bool get backgroundLocationReady => _backgroundLocationReady;
  bool get backgroundLocationPermissionRequired =>
      _backgroundLocationPermissionRequired;
  int get registeredBackgroundOffices => _registeredBackgroundOffices;
  NotificationPreferences get preferences => _preferences;

  Future<void> start(WorkPulseUserProfile profile) async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }
    if (_activeUserId == profile.id && _started) {
      return;
    }
    stop();
    _activeUserId = profile.id;
    _started = true;
    _attendanceService ??= AttendanceService();
    _notificationService ??= WorkPulseNotificationService();
    _backgroundGeofences ??= BackgroundGeofenceService();
    _preferencesService ??= NotificationPreferencesService();
    await _localNotifications.initialize();
    await _localNotifications.requestPermission();
    await refresh();
    await _refreshAttendance(force: true);
    await _configureBackgroundGeofences(profile);
    await _runTick();
    _monitorTimer = Timer.periodic(_monitorInterval, (_) => _runTick());
  }

  void stop() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _started = false;
    _activeUserId = null;
    _notifications = const <WorkPulseNotification>[];
    _todayAttendance = null;
    _lastAttendanceRefresh = null;
    _lastNotificationRefresh = null;
    _insideOfficeId = null;
    _insideOfficeName = null;
    _candidateOfficeId = null;
    _candidateInsideSamples = 0;
    _outsideSamples = 0;
    _presenceSynced = false;
    _backgroundLocationReady = false;
    _backgroundLocationPermissionRequired = false;
    _registeredBackgroundOffices = 0;
    _preferences = const NotificationPreferences();
  }

  Future<void> refresh() async {
    if (!SupabaseBootstrap.isInitialized || _activeUserId == null) {
      return;
    }
    try {
      final List<WorkPulseNotification> refreshed = await _notificationService!
          .fetchNotifications();
      _notifications = refreshed;
      _lastNotificationRefresh = DateTime.now();
      notifyListeners();
    } catch (error) {
      developer.log(
        'Unable to refresh notifications',
        name: 'workpulse.reminders',
        error: error,
      );
    }
  }

  Future<void> markRead(String id) async {
    await _notificationService!.markRead(id);
    _notifications = _notifications
        .map(
          (WorkPulseNotification item) =>
              item.id == id ? item.copyWith(isRead: true) : item,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _notificationService!.clearAll();
    _notifications = const <WorkPulseNotification>[];
    notifyListeners();
  }

  Future<void> onAttendanceChanged({
    ClockLocationSnapshot? actionLocation,
  }) async {
    await _refreshAttendance(force: true);
    if (_isClockedIn &&
        actionLocation?.status == ClockLocationStatus.insideOffice) {
      final String? officeId =
          actionLocation?.verifiedOfficeLocationId ??
          actionLocation?.nearestOfficeLocationId;
      if (officeId != null) {
        _insideOfficeId = officeId;
        _insideOfficeName =
            actionLocation?.verifiedOfficeName ??
            actionLocation?.nearestOfficeName;
        _candidateOfficeId = officeId;
        _candidateInsideSamples = 2;
        _outsideSamples = 0;
        await _recordLocationPresence(
          isInsideOffice: true,
          officeLocationId: officeId,
        );
        _presenceSynced = true;
      }
    }
    if (_todayAttendance?.clockInAt != null) {
      await _notificationService!.resolveWhere(
        types: const <WorkPulseNotificationType>[
          WorkPulseNotificationType.clockInReminder,
        ],
      );
    }
    if (_todayAttendance?.clockOutAt != null) {
      await _notificationService!.resolveWhere(
        types: const <WorkPulseNotificationType>[
          WorkPulseNotificationType.clockOutReminder,
        ],
      );
    }
    await refresh();
    final WorkPulseUserProfile? profile = await AuthService()
        .fetchCurrentProfile();
    if (profile != null) {
      await _configureBackgroundGeofences(profile);
    }
  }

  Future<void> openBackgroundLocationSettings() async {
    await _backgroundGeofences?.openLocationSettings();
  }

  Future<void> refreshBackgroundGeofences() async {
    final WorkPulseUserProfile? profile = await AuthService()
        .fetchCurrentProfile();
    if (profile != null) {
      await _refreshAttendance(force: true);
      await _configureBackgroundGeofences(profile);
    }
  }

  Future<void> refreshPreferences() async {
    if (_activeUserId == null) {
      return;
    }
    _preferencesService ??= NotificationPreferencesService();
    _preferences = await _preferencesService!.fetch();
    notifyListeners();
  }

  Future<void> _configureBackgroundGeofences(
    WorkPulseUserProfile profile,
  ) async {
    try {
      _backgroundGeofences ??= BackgroundGeofenceService();
      _preferencesService ??= NotificationPreferencesService();
      _preferences = await _preferencesService!.fetch();
      final BackgroundGeofenceConfiguration configuration =
          await _backgroundGeofences!.configure(
            profile: profile,
            todayAttendance: _todayAttendance,
            enabled: _preferences.smartLocationEnabled,
          );
      if (_preferences.smartLocationEnabled) {
        await _backgroundGeofences!.synchronizePendingEvents();
        final BackgroundGeofencePermission permission =
            await _backgroundGeofences!.permissionState();
        _backgroundLocationReady = permission.isReady;
        _backgroundLocationPermissionRequired =
            configuration.permissionRequired || !permission.isReady;
      } else {
        _backgroundLocationReady = false;
        _backgroundLocationPermissionRequired = false;
      }
      _registeredBackgroundOffices = configuration.registeredOffices;
      await refresh();
      notifyListeners();
    } catch (error) {
      developer.log(
        'Unable to configure background office reminders',
        name: 'workpulse.geofencing',
        error: error,
      );
    }
  }

  Future<void> _runTick() async {
    if (_tickRunning || !_started || _activeUserId == null) {
      return;
    }
    _tickRunning = true;
    try {
      await _refreshAttendance();
      await _refreshRemoteNotificationsIfDue();
      if (!_preferences.smartLocationEnabled) {
        return;
      }
      final WorkPulseLocationResult result = await _locationService
          .captureCurrentLocation();
      await _evaluateLocation(result);
    } catch (error) {
      developer.log(
        'Reminder monitor tick failed',
        name: 'workpulse.reminders',
        error: error,
      );
    } finally {
      _tickRunning = false;
    }
  }

  Future<void> _refreshRemoteNotificationsIfDue() async {
    final DateTime now = DateTime.now();
    if (_lastNotificationRefresh != null &&
        now.difference(_lastNotificationRefresh!) <
            const Duration(minutes: 1)) {
      return;
    }
    await refresh();
  }

  Future<void> _refreshAttendance({bool force = false}) async {
    final DateTime now = DateTime.now();
    if (!force &&
        _lastAttendanceRefresh != null &&
        now.difference(_lastAttendanceRefresh!) < _attendanceRefreshInterval) {
      return;
    }
    _todayAttendance = await _attendanceService!.fetchTodaysAttendance();
    _lastAttendanceRefresh = now;
    _restoreClockInOfficeFromAttendance();
  }

  void _restoreClockInOfficeFromAttendance() {
    final SupabaseAttendanceRecord? attendance = _todayAttendance;
    if (!_isClockedIn ||
        _insideOfficeId != null ||
        attendance?.clockInLocationStatus !=
            ClockLocationStatus.insideOffice.dbValue ||
        attendance?.clockInVerifiedOfficeLocationId == null) {
      return;
    }

    final String officeId = attendance!.clockInVerifiedOfficeLocationId!;
    _insideOfficeId = officeId;
    _candidateOfficeId = officeId;
    _candidateInsideSamples = 2;
    _outsideSamples = 0;
  }

  Future<void> _evaluateLocation(WorkPulseLocationResult result) async {
    final ClockLocationSnapshot? snapshot = result.snapshot;
    if (snapshot == null ||
        snapshot.status == ClockLocationStatus.lowAccuracy ||
        snapshot.status == ClockLocationStatus.locationUnavailable ||
        snapshot.status == ClockLocationStatus.noOfficesConfigured) {
      return;
    }

    final String? nearestId = snapshot.nearestOfficeLocationId;
    if (_insideOfficeName == null && nearestId == _insideOfficeId) {
      _insideOfficeName =
          snapshot.verifiedOfficeName ?? snapshot.nearestOfficeName;
    }
    final bool withinExitBuffer =
        _insideOfficeId != null &&
        nearestId == _insideOfficeId &&
        snapshot.distanceMeters != null &&
        snapshot.geofenceRadiusMeters != null &&
        snapshot.distanceMeters! <=
            snapshot.geofenceRadiusMeters! + _exitBufferMeters;
    final bool inside =
        snapshot.status == ClockLocationStatus.insideOffice || withinExitBuffer;

    if (inside) {
      final String? officeId = snapshot.verifiedOfficeLocationId ?? nearestId;
      if (officeId == null) {
        return;
      }
      _outsideSamples = 0;
      if (_candidateOfficeId == officeId) {
        _candidateInsideSamples++;
      } else {
        _candidateOfficeId = officeId;
        _candidateInsideSamples = 1;
      }
      if (_candidateInsideSamples >= 2 &&
          (_insideOfficeId != officeId || !_presenceSynced)) {
        _insideOfficeId = officeId;
        _insideOfficeName =
            snapshot.verifiedOfficeName ?? snapshot.nearestOfficeName;
        await _recordLocationPresence(
          isInsideOffice: true,
          officeLocationId: officeId,
        );
        _presenceSynced = true;
      }
      return;
    }

    _candidateOfficeId = null;
    _candidateInsideSamples = 0;
    if (_insideOfficeId == null) {
      return;
    }
    _outsideSamples++;
    if (_outsideSamples < 2) {
      return;
    }
    final String officeId = _insideOfficeId!;
    final String officeName = _insideOfficeName ?? 'the office';
    _insideOfficeId = null;
    _insideOfficeName = null;
    _presenceSynced = false;
    _outsideSamples = 0;
    if (_isClockedIn) {
      await _recordLocationPresence(
        isInsideOffice: false,
        officeLocationId: officeId,
      );
      developer.log(
        'Recorded confirmed exit from $officeName',
        name: 'workpulse.reminders',
      );
    }
  }

  Future<void> _recordLocationPresence({
    required bool isInsideOffice,
    required String officeLocationId,
  }) async {
    try {
      await _notificationService!.recordLocationPresence(
        isInsideOffice: isInsideOffice,
        officeLocationId: officeLocationId,
      );
    } catch (error) {
      developer.log(
        'Unable to record the confirmed office transition',
        name: 'workpulse.reminders',
        error: error,
      );
    }
  }

  bool get _isClockedIn =>
      _todayAttendance?.clockInAt != null &&
      _todayAttendance?.clockOutAt == null;

}
