// lib/services/smart_scam_detection_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:elephas_ai/models/alert_level.dart';
import 'package:elephas_ai/models/scam_detection_models.dart';
import 'package:elephas_ai/config/app_config.dart';

class SmartScamDetectionService extends ChangeNotifier {
  // Use configuration system instead of hardcoded URL
  final String _bertApiUrl = AppConfig.apiUrl;

  // Cache to avoid re-scanning same content
  final Map<String, ScamDetectionResult> _cache = {};

  // Scan history
  final List<ScamDetectionResult> _scanHistory = [];
  List<ScamDetectionResult> get scanHistory => List.unmodifiable(_scanHistory);

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Sensitivity settings
  double _smsSensitivity = 0.5;
  double _callSensitivity = 0.5;
  double _screenSensitivity = 0.5;
  AlertLevel _defaultAlertLevel = AlertLevel.medium;

  // Sensitivity getters and setters
  double get smsSensitivity => _smsSensitivity;
  set smsSensitivity(double value) {
    _smsSensitivity = value;
    notifyListeners();
  }

  double get callSensitivity => _callSensitivity;
  set callSensitivity(double value) {
    _callSensitivity = value;
    notifyListeners();
  }

  double get screenSensitivity => _screenSensitivity;
  set screenSensitivity(double value) {
    _screenSensitivity = value;
    notifyListeners();
  }

  AlertLevel get defaultAlertLevel => _defaultAlertLevel;
  set defaultAlertLevel(AlertLevel value) {
    _defaultAlertLevel = value;
    notifyListeners();
  }

  // Custom rules list
  final List<Map<String, dynamic>> _customRules = [];
  List<Map<String, dynamic>> get customRules => List.unmodifiable(_customRules);

  // Configurable thresholds
  static const double _criticalThreshold =
      0.9; // 90% confidence = immediate alert
  static const double _highThreshold = 0.7; // 70% confidence = warning
  static const double _mediumThreshold =
      0.5; // 50% confidence = subtle indication

  /// Main method to scan message and determine if alert should be shown
  Future<ScamDetectionResult> scanMessage(String content,
      {String? source}) async {
    try {
      _isScanning = true;
      notifyListeners();

      // 1. Quick validation - don't scan empty or very short messages
      if (content.trim().isEmpty || content.length < 10) {
        return ScamDetectionResult(
          isScam: false,
          confidence: 0.0,
          reason: 'Message too short to analyze',
          alertLevel: AlertLevel.none,
        );
      }

      // 2. Check cache first (avoid duplicate API calls)
      final contentHash = content.hashCode.toString();
      if (_cache.containsKey(contentHash)) {
        return _cache[contentHash]!;
      }

      // 3. Pre-filter with quick keyword check (saves API calls)
      final quickCheck = _performQuickKeywordCheck(content);
      if (!quickCheck.isPotentialScam) {
        final result = ScamDetectionResult(
          isScam: false,
          confidence: 0.0,
          reason: 'Passed quick safety check',
          alertLevel: AlertLevel.none,
        );
        _cache[contentHash] = result;
        return result;
      }

      // 4. Call BERT API for detailed analysis
      final bertResult = await _callBertApi(content);

      // Apply sensitivity adjustment based on content source
      double adjustedConfidence = bertResult.confidence;
      if (source == 'sms') {
        adjustedConfidence = _adjustConfidenceBasedOnSensitivity(
            adjustedConfidence, _smsSensitivity);
      } else if (source == 'call') {
        adjustedConfidence = _adjustConfidenceBasedOnSensitivity(
            adjustedConfidence, _callSensitivity);
      } else if (source == 'screen') {
        adjustedConfidence = _adjustConfidenceBasedOnSensitivity(
            adjustedConfidence, _screenSensitivity);
      }

      // 5. Determine alert level based on confidence
      final alertLevel = _determineAlertLevel(adjustedConfidence);

      final result = ScamDetectionResult(
        isScam: alertLevel != AlertLevel.none,
        confidence: adjustedConfidence,
        reason: bertResult.reason,
        alertLevel: alertLevel,
        scamTypes: bertResult.scamTypes,
      );

      _cache[contentHash] = result;
      _scanHistory.add(result);
      notifyListeners();
      return result;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Quick keyword-based pre-filtering to avoid unnecessary API calls
  QuickCheckResult _performQuickKeywordCheck(String content) {
    final contentLower = content.toLowerCase();

    // High-risk keywords that warrant API analysis
    final highRiskKeywords = [
      'urgent',
      'immediate',
      'act now',
      'limited time',
      'expire',
      'click here',
      'verify account',
      'suspended',
      'blocked',
      'winner',
      'congratulations',
      'prize',
      'lottery',
      'reward',
      'refund',
      'tax',
      'irs',
      'government',
      'bank',
      'paypal',
      'cryptocurrency',
      'bitcoin',
      'investment',
      'profit',
      'romance',
      'love',
      'relationship',
      'meet',
      'lonely',
      'social security',
      'ssn',
      'credit card',
      'account number',
      'password',
      'pin',
      'otp',
      'verification code',
    ];

    // Transliterated high-risk keywords (Hinglish examples)
    final transliteratedKeywords = [
      'jaldi',
      'turant',
      'abhi',
      'seemasamapt',
      'avsar',
      'yahan click kare',
      'account verify',
      'rukawat',
      'band',
      'vijeta',
      'badhai',
      'inaam',
      'lottery',
      'uphaar',
      'wapsi',
      'tax',
      'sarkari',
      'bank',
      'paise',
      'bitcoin',
      'nivesh',
      'munafa',
      'labh',
      'pyaar',
      'ishq',
      'rishta',
      'milna',
      'akela',
      'password',
      'pin',
      'otp',
      'verification code',
      'paisa',
      'rupaye',
      'rupee',
      'lakhpati',
      'crorepati',
      'free',
      'muft',
      'bonus',
    ];

    // Suspicious patterns
    final suspiciousPatterns = [
      RegExp(r'\$\d+'), // Money amounts
      RegExp(r'\d{4}-\d{4}-\d{4}-\d{4}'), // Credit card patterns
      RegExp(r'http[s]?://[^\s]+'), // URLs
      RegExp(r'\d{3}-\d{2}-\d{4}'), // SSN patterns
      RegExp(r'[A-Z]{2,}\s+[A-Z]{2,}'), // All caps words
    ];

    // Check for high-risk keywords (English)
    for (final keyword in highRiskKeywords) {
      if (contentLower.contains(keyword)) {
        return QuickCheckResult(
          isPotentialScam: true,
          reason: 'Contains high-risk keyword: $keyword',
        );
      }
    }

    // Check for transliterated high-risk keywords
    for (final keyword in transliteratedKeywords) {
      if (contentLower.contains(keyword)) {
        return QuickCheckResult(
          isPotentialScam: true,
          reason: 'Contains transliterated high-risk keyword: $keyword',
        );
      }
    }

    // Check for suspicious patterns
    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(content)) {
        return QuickCheckResult(
          isPotentialScam: true,
          reason: 'Contains suspicious pattern',
        );
      }
    }

    return QuickCheckResult(
      isPotentialScam: false,
      reason: 'No suspicious indicators found',
    );
  }

  /// Call BERT API for detailed scam analysis
  Future<BertApiResult> _callBertApi(String content) async {
    try {
      // Add timeout to avoid hanging indefinitely
      final response = await http
          .post(
            Uri.parse('$_bertApiUrl/scan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': content,
              'metadata': {
                'app': 'elephas_ai',
                'version': '1.0.0',
                'platform': 'android',
                'timestamp': DateTime.now().toIso8601String(),
                'detect_mixed_language':
                    true, // Flag for mixed language detection
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BertApiResult(
          confidence: data['risk_score']?.toDouble() ?? 0.0,
          reason: data['explanation'] ?? 'No specific reason provided',
          scamTypes: (data['details']?['scam_types'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
        );
      } else {
        // API error - fall back to local analysis
        debugPrint('BERT API error: ${response.statusCode} - ${response.body}');
        return _fallbackAnalysis(content);
      }
    } catch (e) {
      // Network/other error - fall back to local analysis
      debugPrint('BERT API call failed: $e');
      return _fallbackAnalysis(content);
    }
  }

  /// Fallback analysis when BERT API is unavailable
  BertApiResult _fallbackAnalysis(String content) {
    final contentLower = content.toLowerCase();
    double confidence = 0.0;
    List<String> scamTypes = [];
    String reason = 'Fallback analysis';

    // Check for common scam indicators in English
    if (contentLower.contains('urgent') && contentLower.contains('account')) {
      confidence = 0.6;
      scamTypes = ['phishing'];
      reason = 'Urgent account-related message detected';
    } else if (contentLower.contains('winner') ||
        contentLower.contains('prize')) {
      confidence = 0.7;
      scamTypes = ['lottery'];
      reason = 'Prize/lottery scam indicators found';
    } else if (contentLower.contains('investment') ||
        contentLower.contains('profit')) {
      confidence = 0.5;
      scamTypes = ['investment'];
      reason = 'Investment scam indicators found';
    }

    // Check for mixed language or transliterated text (Hinglish examples)
    else if (contentLower.contains('jaldi') &&
        (contentLower.contains('account') || contentLower.contains('bank'))) {
      confidence = 0.6;
      scamTypes = ['phishing'];
      reason = 'Urgent account-related message in mixed language';
    } else if (contentLower.contains('inaam') ||
        contentLower.contains('jeetna') ||
        contentLower.contains('lottery')) {
      confidence = 0.7;
      scamTypes = ['lottery'];
      reason = 'Prize/lottery scam in mixed language';
    } else if (contentLower.contains('nivesh') ||
        contentLower.contains('paisa') ||
        contentLower.contains('labh')) {
      confidence = 0.5;
      scamTypes = ['investment'];
      reason = 'Investment scam in mixed language';
    } else if (contentLower.contains('otp') ||
        contentLower.contains('code') ||
        contentLower.contains('bhejo')) {
      confidence = 0.65;
      scamTypes = ['phishing'];
      reason = 'OTP/verification scam in mixed language';
    }

    return BertApiResult(
      confidence: confidence,
      reason: reason,
      scamTypes: scamTypes,
    );
  }

  /// Determine alert level based on BERT confidence score
  AlertLevel _determineAlertLevel(double confidence) {
    if (confidence >= _criticalThreshold) {
      return AlertLevel.critical; // Show immediate blocking alert
    } else if (confidence >= _highThreshold) {
      return AlertLevel.high; // Show prominent warning
    } else if (confidence >= _mediumThreshold) {
      return AlertLevel.medium; // Show subtle indication
    } else {
      return AlertLevel.none; // No alert needed
    }
  }

  /// Clear scan history
  void clearHistory() {
    _scanHistory.clear();
    notifyListeners();
  }

  /// Clear cache periodically to prevent memory issues
  void clearCache() {
    _cache.clear();
  }

  /// Adjust the confidence score based on user-defined sensitivity
  double _adjustConfidenceBasedOnSensitivity(
      double confidence, double sensitivity) {
    // At sensitivity 0.5 (default), return the original confidence
    // At sensitivity 1.0 (high), increase the confidence by up to 25%
    // At sensitivity 0.0 (low), decrease the confidence by up to 25%
    final adjustmentFactor = (sensitivity - 0.5) * 0.5; // Range: -0.25 to 0.25
    return (confidence * (1 + adjustmentFactor)).clamp(0.0, 1.0);
  }

  /// Add a new custom rule
  void addCustomRule(Map<String, dynamic> rule) {
    _customRules.add(rule);
    notifyListeners();
  }

  /// Remove a custom rule
  void removeCustomRule(int index) {
    if (index >= 0 && index < _customRules.length) {
      _customRules.removeAt(index);
      notifyListeners();
    }
  }

  /// Update an existing custom rule
  void updateCustomRule(int index, Map<String, dynamic> rule) {
    if (index >= 0 && index < _customRules.length) {
      _customRules[index] = rule;
      notifyListeners();
    }
  }
}
