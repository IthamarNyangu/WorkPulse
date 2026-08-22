import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackgroundGeofencePermission {
  const BackgroundGeofencePermission({
    required this.hasForeground,
    required this.hasBackground,
  });

  final bool hasForeground;
  final bool hasBackground;

  bool get isReady => hasForeground && hasBackground;
}

class BackgroundGeofenceConfiguration {
  const BackgroundGeofenceConfiguration({
    required this.registeredOffices,
    required this.permissionRequired,
  });

  final int registeredOffices;
  final bool permissionRequired;
}

class BackgroundGeofenceService {
  BackgroundGeofenceService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const MethodChannel _channel = MethodChannel(
    'workpulse/geofencing',
  );
  static const int _eligibilityWindowDays = 45;

  final SupabaseClient _client;

  bool get isSupported => Platform.isAndroid;

  Future<BackgroundGeofencePermission> permissionState() async {
    if (!isSupported) {
      return const BackgroundGeofencePermission(
        hasForeground: true,
        hasBackground: true,
      );
    }
    final Map<dynamic, dynamic>? result = await _channel
        .invokeMapMethod<dynamic, dynamic>('permissionState');
    return BackgroundGeofencePermission(
      hasForeground: result?['foreground'] == true,
      hasBackground: result?['background'] == true,
    );
  }

  Future<void> openLocationSettings() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('openLocationSettings');
    }
  }

  Future<BackgroundGeofenceConfiguration> configure({
    required WorkPulseUserProfile profile,
    required SupabaseAttendanceRecord? todayAttendance,
    required bool enabled,
  }) async {
    if (!isSupported) {
      return const BackgroundGeofenceConfiguration(
        registeredOffices: 0,
        permissionRequired: false,
      );
    }

    if (!enabled) {
      await clear();
      return const BackgroundGeofenceConfiguration(
        registeredOffices: 0,
        permissionRequired: false,
      );
    }

    final List<dynamic> values = await Future.wait<dynamic>(<Future<dynamic>>[
      OfficeLocationService(client: _client).fetchActiveOffices(),
      _eligibleWindows(profile.id),
    ]);
    final List<OfficeLocation> offices = values[0] as List<OfficeLocation>;
    final List<Map<String, dynamic>> eligibleWindows =
        values[1] as List<Map<String, dynamic>>;
    final String? clockedInDate = todayAttendance?.clockInAt == null
        ? null
        : _dateLabel(todayAttendance!.clockInAt!.toLocal());

    final Map<dynamic, dynamic>? result = await _channel
        .invokeMapMethod<dynamic, dynamic>('configure', <String, dynamic>{
          'offices': offices
              .map(
                (OfficeLocation office) => <String, dynamic>{
                  'id': office.id,
                  'officeName': office.officeName,
                  'latitude': office.latitude,
                  'longitude': office.longitude,
                  'radiusMeters': office.radiusMeters,
                },
              )
              .toList(growable: false),
          'eligibleWindows': eligibleWindows,
          'clockedInDate': clockedInDate,
          'userId': profile.id,
          'enabled': enabled,
        });
    return BackgroundGeofenceConfiguration(
      registeredOffices: (result?['registered'] as num?)?.toInt() ?? 0,
      permissionRequired: result?['permissionRequired'] == true,
    );
  }

  Future<int> synchronizePendingEvents() async {
    if (!isSupported) {
      return 0;
    }
    final List<dynamic>? events = await _channel.invokeListMethod<dynamic>(
      'drainEvents',
    );
    int synchronized = 0;
    for (final dynamic rawEvent in events ?? const <dynamic>[]) {
      final Map<String, dynamic> event = Map<String, dynamic>.from(
        rawEvent as Map,
      );
      try {
        await _client.rpc(
          'record_my_geofence_reminder',
          params: <String, dynamic>{
            'p_event_key': event['eventKey'],
            'p_title': event['title'],
            'p_message': event['message'],
            'p_occurred_at': event['occurredAt'],
            'p_office_location_id': event['officeLocationId'],
          },
        );
        synchronized++;
      } catch (error) {
        developer.log(
          'Unable to synchronize a native geofence reminder',
          name: 'workpulse.geofencing',
          error: error,
        );
      }
    }
    return synchronized;
  }

  Future<void> clear() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('clear');
    }
  }

  Future<List<Map<String, dynamic>>> _eligibleWindows(String userId) async {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime endDate = today.add(
      const Duration(days: _eligibilityWindowDays),
    );
    final Map<String, dynamic> profile = await _client
        .from('profiles')
        .select('work_schedule_id')
        .eq('id', userId)
        .single();
    String? scheduleId = profile['work_schedule_id'] as String?;
    scheduleId ??= await _defaultScheduleId();
    if (scheduleId == null) {
      return const <Map<String, dynamic>>[];
    }

    final List<dynamic> dayRows = await _client
        .from('work_schedule_days')
        .select('iso_weekday, is_working_day, start_time, end_time')
        .eq('schedule_id', scheduleId);
    final Map<int, Map<String, dynamic>> workingDays = <int, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in dayRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .where((Map<String, dynamic> row) => row['is_working_day'] == true))
        row['iso_weekday'] as int: row,
    };

    final List<dynamic> holidayRows = await _client
        .from('public_holidays')
        .select('holiday_date')
        .eq('is_active', true)
        .gte('holiday_date', _dateLabel(today))
        .lte('holiday_date', _dateLabel(endDate));
    final Set<String> holidays = holidayRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .map((Map<String, dynamic> row) => row['holiday_date'] as String)
        .toSet();

    final List<dynamic> leaveRows = await _client
        .from('leave_requests')
        .select('start_date, end_date')
        .eq('user_id', userId)
        .inFilter('status', const <String>['pending', 'approved'])
        .lte('start_date', _dateLabel(endDate))
        .gte('end_date', _dateLabel(today));
    final List<Map<String, dynamic>> leaveRanges = leaveRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);

    final List<Map<String, dynamic>> eligible = <Map<String, dynamic>>[];
    DateTime cursor = today;
    while (!cursor.isAfter(endDate)) {
      final String label = _dateLabel(cursor);
      final bool onProtectedLeave = leaveRanges.any(
        (Map<String, dynamic> leave) =>
            label.compareTo(leave['start_date'] as String) >= 0 &&
            label.compareTo(leave['end_date'] as String) <= 0,
      );
      final Map<String, dynamic>? workingDay = workingDays[cursor.weekday];
      if (workingDay != null &&
          !holidays.contains(label) &&
          !onProtectedLeave) {
        eligible.add(<String, dynamic>{
          'date': label,
          'startMinute': _timeToMinute(workingDay['start_time'] as String?),
          'endMinute': _timeToMinute(workingDay['end_time'] as String?),
        });
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return eligible;
  }

  int _timeToMinute(String? value) {
    if (value == null || value.isEmpty) {
      return 0;
    }
    final List<String> parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<String?> _defaultScheduleId() async {
    final Map<String, dynamic>? row = await _client
        .from('work_schedules')
        .select('id')
        .eq('is_default', true)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    return row?['id'] as String?;
  }

  DateTime _dateOnly(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateLabel(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
