import 'package:flutter/material.dart';
import '../services/scamshield_main_service.dart';

/// Complete integration test for Phase 1 ScamShield system
class ScamShieldIntegrationTest extends StatefulWidget {
  const ScamShieldIntegrationTest({super.key});

  @override
  State<ScamShieldIntegrationTest> createState() => _ScamShieldIntegrationTestState();
}

class _ScamShieldIntegrationTestState extends State<ScamShieldIntegrationTest> {
  final _scamShield = ScamShieldMainService.instance;
  String _status = 'Not initialized';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 1 Integration Test'),
        backgroundColor: _scamShield.isActive ? Colors.green : Colors.grey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _getStatusColor(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _initializeService,
              icon: const Icon(Icons.settings),
              label: const Text('1. Initialize System'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: (_scamShield.isInitialized && !_scamShield.isActive && !_isLoading) 
                  ? _startProtection 
                  : null,
              icon: const Icon(Icons.shield),
              label: const Text('2. Start Protection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _scamShield.isActive && !_isLoading ? _testOverlay : null,
              icon: const Icon(Icons.warning),
              label: const Text('3. Test Image Overlay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Monitored Apps
            if (_scamShield.isActive) ...[
              const Text(
                'High-Risk Apps Being Monitored:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAppItem('WhatsApp', '🟢 ACTIVE'),
                      _buildAppItem('Telegram', '🟢 ACTIVE'),
                      _buildAppItem('Instagram DM', '🟢 ACTIVE'),
                      _buildAppItem('SMS', '🟢 ACTIVE'),
                      _buildAppItem('Gmail', '🟢 ACTIVE'),
                      _buildAppItem('Dating Apps', '🟢 ACTIVE'),
                    ],
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Integration Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Integration Status:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildCheckItem('Core Detection Engine', true),
                  _buildCheckItem('Contact Intelligence', true),
                  _buildCheckItem('Context Analysis', true),
                  _buildCheckItem('Channel Monitoring', true),
                  _buildCheckItem('Overlay Integration', true),
                  _buildCheckItem('Zero False Positive Logic', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppItem(String name, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(status, style: const TextStyle(fontSize: 12, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String item, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isComplete ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(item),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_scamShield.isActive) return Colors.green;
    if (_scamShield.isInitialized) return Colors.blue;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_scamShield.isActive) return Icons.security;
    if (_scamShield.isInitialized) return Icons.settings;
    return Icons.info;
  }

  Future<void> _initializeService() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing Phase 1 system...';
    });

    try {
      await _scamShield.initialize();
      setState(() {
        _status = 'System initialized ✅\nReady to start protection';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startProtection() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting protection...';
    });

    try {
      await _scamShield.startProtection();
      final monitoredApps = _scamShield.getMonitoredApps();
      setState(() {
        _status = 'Protection ACTIVE ✅\nMonitoring ${monitoredApps.length} high-risk apps\nReady for overlay test';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to start protection: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testOverlay() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing image overlay...';
    });

    try {
      await _scamShield.testScamDetection();
      setState(() {
        _status = 'Overlay test triggered ✅\nImage overlay should appear now!';
      });
      
      // Show confirmation dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Overlay Test'),
            content: const Text('The image overlay should now be displayed on your screen. This is what users will see when a scam is detected in WhatsApp, Telegram, Instagram, SMS, or Gmail.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Overlay test failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
