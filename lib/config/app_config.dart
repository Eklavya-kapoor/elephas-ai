// lib/config/app_config.dart
class AppConfig {
  // API endpoints
  static const bool useLocalEndpoint = false; // false = use cloudRunApiUrl (now on Cloud Run, verified working)
  static const String localApiUrl =
      'http://172.20.10.4:8000'; // Local development server - MUST match the WiFi IP of the machine running start_server.py (run `ifconfig | grep inet` there to check/update before each demo)
  static const String cloudRunApiUrl =
      'https://scamshield-ai-720104534346.asia-south1.run.app'; // Cloud Run production (elephas-ai-backend-2026 project)
  static const String productionApiUrl = 'https://api.elephasai.com';

  // Analytics and ML Pipeline endpoints
  static String get mlPipelineUrl => useLocalEndpoint
      ? '$localApiUrl/ml-pipeline'
      : '$cloudRunApiUrl/ml-pipeline';

  static String get threatIntelUrl => useLocalEndpoint
      ? '$localApiUrl/threat-intel'
      : '$cloudRunApiUrl/threat-intel';

  // Feature flags
  static const bool enableOfflineDetection = true;
  static const bool enableCloudSync = true;
  static const bool enableTelemetry = true;

  // Performance settings
  static const int cacheMaxSize = 1000;
  static const Duration cacheExpiry = Duration(days: 7);

  // Security settings
  static const bool enableCertificatePinning =
      false; // Disabled for Cloud Run (SSL handled by Cloud Run)

  // Get the appropriate API URL based on environment
  static String get apiUrl {
    if (useLocalEndpoint) {
      return localApiUrl;
    }
    return cloudRunApiUrl;
  }

  // API key for authentication
  static String get apiKey {
    if (useLocalEndpoint) {
      return 'dev_test_key_123'; // Development API key
    }
    return const String.fromEnvironment('ELEPHAS_API_KEY',
        defaultValue: 'client_live_api_key'); // Set your production API key
  }

  // For development logging
  static const bool verbose = false; // Disable verbose logging in production

  // Testing mode
  static const bool testingMode = false; // Disable testing mode in production
}
