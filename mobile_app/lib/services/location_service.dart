import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Détermine la position actuelle.
  /// Demande la permission si nécessaire.
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Vérifier si le GPS est activé sur le téléphone
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Le service de localisation est désactivé.');
    }

    // 2. Vérifier les permissions de l'application
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Les permissions de localisation sont refusées.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Les permissions sont définitivement refusées, nous ne pouvons pas demander l\'accès.');
    }

    // 3. Récupérer la position actuelle (Précision élevée)
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}