import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  static String? _cleanStreet(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim();
    // Remove numero apos virgula: "Rua Professor Rui Corte Brilho, 1161" -> "Rua Professor Rui Corte Brilho"
    s = s.split(',').first.trim();
    // Remove numero solto no fim: "Rua X 1161" -> "Rua X"
    s = s.replaceFirst(RegExp(r'\s+\d+.*$'), '').trim();
    return s.isNotEmpty ? s : null;
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

      String? street;
      String? neighborhood;
      String? city;
      String? state;

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        street = _cleanStreet(place.thoroughfare) ?? _cleanStreet(place.street);
        neighborhood = place.subLocality?.trim();
        final rawState = place.administrativeArea?.trim();
        final subAdmin = place.subAdministrativeArea?.trim();
        final locality = place.locality?.trim();

        // Resolucao de Municipio/Cidade no Brasil:
        // subAdministrativeArea armazena o municipio (ex: Limeira)
        // locality pode conter a regiao/estado ou ser nulo
        // administrativeArea armazena o estado (ex: Sao Paulo)
        if (subAdmin != null &&
            subAdmin.isNotEmpty &&
            (rawState == null ||
                subAdmin.toLowerCase() != rawState.toLowerCase())) {
          city = subAdmin;
        } else if (locality != null &&
            locality.isNotEmpty &&
            (rawState == null ||
                locality.toLowerCase() != rawState.toLowerCase())) {
          city = locality;
        } else if (subAdmin != null && subAdmin.isNotEmpty) {
          city = subAdmin;
        } else if (locality != null && locality.isNotEmpty) {
          city = locality;
        }

        state = rawState;
      }

      // Se a cidade estiver nula ou foi identificada apenas como o estado (ex: "Sao Paulo"),
      // fazemos uma consulta complementar ao OpenStreetMap Nominatim para obter o municipio exato
      if (city == null ||
          (state != null && city.toLowerCase() == state.toLowerCase())) {
        try {
          final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=json&addressdetails=1',
          );
          final response = await http.get(
            uri,
            headers: {'User-Agent': 'GatalogoApp/2.0 (contato@gatalogo.app)'},
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final addr = data['address'] as Map<String, dynamic>?;
            if (addr != null) {
              final nomCity = addr['city'] as String? ??
                  addr['town'] as String? ??
                  addr['municipality'] as String? ??
                  addr['village'] as String?;
              if (nomCity != null && nomCity.trim().isNotEmpty) {
                city = nomCity.trim();
              }
              if (street == null || street.isEmpty) {
                street = _cleanStreet(addr['road'] as String?);
              }
              if (neighborhood == null || neighborhood.isEmpty) {
                neighborhood = (addr['suburb'] as String? ??
                        addr['neighbourhood'] as String? ??
                        addr['city_district'] as String?)
                    ?.trim();
              }
              if (state == null || state.isEmpty) {
                state = (addr['state'] as String?)?.trim();
              }
            }
          }
        } catch (_) {
          // Ignora erro de rede mantendo os dados locais
        }
      }

      final parts = <String>[];

      // Rua (omitindo numero residencial para proteger privacidade)
      if (street != null && street.isNotEmpty) {
        parts.add(street);
      }

      // Bairro
      if (neighborhood != null &&
          neighborhood.isNotEmpty &&
          neighborhood.toLowerCase() != city?.toLowerCase()) {
        parts.add(neighborhood);
      }

      // Cidade (Municipio)
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
