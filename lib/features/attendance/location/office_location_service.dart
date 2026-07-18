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
    required this.isActive,
    this.province,
    this.district,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String officeName;
  final String? province;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final String? district;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OfficeLocation.fromMap(Map<String, dynamic> map) {
    return OfficeLocation(
      id: map['id'] as String,
      officeName: map['office_name'] as String,
      province: map['province'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: (map['radius_m'] as num).toDouble(),
      isActive: map['is_active'] as bool? ?? true,
      district: map['district'] as String?,
      createdAt: _dateTimeFromMap(map['created_at']),
      updatedAt: _dateTimeFromMap(map['updated_at']),
    );
  }

  static DateTime? _dateTimeFromMap(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value as String);
  }
}

class OfficeLocationService {
  OfficeLocationService({SupabaseClient? client}) : _client = client;

  static const String tableName = 'office_locations';
  static const String _selectColumns =
      'id, office_name, province, district, latitude, longitude, radius_m, '
      'is_active, created_at, updated_at';

  final SupabaseClient? _client;

  Future<List<OfficeLocation>> fetchActiveOffices() async {
    if (_client == null && !SupabaseBootstrap.isInitialized) {
      return const <OfficeLocation>[];
    }
    final SupabaseClient client = _client ?? SupabaseBootstrap.client;

    try {
      final List<dynamic> rows = await client
          .from(tableName)
          .select(_selectColumns)
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

  Future<List<OfficeLocation>> fetchOfficeLocations() async {
    final SupabaseClient client = _requiredClient();

    final List<dynamic> rows = await client
        .from(tableName)
        .select(_selectColumns)
        .order('is_active', ascending: false)
        .order('office_name', ascending: true);

    return rows
        .map(
          (dynamic row) =>
              OfficeLocation.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<OfficeLocation> createOfficeLocation({
    required String officeName,
    required String? province,
    required String? district,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final SupabaseClient client = _requiredClient();

    final Map<String, dynamic> row = await client
        .from(tableName)
        .insert(<String, dynamic>{
          'office_name': officeName,
          'province': _blankToNull(province),
          'district': _blankToNull(district),
          'latitude': latitude,
          'longitude': longitude,
          'radius_m': radiusMeters,
          'is_active': true,
          'created_by': client.auth.currentUser?.id,
        })
        .select(_selectColumns)
        .single();

    return OfficeLocation.fromMap(row);
  }

  Future<OfficeLocation> updateOfficeLocation({
    required String id,
    required String officeName,
    required String? province,
    required String? district,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required bool isActive,
  }) async {
    final SupabaseClient client = _requiredClient();

    final Map<String, dynamic> row = await client
        .from(tableName)
        .update(<String, dynamic>{
          'office_name': officeName,
          'province': _blankToNull(province),
          'district': _blankToNull(district),
          'latitude': latitude,
          'longitude': longitude,
          'radius_m': radiusMeters,
          'is_active': isActive,
        })
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return OfficeLocation.fromMap(row);
  }

  Future<OfficeLocation> setOfficeActive({
    required String id,
    required bool isActive,
  }) async {
    final SupabaseClient client = _requiredClient();

    final Map<String, dynamic> row = await client
        .from(tableName)
        .update(<String, dynamic>{'is_active': isActive})
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return OfficeLocation.fromMap(row);
  }

  SupabaseClient _requiredClient() {
    if (_client != null) {
      return _client;
    }
    return SupabaseBootstrap.client;
  }

  String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
