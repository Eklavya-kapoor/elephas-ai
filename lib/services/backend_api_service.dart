import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../core/models/detection_models.dart';
import 'device_registration_service.dart';

/// Service for communicating with the Elephas AI backend API
class BackendApiService {
  static const String _logTag = 'BackendApiService';
  static BackendApiService? _instance;
  static BackendApiService get instance => _instance ??= BackendApiService._();

  BackendApiService._();

  final http.Client _httpClient = http.Client();
  bool _isHealthy = false;
  DateTime? _lastHealthCheck;

  /// Standard headers with API key authentication
  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.apiKey}',
      };

  /// Check if backend is healthy and update status
  Future<bool> checkHealth() async {
    final url = '${AppConfig.apiUrl}/health';
    developer.log('Checking backend health at: $url', name: _logTag);
    try {
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
          const Duration(seconds: 15)); // Increased for Cloud Run cold start

      _isHealthy = response.statusCode == 200;
      _lastHealthCheck = DateTime.now();
      developer.log(
        _isHealthy
            ? '✅ Backend health check passed'
            : '❌ Backend unhealthy: ${response.statusCode}',
        name: _logTag,
      );
      return _isHealthy;
    } catch (e) {
      _isHealthy = false;
      _lastHealthCheck = DateTime.now();
      developer.log('❌ Backend health check failed: $e', name: _logTag);
      return false;
    }
  }

  /// Analyze content using the backend AI model
  Future<DetectionResult> analyzeContent(
    String message, {
    String? appPackage,
    String? contactId,
    String? conversationHistory,
    String? sender,
    String? contactName,
    String? phoneNumber,
    bool? isSavedContact,
    bool? isVerifiedSender,
    bool? hasProfilePicture,
  }) async {
    final startTime = DateTime.now();
    developer.log('🔍 Starting content analysis...', name: _logTag);

    // Skip health check if recently checked (within 5 mins) - reduces delay
    if (!_isHealthy ||
        _lastHealthCheck == null ||
        DateTime.now().difference(_lastHealthCheck!) >
            const Duration(minutes: 5)) {
      developer.log('🔄 Health check required...', name: _logTag);
      final isHealthy = await checkHealth();
      if (!isHealthy) {
        developer.log('❌ Backend health check failed, trying scan anyway...',
            name: _logTag);
        // Don't wait - just try the scan directly
      }
    }

    try {
      developer.log('📤 Sending scan request...', name: _logTag);
      final response = await _httpClient
          .post(
            Uri.parse('${AppConfig.apiUrl}/scan'),
            headers: _authHeaders,
            body: jsonEncode({
              'text':
                  message, // Using 'text' field to match backend expectations
              if (sender != null) 'sender': sender,
              if (contactName != null) 'contact_name': contactName,
              if (phoneNumber != null) 'phone_number': phoneNumber,
              if (isSavedContact != null) 'is_saved_contact': isSavedContact,
              if (isVerifiedSender != null)
                'is_verified_sender': isVerifiedSender,
              if (hasProfilePicture != null)
                'has_profile_picture': hasProfilePicture,
              'metadata': {
                if (appPackage != null) 'package_name': appPackage,
                if (contactId != null) 'contact_id': contactId,
                if (conversationHistory != null)
                  'conversation_history': conversationHistory,
                'scan_source': 'flutter_app',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              },
            }),
          )
          .timeout(const Duration(
              seconds: 10)); // Reduced timeout for faster response

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      developer.log('📥 Got response: ${response.statusCode} in ${elapsed}ms',
          name: _logTag);

      if (response.statusCode != 200) {
        developer.log(
          'Backend error: ${response.statusCode}',
          name: _logTag,
        );
        return DetectionResult.error(
          'Backend error: ${response.statusCode} - ${response.body}',
        );
      }

      final result = _parseBackendResponse(
        jsonDecode(response.body) as Map<String, dynamic>,
        message,
      );

      // Fire-and-forget: feeds the admin dashboard's live stats, never
      // blocks or delays returning the result to the caller.
      DeviceRegistrationService.instance.logDetectionEvent(
        messageContent: message,
        sender: sender,
        isScam: result.isThreat,
        confidence: result.confidence,
        riskScore: result.riskScore,
        reasoning: result.reasoning,
        actionTaken: result.isThreat ? 'alerted' : 'logged',
      );

      return result;
    } catch (e) {
      developer.log('Analysis error: $e', name: _logTag);
      return DetectionResult.error(e.toString());
    }
  }

  /// Parse backend response into DetectionResult
  DetectionResult _parseBackendResponse(
    Map<String, dynamic> response,
    String originalMessage,
  ) {
    try {
      final classification =
          response['classification']?.toString().toLowerCase() ?? 'legitimate';
      final riskLevel =
          response['risk_level']?.toString().toLowerCase() ?? 'low';

      // FIXED: Check for ALL threat classifications, not just 'scam'
      // Backend can return: scam, suspicious, spam, fraud, legitimate
      final threatClassifications = ['scam', 'suspicious', 'spam', 'fraud'];
      final highRiskLevels = ['critical', 'high', 'medium'];

      final isScam = threatClassifications.contains(classification) ||
          highRiskLevels.contains(riskLevel);

      final confidence = (response['confidence'] as num?)?.toDouble() ?? 0.0;
      final riskScore = (response['risk_score'] as num?)?.toDouble() ?? 0.0;
      final explanation =
          response['explanation']?.toString() ?? 'Analysis completed';
      final warnings = List<String>.from(response['warnings'] ?? []);

      final reasoning = [explanation, ...warnings].join(' • ');
      // The backend answers from a fast keyword-based fallback (instead of
      // the real BERT model) while the model is still loading - typically
      // for the first couple minutes after a cold start. It flags this via
      // model_version so the UI can be honest about it rather than showing
      // a possibly-wrong verdict as if it were final.
      final modelVersion = response['model_version']?.toString() ?? '';
      final isFallback = modelVersion.contains('fallback');
      final metadata = <String, dynamic>{
        'backend_analysis': true,
        'backend_timestamp': DateTime.now().toIso8601String(),
        if (response['scan_id'] != null) 'scan_id': response['scan_id'],
        if (response['risk_level'] != null)
          'risk_level': response['risk_level'],
        if (response['processing_time'] != null)
          'processing_time': response['processing_time'],
        if (response['model_version'] != null) 'model_version': modelVersion,
        'is_fallback': isFallback,
        'warnings': warnings,
      };

      return isScam
          ? DetectionResult.threat(
              message: originalMessage,
              contactId: 'backend_analyzed',
              riskScore: riskScore,
              confidence: confidence,
              reasoning: reasoning,
              evidence: metadata,
              metadata: metadata,
            )
          : DetectionResult.safe(reasoning, metadata: metadata);
    } catch (e) {
      developer.log('Parse error: $e', name: _logTag);
      return DetectionResult.error('Failed to parse backend response: $e');
    }
  }

  /// Get backend performance stats
  Future<Map<String, dynamic>?> getBackendStats() async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('${AppConfig.apiUrl}/stats'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      developer.log('Stats error: $e', name: _logTag);
      return null;
    }
  }

  /// Test backend connection with latency
  Future<Map<String, dynamic>> testConnection() async {
    final startTime = DateTime.now();
    try {
      final healthy = await checkHealth();
      return {
        'connected': healthy,
        'latency_ms': DateTime.now().difference(startTime).inMilliseconds,
        'endpoint': AppConfig.apiUrl,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'connected': false,
        'latency_ms': DateTime.now().difference(startTime).inMilliseconds,
        'endpoint': AppConfig.apiUrl,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get current connection status
  bool get isHealthy => _isHealthy;

  /// Get last health check timestamp
  DateTime? get lastHealthCheck => _lastHealthCheck;

  /// Clean up resources
  void dispose() {
    _httpClient.close();
  }
}
