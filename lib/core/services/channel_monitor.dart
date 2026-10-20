import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/channel_info.dart';

/// Monitors specific channels (apps) for potential scam activity
class ChannelMonitor extends ChangeNotifier {
  final Map<String, ChannelInfo> _monitoredChannels = {};
  bool _isInitialized = false;

  // List of apps that should be monitored
  static const _targetApps = {
    'com.whatsapp': ('WhatsApp', 'messaging'),
    'org.telegram.messenger': ('Telegram', 'messaging'),
    'com.facebook.orca': ('Messenger', 'messaging'),
    'com.instagram.android': ('Instagram', 'social'),
    'com.android.mms': ('SMS', 'messaging'),
    'com.google.android.apps.messaging': ('Messages', 'messaging'),
    'com.tinder': ('Tinder', 'dating'),
    'com.bumble.app': ('Bumble', 'dating'),
    'com.okcupid.okcupid': ('OkCupid', 'dating'),
  };

  bool get isInitialized => _isInitialized;

  /// Get set of monitored app package names
  Set<String> get monitoredApps => _monitoredChannels.keys.toSet();

  /// Initialize the channel monitor
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Set up monitoring for known channels
    for (final entry in _targetApps.entries) {
      final (appName, channelType) = _targetApps[entry.key]!;
      _monitoredChannels[entry.key] = ChannelInfo(
        packageName: entry.key,
        appName: appName,
        channelType: channelType,
        isActive: true,
        lastScan: DateTime.now(),
      );
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Get list of currently active channels
  List<ChannelInfo> getActiveChannels() {
    return _monitoredChannels.values
        .where((channel) => channel.isActive)
        .toList();
  }

  /// Update monitoring status for a channel
  void updateChannel(String packageName, {
    bool? isActive,
    int? threatsDetected,
    double? riskScore,
  }) {
    final channel = _monitoredChannels[packageName];
    if (channel == null) return;

    _monitoredChannels[packageName] = ChannelInfo(
      packageName: channel.packageName,
      appName: channel.appName,
      channelType: channel.channelType,
      isActive: isActive ?? channel.isActive,
      lastScan: DateTime.now(),
      threatsDetected: threatsDetected ?? channel.threatsDetected,
      riskScore: riskScore ?? channel.riskScore,
    );
    notifyListeners();
  }

  /// Check if a channel should be monitored
  bool shouldMonitorChannel(String packageName) {
    return _targetApps.containsKey(packageName);
  }

  /// Get type of channel for analysis context
  String getChannelType(String packageName) {
    final channel = _monitoredChannels[packageName];
    return channel?.channelType ?? 'other';
  }
}
