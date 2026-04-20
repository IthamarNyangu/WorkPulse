import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceService {
  AttendanceService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const String tableName = 'attendance_records';

  final SupabaseClient _client;

  Future<SupabaseAttendanceRecord> insertClockIn({
    required String employeeId,
    String? comment,
    DateTime? clockInAt,
  }) async {
    final DateTime effectiveClockInAt = clockInAt ?? DateTime.now();
    final String userId = _requireUserId();

    final Map<String, dynamic> row = (await _client
        .from(tableName)
        .insert(<String, dynamic>{
          'user_id': userId,
          'employee_id': employeeId,
          'work_date': _dateOnlyLabel(effectiveClockInAt),
          'clock_in_at': effectiveClockInAt.toUtc().toIso8601String(),
          'comment': comment,
          'status': 'on_duty',
        })
        .select()
        .single());

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<SupabaseAttendanceRecord> insertClockOut({
    required String employeeId,
    String? comment,
    DateTime? clockOutAt,
  }) async {
    final DateTime effectiveClockOutAt = clockOutAt ?? DateTime.now();
    final SupabaseAttendanceRecord? record = await fetchTodaysAttendance(
      employeeId: employeeId,
      date: effectiveClockOutAt,
    );

    if (record == null) {
      throw StateError('No open attendance record found for today.');
    }

    final Map<String, dynamic> row = (await _client
        .from(tableName)
        .update(<String, dynamic>{
          'clock_out_at': effectiveClockOutAt.toUtc().toIso8601String(),
          'comment': comment ?? record.comment,
          'status': 'completed',
        })
        .eq('id', record.id)
        .select()
        .single());

    return SupabaseAttendanceRecord.fromMap(row);
  }

  Future<SupabaseAttendanceRecord?> fetchTodaysAttendance({
    required String employeeId,
    DateTime? date,
  }) async {
    final String userId = _requireUserId();
    final String workDate = _dateOnlyLabel(date ?? DateTime.now());

    final List<dynamic> rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('employee_id', employeeId)
        .eq('work_date', workDate)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    return SupabaseAttendanceRecord.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  String _requireUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be logged in before using attendance APIs.');
    }
    return userId;
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
    this.comment,
    this.status,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String employeeId;
  final DateTime workDate;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final String? comment;
  final String? status;
  final DateTime? createdAt;

  factory SupabaseAttendanceRecord.fromMap(Map<String, dynamic> map) {
    return SupabaseAttendanceRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      employeeId: map['employee_id'] as String,
      workDate: DateTime.parse(map['work_date'] as String),
      clockInAt: _parseDateTime(map['clock_in_at']),
      clockOutAt: _parseDateTime(map['clock_out_at']),
      comment: map['comment'] as String?,
      status: map['status'] as String?,
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String).toLocal();
  }
}
