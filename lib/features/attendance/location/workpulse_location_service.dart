import 'package:geolocator/geolocator.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';

class WorkPulseGeofenceConfig {
  const WorkPulseGeofenceConfig({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
}

class WorkPulseLocationResult {
  const WorkPulseLocationResult({
    required this.snapshot,
    required this.message,
    required this.officeDistanceMeters,
    required this.config,
  });

  final ClockLocationSnapshot? snapshot;
  final String? message;
  final double? officeDistanceMeters;
  final WorkPulseGeofenceConfig config;

  bool get hasLocation => snapshot != null;
}

class WorkPulseLocationService {
  WorkPulseLocationService({this.config = defaultConfig});

  static const WorkPulseGeofenceConfig defaultConfig = WorkPulseGeofenceConfig(
    name: 'WorkPulse Demo Office',
    latitude: -15.3875,
    longitude: 28.3228,
    radiusMeters: 150,
  );

  final WorkPulseGeofenceConfig config;

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

      final double distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        config.latitude,
        config.longitude,
      );
      final bool insideGeofence = distanceMeters <= config.radiusMeters;

      return WorkPulseLocationResult(
        snapshot: ClockLocationSnapshot(
          coordinates:
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          accuracyMeters: position.accuracy,
          isInsideGeofence: insideGeofence,
        ),
        message: null,
        officeDistanceMeters: distanceMeters,
        config: config,
      );
    } catch (_) {
      return _unavailable('Unable to read current location.');
    }
  }

  WorkPulseLocationResult _unavailable(String message) {
    return WorkPulseLocationResult(
      snapshot: null,
      message: message,
      officeDistanceMeters: null,
      config: config,
    );
  }
}
