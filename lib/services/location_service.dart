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
      final neighborhood = place.subLocality?.trim();
      final city = place.locality?.trim();
      final state = place.administrativeArea?.trim();

      final parts = <String>[];

      // Rua (omitindo propositalmente o número residencial para proteger a privacidade)
      if (streetName != null && streetName.isNotEmpty) {
        parts.add(streetName);
      } else {
        // Fallback caso o sistema não retorne "thoroughfare"
        final street = place.street?.trim();
        if (street != null && street.isNotEmpty) {
          // Se o campo street contiver vírgula com número, removemos o número
          final cleanStreet = street.split(',').first.trim();
          if (cleanStreet.isNotEmpty) {
            parts.add(cleanStreet);
          }
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

  /// Geocodificação direta: busca latitude e longitude a partir de um texto de endereço/bairro.
  static Future<List<Location>> searchAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      return await _geocoding.locationFromAddress(cleanQuery);
    } catch (e) {
      debugPrint('Erro ao buscar endereço por texto: $e');
      return [];
    }
  }
}
