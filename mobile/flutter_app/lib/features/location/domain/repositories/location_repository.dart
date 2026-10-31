import '../entities/current_location.dart';

abstract interface class LocationRepository {
  Future<CurrentLocation> getCurrentLocation();

  Future<LocationAccessStatus> getAccessStatus();

  Future<LocationAccessStatus> requestAccess();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

enum LocationAccessStatus {
  granted,
  denied,
  permanentlyDenied,
  servicesDisabled,
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
