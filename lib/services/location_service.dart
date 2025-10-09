// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Konum servisinin etkin olup olmadığını kontrol et
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        throw Exception('Konum izni reddedildi veya konum servisleri kapalı');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Konum alma hatası: $e');
      return null;
    }
  }

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  static bool isWithinRadius(
    double currentLat,
    double currentLon,
    double targetLat,
    double targetLon,
    double radiusMeters,
  ) {
    final distance = calculateDistance(currentLat, currentLon, targetLat, targetLon);
    return distance <= radiusMeters;
  }
}