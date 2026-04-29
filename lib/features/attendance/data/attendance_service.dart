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

  final SupabaseClient _client;
  final AuthService _authService;

  Future<SupabaseAttendanceRecord> insertClockIn({
    String? comment,
    DateTime? clockInAt,
    double? latitude,
    double? longitude,
  }) async {
    final DateTime effectiveClockInAt = clockInAt ?? DateTime.now();
    final WorkPulseUserProfile profile = await _requireCurrentProfile();
    final SupabaseAttendanceRecord? existing = await fetchTodaysAttendance(
      date: effectiveClockInAt,
    );

    if (existing != null) {
      if (existing.clockOutAt == null) {
        throw StateError('You are already clocked in for today.');
      }
      throw StateError('Attendance for today is already completed.');
    }

    final Map<String, dynamic> row =
        (await _client
                .from(tableName)
                .insert(<String, dynamic>{
                  'user_id': profile.id,
                  'employee_id': profile.employeeId,
                  'work_date': _dateOnlyLabel(effectiveClockInAt),
                  'clock_in': effectiveClockInAt.toUtc().toIso8601String(),
                  'clock_in_comment': comment,
                  'clock_in_lat': latitude,
                  'clock_in_lng': longitude,
                  'status': 'on_duty',
                })
                .select()
                .single())
            as Map<String, dynamic>;

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<SupabaseAttendanceRecord> insertClockOut({
    String? comment,
    DateTime? clockOutAt,
    double? latitude,
    double? longitude,
  }) async {
    final DateTime effectiveClockOutAt = clockOutAt ?? DateTime.now();
    final SupabaseAttendanceRecord? record = await fetchTodaysAttendance(
      date: effectiveClockOutAt,
    );

    if (record == null) {
      throw StateError('No open attendance record found for today.');
    }
    if (record.clockInAt == null) {
      throw StateError('Today does not have a clock-in record yet.');
    }
    if (record.clockOutAt != null) {
      throw StateError('You are already clocked out for today.');
    }

    final Map<String, dynamic> row =
        (await _client
                .from(tableName)
                .update(<String, dynamic>{
                  'clock_out': effectiveClockOutAt.toUtc().toIso8601String(),
                  'clock_out_comment': comment,
                  'clock_out_lat': latitude,
                  'clock_out_lng': longitude,
                  'status': 'completed',
                })
                .eq('id', record.id)
                .select()
                .single())
            as Map<String, dynamic>;

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<SupabaseAttendanceRecord?> fetchTodaysAttendance({DateTime? date}) async {
    final WorkPulseUserProfile profile = await _requireCurrentProfile();
    final String workDate = _dateOnlyLabel(date ?? DateTime.now());

    final Map<String, dynamic>? row =
        (await _client
                .from(tableName)
                .select()
                .eq('user_id', profile.id)
                .eq('work_date', workDate)
                .maybeSingle())
            as Map<String, dynamic>?;

    if (row == null) {
      return null;
    }

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<List<AttendanceRecord>> fetchHistoryRecords() async {
    final WorkPulseUserProfile profile = await _requireCurrentProfile();

    final List<dynamic> rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', profile.id)
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

    final Map<String, dynamic>? row =
        (await _client
                .from(tableName)
                .select()
                .eq('user_id', profile.id)
                .eq('id', id)
                .maybeSingle())
            as Map<String, dynamic>?;

    if (row == null) {
      return null;
    }

    return SupabaseAttendanceRecord.fromMap(row).toHistoryRecord();
  }

  Future<WorkPulseUserProfile> _requireCurrentProfile() async {
    final WorkPulseUserProfile? profile = await _authService.fetchCurrentProfile();
    if (profile == null) {
      throw StateError(
        'No employee profile found for the current user. Confirm the profiles trigger and test user are set up in Supabase.',
      );
    }
    return profile;
  }

  String _dateOnlyLabel(DateTime dateTime) {
    final DateTime localDate = dateTime.toLocal();
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
    this.clockOutLatitude,
    this.clockOutLongitude,
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
  final double? clockOutLatitude;
  final double? clockOutLongitude;
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
      clockOutLatitude: _parseDouble(map['clock_out_lat']),
      clockOutLongitude: _parseDouble(map['clock_out_lng']),
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
    final String clockInTimeLabel = clockInAt == null ? '--' : timeLabel(clockInAt!);
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
