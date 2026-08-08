import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class VisitLocation {
  const VisitLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}

abstract final class LocationService {
  static const Duration _positionTimeout = Duration(seconds: 12);
  static const Duration _geocodeTimeout = Duration(seconds: 8);

  static Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<Position?> getCurrentPosition() async {
    if (!await ensurePermission()) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _positionTimeout,
        ),
      ).timeout(_positionTimeout);
    } catch (_) {
      // Fall back to last known fix so visit start is never blocked by GPS.
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude)
          .timeout(_geocodeTimeout);
      if (places.isEmpty) return _coordinateLabel(latitude, longitude);

      final place = places.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();

      if (parts.isEmpty) return _coordinateLabel(latitude, longitude);
      return parts.join(', ');
    } catch (_) {
      return _coordinateLabel(latitude, longitude);
    }
  }

  static Future<VisitLocation?> getCurrentVisitLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    final address = await reverseGeocode(position.latitude, position.longitude);
    return VisitLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }

  static String _coordinateLabel(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
