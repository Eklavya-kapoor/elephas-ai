// lib/screens/home_screen_phase1.dart - Updated for Elephas AI
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/elephas_main_service.dart';
import '../widgets/scam_history_widget.dart';
import 'history_screen.dart';

class HomeScreenPhase1 extends StatefulWidget {
  const HomeScreenPhase1({super.key});

  @override
  State<HomeScreenPhase1> createState() => _HomeScreenPhase1State();
}

class _HomeScreenPhase1State extends State<HomeScreenPhase1> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elephas AI - Smart Protection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings if needed
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Protection Status Card
            Consumer<ElephasMainService>(
              builder: (context, elephas, child) {
                return Card(
                  elevation: 4,
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: elephas.isActive 
                          ? [Colors.green.shade600, Colors.green.shade800]
                          : [Colors.orange.shade600, Colors.orange.shade800],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          elephas.isActive ? Icons.security : Icons.warning,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          elephas.isActive 
                            ? 'ELEPHAS AI PROTECTION ACTIVE'
                            : 'INITIALIZING PROTECTION...',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          elephas.isActive
                            ? 'Zero false positive scam detection is monitoring your device'
                            : 'Please wait while we initialize your protection',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Features Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phase 1 Features',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.apps,
                      'Channel-Specific Monitoring',
                      'WhatsApp, Telegram, Instagram, SMS, Gmail',
                    ),
                    _buildFeatureItem(
                      Icons.psychology,
                      'Context Intelligence',
                      'Contact relationships & conversation analysis',
                    ),
                    _buildFeatureItem(
                      Icons.security,
                      'Zero False Positives',
                      'Surgical precision with multi-layer detection',
                    ),
                    _buildFeatureItem(
                      Icons.image,
                      'Simple Image Overlay',
                      'Clean warning system with no buttons',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Test Protection Button
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Your Protection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Want to see the system in action? Use the demo app to test scam detection.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Show dialog with test instructions
                        _showTestInstructions(context);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('View Test Instructions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Status Information
            Consumer<ElephasMainService>(
              builder: (context, elephas, child) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusItem(
                          'Protection Service',
                          elephas.isActive ? 'Active' : 'Inactive',
                          elephas.isActive,
                        ),
                        _buildStatusItem(
                          'Zero False Positive Detector',
                          elephas.isInitialized ? 'Ready' : 'Loading',
                          elephas.isInitialized,
                        ),
                        _buildStatusItem(
                          'Contact Intelligence',
                          elephas.isInitialized ? 'Ready' : 'Loading',
                          elephas.isInitialized,
                        ),
                        _buildStatusItem(
                          'Channel Monitor',
                          elephas.isInitialized ? 'Ready' : 'Loading',
                          elephas.isInitialized,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Scam History Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scam Detection History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(
                      height: 200,
                      child: ScamHistoryWidget(),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to detailed history screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('View Full History'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String title, String status, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.green.shade800 : Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Your Protection'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To test the Phase 1 scam detection system:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Open WhatsApp or Telegram'),
              SizedBox(height: 8),
              Text('2. Type a test scam message like:'),
              SizedBox(height: 4),
              Text(
                '"URGENT! Bank account blocked, send OTP: 123456"',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
              SizedBox(height: 8),
              Text('3. The image overlay will appear if a scam is detected'),
              SizedBox(height: 12),
              Text(
                'Note: The system only monitors high-risk messaging apps for maximum accuracy.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
