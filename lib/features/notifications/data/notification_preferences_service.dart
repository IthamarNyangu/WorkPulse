import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.basicAttendanceEnabled = true,
    this.smartLocationEnabled = false,
    this.requestUpdatesEnabled = true,
    this.pushEnabled = true,
  });

  final bool basicAttendanceEnabled;
  final bool smartLocationEnabled;
  final bool requestUpdatesEnabled;
  final bool pushEnabled;

  NotificationPreferences copyWith({
    bool? basicAttendanceEnabled,
    bool? smartLocationEnabled,
    bool? requestUpdatesEnabled,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      basicAttendanceEnabled:
          basicAttendanceEnabled ?? this.basicAttendanceEnabled,
      smartLocationEnabled:
          smartLocationEnabled ?? this.smartLocationEnabled,
      requestUpdatesEnabled:
          requestUpdatesEnabled ?? this.requestUpdatesEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      basicAttendanceEnabled:
          map['basic_attendance_enabled'] as bool? ?? true,
      smartLocationEnabled:
          map['smart_location_enabled'] as bool? ?? false,
      requestUpdatesEnabled: map['request_updates_enabled'] as bool? ?? true,
      pushEnabled: map['push_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return <String, dynamic>{
      'user_id': userId,
      'basic_attendance_enabled': basicAttendanceEnabled,
      'smart_location_enabled': smartLocationEnabled,
      'request_updates_enabled': requestUpdatesEnabled,
      'push_enabled': pushEnabled,
    };
  }
}

class NotificationPreferencesService {
  NotificationPreferencesService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  String get _userId {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required.');
    }
    return userId;
  }

  Future<NotificationPreferences> fetch() async {
    final Map<String, dynamic>? row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    if (row != null) {
      return NotificationPreferences.fromMap(row);
    }

    const NotificationPreferences defaults = NotificationPreferences();
    final Map<String, dynamic> inserted = await _client
        .from('notification_preferences')
        .upsert(defaults.toMap(_userId), onConflict: 'user_id')
        .select()
        .single();
    return NotificationPreferences.fromMap(inserted);
  }

  Future<NotificationPreferences> save(
    NotificationPreferences preferences,
  ) async {
    final Map<String, dynamic> row = await _client
        .from('notification_preferences')
        .upsert(preferences.toMap(_userId), onConflict: 'user_id')
        .select()
        .single();
    return NotificationPreferences.fromMap(row);
  }
}
