import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/data/work_calendar_service.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SupervisorAttendanceStatus {
  noClockIn,
  nonWorkingDay,
  onDuty,
  completed,
  missedPunch,
  correctionPending,
  leavePending,
  onLeave,
  absent,
}

extension SupervisorAttendanceStatusLabels on SupervisorAttendanceStatus {
  String get label {
    switch (this) {
      case SupervisorAttendanceStatus.noClockIn:
        return 'No Clock In';
      case SupervisorAttendanceStatus.nonWorkingDay:
        return 'Non-Working Day';
      case SupervisorAttendanceStatus.onDuty:
        return 'On Duty';
      case SupervisorAttendanceStatus.completed:
        return 'Completed';
      case SupervisorAttendanceStatus.missedPunch:
        return 'Missed Punch';
      case SupervisorAttendanceStatus.correctionPending:
        return 'Correction Pending';
      case SupervisorAttendanceStatus.leavePending:
        return 'Leave Pending';
      case SupervisorAttendanceStatus.onLeave:
        return 'On Leave';
      case SupervisorAttendanceStatus.absent:
        return 'Absent';
    }
  }
}

class SupervisorAttendanceDay {
  const SupervisorAttendanceDay({
    required this.date,
    required this.summary,
    required this.records,
  });

  final DateTime date;
  final SupervisorAttendanceSummary summary;
  final List<SupervisorAttendanceEmployeeRecord> records;
}

class SupervisorAttendanceReport {
  const SupervisorAttendanceReport({
    required this.startDate,
    required this.endDate,
    required this.records,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<SupervisorAttendanceEmployeeRecord> records;
}

class SupervisorAttendanceSummary {
  const SupervisorAttendanceSummary({
    required this.totalEmployees,
    required this.clockedIn,
    required this.clockedOut,
    required this.absent,
    required this.onLeave,
    required this.locationExceptions,
  });

  final int totalEmployees;
  final int clockedIn;
  final int clockedOut;
  final int absent;
  final int onLeave;
  final int locationExceptions;
}

class SupervisorAttendanceEmployeeRecord {
  const SupervisorAttendanceEmployeeRecord({
    required this.employeeId,
    required this.employeeName,
    required this.email,
    required this.status,
    required this.date,
    this.department,
    this.attendanceRecordId,
    this.clockInAt,
    this.clockOutAt,
    this.workedDuration,
    this.clockInComment,
    this.clockOutComment,
    this.clockInLocation,
    this.clockOutLocation,
    this.officeProvince,
    this.officeDistrict,
  });

  final String employeeId;
  final String employeeName;
  final String email;
  final String? department;
  final SupervisorAttendanceStatus status;
  final DateTime date;
  final String? attendanceRecordId;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final Duration? workedDuration;
  final String? clockInComment;
  final String? clockOutComment;
  final ClockLocationSnapshot? clockInLocation;
  final ClockLocationSnapshot? clockOutLocation;
  final String? officeProvince;
  final String? officeDistrict;

  String get clockInLabel => clockInAt == null ? '--' : timeLabel(clockInAt!);
  String get clockOutLabel =>
      clockOutAt == null ? '--' : timeLabel(clockOutAt!);
  String get workHoursLabel =>
      workedDuration == null ? '--' : durationLabel(workedDuration!);
  bool get hasClockedIn => clockInAt != null;
  bool get hasClockedOut => clockOutAt != null;
  bool get hasLocationException =>
      _isLocationException(clockInLocation) ||
      _isLocationException(clockOutLocation);

  String? get officeDisplayName {
    return clockInLocation?.officeDisplayName ??
        clockOutLocation?.officeDisplayName;
  }

  bool matchesOfficeProvince(String province) {
    return officeProvince?.toLowerCase() == province.toLowerCase();
  }

  static bool _isLocationException(ClockLocationSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    return snapshot.status != ClockLocationStatus.insideOffice;
  }
}

class SupervisorAttendanceService {
  SupervisorAttendanceService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client,
      _authService = AuthService(client: client ?? SupabaseBootstrap.client),
      _officeLocationService = OfficeLocationService(
        client: client ?? SupabaseBootstrap.client,
      ),
      _workCalendarService = WorkCalendarService(
        client: client ?? SupabaseBootstrap.client,
      );

  static const String profilesTableName = 'profiles';
  static const String attendanceTableName = 'attendance_records';
  static const String leaveTableName = 'leave_requests';
  static const Set<String> reviewerRoles = <String>{
    'supervisor',
    'hr',
    'admin',
  };

  final SupabaseClient _client;
  final AuthService _authService;
  final OfficeLocationService _officeLocationService;
  final WorkCalendarService _workCalendarService;

  Future<SupervisorAttendanceDay> fetchAttendanceDay(DateTime date) async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();
    if (!reviewerRoles.contains(reviewer.role)) {
      throw StateError(
        'Only supervisors, HR, and admins can view the attendance dashboard.',
      );
    }

    final DateTime selectedDate = _dateOnly(date);
    final String selectedDateLabel = _dateOnlyLabel(selectedDate);
    final Set<String> publicHolidayDates = await _workCalendarService
        .fetchPublicHolidayDates(
          startDate: selectedDate,
          endDate: selectedDate,
        );
    final bool isWorkday = WorkCalendarService.isWorkingDay(
      selectedDate,
      publicHolidayDates,
    );

    final List<_DashboardEmployee> employees = await _fetchEmployees(
      activeOnly: true,
      reviewerId: reviewer.id,
    );
    final List<Map<String, dynamic>> attendanceRows =
        await _fetchAttendanceRows(selectedDateLabel);
    final List<Map<String, dynamic>> leaveRows = await _fetchLeaveRows(
      selectedDateLabel,
    );
    final Map<String, _OfficeLookup> officesById = await _officesById();

    final Map<String, SupabaseAttendanceRecord> attendanceByUserId =
        <String, SupabaseAttendanceRecord>{
          for (final Map<String, dynamic> row in attendanceRows)
            row['user_id'] as String: SupabaseAttendanceRecord.fromMap(row),
        };

    final Map<String, String> leaveStatusByUserId = _leaveStatusByUserId(
      leaveRows,
    );

    final List<SupervisorAttendanceEmployeeRecord> records =
        employees
            .map(
              (_DashboardEmployee employee) => _recordForEmployee(
                employee: employee,
                date: selectedDate,
                isWorkday: isWorkday,
                attendance: attendanceByUserId[employee.id],
                leaveStatus: leaveStatusByUserId[employee.id],
                officesById: officesById,
              ),
            )
            .toList(growable: false)
          ..sort(
            (
              SupervisorAttendanceEmployeeRecord a,
              SupervisorAttendanceEmployeeRecord b,
            ) => a.employeeName.compareTo(b.employeeName),
          );

    return SupervisorAttendanceDay(
      date: selectedDate,
      records: records,
      summary: _summaryFor(records),
    );
  }

  Future<SupervisorAttendanceReport> fetchAttendanceReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();
    if (!reviewerRoles.contains(reviewer.role)) {
      throw StateError(
        'Only supervisors, HR, and admins can view attendance reports.',
      );
    }

    final DateTime reportStartDate = _dateOnly(startDate);
    final DateTime reportEndDate = _dateOnly(endDate);
    final DateTime normalizedStartDate = reportStartDate.isAfter(reportEndDate)
        ? reportEndDate
        : reportStartDate;
    final DateTime normalizedEndDate = reportStartDate.isAfter(reportEndDate)
        ? reportStartDate
        : reportEndDate;

    final String startLabel = _dateOnlyLabel(normalizedStartDate);
    final String endLabel = _dateOnlyLabel(normalizedEndDate);

    final List<_DashboardEmployee> employees = await _fetchEmployees(
      reviewerId: reviewer.id,
    );
    final List<Map<String, dynamic>> attendanceRows =
        await _fetchAttendanceRowsForRange(
          startLabel: startLabel,
          endLabel: endLabel,
        );
    final List<Map<String, dynamic>> leaveRows = await _fetchLeaveRowsForRange(
      startLabel: startLabel,
      endLabel: endLabel,
    );
    final Map<String, _OfficeLookup> officesById = await _officesById();
    final Set<String> publicHolidayDates = await _workCalendarService
        .fetchPublicHolidayDates(
          startDate: normalizedStartDate,
          endDate: normalizedEndDate,
        );

    final Map<String, SupabaseAttendanceRecord> attendanceByKey =
        <String, SupabaseAttendanceRecord>{
          for (final Map<String, dynamic> row in attendanceRows)
            _attendanceKey(
              userId: row['user_id'] as String,
              dateLabel: row['work_date'] as String,
            ): SupabaseAttendanceRecord.fromMap(
              row,
            ),
        };

    final List<SupervisorAttendanceEmployeeRecord> records =
        <SupervisorAttendanceEmployeeRecord>[];
    DateTime cursor = normalizedStartDate;
    while (!cursor.isAfter(normalizedEndDate)) {
      final String dateKey = _dateOnlyLabel(cursor);
      final bool isWorkday = WorkCalendarService.isWorkingDay(
        cursor,
        publicHolidayDates,
      );
      for (final _DashboardEmployee employee in employees) {
        final SupabaseAttendanceRecord? attendance =
            attendanceByKey[_attendanceKey(
              userId: employee.id,
              dateLabel: dateKey,
            )];
        final String? leaveStatus = _leaveStatusForEmployeeDate(
          leaveRows: leaveRows,
          userId: employee.id,
          date: cursor,
        );

        if (attendance == null &&
            leaveStatus == null &&
            !cursor.isBefore(_dateOnly(DateTime.now())) &&
            !isWorkday) {
          continue;
        }

        records.add(
          _recordForEmployee(
            employee: employee,
            date: cursor,
            isWorkday: isWorkday,
            attendance: attendance,
            leaveStatus: leaveStatus,
            officesById: officesById,
          ),
        );
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    records.sort((
      SupervisorAttendanceEmployeeRecord a,
      SupervisorAttendanceEmployeeRecord b,
    ) {
      final int dateComparison = b.date.compareTo(a.date);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return a.employeeName.compareTo(b.employeeName);
    });

    return SupervisorAttendanceReport(
      startDate: normalizedStartDate,
      endDate: normalizedEndDate,
      records: records,
    );
  }

  Future<WorkPulseUserProfile> _requireReviewerProfile() async {
    final WorkPulseUserProfile? profile = await _authService
        .fetchCurrentProfile();
    if (profile == null) {
      throw StateError('No active WorkPulse profile found.');
    }
    return profile;
  }

  Future<List<_DashboardEmployee>> _fetchEmployees({
    bool activeOnly = false,
    required String reviewerId,
  }) async {
    final List<dynamic> rows = activeOnly
        ? await _client
              .from(profilesTableName)
              .select('id, employee_id, full_name, email, department, role')
              .neq('id', reviewerId)
              .eq('is_active', true)
              .order('full_name', ascending: true)
        : await _client
              .from(profilesTableName)
              .select('id, employee_id, full_name, email, department, role')
              .neq('id', reviewerId)
              .order('full_name', ascending: true);

    return rows
        .map(
          (dynamic row) =>
              _DashboardEmployee.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRows(
    String dateLabel,
  ) async {
    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select()
        .eq('work_date', dateLabel);

    return rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRowsForRange({
    required String startLabel,
    required String endLabel,
  }) async {
    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select()
        .gte('work_date', startLabel)
        .lte('work_date', endLabel);

    return rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchLeaveRows(String dateLabel) async {
    final List<dynamic> rows = await _client
        .from(leaveTableName)
        .select('user_id, status, start_date, end_date')
        .lte('start_date', dateLabel)
        .gte('end_date', dateLabel);

    return rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchLeaveRowsForRange({
    required String startLabel,
    required String endLabel,
  }) async {
    final List<dynamic> rows = await _client
        .from(leaveTableName)
        .select('user_id, status, start_date, end_date')
        .lte('start_date', endLabel)
        .gte('end_date', startLabel);

    return rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, _OfficeLookup>> _officesById() async {
    final List<OfficeLocation> offices = await _officeLocationService
        .fetchOfficeLocations();
    return <String, _OfficeLookup>{
      for (final OfficeLocation office in offices)
        office.id: _OfficeLookup(
          id: office.id,
          officeName: office.officeName,
          province: office.province,
          district: office.district,
        ),
    };
  }

  Map<String, String> _leaveStatusByUserId(List<Map<String, dynamic>> rows) {
    final Map<String, String> statuses = <String, String>{};
    for (final Map<String, dynamic> row in rows) {
      final String? userId = row['user_id'] as String?;
      final String? status = row['status'] as String?;
      if (userId == null || status == null || status == 'rejected') {
        continue;
      }
      if (status == 'approved') {
        statuses[userId] = status;
        continue;
      }
      statuses.putIfAbsent(userId, () => status);
    }
    return statuses;
  }

  String? _leaveStatusForEmployeeDate({
    required List<Map<String, dynamic>> leaveRows,
    required String userId,
    required DateTime date,
  }) {
    bool hasPending = false;
    for (final Map<String, dynamic> row in leaveRows) {
      if (row['user_id'] != userId) {
        continue;
      }

      final DateTime startDate = _dateOnly(
        DateTime.parse(row['start_date'] as String),
      );
      final DateTime endDate = _dateOnly(
        DateTime.parse(row['end_date'] as String),
      );
      if (date.isBefore(startDate) || date.isAfter(endDate)) {
        continue;
      }

      switch (row['status'] as String?) {
        case 'approved':
          return 'approved';
        case 'pending':
          hasPending = true;
          break;
      }
    }
    return hasPending ? 'pending' : null;
  }

  SupervisorAttendanceEmployeeRecord _recordForEmployee({
    required _DashboardEmployee employee,
    required DateTime date,
    required bool isWorkday,
    required SupabaseAttendanceRecord? attendance,
    required String? leaveStatus,
    required Map<String, _OfficeLookup> officesById,
  }) {
    if (attendance == null) {
      return SupervisorAttendanceEmployeeRecord(
        employeeId: employee.employeeId,
        employeeName: employee.fullName,
        email: employee.email,
        department: employee.department,
        date: date,
        status: _statusWithoutAttendance(
          date: date,
          leaveStatus: leaveStatus,
          isWorkday: isWorkday,
        ),
      );
    }

    return SupervisorAttendanceEmployeeRecord(
      employeeId: employee.employeeId,
      employeeName: employee.fullName,
      email: employee.email,
      department: employee.department,
      date: date,
      attendanceRecordId: attendance.id,
      status:
          !isWorkday &&
              attendance.clockInAt == null &&
              attendance.clockOutAt == null
          ? SupervisorAttendanceStatus.nonWorkingDay
          : _statusFromAttendance(attendance.status),
      clockInAt: attendance.clockInAt,
      clockOutAt: attendance.clockOutAt,
      workedDuration: _workedDuration(attendance),
      clockInComment: attendance.clockInComment,
      clockOutComment: attendance.clockOutComment,
      officeProvince: _officeLookupForAttendance(
        attendance,
        officesById,
      )?.province,
      officeDistrict: _officeLookupForAttendance(
        attendance,
        officesById,
      )?.district,
      clockInLocation: _locationSnapshot(
        latitude: attendance.clockInLatitude,
        longitude: attendance.clockInLongitude,
        accuracyMeters: attendance.clockInAccuracyMeters,
        isInsideGeofence: attendance.clockInInsideGeofence,
        locationStatus: attendance.clockInLocationStatus,
        verifiedOfficeLocationId: attendance.clockInVerifiedOfficeLocationId,
        verifiedOfficeName:
            officesById[attendance.clockInVerifiedOfficeLocationId]?.officeName,
        nearestOfficeLocationId: attendance.clockInNearestOfficeLocationId,
        nearestOfficeName:
            officesById[attendance.clockInNearestOfficeLocationId]?.officeName,
        distanceMeters: attendance.clockInDistanceMeters,
        geofenceRadiusMeters: attendance.clockInGeofenceRadiusMeters,
      ),
      clockOutLocation: _locationSnapshot(
        latitude: attendance.clockOutLatitude,
        longitude: attendance.clockOutLongitude,
        accuracyMeters: attendance.clockOutAccuracyMeters,
        isInsideGeofence: attendance.clockOutInsideGeofence,
        locationStatus: attendance.clockOutLocationStatus,
        verifiedOfficeLocationId: attendance.clockOutVerifiedOfficeLocationId,
        verifiedOfficeName:
            officesById[attendance.clockOutVerifiedOfficeLocationId]
                ?.officeName,
        nearestOfficeLocationId: attendance.clockOutNearestOfficeLocationId,
        nearestOfficeName:
            officesById[attendance.clockOutNearestOfficeLocationId]?.officeName,
        distanceMeters: attendance.clockOutDistanceMeters,
        geofenceRadiusMeters: attendance.clockOutGeofenceRadiusMeters,
      ),
    );
  }

  SupervisorAttendanceStatus _statusWithoutAttendance({
    required DateTime date,
    required String? leaveStatus,
    required bool isWorkday,
  }) {
    if (!isWorkday) {
      return SupervisorAttendanceStatus.nonWorkingDay;
    }
    if (leaveStatus == 'approved') {
      return SupervisorAttendanceStatus.onLeave;
    }
    if (leaveStatus == 'pending') {
      return SupervisorAttendanceStatus.leavePending;
    }
    final DateTime today = _dateOnly(DateTime.now());
    if (date.isBefore(today) && isWorkday) {
      return SupervisorAttendanceStatus.absent;
    }
    return SupervisorAttendanceStatus.noClockIn;
  }

  SupervisorAttendanceStatus _statusFromAttendance(String? status) {
    switch (status) {
      case 'on_duty':
        return SupervisorAttendanceStatus.onDuty;
      case 'completed':
        return SupervisorAttendanceStatus.completed;
      case 'missed_punch':
        return SupervisorAttendanceStatus.missedPunch;
      case 'correction_pending':
        return SupervisorAttendanceStatus.correctionPending;
      case 'leave_pending':
        return SupervisorAttendanceStatus.leavePending;
      case 'on_leave':
        return SupervisorAttendanceStatus.onLeave;
      case 'absent':
        return SupervisorAttendanceStatus.absent;
      default:
        return SupervisorAttendanceStatus.noClockIn;
    }
  }

  _OfficeLookup? _officeLookupForAttendance(
    SupabaseAttendanceRecord attendance,
    Map<String, _OfficeLookup> officesById,
  ) {
    final String? officeId =
        attendance.clockInVerifiedOfficeLocationId ??
        attendance.clockInNearestOfficeLocationId ??
        attendance.clockOutVerifiedOfficeLocationId ??
        attendance.clockOutNearestOfficeLocationId;
    if (officeId == null) {
      return null;
    }
    return officesById[officeId];
  }

  Duration? _workedDuration(SupabaseAttendanceRecord attendance) {
    if (attendance.clockInAt == null) {
      return null;
    }
    if (attendance.clockOutAt != null &&
        !attendance.clockOutAt!.isBefore(attendance.clockInAt!)) {
      return attendance.clockOutAt!.difference(attendance.clockInAt!);
    }
    if (attendance.status == 'on_duty') {
      return DateTime.now().difference(attendance.clockInAt!);
    }
    return null;
  }

  SupervisorAttendanceSummary _summaryFor(
    List<SupervisorAttendanceEmployeeRecord> records,
  ) {
    return SupervisorAttendanceSummary(
      totalEmployees: records.length,
      clockedIn: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) => record.hasClockedIn,
          )
          .length,
      clockedOut: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) => record.hasClockedOut,
          )
          .length,
      absent: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.status == SupervisorAttendanceStatus.absent,
          )
          .length,
      onLeave: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.status == SupervisorAttendanceStatus.onLeave,
          )
          .length,
      locationExceptions: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.hasLocationException,
          )
          .length,
    );
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

  String _attendanceKey({required String userId, required String dateLabel}) {
    return '$userId::$dateLabel';
  }
}

class _DashboardEmployee {
  const _DashboardEmployee({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    this.department,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String? department;

  factory _DashboardEmployee.fromMap(Map<String, dynamic> map) {
    return _DashboardEmployee(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      department: map['department'] as String?,
    );
  }
}

class _OfficeLookup {
  const _OfficeLookup({
    required this.id,
    required this.officeName,
    this.province,
    this.district,
  });

  final String id;
  final String officeName;
  final String? province;
  final String? district;
}

ClockLocationSnapshot? _locationSnapshot({
  required double? latitude,
  required double? longitude,
  required double? accuracyMeters,
  required bool? isInsideGeofence,
  required String? locationStatus,
  required String? verifiedOfficeLocationId,
  required String? verifiedOfficeName,
  required String? nearestOfficeLocationId,
  required String? nearestOfficeName,
  required double? distanceMeters,
  required double? geofenceRadiusMeters,
}) {
  if (latitude == null || longitude == null) {
    if (locationStatus == null && isInsideGeofence == null) {
      return null;
    }

    final ClockLocationStatus status = locationStatus == null
        ? ((isInsideGeofence ?? false)
              ? ClockLocationStatus.insideOffice
              : ClockLocationStatus.locationUnavailable)
        : ClockLocationStatusLabels.fromDbValue(locationStatus);

    return ClockLocationSnapshot(
      coordinates: 'Not captured',
      accuracyMeters: accuracyMeters ?? 0,
      status: status,
      verifiedOfficeLocationId: verifiedOfficeLocationId,
      verifiedOfficeName: verifiedOfficeName,
      nearestOfficeLocationId: nearestOfficeLocationId,
      nearestOfficeName: nearestOfficeName,
      distanceMeters: distanceMeters,
      geofenceRadiusMeters: geofenceRadiusMeters,
    );
  }

  final ClockLocationStatus status = locationStatus == null
      ? ((isInsideGeofence ?? false)
            ? ClockLocationStatus.insideOffice
            : ClockLocationStatus.outsideAllOffices)
      : ClockLocationStatusLabels.fromDbValue(locationStatus);

  return ClockLocationSnapshot(
    coordinates:
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    accuracyMeters: accuracyMeters ?? 0,
    status: status,
    latitude: latitude,
    longitude: longitude,
    verifiedOfficeLocationId: verifiedOfficeLocationId,
    verifiedOfficeName: verifiedOfficeName,
    nearestOfficeLocationId: nearestOfficeLocationId,
    nearestOfficeName: nearestOfficeName,
    distanceMeters: distanceMeters,
    geofenceRadiusMeters: geofenceRadiusMeters,
  );
}
