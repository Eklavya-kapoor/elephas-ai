// lib/screens/sensitivity_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scam_detection_service.dart'; // Enhanced Elephas AI
import '../core/models/alert_types.dart';

class SensitivitySettingsScreen extends StatefulWidget {
  const SensitivitySettingsScreen({super.key});

  @override
  SensitivitySettingsState createState() => SensitivitySettingsState();
}

class SensitivitySettingsState extends State<SensitivitySettingsScreen> {
  // Default sensitivity values
  double _smsSensitivity = 0.5;
  double _callSensitivity = 0.5;
  double _screenSensitivity = 0.5;
  AlertLevel _defaultAlertLevel = AlertLevel.medium;

  @override
  void initState() {
    super.initState();
    // Load current settings from scam detection service
    final scamService =
        Provider.of<SmartScamDetectionService>(context, listen: false);
    _smsSensitivity = scamService.smsSensitivity;
    _callSensitivity = scamService.callSensitivity;
    _screenSensitivity = scamService.screenSensitivity;
    _defaultAlertLevel = scamService.defaultAlertLevel;
  }

  @override
  Widget build(BuildContext context) {
    final scamService = Provider.of<SmartScamDetectionService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Sensitivity'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Adjust sensitivity levels for different types of scans. Higher sensitivity may result in more false positives.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('SMS Detection'),
          _buildSensitivitySlider(
            value: _smsSensitivity,
            onChanged: (value) {
              setState(() {
                _smsSensitivity = value;
                scamService.smsSensitivity = value;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Call Screening'),
          _buildSensitivitySlider(
            value: _callSensitivity,
            onChanged: (value) {
              setState(() {
                _callSensitivity = value;
                scamService.callSensitivity = value;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Screen Monitoring'),
          _buildSensitivitySlider(
            value: _screenSensitivity,
            onChanged: (value) {
              setState(() {
                _screenSensitivity = value;
                scamService.screenSensitivity = value;
              });
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Default Alert Level'),
          _buildAlertLevelSelector(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Reset to default values
              setState(() {
                _smsSensitivity = 0.5;
                _callSensitivity = 0.5;
                _screenSensitivity = 0.5;
                _defaultAlertLevel = AlertLevel.medium;

                // Update service
                scamService.smsSensitivity = 0.5;
                scamService.callSensitivity = 0.5;
                scamService.screenSensitivity = 0.5;
                scamService.defaultAlertLevel = AlertLevel.medium;
              });
            },
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSensitivitySlider({
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Low'),
            Text('High'),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          label: _getSensitivityLabel(value),
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _getSensitivityLabel(double value) {
    if (value < 0.3) return 'Low';
    if (value < 0.7) return 'Medium';
    return 'High';
  }

  Widget _buildAlertLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose the default alert level for detected scams:'),
        const SizedBox(height: 8),
        ListTile(
          title: const Text('None'),
          subtitle: const Text('Only detect, no alerts'),
          leading: Radio<AlertLevel>(
            value: AlertLevel.info,
            groupValue: _defaultAlertLevel,
            onChanged: (AlertLevel? value) {
              if (value != null) {
                setState(() {
                  _defaultAlertLevel = value;
                  Provider.of<SmartScamDetectionService>(context, listen: false)
                      .defaultAlertLevel = value;
                });
              }
            },
          ),
        ),
        ListTile(
          title: const Text('Medium'),
          leading: Radio<AlertLevel>(
            value: AlertLevel.medium,
            groupValue: _defaultAlertLevel,
            onChanged: (AlertLevel? value) {
              if (value != null) {
                setState(() {
                  _defaultAlertLevel = value;
                  Provider.of<SmartScamDetectionService>(context, listen: false)
                      .defaultAlertLevel = value;
                });
              }
            },
          ),
        ),
        ListTile(
          title: const Text('High'),
          leading: Radio<AlertLevel>(
            value: AlertLevel.high,
            groupValue: _defaultAlertLevel,
            onChanged: (AlertLevel? value) {
              if (value != null) {
                setState(() {
                  _defaultAlertLevel = value;
                  Provider.of<SmartScamDetectionService>(context, listen: false)
                      .defaultAlertLevel = value;
                });
              }
            },
          ),
        ),
        ListTile(
          title: const Text('Critical'),
          leading: Radio<AlertLevel>(
            value: AlertLevel.critical,
            groupValue: _defaultAlertLevel,
            onChanged: (AlertLevel? value) {
              if (value != null) {
                setState(() {
                  _defaultAlertLevel = value;
                  Provider.of<SmartScamDetectionService>(context, listen: false)
                      .defaultAlertLevel = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }
}
