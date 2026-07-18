import 'dart:developer' as developer;

import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfficeLocation {
  const OfficeLocation({
    required this.id,
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.province,
  });

  final String id;
  final String officeName;
  final String? province;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  factory OfficeLocation.fromMap(Map<String, dynamic> map) {
    return OfficeLocation(
      id: map['id'] as String,
      officeName: map['office_name'] as String,
      province: map['province'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: (map['radius_m'] as num).toDouble(),
    );
  }
}

class OfficeLocationService {
  OfficeLocationService({SupabaseClient? client}) : _client = client;

  static const String tableName = 'office_locations';

  final SupabaseClient? _client;

  Future<List<OfficeLocation>> fetchActiveOffices() async {
    if (_client == null && !SupabaseBootstrap.isInitialized) {
      return const <OfficeLocation>[];
    }
    final SupabaseClient client = _client ?? SupabaseBootstrap.client;

    try {
      final List<dynamic> rows = await client
          .from(tableName)
          .select('id, office_name, province, latitude, longitude, radius_m')
          .eq('is_active', true)
          .order('office_name', ascending: true);

      return rows
          .map(
            (dynamic row) =>
                OfficeLocation.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } catch (error) {
      developer.log(
        'Unable to load active office locations',
        name: 'workpulse.office_locations',
        error: error,
      );
      return const <OfficeLocation>[];
    }
  }
}
