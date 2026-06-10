import 'package:geolocator/geolocator.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../utils/geo_utils.dart';

class GeofenceFailure implements Exception {
  GeofenceFailure(this.message);
  final String message;
}

class GeofenceService {
  /// Returns true if login is allowed. No geofence configured → always allowed.
  Future<bool> isWithinGeofence(String societyId) async {
    if (!Env.isConfigured) return true;

    final rows = await SupabaseBootstrap.client
        .from('geofence_settings')
        .select('*')
        .eq('society_id', societyId)
        .order('created_at', ascending: false)
        .limit(1);

    if ((rows as List).isEmpty) return true;

    final geo = Map<String, dynamic>.from(rows.first as Map);
    final lat = (geo['latitude'] as num).toDouble();
    final lng = (geo['longitude'] as num).toDouble();
    final radius = (geo['radius_meters'] as num?)?.toDouble() ?? 100;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw GeofenceFailure('Location services are off. Enable GPS to login.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw GeofenceFailure('Location permission required for guard login.');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final dist = distanceMeters(pos.latitude, pos.longitude, lat, lng);
    if (dist > radius) {
      throw GeofenceFailure('You are outside the allowed zone (${dist.round()}m away). Contact admin.');
    }
    return true;
  }
}
