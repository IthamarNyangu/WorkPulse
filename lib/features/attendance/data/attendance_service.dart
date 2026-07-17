import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceService {
  AttendanceService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client,
      _authService = AuthService(client: client ?? SupabaseBootstrap.client);

  static const String tableName = 'attendance_records';
  static const String leaveTableName = 'leave_requests';
  static const String correctionTableName = 'correction_requests';
  static const int _classificationLookbackDays = 45;

  final SupabaseClient _client;
  final AuthService _authService;

  Future<SupabaseAttendanceRecord> insertClockIn({
    String? comment,
    DateTime? clockInAt,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    bool? isInsideGeofence,
  }) async {
    final DateTime effectiveClockInAt = clockInAt ?? DateTime.now();
    final WorkPulseUserProfile profile = await _requireCurrentProfile();
    final SupabaseAttendanceRecord? existing = await fetchTodaysAttendance(
      date: effectiveClockInAt,
    );

    if (existing != null) {
      if (existing.clockInAt == null && existing.status == 'leave_pending') {
        throw StateError('You have a pending leave request for today.');
      }
      if (existing.clockInAt == null && existing.status == 'on_leave') {
        throw StateError('Approved leave is active for today.');
      }
      if (existing.clockInAt != null && existing.clockOutAt == null) {
        throw StateError('You are already clocked in for today.');
      }
      throw StateError('Attendance for today is already completed.');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'user_id': profile.id,
      'employee_id': profile.employeeId,
      'work_date': _dateOnlyLabel(effectiveClockInAt),
      'clock_in': effectiveClockInAt.toUtc().toIso8601String(),
      'clock_in_comment': comment,
      'clock_in_lat': latitude,
      'clock_in_lng': longitude,
      'clock_in_accuracy_m': accuracyMeters,
      'clock_in_inside_geofence': isInsideGeofence,
      'status': 'on_duty',
    };

    final Map<String, dynamic> row = await _insertAttendance(payload);

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<SupabaseAttendanceRecord> insertClockOut({
    String? comment,
    DateTime? clockOutAt,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    bool? isInsideGeofence,
  }) async {
    final DateTime effectiveClockOutAt = clockOutAt ?? DateTime.now();
    final SupabaseAttendanceRecord? record = await fetchTodaysAttendance(
      date: effectiveClockOutAt,
    );

    if (record == null) {
      throw StateError('No open attendance record found for today.');
    }
    if (record.status == 'leave_pending') {
      throw StateError('You have a pending leave request for today.');
    }
    if (record.status == 'on_leave') {
      throw StateError('Approved leave is active for today.');
    }
    if (record.clockInAt == null) {
      throw StateError('Today does not have a clock-in record yet.');
    }
    if (record.clockOutAt != null) {
      throw StateError('You are already clocked out for today.');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'clock_out': effectiveClockOutAt.toUtc().toIso8601String(),
      'clock_out_comment': comment,
      'clock_out_lat': latitude,
      'clock_out_lng': longitude,
      'clock_out_accuracy_m': accuracyMeters,
      'clock_out_inside_geofence': isInsideGeofence,
      'status': 'completed',
    };

    final Map<String, dynamic> row = await _updateAttendance(
      recordId: record.id,
      payload: payload,
    );

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<SupabaseAttendanceRecord?> fetchTodaysAttendance({
    DateTime? date,
  }) async {
    final WorkPulseUserProfile profile = await _requireCurrentProfile();
    await syncAttendanceClassifications(profile: profile);
    final String workDate = _dateOnlyLabel(date ?? DateTime.now());

    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select()
        .eq('user_id', profile.id)
        .eq('work_date', workDate)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<List<AttendanceRecord>> fetchHistoryRecords() async {
    final WorkPulseUserProfile profile = await _requireCurrentProfile();
    await syncAttendanceClassifications(profile: profile);
    final String today = _dateOnlyLabel(DateTime.now());

    final List<dynamic> rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', profile.id)
        .lte('work_date', today)
        .order('work_date', ascending: false)
        .order('created_at', ascending: false);

    return rows
        .map(
          (dynamic row) => SupabaseAttendanceRecord.fromMap(
            Map<String, dynamic>.from(row as Map),
          ).toHistoryRecord(),
        )
        .toList(growable: false);
  }

  Future<AttendanceRecord?> fetchHistoryRecordById(String id) async {
    final WorkPulseUserProfile profile = await _requireCurrentProfile();
    await syncAttendanceClassifications(profile: profile);

    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select()
        .eq('user_id', profile.id)
        .eq('id', id)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return SupabaseAttendanceRecord.fromMap(row).toHistoryRecord();
  }

  Future<void> syncAttendanceClassifications({
    WorkPulseUserProfile? profile,
    DateTime? now,
  }) async {
    final WorkPulseUserProfile activeProfile =
        profile ?? await _requireCurrentProfile();
    final DateTime today = _dateOnly(now ?? DateTime.now());

    final List<dynamic> attendanceRows = await _client
        .from(tableName)
        .select()
        .eq('user_id', activeProfile.id);

    final List<Map<String, dynamic>> attendance = attendanceRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .where((Map<String, dynamic> row) {
          final DateTime workDate = _dateOnly(
            DateTime.parse(row['work_date'] as String),
          );
          return !workDate.isAfter(today);
        })
        .toList(growable: false);

    final List<dynamic> leaveRows = await _client
        .from(leaveTableName)
        .select()
        .eq('user_id', activeProfile.id)
        .lte('start_date', _dateOnlyLabel(today));

    final List<Map<String, dynamic>> leaveRequests = leaveRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);

    final List<dynamic> correctionRows = await _client
        .from(correctionTableName)
        .select('attendance_record_id')
        .eq('user_id', activeProfile.id)
        .eq('status', 'pending');

    final Set<String> pendingCorrectionAttendanceIds = correctionRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .map(
          (Map<String, dynamic> row) => row['attendance_record_id'] as String?,
        )
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Map<String, Map<String, dynamic>> attendanceByDate =
        <String, Map<String, dynamic>>{};
    DateTime? earliestActivityDate;
    for (final Map<String, dynamic> row in attendance) {
      final DateTime workDate = _dateOnly(
        DateTime.parse(row['work_date'] as String),
      );
      attendanceByDate[_dateOnlyLabel(workDate)] = row;
      earliestActivityDate = _earliestDate(earliestActivityDate, workDate);
    }
    for (final Map<String, dynamic> row in leaveRequests) {
      final DateTime startDate = _dateOnly(
        DateTime.parse(row['start_date'] as String),
      );
      if (!startDate.isAfter(today)) {
        earliestActivityDate = _earliestDate(earliestActivityDate, startDate);
      }
    }

    for (final Map<String, dynamic> row in attendance) {
      final DateTime workDate = _dateOnly(
        DateTime.parse(row['work_date'] as String),
      );
      final String? targetStatus = _statusForExistingAttendance(
        row: row,
        workDate: workDate,
        today: today,
        leaveStatus: _leaveStatusForDate(leaveRequests, workDate),
        hasPendingCorrection: pendingCorrectionAttendanceIds.contains(
          row['id'] as String,
        ),
      );

      if (targetStatus == null) {
        await _client
            .from(tableName)
            .delete()
            .eq('id', row['id'] as String)
            .eq('user_id', activeProfile.id);
        continue;
      }

      if (row['status'] != targetStatus) {
        await _client
            .from(tableName)
            .update(<String, dynamic>{'status': targetStatus})
            .eq('id', row['id'] as String)
            .eq('user_id', activeProfile.id);
      }
    }

    final DateTime startDate = _classificationStartDate(
      earliestActivityDate: earliestActivityDate,
      today: today,
    );
    DateTime cursor = startDate;
    while (!cursor.isAfter(today)) {
      final String dateKey = _dateOnlyLabel(cursor);
      if (!attendanceByDate.containsKey(dateKey)) {
        final String? status = _statusForMissingAttendance(
          leaveStatus: _leaveStatusForDate(leaveRequests, cursor),
          date: cursor,
          today: today,
        );
        if (status != null) {
          await _client.from(tableName).insert(<String, dynamic>{
            'user_id': activeProfile.id,
            'employee_id': activeProfile.employeeId,
            'work_date': dateKey,
            'status': status,
          });
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  Future<WorkPulseUserProfile> _requireCurrentProfile() async {
    final WorkPulseUserProfile? profile = await _authService
        .fetchCurrentProfile();
    if (profile == null) {
      throw StateError(
        'No employee profile found for the current user. Confirm the profiles trigger and test user are set up in Supabase.',
      );
    }
    return profile;
  }

  Future<Map<String, dynamic>> _insertAttendance(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _client.from(tableName).insert(payload).select().single();
    } catch (error) {
      if (!_looksLikeMissingGeofenceColumns(error)) {
        rethrow;
      }
      return _client
          .from(tableName)
          .insert(_withoutGeofenceColumns(payload))
          .select()
          .single();
    }
  }

  Future<Map<String, dynamic>> _updateAttendance({
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _client
          .from(tableName)
          .update(payload)
          .eq('id', recordId)
          .select()
          .single();
    } catch (error) {
      if (!_looksLikeMissingGeofenceColumns(error)) {
        rethrow;
      }
      return _client
          .from(tableName)
          .update(_withoutGeofenceColumns(payload))
          .eq('id', recordId)
          .select()
          .single();
    }
  }

  bool _looksLikeMissingGeofenceColumns(Object error) {
    final String message = error.toString().toLowerCase();
    return message.contains('accuracy_m') ||
        message.contains('inside_geofence') ||
        message.contains('schema cache');
  }

  Map<String, dynamic> _withoutGeofenceColumns(Map<String, dynamic> payload) {
    final Map<String, dynamic> safePayload = Map<String, dynamic>.of(payload);
    safePayload.remove('clock_in_accuracy_m');
    safePayload.remove('clock_in_inside_geofence');
    safePayload.remove('clock_out_accuracy_m');
    safePayload.remove('clock_out_inside_geofence');
    return safePayload;
  }

  String? _statusForExistingAttendance({
    required Map<String, dynamic> row,
    required DateTime workDate,
    required DateTime today,
    required String? leaveStatus,
    required bool hasPendingCorrection,
  }) {
    final bool hasClockIn = row['clock_in'] != null;
    final bool hasClockOut = row['clock_out'] != null;

    if (hasPendingCorrection) {
      return 'correction_pending';
    }

    if (hasClockIn && hasClockOut) {
      return 'completed';
    }

    if (leaveStatus == 'approved') {
      return 'on_leave';
    }
    if (leaveStatus == 'pending') {
      return 'leave_pending';
    }

    if (hasClockIn && !hasClockOut) {
      return workDate.isBefore(today) ? 'missed_punch' : 'on_duty';
    }

    if (workDate.isBefore(today) && _isWorkday(workDate)) {
      return 'absent';
    }

    return null;
  }

  String? _statusForMissingAttendance({
    required String? leaveStatus,
    required DateTime date,
    required DateTime today,
  }) {
    if (leaveStatus == 'approved') {
      return 'on_leave';
    }
    if (leaveStatus == 'pending') {
      return 'leave_pending';
    }
    if (date.isBefore(today) && _isWorkday(date)) {
      return 'absent';
    }
    return null;
  }

  String? _leaveStatusForDate(
    List<Map<String, dynamic>> leaveRequests,
    DateTime date,
  ) {
    bool hasPending = false;
    bool hasRejected = false;
    for (final Map<String, dynamic> request in leaveRequests) {
      final DateTime startDate = _dateOnly(
        DateTime.parse(request['start_date'] as String),
      );
      final DateTime endDate = _dateOnly(
        DateTime.parse(request['end_date'] as String),
      );
      if (date.isBefore(startDate) || date.isAfter(endDate)) {
        continue;
      }

      switch (request['status'] as String) {
        case 'approved':
          return 'approved';
        case 'pending':
          hasPending = true;
          break;
        case 'rejected':
          hasRejected = true;
          break;
      }
    }

    if (hasPending) {
      return 'pending';
    }
    if (hasRejected) {
      return 'rejected';
    }
    return null;
  }

  DateTime _classificationStartDate({
    required DateTime? earliestActivityDate,
    required DateTime today,
  }) {
    if (earliestActivityDate == null) {
      return today;
    }

    final DateTime lookbackStart = today.subtract(
      const Duration(days: _classificationLookbackDays),
    );
    if (earliestActivityDate.isBefore(lookbackStart)) {
      return lookbackStart;
    }
    return earliestActivityDate;
  }

  DateTime? _earliestDate(DateTime? current, DateTime candidate) {
    if (current == null || candidate.isBefore(current)) {
      return candidate;
    }
    return current;
  }

  bool _isWorkday(DateTime date) {
    return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
  }

  DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  String _dateOnlyLabel(DateTime dateTime) {
    final DateTime localDate = _dateOnly(dateTime.toLocal());
    final String year = localDate.year.toString().padLeft(4, '0');
    final String month = localDate.month.toString().padLeft(2, '0');
    final String day = localDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class SupabaseAttendanceRecord {
  const SupabaseAttendanceRecord({
    required this.id,
    required this.userId,
    required this.employeeId,
    required this.workDate,
    this.clockInAt,
    this.clockOutAt,
    this.clockInComment,
    this.clockOutComment,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockInAccuracyMeters,
    this.clockInInsideGeofence,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockOutAccuracyMeters,
    this.clockOutInsideGeofence,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String employeeId;
  final DateTime workDate;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final String? clockInComment;
  final String? clockOutComment;
  final double? clockInLatitude;
  final double? clockInLongitude;
  final double? clockInAccuracyMeters;
  final bool? clockInInsideGeofence;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final double? clockOutAccuracyMeters;
  final bool? clockOutInsideGeofence;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SupabaseAttendanceRecord.fromMap(Map<String, dynamic> map) {
    return SupabaseAttendanceRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      employeeId: map['employee_id'] as String,
      workDate: DateTime.parse(map['work_date'] as String),
      clockInAt: _parseDateTime(map['clock_in']),
      clockOutAt: _parseDateTime(map['clock_out']),
      clockInComment: map['clock_in_comment'] as String?,
      clockOutComment: map['clock_out_comment'] as String?,
      clockInLatitude: _parseDouble(map['clock_in_lat']),
      clockInLongitude: _parseDouble(map['clock_in_lng']),
      clockInAccuracyMeters: _parseDouble(map['clock_in_accuracy_m']),
      clockInInsideGeofence: map['clock_in_inside_geofence'] as bool?,
      clockOutLatitude: _parseDouble(map['clock_out_lat']),
      clockOutLongitude: _parseDouble(map['clock_out_lng']),
      clockOutAccuracyMeters: _parseDouble(map['clock_out_accuracy_m']),
      clockOutInsideGeofence: map['clock_out_inside_geofence'] as bool?,
      status: map['status'] as String?,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String).toLocal();
  }

  static double? _parseDouble(Object? value) {
    if (value == null) {
      return null;
    }
    return (value as num).toDouble();
  }

  AttendanceRecord toHistoryRecord() {
    final String clockInTimeLabel = clockInAt == null
        ? '--'
        : timeLabel(clockInAt!);
    final String clockOutTimeLabel = clockOutAt == null
        ? '--'
        : timeLabel(clockOutAt!);
    final Duration? workedDuration = _workedDuration;

    return AttendanceRecord(
      id: id,
      date: workDate,
      clockInTime: clockInTimeLabel,
      clockOutTime: clockOutTimeLabel,
      workHours: _workHoursLabel(workedDuration),
      status: _historyStatus,
      note: _historyNote,
      clockInLocation: _locationSnapshot(
        latitude: clockInLatitude,
        longitude: clockInLongitude,
        accuracyMeters: clockInAccuracyMeters,
        isInsideGeofence: clockInInsideGeofence,
      ),
      clockOutLocation: _locationSnapshot(
        latitude: clockOutLatitude,
        longitude: clockOutLongitude,
        accuracyMeters: clockOutAccuracyMeters,
        isInsideGeofence: clockOutInsideGeofence,
      ),
    );
  }

  Duration? get _workedDuration {
    if (clockInAt == null) {
      return null;
    }
    if (clockOutAt != null && !clockOutAt!.isBefore(clockInAt!)) {
      return clockOutAt!.difference(clockInAt!);
    }
    if (status == 'on_duty') {
      return DateTime.now().difference(clockInAt!);
    }
    return null;
  }

  AttendanceRecordStatus get _historyStatus {
    switch (status) {
      case 'on_duty':
        return AttendanceRecordStatus.onDuty;
      case 'completed':
        return AttendanceRecordStatus.completed;
      case 'missed_punch':
        return AttendanceRecordStatus.missedPunch;
      case 'correction_pending':
        return AttendanceRecordStatus.correctionPending;
      case 'leave_pending':
        return AttendanceRecordStatus.leavePending;
      case 'on_leave':
        return AttendanceRecordStatus.onLeave;
      case 'absent':
        return AttendanceRecordStatus.absent;
      default:
        return AttendanceRecordStatus.completed;
    }
  }

  String _workHoursLabel(Duration? workedDuration) {
    if (workedDuration != null) {
      return durationLabel(workedDuration);
    }

    switch (_historyStatus) {
      case AttendanceRecordStatus.onLeave:
      case AttendanceRecordStatus.leavePending:
      case AttendanceRecordStatus.absent:
        return '0h 0m';
      default:
        return '--';
    }
  }

  String? get _historyNote {
    final List<String> notes = <String>[];
    if (clockInComment != null && clockInComment!.trim().isNotEmpty) {
      notes.add('Clock In Comment: ${clockInComment!.trim()}');
    }
    if (clockOutComment != null && clockOutComment!.trim().isNotEmpty) {
      notes.add('Clock Out Comment: ${clockOutComment!.trim()}');
    }
    if (notes.isEmpty) {
      return null;
    }
    return notes.join('\n');
  }
}

ClockLocationSnapshot? _locationSnapshot({
  required double? latitude,
  required double? longitude,
  required double? accuracyMeters,
  required bool? isInsideGeofence,
}) {
  if (latitude == null || longitude == null) {
    return null;
  }

  return ClockLocationSnapshot(
    coordinates:
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    accuracyMeters: accuracyMeters ?? 0,
    isInsideGeofence: isInsideGeofence ?? false,
  );
}
