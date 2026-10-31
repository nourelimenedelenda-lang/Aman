import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/current_location.dart';
import '../../domain/repositories/location_repository.dart';

class DeviceLocationRepository implements LocationRepository {
  @override
  Future<LocationAccessStatus> getAccessStatus() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccessStatus.servicesDisabled;
    }

    return _toAccessStatus(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccessStatus> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccessStatus.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _toAccessStatus(permission);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  LocationAccessStatus _toAccessStatus(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccessStatus.granted,
      LocationPermission.deniedForever =>
        LocationAccessStatus.permanentlyDenied,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => LocationAccessStatus.denied,
    };
  }

  @override
  Future<CurrentLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Location services are turned off. Enable them and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission was denied. Allow location access to see your position.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is blocked. Enable it in your device settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    var address = 'Address unavailable';
    var addressUnavailable = true;
    if (GeocodingPlatformFactory.instance != null) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final locality = place.locality ?? place.subAdministrativeArea;
          final parts = <String>[
            if (place.thoroughfare?.isNotEmpty == true) place.thoroughfare!,
            if (place.subThoroughfare?.isNotEmpty == true)
              place.subThoroughfare!,
            if (locality?.isNotEmpty == true) locality!,
            if (place.country?.isNotEmpty == true) place.country!,
          ];
          if (parts.isNotEmpty) {
            address = parts.join(', ');
            addressUnavailable = false;
          }
        }
      } on PlatformException {
        // The GPS fix is still useful if the platform geocoder is unavailable.
      } on MissingPluginException {
        // Some platforms provide GPS without a reverse-geocoding plugin.
      }
    }

    return CurrentLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
      address: address,
      addressUnavailable: addressUnavailable,
    );
  }
}
