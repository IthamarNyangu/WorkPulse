import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/location/workpulse_location_service.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/features/notifications/data/local_notification_service.dart';
import 'package:pulseclock/features/notifications/data/workpulse_notification_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';

class WorkPulseReminderController extends ChangeNotifier {
  WorkPulseReminderController._();

  static final WorkPulseReminderController instance =
      WorkPulseReminderController._();

  static const ReminderConfig config = ReminderConfig(
    workdayStartHour: 8,
    clockOutReminderHour: 17,
    missedPunchBufferMinutes: 30,
  );
  //static const Duration followUpDelay = Duration(minutes: 30);
  static const Duration followUpDelay = Duration(minutes: 2);
  static const Duration _monitorInterval = Duration(seconds: 30);
  static const Duration _attendanceRefreshInterval = Duration(minutes: 1);
  static const double _exitBufferMeters = 35;

  AttendanceService? _attendanceService;
  final WorkPulseLocationService _locationService = WorkPulseLocationService();
  WorkPulseNotificationService? _notificationService;
  final WorkPulseLocalNotificationService _localNotifications =
      WorkPulseLocalNotificationService.instance;

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
  DateTime? _clockInReminderAt;
  DateTime? _exitReminderAt;
  String? _exitOfficeName;

  List<WorkPulseNotification> get notifications =>
      List<WorkPulseNotification>.unmodifiable(_notifications);
  int get unreadCount =>
      _notifications.where((WorkPulseNotification item) => !item.isRead).length;
  bool get isStarted => _started;

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
    await _localNotifications.initialize();
    await _localNotifications.requestPermission();
    await refresh();
    await _refreshAttendance(force: true);
    await _createPastAttendanceReminder();
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
    _clockInReminderAt = null;
    _exitReminderAt = null;
    _exitOfficeName = null;
  }

  Future<void> refresh({bool showNewLocally = false}) async {
    if (!SupabaseBootstrap.isInitialized || _activeUserId == null) {
      return;
    }
    try {
      final Set<String> existingIds = _notifications
          .map((WorkPulseNotification item) => item.id)
          .toSet();
      final List<WorkPulseNotification> refreshed = await _notificationService!
          .fetchNotifications();
      _notifications = refreshed;
      _lastNotificationRefresh = DateTime.now();
      _restoreReminderTimes();
      notifyListeners();
      if (showNewLocally) {
        for (final WorkPulseNotification item in refreshed.reversed) {
          if (!item.isRead && !existingIds.contains(item.id)) {
            await _localNotifications.show(item);
          }
        }
      }
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
      }
    }
    if (_todayAttendance?.clockInAt != null) {
      await _notificationService!.resolveWhere(
        types: const <WorkPulseNotificationType>[
          WorkPulseNotificationType.clockInReminder,
        ],
      );
      _clockInReminderAt = null;
    }
    if (_todayAttendance?.clockOutAt != null) {
      await _notificationService!.resolveWhere(
        types: const <WorkPulseNotificationType>[
          WorkPulseNotificationType.clockOutReminder,
        ],
      );
      _exitReminderAt = null;
    }
    await refresh();
  }

  Future<void> _runTick() async {
    if (_tickRunning || !_started || _activeUserId == null) {
      return;
    }
    _tickRunning = true;
    try {
      await _refreshAttendance();
      await _refreshRemoteNotificationsIfDue();
      final WorkPulseLocationResult result = await _locationService
          .captureCurrentLocation();
      await _evaluateLocation(result);
      await _evaluateTimeReminders();
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
    await refresh(showNewLocally: true);
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
        _exitReminderAt != null ||
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
      if (_candidateInsideSamples >= 2 && _insideOfficeId != officeId) {
        _insideOfficeId = officeId;
        _insideOfficeName =
            snapshot.verifiedOfficeName ?? snapshot.nearestOfficeName;
        await _createClockInReminder();
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
    _outsideSamples = 0;
    if (_isClockedIn) {
      _exitReminderAt = DateTime.now();
      _exitOfficeName = officeName;
      await _createNotification(
        eventKey: 'office_exit:${_todayKey()}:$officeId',
        type: WorkPulseNotificationType.clockOutReminder,
        title: 'Clock Out Reminder',
        message: 'You left $officeName while still clocked in. Clock out now?',
        actionLabel: 'Clock Out',
        target: NotificationNavigationTarget.clockOutConfirmation,
        officeLocationId: officeId,
      );
    }
  }

  Future<void> _createClockInReminder() async {
    final DateTime now = DateTime.now();
    if (_todayAttendance?.clockInAt != null ||
        now.hour < config.workdayStartHour ||
        _insideOfficeId == null) {
      return;
    }
    _clockInReminderAt = now;
    final String officeName = _insideOfficeName ?? 'an approved office';
    await _createNotification(
      eventKey: 'clock_in:${_todayKey()}:$_insideOfficeId',
      type: WorkPulseNotificationType.clockInReminder,
      title: 'Clock In Reminder',
      message: 'You are at $officeName. Clock in to start your day.',
      actionLabel: 'Clock In',
      target: NotificationNavigationTarget.clockInConfirmation,
      officeLocationId: _insideOfficeId,
    );
  }

  Future<void> _evaluateTimeReminders() async {
    final DateTime now = DateTime.now();
    if (_isClockedIn &&
        now.hour >= config.clockOutReminderHour &&
        _exitReminderAt == null) {
      await _createNotification(
        eventKey: 'late_clock_out:${_todayKey()}',
        type: WorkPulseNotificationType.clockOutReminder,
        title: 'Clock Out Reminder',
        message: 'You are still clocked in. Did you forget to clock out?',
        actionLabel: 'Clock Out',
        target: NotificationNavigationTarget.clockOutConfirmation,
      );
    }

    if (_todayAttendance?.clockInAt == null &&
        _clockInReminderAt != null &&
        now.difference(_clockInReminderAt!) >= followUpDelay) {
      final String officeName = _insideOfficeName ?? 'the office';
      await _createNotification(
        eventKey: 'clock_in_follow_up:${_todayKey()}',
        type: WorkPulseNotificationType.clockInReminder,
        title: 'Clock In Still Pending',
        message: 'You arrived at $officeName 30 minutes ago. Please clock in.',
        actionLabel: 'Clock In',
        target: NotificationNavigationTarget.clockInConfirmation,
        officeLocationId: _insideOfficeId,
      );
    }

    if (_isClockedIn &&
        _exitReminderAt != null &&
        now.difference(_exitReminderAt!) >= followUpDelay) {
      final String officeName = _exitOfficeName ?? 'the office';
      await _createNotification(
        eventKey: 'office_exit_follow_up:${_todayKey()}',
        type: WorkPulseNotificationType.clockOutReminder,
        title: 'Clock Out Still Pending',
        message: 'You left $officeName 30 minutes ago. Please clock out.',
        actionLabel: 'Clock Out',
        target: NotificationNavigationTarget.clockOutConfirmation,
      );
    }
  }

  Future<void> _createPastAttendanceReminder() async {
    try {
      final List<AttendanceRecord> records = await _attendanceService!
          .fetchHistoryRecords();
      final DateTime today = DateTime.now();
      final DateTime yesterday = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 1));
      AttendanceRecord? record;
      for (final AttendanceRecord candidate in records) {
        if (candidate.date.year == yesterday.year &&
            candidate.date.month == yesterday.month &&
            candidate.date.day == yesterday.day &&
            (candidate.status == AttendanceRecordStatus.missedPunch ||
                candidate.status == AttendanceRecordStatus.absent)) {
          record = candidate;
          break;
        }
      }
      if (record == null) {
        return;
      }
      await _createNotification(
        eventKey: 'attendance_attention:${_dateKey(record.date)}',
        type: WorkPulseNotificationType.missedPunchReminder,
        title: 'Attendance Needs Attention',
        message: "Yesterday's attendance is incomplete. Submit a correction.",
        actionLabel: 'Request Correction',
        target: NotificationNavigationTarget.correctionList,
        attendanceRecordId: record.id,
      );
    } catch (error) {
      developer.log(
        'Unable to create past attendance reminder',
        name: 'workpulse.reminders',
        error: error,
      );
    }
  }

  Future<void> _createNotification({
    required String eventKey,
    required WorkPulseNotificationType type,
    required String title,
    required String message,
    required String actionLabel,
    required NotificationNavigationTarget target,
    String? attendanceRecordId,
    String? officeLocationId,
  }) async {
    final WorkPulseNotification? created = await _notificationService!
        .ensureNotification(
          eventKey: eventKey,
          type: type,
          title: title,
          message: message,
          occurredAt: DateTime.now(),
          actionLabel: actionLabel,
          navigationTarget: target,
          attendanceRecordId: attendanceRecordId,
          officeLocationId: officeLocationId,
        );
    if (created == null) {
      return;
    }
    _notifications = <WorkPulseNotification>[created, ..._notifications];
    notifyListeners();
    await _localNotifications.show(created);
  }

  void _restoreReminderTimes() {
    for (final WorkPulseNotification item in _notifications) {
      if (item.eventKey?.startsWith('clock_in:${_todayKey()}:') ?? false) {
        _clockInReminderAt ??= item.timestamp;
      }
      if (item.eventKey?.startsWith('office_exit:${_todayKey()}:') ?? false) {
        _exitReminderAt ??= item.timestamp;
      }
    }
  }

  bool get _isClockedIn =>
      _todayAttendance?.clockInAt != null &&
      _todayAttendance?.clockOutAt == null;

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
