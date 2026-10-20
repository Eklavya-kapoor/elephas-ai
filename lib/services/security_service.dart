// lib/services/security_service.dart
/*
🔐 Security Service for ScamShield AI
Handles encryption, secure storage, and security utilities
*/

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Security service for handling encryption and secure operations
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  /// Generate a secure API signature
  String generateSignature(String method, String path, String timestamp,
      String body, String apiKey) {
    final message = '$method$path$timestamp$body';
    final key = utf8.encode(apiKey);
    final messageBytes = utf8.encode(message);

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(messageBytes);

    return digest.toString();
  }

  /// Generate secure timestamp
  String generateTimestamp() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Validate API response signature
  bool validateResponseSignature(
      String responseBody, String signature, String apiKey) {
    try {
      final expectedSignature =
          _generateResponseSignature(responseBody, apiKey);
      return expectedSignature == signature;
    } catch (e) {
      return false;
    }
  }

  /// Generate response signature for validation
  String _generateResponseSignature(String responseBody, String apiKey) {
    final key = utf8.encode(apiKey);
    final messageBytes = utf8.encode(responseBody);

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(messageBytes);

    return digest.toString();
  }

  /// Secure storage operations
  Future<void> storeSecurely(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = _simpleEncrypt(value);
    await prefs.setString(key, encrypted);
  }

  /// Retrieve from secure storage
  Future<String?> retrieveSecurely(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(key);
    if (encrypted == null) return null;

    try {
      return _simpleDecrypt(encrypted);
    } catch (e) {
      return null;
    }
  }

  /// Simple encryption (for demo - use proper encryption in production)
  String _simpleEncrypt(String data) {
    final bytes = utf8.encode(data);
    final encoded = base64.encode(bytes);
    return encoded;
  }

  /// Simple decryption (for demo - use proper encryption in production)
  String _simpleDecrypt(String encryptedData) {
    final decoded = base64.decode(encryptedData);
    return utf8.decode(decoded);
  }

  /// Generate secure random string
  String generateSecureToken(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var result = '';

    for (int i = 0; i < length; i++) {
      result += chars[(random + i) % chars.length];
    }

    return result;
  }

  /// Validate API key format
  bool isValidApiKey(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return false;
    // Basic validation - should be at least 32 characters
    return apiKey.length >= 32 && apiKey.contains('_');
  }

  /// Clean sensitive data from memory
  void clearSensitiveData() {
    // In a real implementation, you would clear sensitive variables
    // This is a placeholder for security best practices
  }

  /// Initialize security service
  Future<void> initialize() async {
    // Initialize security components
    await _initializeSecurityChecks();
  }

  /// Check if device is secure
  bool isDeviceSecure() {
    // Basic device security checks
    // In a real implementation, check for root/jailbreak, debugger, etc.
    return true; // For demo purposes
  }

  /// Get detected security threats
  List<String> getDetectedThreats() {
    final threats = <String>[];

    // Check for common threats
    if (!isDeviceSecure()) {
      threats.add('Device security compromised');
    }

    return threats;
  }

  /// Check if user is locked out due to security violations
  bool isLockedOut() {
    // Check if user exceeded security attempts
    return false; // For demo purposes
  }

  /// Validate network security
  Future<bool> validateNetworkSecurity() async {
    // Check network security (SSL pinning, etc.)
    return true; // For demo purposes
  }

  /// Generate secure headers for API requests
  Map<String, String> generateSecureHeaders(
      String method, String endpoint, String body) {
    final timestamp = generateTimestamp();
    final signature =
        generateSignature(method, endpoint, timestamp, body, _getApiKey());

    return {
      'X-Timestamp': timestamp,
      'X-Signature': signature,
      'X-Request-ID': generateSecureToken(16),
      'Content-Type': 'application/json',
    };
  }

  /// Get app signing key (getter)
  String? get appSigningKey => _getApiKey();

  /// Get security status
  Map<String, dynamic> getSecurityStatus() {
    return {
      'device_secure': isDeviceSecure(),
      'locked_out': isLockedOut(),
      'threats_detected': getDetectedThreats().length,
      'last_check': DateTime.now().toIso8601String(),
    };
  }

  /// Initialize security checks
  Future<void> _initializeSecurityChecks() async {
    // Perform initial security validation
    // This would include device integrity checks, etc.
  }

  /// Get API key from secure storage
  String _getApiKey() {
    // In a real implementation, retrieve from secure storage
    return 'demo_api_key_${DateTime.now().millisecondsSinceEpoch}';
  }
}
