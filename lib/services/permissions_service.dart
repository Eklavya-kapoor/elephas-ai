// lib/services/permissions_service.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PermissionsService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.example.scamshield_flutter_app/permissions');

  // Core permissions required
  final List<Permission> _requiredPermissions = [
    Permission.sms,
    Permission.phone,
    Permission.systemAlertWindow,
    Permission.microphone,
    Permission.notification,
    Permission.contacts, // Needed for real contact-trust matching, not screen-text guessing
  ];

  bool _isAccessibilityEnabled = false;
  bool _isOverlayEnabled = false;
  Map<Permission, PermissionStatus> _permissions = {};
  Map<String, bool> _specialPermissions = {};
  String _protectionLevel = 'UNKNOWN';

  bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  bool get isOverlayEnabled => _isOverlayEnabled;
  Map<Permission, PermissionStatus> get permissions => _permissions;
  Map<String, bool> get specialPermissions => _specialPermissions;
  String get protectionLevel => _protectionLevel;

  // Check if all permissions are granted
  Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};
    for (Permission permission in _requiredPermissions) {
      statuses[permission] = await permission.status;
    }
    _permissions = statuses;
    notifyListeners();
    return statuses;
  }

  // Check specific Android permissions that require special handling
  Future<Map<String, bool>> checkSpecialPermissions() async {
    Map<String, bool> specialPerms = {};

    try {
      // Check accessibility service
      _isAccessibilityEnabled = await _channel.invokeMethod('checkAccessibilityPermission');
      specialPerms['accessibility'] = _isAccessibilityEnabled;

      // Check system alert window
      _isOverlayEnabled = await _channel.invokeMethod('checkSystemAlertWindowPermission');
      specialPerms['systemAlertWindow'] = _isOverlayEnabled;

      _specialPermissions = specialPerms;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking special permissions: $e');
    }

    return specialPerms;
  }

  // Get current protection level based on granted permissions
  Future<String> getProtectionLevel() async {
    await checkAllPermissions();
    await checkSpecialPermissions();

    int grantedCount = 0;
    for (var status in _permissions.values) {
      if (status == PermissionStatus.granted) grantedCount++;
    }

    for (var granted in _specialPermissions.values) {
      if (granted) grantedCount++;
    }

    if (grantedCount >= 8) {
      _protectionLevel = 'EXCELLENT';
    } else if (grantedCount >= 6) {
      _protectionLevel = 'GOOD';
    } else if (grantedCount >= 4) {
      _protectionLevel = 'BASIC';
    } else {
      _protectionLevel = 'INSUFFICIENT';
    }

    notifyListeners();
    return _protectionLevel;
  }

  // Check if we have sufficient permissions to proceed. Accessibility is
  // required explicitly - without it Elephas cannot read messages at all,
  // so no amount of other granted permissions can substitute for it.
  bool hasAllRequiredPermissions() {
    if (!_isAccessibilityEnabled) return false;

    for (var status in _permissions.values) {
      if (!status.isGranted) return false;
    }

    return true;
  }

  // Request all permissions
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final results = await _requiredPermissions.request();
    _permissions = results;
    notifyListeners();
    return results;
  }

  // Open specific settings
  Future<bool> openSystemAlertWindowSettings() async {
    try {
      return await _channel.invokeMethod('openSystemAlertWindowSettings');
    } catch (e) {
      debugPrint('Error opening system alert window settings: $e');
      return false;
    }
  }

  // Open accessibility settings
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error opening accessibility settings: $e');
      // Fallback to app settings if direct accessibility settings fails
      await openAppSettings();
    }
  }
}
