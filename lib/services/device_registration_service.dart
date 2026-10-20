// lib/services/device_registration_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';

/// Registers this install with the backend and sends periodic heartbeats,
/// so the admin dashboard can show real device/scan counts instead of
/// fake data. Every network call here is best-effort: scanning must keep
/// working even if the backend is unreachable or this fails entirely.
class DeviceRegistrationService {
  static const _logTag = 'DeviceRegistration';
  static DeviceRegistrationService? _instance;
  static DeviceRegistrationService get instance =>
      _instance ??= DeviceRegistrationService._();
  DeviceRegistrationService._();

  static const _installIdKey = 'elephas_install_id';
  static const _deviceIdKey = 'elephas_device_id';

  final http.Client _httpClient = http.Client();
  String? _deviceId;
  Timer? _heartbeatTimer;

  String? get deviceId => _deviceId;

  Future<void> registerAndStartHeartbeat() async {
    if (!AppConfig.enableTelemetry) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      var installId = prefs.getString(_installIdKey);
      if (installId == null) {
        installId = _generateInstallId();
        await prefs.setString(_installIdKey, installId);
      }

      final packageInfo = await PackageInfo.fromPlatform();

      final response = await _httpClient
          .post(
            Uri.parse('${AppConfig.apiUrl}/api/v1/devices/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'install_id': installId,
              'device_name': Platform.operatingSystemVersion,
              'app_version': packageInfo.version,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _deviceId = data['device_id'] as String?;
        if (_deviceId != null) {
          await prefs.setString(_deviceIdKey, _deviceId!);
          developer.log('Registered as $_deviceId', name: _logTag);
        }
      } else {
        _deviceId = prefs.getString(_deviceIdKey);
      }
    } catch (e) {
      developer.log('Registration failed (non-fatal): $e', name: _logTag);
      try {
        final prefs = await SharedPreferences.getInstance();
        _deviceId = prefs.getString(_deviceIdKey);
      } catch (_) {
        // No cached device_id available either - heartbeat/events just
        // won't fire this session, scanning is unaffected either way.
      }
    }

    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (_deviceId == null) return;
    _heartbeatTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => _sendHeartbeat());
    _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    if (_deviceId == null) return;
    try {
      await _httpClient
          .post(
            Uri.parse('${AppConfig.apiUrl}/api/v1/devices/$_deviceId/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': 'active'}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      developer.log('Heartbeat failed (non-fatal): $e', name: _logTag);
    }
  }

  /// Log a detection event for dashboard stats. Best-effort - never blocks
  /// or delays showing the scan result to the user.
  Future<void> logDetectionEvent({
    required String messageContent,
    String? sender,
    required bool isScam,
    required double confidence,
    required double riskScore,
    required String reasoning,
    required String actionTaken,
  }) async {
    if (!AppConfig.enableTelemetry || _deviceId == null) return;
    try {
      await _httpClient
          .post(
            Uri.parse('${AppConfig.apiUrl}/api/v1/events/log'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': _deviceId,
              'sender': sender,
              'message_content': messageContent,
              'is_scam': isScam,
              'confidence': confidence,
              'risk_score': riskScore,
              'reasoning': reasoning,
              'action_taken': actionTaken,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      developer.log('Event log failed (non-fatal): $e', name: _logTag);
    }
  }

  /// RFC 4122 v4 UUID, hand-rolled to avoid adding a new package dependency.
  String _generateInstallId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _httpClient.close();
  }
}
