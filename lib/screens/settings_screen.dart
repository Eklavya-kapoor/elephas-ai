// screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/screen_monitor_service.dart';

import 'sensitivity_settings_screen.dart';
import 'custom_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _screenMonitoring = true;
  bool _notifications = true;
  bool _autoBlock = false;

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Protection Settings'),
          Consumer<ScreenMonitorService>(
            builder: (context, screenService, child) {
              return SwitchListTile(
                title: const Text('Screen Protection'),
                subtitle: Text(
                  screenService.isMonitoring
                      ? 'Actively monitoring for scams'
                      : 'Screen protection disabled',
                ),
                value: _screenMonitoring && screenService.isMonitoring,
                onChanged: (value) async {
                  setState(() => _screenMonitoring = value);
                  if (value) {
                    // Start monitoring
                    await screenService.startMonitoring();
                  } else {
                    await screenService.stopMonitoring();
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
            subtitle: const Text('Automatically block detected scams'),
            value: _autoBlock,
            onChanged: (value) {
              setState(() => _autoBlock = value);
            },
          ),
          const Divider(),
          _buildSectionHeader('Detection Settings'),
          ListTile(
            leading: const Icon(Icons.tune, color: Colors.blue),
            title: const Text('Detection Sensitivity'),
            subtitle: const Text('Adjust how aggressively scams are detected'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SensitivitySettingsScreen(),
                  ),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.rule, color: Colors.orange),
            title: const Text('Custom Detection Rules'),
            subtitle: const Text('Add keywords and patterns to watch for'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomRulesScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
