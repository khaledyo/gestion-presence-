// lib/services/face_recognition_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/facepp_config.dart';

class FaceRecognitionService {
  // Ajouter des délais pour respecter les limites
  static const Duration API_DELAY = Duration(milliseconds: 1000);

  static Future<Map<String, dynamic>> verifyFaceMatch(
      Uint8List capturedImageBytes,
      String userUid
      ) async {
    try {
      FacePPConfig.validateConfig();

      // Récupérer l'URL de la photo de profil
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Utilisateur non trouvé dans la base de données');
      }

      final userData = userDoc.data()!;
      final profileImageUrl = userData['profilePicture'] as String?;

      if (profileImageUrl == null || profileImageUrl.isEmpty) {
        throw Exception('Aucune photo de profil trouvée pour cet utilisateur');
      }

      print('🔄 Début de la vérification faciale Face++ pour: $userUid');

      // Étape 1: Détecter les visages dans l'image capturée
      final String faceToken1 = await _detectFace(capturedImageBytes);

      // Délai entre les appels API
      await Future.delayed(API_DELAY);

      // Étape 2: Détecter les visages dans la photo de profil
      final Uint8List profileImageBytes = await _downloadImage(profileImageUrl);
      final String faceToken2 = await _detectFace(profileImageBytes);

      // Délai entre les appels API
      await Future.delayed(API_DELAY);

      // Étape 3: Comparer les deux visages
      final double similarity = await _compareFaces(faceToken1, faceToken2);

      print('🔍 Résultat Face++ - Similarité: ${similarity.toStringAsFixed(2)}%');

      return {
        'success': true,
        'confidence': similarity,
        'isMatch': similarity >= FacePPConfig.SIMILARITY_THRESHOLD,
        'message': 'Analyse faciale terminée',
      };

    } catch (e) {
      print('❌ Erreur vérification faciale: $e');
      return {
        'success': false,
        'confidence': 0.0,
        'isMatch': false,
        'error': e.toString(),
      };
    }
  }

  // Détecter un visage et retourner son face_token
  static Future<String> _detectFace(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('${FacePPConfig.BASE_URL}/detect');

      var request = http.MultipartRequest('POST', uri)
        ..fields.addAll({
          'api_key': FacePPConfig.API_KEY,
          'api_secret': FacePPConfig.API_SECRET,
          'return_landmark': '0',
          'return_attributes': 'none',
        })
        ..files.add(http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: 'face.jpg',
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final Map<String, dynamic> data = json.decode(responseBody);

      if (response.statusCode != 200) {
        // Gérer spécifiquement l'erreur de limite
        if (data['error_message']?.toString().contains('Concurrency') ?? false) {
          throw Exception('Limite de requêtes simultanées dépassée. Réessayez dans quelques secondes.');
        }
        throw Exception('Erreur API Face++: ${data['error_message'] ?? 'Unknown error'}');
      }

      if (data['faces'] == null || (data['faces'] as List).isEmpty) {
        throw Exception('Aucun visage détecté dans l\'image');
      }

      final String faceToken = data['faces'][0]['face_token'];
      print('✅ Visage détecté - Token: ${faceToken.substring(0, 10)}...');

      return faceToken;

    } catch (e) {
      print('❌ Erreur détection Face++: $e');
      throw Exception('Impossible de détecter un visage: ${e.toString()}');
    }
  }

  // Comparer deux visages avec Face++ Compare API
  static Future<double> _compareFaces(String faceToken1, String faceToken2) async {
    try {
      final uri = Uri.parse('${FacePPConfig.BASE_URL}/compare');

      final response = await http.post(
        uri,
        body: {
          'api_key': FacePPConfig.API_KEY,
          'api_secret': FacePPConfig.API_SECRET,
          'face_token1': faceToken1,
          'face_token2': faceToken2,
        },
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode != 200) {
        final errorMsg = data['error_message'] ?? 'HTTP ${response.statusCode}';

        // Gérer spécifiquement l'erreur de limite de concurrence
        if (errorMsg.toString().contains('Concurrency')) {
          throw Exception('Limite de requêtes simultanées dépassée. Réessayez dans quelques secondes.');
        }

        throw Exception('Erreur comparaison Face++: $errorMsg');
      }

      final double confidence = data['confidence']?.toDouble() ?? 0.0;
      print('📊 Score de confiance Face++: $confidence');

      return confidence;

    } catch (e) {
      print('❌ Erreur comparaison Face++: $e');
      throw Exception('Erreur lors de la comparaison des visages: ${e.toString()}');
    }
  }

  // Télécharger une image depuis une URL
  static Future<Uint8List> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception('Erreur téléchargement image: ${response.statusCode}');
    } catch (e) {
      print('❌ Erreur téléchargement image: $e');
      throw Exception('Impossible de télécharger l\'image de profil: ${e.toString()}');
    }
  }

  // Vérifier si l'API Face++ est accessible
  static Future<bool> checkAPIStatus() async {
    try {
      final testImage = Uint8List.fromList(List.generate(100, (index) => 0));
      await _detectFace(testImage);
      return true;
    } catch (e) {
      print('❌ Face++ API non accessible: $e');
      return false;
    }
  }
}