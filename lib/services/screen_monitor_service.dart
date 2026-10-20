// lib/services/screen_monitor_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/backend_api_service.dart';
import '../services/overlay_service.dart';
import '../services/real_contacts_service.dart';

/// Service for monitoring screen content and detecting scams
class ScreenMonitorService extends ChangeNotifier {
  final MethodChannel _screenMonitorChannel =
      const MethodChannel('elephas_ai/screen_monitor');
  final MethodChannel _ocrChannel = const MethodChannel('elephas_ai/ocr');
  final OverlayService _overlayService;
  final BackendApiService _backendApi = BackendApiService.instance;
  final RealContactsService _contactsService = RealContactsService.instance;

  bool _isMonitoring = false;
  bool _isProcessing = false;
  bool _isActive = false;
  String _lastProcessedContent = '';
  String _activePackage = '';

  int _totalScreensMonitored = 0;
  int _scamsDetected = 0;
  double _protectionScore = 0.0;
  int _activeAlerts = 0;

  static const int minContentLength = 10;
  static const int maxContentLength = 10000;

  // === NEW: Deduplication to prevent repeat alerts ===
  final Set<String> _alertedHashes = {}; // Content we already showed alert for
  DateTime? _lastScamAlertTime; // Last RED scam alert time
  DateTime? _lastUrlAlertTime; // Last BLACK URL alert time

  // === Separate cooldowns for different alert types ===
  static const Duration _scamAlertCooldown =
      Duration(seconds: 3); // RED alert: 3 seconds between alerts
  static const Duration _urlAlertCooldown =
      Duration(hours: 12); // BLACK alert: 12 hours between alerts

  // === NEW: Stricter thresholds - LOWERED to catch more scams ===
  static const double _scamThreshold =
      0.60; // Lowered from 0.85 to catch more scams
  static const double _urlWarningThreshold =
      0.50; // Lowered from 0.70 for better URL detection
  static const double _minConfidence =
      0.50; // Lowered from 0.75 for better coverage

  // === Patterns indicating media/images (not text messages) ===
  static final RegExp _imageMediaPattern = RegExp(
    r'(good\s*morning|good\s*night|good\s*evening|happy\s*birthday|happy\s*diwali|happy\s*holi|'
    r'happy\s*new\s*year|jai\s*shri|jai\s*mata|har\s*har|om\s*namah|radhe\s*radhe|'
    r'shubh\s*prabhat|suprabhat|🙏|🌅|🌄|🌞|🌙|✨|🎂|🎉|🎊|'
    r'photo|image|video|gif|sticker|voice\s*message|audio|'
    r'\.jpg|\.jpeg|\.png|\.gif|\.mp4|\.mp3|\.pdf|\.doc|\.xls)',
    caseSensitive: false,
  );

  // === Patterns indicating forwarded messages (should still scan these) ===
  static final RegExp _forwardedPattern = RegExp(
    r'(forwarded|forwarded\s*many\s*times|fwd:|fw:)',
    caseSensitive: false,
  );

  bool get isMonitoring => _isMonitoring;
  bool get isProcessing => _isProcessing;
  bool get isActive => _isActive;
  int get totalScreensMonitored => _totalScreensMonitored;
  int get scamsDetected => _scamsDetected;
  double get protectionScore => _protectionScore;
  int get activeAlerts => _activeAlerts;

  ScreenMonitorService({required OverlayService overlayService})
      : _overlayService = overlayService {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _screenMonitorChannel.setMethodCallHandler(_handleNativeMethodCall);
    _ocrChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenContent':
        final content = call.arguments['content'] as String?;
        final packageName = call.arguments['packageName'] as String?;
        if (content != null && packageName != null) {
          developer.log(
              '📥 RECEIVED from native: ${content.length} chars from $packageName',
              name: 'ScreenMonitor');
          await _processScreenContent(content, packageName);
        }
        break;

      case 'onAppChanged':
        final packageName = call.arguments['packageName'] as String?;
        if (packageName != null) {
          developer.log('📱 APP CHANGED to: $packageName',
              name: 'ScreenMonitor');
          // === AUTO-HIDE overlay when screen/app changes ===
          if (_activePackage.isNotEmpty && _activePackage != packageName) {
            developer.log(
                '📱 Screen changed from $_activePackage to $packageName - hiding overlay',
                name: 'ScreenMonitor');
            await _overlayService.hideAlert();
            _activeAlerts = 0;
          }
          _activePackage = packageName;
          _overlayService.setCurrentApp(packageName);
          // Clear last processed content on screen change to allow fresh scan
          _lastProcessedContent = '';
        }
        break;

      case 'onTextDetected':
        final text = call.arguments as String?;
        if (text != null && _activePackage.isNotEmpty) {
          await _processScreenContent(text, _activePackage);
        }
        break;
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    try {
      // The accessibility service is always running - we just need to be ready to receive content
      // No need to call native startMonitoring - the broadcast receiver handles it
      _isMonitoring = true;
      _isActive = true;
      developer.log('✅ Screen monitoring ready (accessibility service based)',
          name: 'ScreenMonitor');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to start monitoring: $e');
      _isMonitoring = false;
      _isActive = false;
      notifyListeners();
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    try {
      // Just mark as not monitoring - accessibility service keeps running in background
      _isMonitoring = false;
      _isActive = false;
      developer.log('🛑 Screen monitoring paused', name: 'ScreenMonitor');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to stop monitoring: $e');
    }
  }

  Future<void> _processScreenContent(String content, String packageName) async {
    // === ALWAYS LOG what we receive ===
    developer.log('📥 PROCESSING: ${content.length} chars from $packageName',
        name: 'ScreenMonitor');

    if (!_shouldProcessContent(content)) {
      developer.log('⏭️ SKIPPED: Content filtered by _shouldProcessContent',
          name: 'ScreenMonitor');
      return;
    }

    // === Check for URLs - ALWAYS scan messages with URLs ===
    final containsUrl = RegExp(
            r'(https?://|www\.|bit\.ly|goo\.gl|t\.co|\.com/|\.in/|\.org/)',
            caseSensitive: false)
        .hasMatch(content);

    // === Check for scam keywords - ALWAYS scan if present ===
    final hasScamKeywords = RegExp(
            r'(lottery|won|prize|claim|urgent|kyc|blocked|verify|otp|bank|upi|paytm|phonepe|gpay|credit|loan|offer|cashback|reward|lucky|winner|congratulations|selected|deposit|transfer|account\s*blocked|suspend|expire|link\s*below|click\s*here|act\s*now|limited\s*time|work\s*from\s*home|part\s*time|full\s*time|earn|income|profit|daily\s*income|weekly\s*income|simple\s*task|easy\s*task|join\s*our\s*team|no\s*experience|flexible\s*hours|online\s*job|telegram\s*job|whatsapp\s*job|youtube\s*job|like\s*videos|review\s*products|referral|commission|investment\s*opportunity|slots\s*available|vacancy|hiring|openings)',
            caseSensitive: false)
        .hasMatch(content);

    // === If URL or scam keywords found, ALWAYS scan regardless of contact status ===
    if (containsUrl || hasScamKeywords) {
      developer.log(
          '🚨 FORCE SCAN: containsUrl=$containsUrl, hasScamKeywords=$hasScamKeywords',
          name: 'ScreenMonitor');
    } else {
      // No URL and no scam keywords - check other filters

      // Skip verified business profiles only (blue checkmark, official WhatsApp/Meta verified)
      if (_isVerifiedProfile(content)) {
        developer.log('✅ Verified BUSINESS profile - skipping',
            name: 'ScreenMonitor');
        _lastProcessedContent = content;
        return;
      }

      // Check if this is a saved contact or unknown number
      final isUnsavedContact = _isUnsavedContact(content);
      final isForwardedMessage = _forwardedPattern.hasMatch(content);
      final isMediaOrImage = _imageMediaPattern.hasMatch(content);

      // For SAVED contacts without suspicious content, skip non-forwarded media
      if (!isUnsavedContact && !isForwardedMessage && isMediaOrImage) {
        developer.log(
            '✅ Saved contact, media only, no suspicious content - skipping',
            name: 'ScreenMonitor');
        _lastProcessedContent = content;
        return;
      }

      developer.log('🔍 Proceeding with scan', name: 'ScreenMonitor');
    }

    // === Determine contact status for backend ===
    final isUnsavedContact = _isUnsavedContact(content);

    // === NEW: Generate hash to prevent repeat alerts for same content ===
    final contentHash =
        md5.convert(utf8.encode('$packageName:${content.trim()}')).toString();

    // Skip if we already alerted on this exact content
    if (_alertedHashes.contains(contentHash)) {
      developer.log('⏭️ Skipping already-alerted content',
          name: 'ScreenMonitor');
      return;
    }

    // Note: Alert cooldown check moved to AFTER we determine alert type
    // This allows separate cooldowns for scam (3s) vs URL (12h) alerts

    _isProcessing = true;
    _activePackage = packageName;

    // Store the package name when we START the analysis
    final originalPackage = packageName;

    // === Extract sender info from screen content (if visible) ===
    final extractedSender = _extractSenderFromContent(content);

    try {
      _incrementScreenCount();

      developer.log(
          '🔍 SENDING TO BACKEND: ${content.substring(0, content.length > 80 ? 80 : content.length)}...',
          name: 'ScreenMonitor');

      final backendResult = await _backendApi.analyzeContent(
        content,
        appPackage: packageName,
        contactId: 'screen_monitor',
        sender: extractedSender,
        isSavedContact: !isUnsavedContact,
        isVerifiedSender:
            false, // Already filtered client-side, but pass for backend logging
      );

      // === CHECK: User might have moved to different screen during analysis ===
      if (_activePackage != originalPackage) {
        developer.log(
            '⏭️ User changed screen during analysis - discarding result',
            name: 'ScreenMonitor');
        return;
      }

      // === CHECK: Content changed during analysis (user scrolled) ===
      if (_lastProcessedContent != content &&
          _lastProcessedContent.isNotEmpty) {
        developer.log(
            '⏭️ Content changed during analysis - discarding stale result',
            name: 'ScreenMonitor');
        return;
      }

      final riskScore = backendResult.riskScore;
      final confidence = backendResult.confidence;

      developer.log(
          '📊 Result: risk=$riskScore, confidence=$confidence, hasUrl=$containsUrl, unsaved=$isUnsavedContact',
          name: 'ScreenMonitor');

      // === ADJUSTED THRESHOLDS for better scam detection ===
      // For saved contacts (forwarded/URL): still require slightly higher threshold
      // For unknown numbers: standard threshold
      double effectiveScamThreshold = _scamThreshold;
      double effectiveUrlThreshold = _urlWarningThreshold;

      if (!isUnsavedContact) {
        // Saved contact - require a very high-confidence match before alerting,
        // since false positives on trusted contacts erode user trust fastest
        effectiveScamThreshold = 0.92;
        effectiveUrlThreshold = 0.80;
      }

      bool shouldShowScamAlert = false;
      bool shouldShowUrlWarning = false;

      if (riskScore >= effectiveScamThreshold && confidence >= _minConfidence) {
        // Definite scam - show harsh red alert
        // Check RED alert cooldown (3 seconds)
        if (_lastScamAlertTime != null &&
            DateTime.now().difference(_lastScamAlertTime!) <
                _scamAlertCooldown) {
          developer.log(
              '⏭️ RED alert cooldown active (3s), skipping scam alert',
              name: 'ScreenMonitor');
        } else {
          shouldShowScamAlert = true;
        }
      } else if (containsUrl &&
          riskScore >= effectiveUrlThreshold &&
          confidence >= 0.6) {
        // Suspicious URL but not definite scam - show softer URL warning
        // Check BLACK alert cooldown (12 hours)
        if (_lastUrlAlertTime != null &&
            DateTime.now().difference(_lastUrlAlertTime!) < _urlAlertCooldown) {
          developer.log(
              '⏭️ BLACK alert cooldown active (12h), skipping URL warning',
              name: 'ScreenMonitor');
        } else {
          shouldShowUrlWarning = true;
        }
      }

      if (shouldShowScamAlert || shouldShowUrlWarning) {
        _incrementScamCount();

        // Add to alerted set to prevent repeat alerts
        _alertedHashes.add(contentHash);

        // Update the appropriate cooldown timer
        if (shouldShowScamAlert) {
          _lastScamAlertTime = DateTime.now();
        } else {
          _lastUrlAlertTime = DateTime.now();
        }

        // Clean up old hashes (keep max 100)
        if (_alertedHashes.length > 100) {
          _alertedHashes.clear();
        }

        final alertData = <String, String>{
          'content': content,
          'packageName': packageName,
          'severity': shouldShowScamAlert ? 'HIGH_RISK' : 'URL_WARNING',
          'riskLevel': backendResult.riskLevel.toString(),
          'score': riskScore.toStringAsFixed(3),
          'confidence': confidence.toStringAsFixed(3),
          'containsUrl': containsUrl.toString(),
        };

        if (backendResult.reasoning.isNotEmpty) {
          alertData['reason'] = backendResult.reasoning;
        }

        alertData['time'] =
            backendResult.timestamp.millisecondsSinceEpoch.toString();

        if (backendResult.evidence?['phone_number'] != null) {
          final phone = backendResult.evidence!['phone_number'].toString();
          if (phone.isNotEmpty) {
            alertData['scamNumber'] = phone;
          }
        }

        _activeAlerts++;

        if (shouldShowScamAlert) {
          developer.log('🚨 SCAM ALERT triggered!', name: 'ScreenMonitor');
          await _overlayService.showScamOverlay(
            'SCAM WARNING: High Risk Content Detected',
            'HIGH_RISK',
            alertData,
          );
          await _triggerHapticFeedback();
        } else {
          developer.log('⚠️ URL WARNING triggered', name: 'ScreenMonitor');
          await _overlayService.showScamOverlay(
            'Caution: Verify this link before clicking',
            'URL_WARNING',
            alertData,
          );
          // Lighter haptic for URL warning
          await HapticFeedback.mediumImpact();
        }

        notifyListeners();
      } else {
        developer.log('✅ Content passed (safe)', name: 'ScreenMonitor');
      }

      _lastProcessedContent = content;
    } catch (e) {
      debugPrint('Failed to process content: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  bool _shouldProcessContent(String content) {
    if (content.length < minContentLength ||
        content.length > maxContentLength) {
      developer.log('⏭️ Content length out of range: ${content.length}',
          name: 'ScreenMonitor');
      return false;
    }
    if (content == _lastProcessedContent) {
      // Don't log this - it's too noisy for duplicate content
      return false;
    }
    if (_isProcessing) {
      developer.log('⏭️ Already processing, skipping', name: 'ScreenMonitor');
      return false;
    }
    return true;
  }

  /// Check if content is from a verified profile (blue checkmark, etc.)
  /// NOTE: Only check for EXPLICIT verified business indicators, NOT emojis
  bool _isVerifiedProfile(String content) {
    final lowerContent = content.toLowerCase();

    // WhatsApp specific: "This chat is with a verified business account"
    if (lowerContent.contains('verified business') ||
        lowerContent.contains('official business account') ||
        lowerContent.contains('meta verified')) {
      developer.log('🔵 Verified business detected', name: 'ScreenMonitor');
      return true;
    }

    // Instagram specific blue badge pattern
    if (lowerContent.contains('verified account') ||
        lowerContent.contains('official account')) {
      developer.log('🔵 Verified account detected', name: 'ScreenMonitor');
      return true;
    }

    // Don't skip just because of emojis like 🙏 or ✓
    return false;
  }

  /// Check if content suggests an unsaved contact.
  ///
  /// IMPORTANT: showing a name-like string is NOT proof of a saved contact -
  /// WhatsApp Business profiles, spoofed display names, and plenty of scam
  /// senders show a name instead of a raw number without being in the
  /// user's phonebook. The only way to be sure is to cross-check against
  /// the real synced Contacts database. Safe default when we can't
  /// determine it either way is UNSAVED (stricter scanning), never SAVED.
  bool _isUnsavedContact(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return true; // safe default: treat as unsaved

    // Check first few lines (usually contain contact name/number)
    final headerContent = lines.take(3).join(' ');
    final firstLine = lines.first.trim();

    // Phone number patterns that indicate an unsaved contact
    final phonePatterns = [
      RegExp(r'\+91[\s-]?\d{5}[\s-]?\d{5}'), // +91 98765 43210
      RegExp(r'\+91[\s-]?\d{10}'), // +91 9876543210
      RegExp(r'\+\d{1,3}[\s-]?\d{6,14}'), // International format
      RegExp(r'^[6-9]\d{9}$'), // Plain Indian mobile number
      RegExp(r'^\d{10,15}$'), // Plain number
    ];

    for (final pattern in phonePatterns) {
      if (pattern.hasMatch(headerContent)) {
        // A raw number is visible - but it might still be a real saved
        // contact number just displayed without the name. Cross-check it.
        if (_contactsService.isKnownPhoneNumber(headerContent)) {
          developer.log('👤 Saved contact detected (number matches real contact)',
              name: 'ScreenMonitor');
          return false;
        }
        developer.log('📞 Unsaved contact detected (phone number visible, no contact match)',
            name: 'ScreenMonitor');
        return true;
      }
    }

    // Also check for WhatsApp's "tap to add to contacts" or similar
    final lowerContent = content.toLowerCase();
    if (lowerContent.contains('tap to add') ||
        lowerContent.contains('add to contacts') ||
        lowerContent.contains('not in your contacts')) {
      developer.log('📞 Unsaved contact detected (add to contacts prompt)',
          name: 'ScreenMonitor');
      return true;
    }

    // A name-like string is shown. Only treat as a saved contact if it
    // exactly matches a name from the real, synced phone contacts -
    // otherwise this could be a business profile or spoofed display name.
    if (_contactsService.isKnownContactName(firstLine)) {
      developer.log('👤 Saved contact detected (name matches real contact): $firstLine',
          name: 'ScreenMonitor');
      return false;
    }

    developer.log(
        '📞 Treating as unsaved contact (name "$firstLine" not found in real contacts, or contacts not yet synced)',
        name: 'ScreenMonitor');
    return true;
  }

  /// Extract sender identifier from screen content (name, phone, or sender ID)
  String? _extractSenderFromContent(String content) {
    if (content.isEmpty) return null;

    final lines = content.split('\n');
    if (lines.isEmpty) return null;

    // The first line often contains the contact name or sender ID
    final firstLine = lines.first.trim();

    // Check for alphanumeric sender IDs (like VK-HDFCBK, AD-AMAZON)
    final senderIdPattern =
        RegExp(r'^([A-Z]{2})-([A-Z0-9]{4,8})$', caseSensitive: false);
    if (senderIdPattern.hasMatch(firstLine)) {
      developer.log('📧 Extracted sender ID: $firstLine',
          name: 'ScreenMonitor');
      return firstLine.toUpperCase();
    }

    // Check for phone number patterns
    final phonePattern = RegExp(r'^\+?\d[\d\s-]{8,15}$');
    if (phonePattern.hasMatch(firstLine)) {
      developer.log('📞 Extracted phone number as sender: $firstLine',
          name: 'ScreenMonitor');
      return firstLine.replaceAll(RegExp(r'[\s-]'), '');
    }

    // Check first few lines for sender ID patterns (might not be first line)
    for (final line in lines.take(5)) {
      final cleanLine = line.trim();
      if (senderIdPattern.hasMatch(cleanLine)) {
        developer.log('📧 Extracted sender ID from content: $cleanLine',
            name: 'ScreenMonitor');
        return cleanLine.toUpperCase();
      }
    }

    // If first line looks like a name (letters, spaces, some special chars)
    final namePattern = RegExp(r"^[A-Za-z][A-Za-z\s.\-']{2,30}$");
    if (namePattern.hasMatch(firstLine)) {
      developer.log('👤 Extracted contact name as sender: $firstLine',
          name: 'ScreenMonitor');
      return firstLine;
    }

    return null;
  }

  void _incrementScreenCount() {
    _totalScreensMonitored++;
    _updateProtectionScore();
    notifyListeners();
  }

  void _incrementScamCount() {
    _scamsDetected++;
    _updateProtectionScore();
    notifyListeners();
  }

  void _updateProtectionScore() {
    if (_totalScreensMonitored > 0) {
      _protectionScore = (1 - (_scamsDetected / _totalScreensMonitored)) * 100;
    } else {
      _protectionScore = 0.0;
    }
  }

  Future<void> _triggerHapticFeedback() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Failed to trigger haptic feedback: $e');
    }
  }
}
