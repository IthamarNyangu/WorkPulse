import 'package:flutter/services.dart';

class SavedAttendanceReport {
  const SavedAttendanceReport({required this.uri, required this.fileName});

  final String uri;
  final String fileName;
}

class AttendanceReportFileSaver {
  const AttendanceReportFileSaver();

  static const MethodChannel _channel = MethodChannel('workpulse/file_saver');

  Future<SavedAttendanceReport?> saveCsv({
    required String fileName,
    required String csv,
  }) async {
    final Map<Object?, Object?>? savedDocument = await _channel
        .invokeMethod<Map<Object?, Object?>>('saveCsv', {
          'fileName': fileName,
          'csv': csv,
        });
    if (savedDocument == null) {
      return null;
    }

    return SavedAttendanceReport(
      uri: savedDocument['uri']! as String,
      fileName: savedDocument['fileName']! as String,
    );
  }

  Future<void> openSavedCsv(SavedAttendanceReport report) {
    return _channel.invokeMethod<void>('openSavedCsv', {'uri': report.uri});
  }

  Future<void> shareSavedCsv(SavedAttendanceReport report) {
    return _channel.invokeMethod<void>('shareSavedCsv', {
      'uri': report.uri,
      'fileName': report.fileName,
    });
  }

  Future<void> shareCsv({required String fileName, required String csv}) {
    return _channel.invokeMethod<void>('shareCsv', {
      'fileName': fileName,
      'csv': csv,
    });
  }
}
