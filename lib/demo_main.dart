import 'package:flutter/material.dart';
import 'test_integration.dart';

void main() {
  runApp(const ScamShieldPhase1Demo());
}

class ScamShieldPhase1Demo extends StatelessWidget {
  const ScamShieldPhase1Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamShield Phase 1 Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ScamShieldDemoHome(),
    );
  }
}

class ScamShieldDemoHome extends StatelessWidget {
  const ScamShieldDemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScamShield Phase 1'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Section
            Card(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.security,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Phase 1: Zero False Positive Protection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Billion-dollar grade scam detection with surgical precision',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Features
            const Text(
              'Key Features:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            _buildFeatureCard(
              Icons.apps,
              'Channel-Specific Monitoring',
              'Only monitors high-risk messaging apps:\nWhatsApp, Telegram, Instagram, SMS, Gmail',
            ),

            _buildFeatureCard(
              Icons.psychology,
              'Context Intelligence',
              'Understands relationships and conversation patterns for accurate detection',
            ),

            _buildFeatureCard(
              Icons.image,
              'Simple Image Overlay',
              'Shows your existing overlay image when scam detected - no buttons or explanations',
            ),

            const Spacer(),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ScamShieldIntegrationTest()),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test Integration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _showQuickStart(context),
              icon: const Icon(Icons.info),
              label: const Text('Integration Guide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickStart(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Integration'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '3-Step Integration:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                  '1. Import: import "lib/services/scamshield_main_service.dart";'),
              SizedBox(height: 4),
              Text('2. Wrap your app with ScamShieldWidget'),
              SizedBox(height: 4),
              Text('3. Set autoStart: true'),
              SizedBox(height: 16),
              Text(
                'Example:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'ScamShieldWidget(\n  autoStart: true,\n  child: YourMainApp(),\n)',
                style: TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: Color(0xFFF5F5F5),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'That\'s it! The system will automatically monitor high-risk messaging apps and show your image overlay when scams are detected.',
                style: TextStyle(fontStyle: FontStyle.italic),
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
