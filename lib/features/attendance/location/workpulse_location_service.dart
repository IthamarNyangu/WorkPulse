import 'package:geolocator/geolocator.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';

class WorkPulseLocationResult {
  const WorkPulseLocationResult({
    required this.snapshot,
    required this.message,
    required this.activeOfficeCount,
  });

  final ClockLocationSnapshot? snapshot;
  final String? message;
  final int activeOfficeCount;

  bool get hasLocation => snapshot != null;
  ClockLocationStatus get status =>
      snapshot?.status ?? ClockLocationStatus.locationUnavailable;
}

class WorkPulseLocationService {
  WorkPulseLocationService({
    OfficeLocationService? officeLocationService,
    this.lowAccuracyThresholdMeters = 100,
  }) : _officeLocationService =
           officeLocationService ?? OfficeLocationService();

  final OfficeLocationService _officeLocationService;
  final double lowAccuracyThresholdMeters;

  Future<WorkPulseLocationResult> captureCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _unavailable('Location services are turned off.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return _unavailable('Location permission was not granted.');
    }
    if (permission == LocationPermission.deniedForever) {
      return _unavailable(
        'Location permission is blocked. Enable it in Android settings.',
      );
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final List<OfficeLocation> offices = await _officeLocationService
          .fetchActiveOffices();
      final _NearestOfficeResult? nearest = _nearestOffice(
        position: position,
        offices: offices,
      );

      if (nearest == null) {
        return WorkPulseLocationResult(
          snapshot: _snapshot(
            position: position,
            status: ClockLocationStatus.noOfficesConfigured,
          ),
          message: 'No active WorkPulse office locations are configured yet.',
          activeOfficeCount: offices.length,
        );
      }

      final bool isLowAccuracy = position.accuracy > lowAccuracyThresholdMeters;
      final bool isInsideOffice =
          nearest.distanceMeters <= nearest.office.radiusMeters;
      final ClockLocationStatus status = isLowAccuracy
          ? ClockLocationStatus.lowAccuracy
          : isInsideOffice
          ? ClockLocationStatus.insideOffice
          : ClockLocationStatus.outsideAllOffices;

      return WorkPulseLocationResult(
        snapshot: _snapshot(
          position: position,
          status: status,
          verifiedOffice: status == ClockLocationStatus.insideOffice
              ? nearest.office
              : null,
          nearestOffice: nearest.office,
          distanceMeters: nearest.distanceMeters,
          geofenceRadiusMeters: nearest.office.radiusMeters,
        ),
        message: null,
        activeOfficeCount: offices.length,
      );
    } catch (_) {
      return _unavailable('Unable to read current location.');
    }
  }

  ClockLocationSnapshot _snapshot({
    required Position position,
    required ClockLocationStatus status,
    OfficeLocation? verifiedOffice,
    OfficeLocation? nearestOffice,
    double? distanceMeters,
    double? geofenceRadiusMeters,
  }) {
    return ClockLocationSnapshot(
      coordinates:
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      accuracyMeters: position.accuracy,
      status: status,
      verifiedOfficeLocationId: verifiedOffice?.id,
      verifiedOfficeName: verifiedOffice?.officeName,
      nearestOfficeLocationId: nearestOffice?.id,
      nearestOfficeName: nearestOffice?.officeName,
      distanceMeters: distanceMeters,
      geofenceRadiusMeters: geofenceRadiusMeters,
    );
  }

  WorkPulseLocationResult _unavailable(String message) {
    return WorkPulseLocationResult(
      snapshot: null,
      message: message,
      activeOfficeCount: 0,
    );
  }

  _NearestOfficeResult? _nearestOffice({
    required Position position,
    required List<OfficeLocation> offices,
  }) {
    _NearestOfficeResult? nearest;
    for (final OfficeLocation office in offices) {
      final double distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        office.latitude,
        office.longitude,
      );
      if (nearest == null || distanceMeters < nearest.distanceMeters) {
        nearest = _NearestOfficeResult(
          office: office,
          distanceMeters: distanceMeters,
        );
      }
    }
    return nearest;
  }
}

class _NearestOfficeResult {
  const _NearestOfficeResult({
    required this.office,
    required this.distanceMeters,
  });

  final OfficeLocation office;
  final double distanceMeters;
}
