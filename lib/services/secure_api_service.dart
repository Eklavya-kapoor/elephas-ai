// lib/services/secure_api_service.dart
/*
🔐 Elephas AI Secure API Service
Enhanced API communication with banking-grade security
*/

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'security_service.dart';

/// Secure API service for Elephas AI
class SecureApiService {
  static final SecureApiService _instance = SecureApiService._internal();
  factory SecureApiService() => _instance;
  SecureApiService._internal();

  final SecurityService _security = SecurityService();
  late String _baseUrl;
  String? _apiKey;

  /// Initialize secure API service
  Future<void> initialize({
    required String baseUrl,
    String? apiKey,
  }) async {
    _baseUrl = baseUrl;
    _apiKey = apiKey;

    await _security.initialize();

    // Validate security before allowing API calls
    if (!_security.isDeviceSecure()) {
      final threats = _security.getDetectedThreats();
      throw SecurityException('Device security compromised: $threats');
    }
  }

  /// Secure POST request with comprehensive security
  Future<Map<String, dynamic>> securePost({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? additionalHeaders,
  }) async {
    // Pre-request security checks
    if (!_security.isDeviceSecure()) {
      throw SecurityException('Device security compromised');
    }

    if (_security.isLockedOut()) {
      throw SecurityException('Device is locked due to security violations');
    }

    // Validate network security
    if (!await _security.validateNetworkSecurity()) {
      throw SecurityException('Network security validation failed');
    }

    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final body = json.encode(data);

      // Generate secure headers
      final secureHeaders =
          _security.generateSecureHeaders('POST', endpoint, body);

      // Add API key if available
      if (_apiKey != null) {
        secureHeaders['Authorization'] = 'Bearer $_apiKey';
      }

      // Add additional headers
      if (additionalHeaders != null) {
        secureHeaders.addAll(additionalHeaders);
      }

      // Log the secure API call (removed internal method call)
      // In production, implement proper logging

      // Make the secure request
      final response = await http
          .post(
            url,
            headers: secureHeaders,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      // Validate response
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;

        // Validate response integrity if signature provided
        final responseSignature =
            response.headers['x-elephas-response-signature'];
        if (responseSignature != null) {
          if (!_validateResponseSignature(response.body, responseSignature)) {
            throw SecurityException('Response integrity validation failed');
          }
        }

        return responseData;
      } else {
        throw ApiException(
            'API call failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // Handle security failures
      if (e is SecurityException) {
        // Log security failure using developer log instead of print
        developer.log('Security failure in API call: ${e.message}',
            name: 'SecureApiService');
      }

      rethrow;
    }
  }

  /// Validate response signature
  bool _validateResponseSignature(String responseBody, String signature) {
    try {
      final key = _security.appSigningKey ?? '';
      final keyBytes = utf8.encode(key);
      final bodyBytes = utf8.encode(responseBody);

      final hmac = Hmac(sha256, keyBytes);
      final expectedSignature = hmac.convert(bodyBytes).toString();

      return expectedSignature == signature;
    } catch (e) {
      return false;
    }
  }

  /// Scan message with enhanced security
  Future<Map<String, dynamic>> scanMessage({
    required String message,
    String? sender,
    String? platform,
    Map<String, dynamic>? metadata,
  }) async {
    final requestData = {
      'text': message,
      if (sender != null) 'sender': sender,
      if (platform != null) 'platform': platform,
      if (metadata != null) 'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
      'client': 'flutter-secure',
    };

    return await securePost(
      endpoint: '/scan',
      data: requestData,
    );
  }

  /// Check API health with security validation
  Future<Map<String, dynamic>> healthCheck() async {
    return await securePost(
      endpoint: '/health',
      data: {
        'timestamp': DateTime.now().toIso8601String(),
        'security_status': _security.getSecurityStatus(),
      },
    );
  }

  /// Get API key status
  Future<Map<String, dynamic>> getApiKeyStatus() async {
    if (_apiKey == null) {
      throw ApiException('No API key configured');
    }

    return await securePost(
      endpoint: '/api/status',
      data: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}

/// Custom exceptions
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
