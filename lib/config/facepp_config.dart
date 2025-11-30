// lib/config/facepp_config.dart
class FacePPConfig {
  // Vos clés Face++ - Free Tier
  static const String API_KEY = 'vDB5YrBsPMhYbCjcp016HwFk-U0SwBLF';
  static const String API_SECRET = 'hyVHMgvOq7bvNOP3-bea0LPSyYpub3jC';

  // Configuration
  static const double SIMILARITY_THRESHOLD = 70.0;
  static const String BASE_URL = 'https://api-us.faceplusplus.com/facepp/v3';

  // Limites du plan gratuit
  static const int FREE_TIER_LIMIT = 10000; // 10,000 appels/mois

  static bool get isConfigured => API_KEY.isNotEmpty && API_SECRET.isNotEmpty;

  static void validateConfig() {
    if (!isConfigured) {
      throw Exception('Configuration Face++ manquante!');
    }
  }
}