import 'package:pulseclock/features/supervisor/attendance/data/supervisor_attendance_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';

class AttendanceReportExport {
  const AttendanceReportExport({
    required this.fileName,
    required this.csv,
    required this.recordCount,
    required this.generatedAt,
    required this.filterSummary,
  });

  final String fileName;
  final String csv;
  final int recordCount;
  final DateTime generatedAt;
  final String filterSummary;

  String preview({int maxLines = 6}) {
    return csv.split('\n').take(maxLines).join('\n');
  }
}

class AttendanceReportExporter {
  const AttendanceReportExporter();

  AttendanceReportExport buildCsv({
    required List<SupervisorAttendanceEmployeeRecord> records,
    required DateTime startDate,
    required DateTime endDate,
    required String dateRangeLabel,
    required String statusLabel,
    required String departmentLabel,
    required String provinceLabel,
    required String officeLabel,
    required String searchQuery,
  }) {
    final DateTime generatedAt = DateTime.now();
    final String filterSummary = _filterSummary(
      dateRangeLabel: dateRangeLabel,
      statusLabel: statusLabel,
      departmentLabel: departmentLabel,
      provinceLabel: provinceLabel,
      officeLabel: officeLabel,
      searchQuery: searchQuery,
    );

    return AttendanceReportExport(
      fileName: _fileName(
        startDate: startDate,
        endDate: endDate,
        generatedAt: generatedAt,
      ),
      csv: _csvForRecords(records),
      recordCount: records.length,
      generatedAt: generatedAt,
      filterSummary: filterSummary,
    );
  }

  String _csvForRecords(List<SupervisorAttendanceEmployeeRecord> records) {
    final List<List<String>> rows = <List<String>>[
      <String>[
        'Date',
        'Day',
        'Employee Name',
        'Employee ID',
        'Email',
        'Department',
        'Status',
        'Clock In',
        'Clock Out',
        'Work Hours',
        'Office',
        'Province',
        'District',
        'Location Exception',
        'Clock In Location Status',
        'Clock In Office',
        'Clock In Coordinates',
        'Clock In Accuracy (m)',
        'Clock In Distance (m)',
        'Clock Out Location Status',
        'Clock Out Office',
        'Clock Out Coordinates',
        'Clock Out Accuracy (m)',
        'Clock Out Distance (m)',
        'Clock In Comment',
        'Clock Out Comment',
      ],
      for (final SupervisorAttendanceEmployeeRecord record in records)
        <String>[
          dateLabel(record.date),
          weekdayName(record.date),
          record.employeeName,
          record.employeeId,
          record.email,
          record.department ?? '',
          record.status.label,
          record.clockInLabel,
          record.clockOutLabel,
          record.workHoursLabel,
          record.officeDisplayName ?? '',
          record.officeProvince ?? '',
          record.officeDistrict ?? '',
          record.hasLocationException ? 'Yes' : 'No',
          _locationStatus(record.clockInLocation),
          _locationOffice(record.clockInLocation),
          record.clockInLocation?.coordinates ?? '',
          _meters(record.clockInLocation?.accuracyMeters),
          _meters(record.clockInLocation?.distanceMeters),
          _locationStatus(record.clockOutLocation),
          _locationOffice(record.clockOutLocation),
          record.clockOutLocation?.coordinates ?? '',
          _meters(record.clockOutLocation?.accuracyMeters),
          _meters(record.clockOutLocation?.distanceMeters),
          record.clockInComment ?? '',
          record.clockOutComment ?? '',
        ],
    ];

    return rows
        .map((List<String> row) => row.map(_csvCell).join(','))
        .join('\n');
  }

  String _filterSummary({
    required String dateRangeLabel,
    required String statusLabel,
    required String departmentLabel,
    required String provinceLabel,
    required String officeLabel,
    required String searchQuery,
  }) {
    final String trimmedSearch = searchQuery.trim();
    final List<String> filters = <String>[
      'Date: $dateRangeLabel',
      'Status: $statusLabel',
      'Department: $departmentLabel',
      'Province: $provinceLabel',
      'Office: $officeLabel',
      if (trimmedSearch.isNotEmpty) 'Search: $trimmedSearch',
    ];
    return filters.join(' | ');
  }

  String _fileName({
    required DateTime startDate,
    required DateTime endDate,
    required DateTime generatedAt,
  }) {
    return 'workpulse_attendance_${_dateStamp(startDate)}_${_dateStamp(endDate)}_${_dateTimeStamp(generatedAt)}.csv';
  }

  String _locationStatus(ClockLocationSnapshot? location) {
    return location?.status.label ?? '';
  }

  String _locationOffice(ClockLocationSnapshot? location) {
    return location?.officeDisplayName ?? '';
  }

  String _meters(double? value) {
    if (value == null) {
      return '';
    }
    return value.toStringAsFixed(value >= 100 ? 0 : 1);
  }

  String _csvCell(String value) {
    final String escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _dateStamp(DateTime date) {
    final DateTime localDate = DateTime(date.year, date.month, date.day);
    return '${localDate.year}${_twoDigits(localDate.month)}${_twoDigits(localDate.day)}';
  }

  String _dateTimeStamp(DateTime dateTime) {
    final DateTime localDateTime = dateTime.toLocal();
    return '${_dateStamp(localDateTime)}_${_twoDigits(localDateTime.hour)}${_twoDigits(localDateTime.minute)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
