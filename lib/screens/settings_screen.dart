// screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sms_monitor_service.dart';
import '../services/call_monitor_service.dart';
import '../services/screen_monitor_service.dart';
import '../services/scam_detection_service.dart';
import '../services/overlay_service.dart';
import 'sensitivity_settings_screen.dart';
import 'custom_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _smsProtection = true;
  bool _callProtection = true;
  bool _screenMonitoring = true;
  bool _notifications = true;
  bool _autoBlock = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Protection Settings'),
          Consumer<SmsMonitorService>(
            builder: (context, smsService, child) {
              return SwitchListTile(
                title: const Text('SMS Protection'),
                subtitle: Text(
                  smsService.isMonitoring
                      ? 'Monitoring incoming messages'
                      : 'SMS monitoring disabled',
                ),
                value: _smsProtection && smsService.isMonitoring,
                onChanged: (value) async {
                  setState(() => _smsProtection = value);
                  if (value) {
                    final detector = Provider.of<SmartScamDetectionService>(
                        context,
                        listen: false);
                    final overlay =
                        Provider.of<OverlayService>(context, listen: false);
                    await smsService.startMonitoring(detector, overlay);
                  } else {
                    smsService.stopMonitoring();
                  }
                },
              );
            },
          ),
          Consumer<CallMonitorService>(
            builder: (context, callService, child) {
              return SwitchListTile(
                title: const Text('Call Protection'),
                subtitle: Text(
                  callService.isMonitoring
                      ? 'Monitoring incoming calls'
                      : 'Call monitoring disabled',
                ),
                value: _callProtection && callService.isMonitoring,
                onChanged: (value) {
                  setState(() => _callProtection = value);
                  if (value) {
                    callService.startMonitoring();
                  } else {
                    callService.stopMonitoring();
                  }
                },
              );
            },
          ),
          Consumer<ScreenMonitorService>(
            builder: (context, screenService, child) {
              return SwitchListTile(
                title: const Text('Screen Monitoring'),
                subtitle: Text(
                  screenService.isMonitoring
                      ? 'Monitoring screen content for scams'
                      : 'Screen monitoring disabled',
                ),
                value: _screenMonitoring && screenService.isMonitoring,
                onChanged: (value) async {
                  setState(() => _screenMonitoring = value);
                  if (value) {
                    await screenService.startRealtimeMonitoring();
                  } else {
                    await screenService.stopRealtimeMonitoring();
                  }
                },
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('Notification Settings'),
          SwitchListTile(
            title: const Text('Show Notifications'),
            subtitle: const Text('Get notified about detected scams'),
            value: _notifications,
            onChanged: (value) {
              setState(() => _notifications = value);
            },
          ),
          SwitchListTile(
            title: const Text('Auto-block Scams'),
            subtitle: const Text(
                'Automatically block detected scam messages and calls'),
            value: _autoBlock,
            onChanged: (value) {
              setState(() => _autoBlock = value);
            },
          ),
          const Divider(),
          _buildSectionHeader('Detection Settings'),
          ListTile(
            title: const Text('Detection Sensitivity'),
            subtitle: const Text('Adjust how sensitive scam detection is'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SensitivitySettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Custom Rules'),
            subtitle: const Text('Add your own scam detection rules'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomRulesScreen(),
                ),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('About'),
          ListTile(
            leading: Image.asset(
              'assets/images/elephas_logo.png',
              height: 40,
              width: 40,
            ),
            title: const Text('Elephas AI'),
            subtitle: const Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
