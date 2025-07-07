// lib/config/app_config.dart
class AppConfig {
  // API endpoints
  static const bool useLocalEndpoint = true; // Use the local API server
  static const String localApiUrl = 'http://127.0.0.1:8000'; // Use localhost
  static const String productionApiUrl = 'https://api.elephasai.com';

  // Feature flags
  static const bool enableOfflineDetection = true;
  static const bool enableCloudSync = true;
  static const bool enableTelemetry = true;

  // Performance settings
  static const int cacheMaxSize = 1000;
  static const Duration cacheExpiry = Duration(days: 7);

  // Security settings
  static const bool enableCertificatePinning = true;

  // Get the appropriate API URL based on environment
  static String get apiUrl {
    return useLocalEndpoint ? localApiUrl : productionApiUrl;
  }

  // For development logging
  static const bool verbose = true; // Enable detailed logging for testing

  // Testing mode
  static const bool testingMode =
      true; // This enables more frequent checks for features
}
