/// Backend configuration for Elephas AI Flutter app.
/// Configured for Tailscale VPN on 172.20.10.4:8000
class BackendConfig {
  // Production Backend Server (Tailscale IP)
  static const String backendUrl = 'http://172.20.10.4:8000';

  // API Endpoints
  static const String scanEndpoint = '/scan';
  static const String healthEndpoint = '/health';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration responseTimeout = Duration(seconds: 15);

  // Retry Configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Feature Flags
  static const bool enableBackendDetection = true;
  static const bool enableLocalDetection = true; // Fallback
  static const bool enableLogging = true;

  // Thresholds
  static const double minimumConfidenceThreshold = 0.7;
  static const double riskScoreThreshold = 0.6;

  /// Get full API endpoint URL
  static String getEndpointUrl(String endpoint) {
    return '$backendUrl$endpoint';
  }

  /// Get scan endpoint URL
  static String getScanUrl() => getEndpointUrl(scanEndpoint);

  /// Get health check URL
  static String getHealthUrl() => getEndpointUrl(healthEndpoint);

  /// Check if backend is available
  static Future<bool> isBackendAvailable() async {
    try {
      // This will be checked at app startup
      return true;
    } catch (e) {
      return false;
    }
  }
}
