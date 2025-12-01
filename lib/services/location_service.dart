// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  //location kelibia centre
  //static const double _establishmentLatitude = 36.84374;
  // static const double _establishmentLongitude = 11.09964;

  // COORDONNÉES DE  ÉTABLISSEMENT (Université)
  static const double _establishmentLatitude = 36.85333;  // 36° 51′ 12″ N
  static const double _establishmentLongitude = 11.05886; // 11° 3′ 32″ E


  // Périmètre autorisé (en mètres)
  static const double _allowedRadiusMeters = 150.0; // 200m pour couvrir le campus universitaire

  // Vérifier si la géolocalisation est activée
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Obtenir la position actuelle
  static Future<Position> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw "Permission de locafvfb blisation refusée";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw "Permission de localisation définitivement refusée. Activez-la dans les paramètres de l'appareil.";
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 15),
    );
  }

  // Calculer la distance entre la position actuelle et l'établissement
  static double calculateDistance(double currentLat, double currentLng) {
    return Geolocator.distanceBetween(
      _establishmentLatitude,
      _establishmentLongitude,
      currentLat,
      currentLng,
    );
  }

  // Vérifier si l'étudiant est dans le périmètre autorisé
  static Future<Map<String, dynamic>> verifyLocation() async {
    try {
      // Vérifier si le GPS est activé
      bool gpsEnabled = await isLocationServiceEnabled();
      if (!gpsEnabled) {
        throw "Veuillez activer votre GPS pour valider la présence";
      }

      // Obtenir la position actuelle
      Position position = await getCurrentPosition();

      // Calculer la distance
      double distance = calculateDistance(position.latitude, position.longitude);

      print("📍 Université - Distance: ${distance.toStringAsFixed(2)} mètres");
      print("📍 Position actuelle: ${position.latitude}, ${position.longitude}");
      print("📍 Établissement: $_establishmentLatitude, $_establishmentLongitude");

      return {
        'isWithinEstablishment': distance <= _allowedRadiusMeters,
        'distance': distance,
        'position': position,
        'establishmentCoords': '$_establishmentLatitude, $_establishmentLongitude'
      };

    } catch (e) {
      print("❌ Erreur géolocalisation: $e");
      rethrow;
    }
  }

  // Stocker la preuve de localisation dans Firestore
  static Future<void> storeLocationProof({
    required String attendanceId,
    required String studentUid,
    required String classId,
    required bool isWithinRadius,
    required double distance,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    await FirebaseFirestore.instance.collection('location_proofs').add({
      'attendanceId': attendanceId,
      'studentUid': studentUid,
      'classId': classId,
      'isWithinRadius': isWithinRadius,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': Timestamp.now(),
      'establishmentLatitude': _establishmentLatitude,
      'establishmentLongitude': _establishmentLongitude,
      'allowedRadius': _allowedRadiusMeters,
      'establishmentName': 'Université', // Tu peux mettre le nom réel
    });
  }

  // Méthode pour obtenir les infos de l'établissement (pour l'UI)
  static Map<String, dynamic> getEstablishmentInfo() {
    return {
      'latitude': _establishmentLatitude,
      'longitude': _establishmentLongitude,
      'radius': _allowedRadiusMeters,
      'name': 'Université'
    };
  }
}