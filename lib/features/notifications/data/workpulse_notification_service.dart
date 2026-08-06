import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkPulseNotificationService {
  WorkPulseNotificationService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const String tableName = 'notifications';
  final SupabaseClient _client;

  String get _userId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('A signed-in user is required for notifications.');
    }
    return id;
  }

  Future<List<WorkPulseNotification>> fetchNotifications() async {
    final List<dynamic> rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', _userId)
        .eq('status', 'active')
        .order('occurred_at', ascending: false)
        .limit(100);
    return rows
        .map((dynamic row) => _fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<WorkPulseNotification?> ensureNotification({
    required String eventKey,
    required WorkPulseNotificationType type,
    required String title,
    required String message,
    required DateTime occurredAt,
    String? actionLabel,
    NotificationNavigationTarget? navigationTarget,
    String? attendanceRecordId,
    String? officeLocationId,
  }) async {
    final String userId = _userId;
    final Map<String, dynamic>? existing = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('event_key', eventKey)
        .maybeSingle();
    if (existing != null) {
      return null;
    }

    try {
      final Map<String, dynamic> row = await _client
          .from(tableName)
          .insert(<String, dynamic>{
            'user_id': userId,
            'event_key': eventKey,
            'type': _typeValue(type),
            'title': title,
            'message': message,
            'occurred_at': occurredAt.toUtc().toIso8601String(),
            'action_label': actionLabel,
            'navigation_target': navigationTarget == null
                ? null
                : _targetValue(navigationTarget),
            'attendance_record_id': attendanceRecordId,
            'office_location_id': officeLocationId,
          })
          .select()
          .single();
      return _fromMap(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return null;
      }
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    await _client
        .from(tableName)
        .update(<String, dynamic>{'is_read': true})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> markAllRead() async {
    await _client
        .from(tableName)
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', _userId)
        .eq('status', 'active');
  }

  Future<void> resolveWhere({
    required List<WorkPulseNotificationType> types,
  }) async {
    await _client
        .from(tableName)
        .update(<String, dynamic>{
          'status': 'resolved',
          'is_read': true,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _userId)
        .eq('status', 'active')
        .inFilter('type', types.map(_typeValue).toList(growable: false));
  }

  Future<void> clearAll() async {
    await _client
        .from(tableName)
        .update(<String, dynamic>{
          'status': 'resolved',
          'is_read': true,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _userId)
        .eq('status', 'active');
  }

  Future<void> recordLocationPresence({
    required bool isInsideOffice,
    String? officeLocationId,
  }) async {
    await _client.rpc(
      'record_my_location_presence',
      params: <String, dynamic>{
        'p_state': isInsideOffice ? 'inside_office' : 'outside_offices',
        'p_office_location_id': officeLocationId,
      },
    );
  }

  WorkPulseNotification _fromMap(Map<String, dynamic> map) {
    return WorkPulseNotification(
      id: map['id'] as String,
      eventKey: map['event_key'] as String?,
      type: _typeFromValue(map['type'] as String),
      title: map['title'] as String,
      message: map['message'] as String,
      timestamp: DateTime.parse(map['occurred_at'] as String).toLocal(),
      isRead: map['is_read'] as bool? ?? false,
      actionLabel: map['action_label'] as String?,
      navigationTarget: _targetFromValue(map['navigation_target'] as String?),
      attendanceRecordId: map['attendance_record_id'] as String?,
      correctionRequestId: map['correction_request_id'] as String?,
      leaveRequestId: map['leave_request_id'] as String?,
    );
  }

  String _typeValue(WorkPulseNotificationType type) {
    switch (type) {
      case WorkPulseNotificationType.clockInReminder:
        return 'clock_in_reminder';
      case WorkPulseNotificationType.clockOutReminder:
        return 'clock_out_reminder';
      case WorkPulseNotificationType.missedPunchReminder:
        return 'missed_punch_reminder';
      case WorkPulseNotificationType.leaveUpdate:
        return 'leave_update';
      case WorkPulseNotificationType.generalInfo:
        return 'general_info';
    }
  }

  WorkPulseNotificationType _typeFromValue(String value) {
    switch (value) {
      case 'clock_in_reminder':
        return WorkPulseNotificationType.clockInReminder;
      case 'clock_out_reminder':
        return WorkPulseNotificationType.clockOutReminder;
      case 'missed_punch_reminder':
        return WorkPulseNotificationType.missedPunchReminder;
      case 'leave_update':
        return WorkPulseNotificationType.leaveUpdate;
      default:
        return WorkPulseNotificationType.generalInfo;
    }
  }

  String _targetValue(NotificationNavigationTarget target) {
    return switch (target) {
      NotificationNavigationTarget.clockInConfirmation => 'clock_in',
      NotificationNavigationTarget.clockOutConfirmation => 'clock_out',
      NotificationNavigationTarget.correctionList => 'correction_list',
      NotificationNavigationTarget.correctionDetails => 'correction_details',
      NotificationNavigationTarget.leaveList => 'leave_list',
      NotificationNavigationTarget.leaveDetails => 'leave_details',
    };
  }

  NotificationNavigationTarget? _targetFromValue(String? value) {
    return switch (value) {
      'clock_in' => NotificationNavigationTarget.clockInConfirmation,
      'clock_out' => NotificationNavigationTarget.clockOutConfirmation,
      'correction_list' => NotificationNavigationTarget.correctionList,
      'correction_details' => NotificationNavigationTarget.correctionDetails,
      'leave_list' => NotificationNavigationTarget.leaveList,
      'leave_details' => NotificationNavigationTarget.leaveDetails,
      _ => null,
    };
  }
}
