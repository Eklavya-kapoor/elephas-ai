// lib/services/sms_monitor_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../core/models/detection_models.dart';
import 'scam_detection_service.dart';
import 'overlay_service.dart';
import 'contact_service.dart';

class _MonitorStats {
  final int totalScanned;
  final int scamsBlocked;

  const _MonitorStats({
    required this.totalScanned,
    required this.scamsBlocked,
  });

  _MonitorStats copyWith({
    int? totalScanned,
    int? scamsBlocked,
  }) {
    return _MonitorStats(
      totalScanned: totalScanned ?? this.totalScanned,
      scamsBlocked: scamsBlocked ?? this.scamsBlocked,
    );
  }
}

class SmsMonitorService extends ChangeNotifier {
  // Services
  final SmsQuery _query = SmsQuery();
  final HighPerformanceContactService _contactService =
      HighPerformanceContactService();

  SmartScamDetectionService? _scamDetectionService;
  OverlayService? _overlayService;

  /// Channel for custom critical alert overlays
  final MethodChannel _criticalAlertChannel =
      const MethodChannel('elephas_ai/critical_alert');

  // Alert assets
  static const String _criticalAlertAsset =
      'assets/images/critical_sms_alert.png';
  static const Duration _criticalAlertDuration = Duration(seconds: 5);

  bool _isMonitoring = false;
  final ValueNotifier<_MonitorStats> _stats = ValueNotifier<_MonitorStats>(
    const _MonitorStats(totalScanned: 0, scamsBlocked: 0),
  );
  Timer? _monitoringTimer;
  final List<SmsMessage> _messageCache = [];

  bool get isMonitoring => _isMonitoring;
  int get totalSmsScanned => _stats.value.totalScanned;
  int get scamsBlocked => _stats.value.scamsBlocked;
  HighPerformanceContactService get contactService => _contactService;

  void _incrementScanned() {
    _stats.value = _stats.value.copyWith(
      totalScanned: _stats.value.totalScanned + 1,
    );
    notifyListeners();
  }

  void _incrementBlocked() {
    _stats.value = _stats.value.copyWith(
      scamsBlocked: _stats.value.scamsBlocked + 1,
    );
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    final smsPermission = await Permission.sms.request();
    final contactPermission = await Permission.contacts.request();

    if (kDebugMode) {
      print('[SmsMonitorService] SMS Permission: ${smsPermission.isGranted}');
      print(
          '[SmsMonitorService] Contact Permission: ${contactPermission.isGranted}');
    }

    if (contactPermission.isGranted) {
      await _contactService.initialize();
    }

    return smsPermission.isGranted;
  }

  /// Start monitoring with scam detection and overlay services
  Future<void> startMonitoring(
    SmartScamDetectionService scamDetection,
    OverlayService overlayService,
  ) async {
    _scamDetectionService = scamDetection;
    _overlayService = overlayService;

    if (kDebugMode) {
      print('[SmsMonitorService] startMonitoring called');
      print(
          '[SmsMonitorService] detector: ${scamDetection.runtimeType} @ ${identityHashCode(scamDetection)}');
      print(
          '[SmsMonitorService] overlayService: ${overlayService.runtimeType} @ ${identityHashCode(overlayService)}');
    }

    // Check SMS permission (and request if not granted)
    if (!await requestPermissions()) {
      if (kDebugMode) {
        print('SMS permissions not granted. Cannot start monitoring.');
      }
      return;
    }

    _isMonitoring = true;
    notifyListeners();

    // Fetch initial batch of messages to avoid processing them as 'new' later
    final initialMessages = await getRecentSms();
    _messageCache.clear();
    _messageCache.addAll(initialMessages);

    // Start a periodic timer to check for new messages
    _monitoringTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkForNewMessages();
    });
  }

  Future<void> _checkForNewMessages() async {
    if (!_isMonitoring ||
        _scamDetectionService == null ||
        _overlayService == null) {
      return;
    }

    try {
      final currentMessages = await getRecentSms();
      final newMessages = _findNewMessages(currentMessages);

      for (final message in newMessages) {
        _incrementScanned();

        final result = await _scamDetectionService!.analyzeMessage(
          message.body ?? '',
          appPackage: 'com.android.messaging',
          contactId: message.address ?? 'unknown',
        );

        if (result.isThreat) {
          _incrementBlocked();
          await _showAlert(message, result);
        }
      }

      _messageCache.clear();
      _messageCache.addAll(currentMessages);
    } catch (e) {
      if (kDebugMode) {
        print('[SmsMonitorService] Error checking messages: $e');
      }
    }
  }

  List<SmsMessage> _findNewMessages(List<SmsMessage> currentMessages) {
    final existingIds = _messageCache.map((m) => m.id).toSet();
    return currentMessages.where((m) => !existingIds.contains(m.id)).toList();
  }

  Future<List<SmsMessage>> getRecentSms() async {
    try {
      return await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 20,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[SmsMonitorService] Error getting SMS: $e');
      }
      return [];
    }
  }

  Future<void> _showAlert(SmsMessage message, DetectionResult result) async {
    if (_overlayService == null) return;

    try {
      // Check if message contains URL - use softer alert for URLs to reduce false positives
      final messageBody = message.body ?? '';
      final containsUrl = messageBody.contains(RegExp(
          r'(https?://|www\.|\.com|\.org|\.net|\.in|\.io)',
          caseSensitive: false));

      final alertData = <String, String>{
        'title': containsUrl ? 'URL Warning' : 'SMS Scam Warning',
        'messagePreview': messageBody.substring(
            0, messageBody.length > 50 ? 50 : messageBody.length),
        'sender': message.address ?? 'Unknown',
        'containsUrl':
            containsUrl.toString(), // This triggers URL alert in overlay
      };

      final alertTitle = containsUrl
          ? 'URL found in message from ${message.address}'
          : 'Suspicious message from ${message.address}';
      final severity = containsUrl ? 'URL_WARNING' : 'SMS_SCAM';

      await _overlayService!.showScamOverlay(alertTitle, severity, alertData);

      // Only show critical native alert for non-URL scams (reduce false positive annoyance)
      if (!containsUrl) {
        await _criticalAlertChannel.invokeMethod('showAlert', {
          'title': 'SMS Scam Warning',
          'message': 'Suspicious message blocked from ${message.address}',
          'image': _criticalAlertAsset,
          'duration': _criticalAlertDuration.inMilliseconds,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SmsMonitorService] Error showing alert: $e');
      }
    }
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _stats.dispose();
    super.dispose();
  }
}
