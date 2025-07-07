// lib/services/sms_monitor_service.dart
import 'package:flutter/foundation.dart'; // Required for ChangeNotifier and kDebugMode
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:elephas_ai/models/alert_level.dart';
import 'scam_detection_service.dart'; // Make sure this path is correct
import 'overlay_service.dart'; // Make sure this path is correct

class SmsMonitorService extends ChangeNotifier {
  final SmsQuery _query = SmsQuery();
  bool _isMonitoring = false;
  int _totalSmsScanned = 0;
  int _scamsBlocked = 0;
  Timer? _monitoringTimer;
  List<SmsMessage> _lastProcessedMessages = [];

  bool get isMonitoring => _isMonitoring;
  int get totalSmsScanned => _totalSmsScanned;
  int get scamsBlocked => _scamsBlocked;

  Future<bool> requestPermissions() async {
    final smsPermission = await Permission.sms.request();
    return smsPermission.isGranted;
  }

  Future<void> startMonitoring(SmartScamDetectionService detector,
      [OverlayService? overlayService]) async {
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
    _lastProcessedMessages = await getRecentSms();

    // Start a periodic timer to check for new messages
    _monitoringTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkForNewMessages(detector, overlayService);
    });

    if (kDebugMode) {
      print('SMS Monitoring started.');
    }
  }

  Future<void> _checkForNewMessages(SmartScamDetectionService detector,
      OverlayService? overlayService) async {
    try {
      final currentMessages = await getRecentSms();

      // Filter out messages that were already processed
      final newMessages = currentMessages.where((current) {
        return !_lastProcessedMessages.any((last) => last.id == current.id);
      }).toList();

      if (newMessages.isEmpty && kDebugMode) {
        // print('No new SMS messages to process.'); // Too chatty for regular use
      }

      for (final message in newMessages) {
        _totalSmsScanned++;
        notifyListeners(); // Update UI for scanned count

        if (kDebugMode) {
          print(
              'Processing new SMS from ${message.address ?? 'Unknown'}: ${message.body ?? 'No body'}');
        }

        // Perform scam detection using the injected service
        final result = await detector.scanMessage(message.body ?? '');

        if (result.isScam) {
          _scamsBlocked++;
          notifyListeners(); // Update UI for blocked scams

          // If an OverlayService is provided, show the scam alert
          // Using the null-aware operator '?.showScamOverlay' ensures it only runs if overlayService is not null
          overlayService?.showScamOverlay(
            "⚠️ Scam SMS Detected",
            result.alertLevel == AlertLevel.critical
                ? "critical_blocking"
                : "high_warning",
            {
              'sender': message.sender,
              'content': message.body,
              'confidence': result.confidence,
              'reason': result.reason,
              'scamTypes': result.scamTypes,
            },
          );

          if (kDebugMode) {
            print('🔥 SCAM DETECTED from ${message.address}: ${message.body}');
            // FIX: Removed the unnecessary null comparison on scanResult.reason
            // If scanResult.reason is null, the ?? '' will handle it for the print.
            // If scanResult.reason is non-nullable, the check is redundant.
            print('   Reason: ${result.reason}');
          }
        } else {
          if (kDebugMode) {
            print('   SMS is CLEAN.');
          }
        }
      }

      // Update the list of last processed messages
      _lastProcessedMessages = currentMessages;
    } catch (e) {
      if (kDebugMode) {
        print('Error in _checkForNewMessages: $e');
      }
    }
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel(); // Cancel the timer if it's active
    _monitoringTimer = null;
    notifyListeners();
    if (kDebugMode) {
      print('SMS Monitoring stopped.');
    }
  }

  Future<List<SmsMessage>> getRecentSms() async {
    // Request permission again just before querying to be safe, though it's done in startMonitoring
    if (!await Permission.sms.isGranted) {
      if (kDebugMode) {
        print('SMS permission not granted for getRecentSms.');
      }
      return [];
    }
    try {
      // Get all SMS messages; you might want to limit this in a real app for performance
      final messages = await _query.getAllSms;
      // Taking the last 50 messages to check for new ones; adjust as needed
      return messages.take(50).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting SMS messages: $e');
      }
      return [];
    }
  }

  @override
  void dispose() {
    stopMonitoring(); // Ensure monitoring is stopped when the service is disposed
    super.dispose();
    if (kDebugMode) {
      print('SmsMonitorService disposed.');
    }
  }
}
