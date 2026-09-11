import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final Geocoding _geocoding = Geocoding();

  static Future<Position?> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    final lastKnownAge = lastKnown == null
        ? null
        : DateTime.now().difference(lastKnown.timestamp);
    if (lastKnown != null &&
        lastKnownAge != null &&
        lastKnownAge <= const Duration(seconds: 30)) {
      return lastKnown;
    }

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high);

    return Geolocator.getCurrentPosition(locationSettings: locationSettings);
  }

  static Future<String?> getLocationName(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return null;
      }

      final place = placemarks.first;

      final streetName = place.thoroughfare?.trim();
      final streetNumber = place.subThoroughfare?.trim();

      final neighborhood = place.subLocality?.trim();
      final city = place.locality?.trim();
      final state = place.administrativeArea?.trim();

      final parts = <String>[];

      // Rua + número
      if (streetName != null && streetName.isNotEmpty) {
        if (streetNumber != null && streetNumber.isNotEmpty) {
          parts.add('$streetName, $streetNumber');
        } else {
          parts.add(streetName);
        }
      } else {
        // Fallback caso o sistema não retorne "thoroughfare"
        final street = place.street?.trim();

        if (street != null && street.isNotEmpty) {
          parts.add(street);
        }
      }

      // Bairro
      if (neighborhood != null && neighborhood.isNotEmpty) {
        parts.add(neighborhood);
      }

      // Cidade
      if (city != null && city.isNotEmpty) {
        parts.add(city);
      }

      // Estado
      if (state != null && state.isNotEmpty) {
        parts.add(state);
      }

      if (parts.isEmpty) {
        return null;
      }

      return parts.join(', ');
    } catch (e) {
      debugPrint('Erro ao obter endereço: $e');
      return null;
    }
  }
}
