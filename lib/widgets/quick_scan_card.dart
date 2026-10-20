import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scam_detection_service.dart'; // Enhanced Elephas AI
import '../core/models/alert_types.dart';
import '../core/models/detection_models.dart';

class QuickScanCard extends StatefulWidget {
  const QuickScanCard({super.key});

  @override
  QuickScanCardState createState() => QuickScanCardState();
}

class QuickScanCardState extends State<QuickScanCard> {
  final TextEditingController _controller = TextEditingController();
  DetectionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    // Add a test message for easy testing (safe message)
    _controller.text =
        "Hello! Hope you are doing well. Let's meet for coffee tomorrow.";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'Quick Scan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<SmartScamDetectionService>(
              builder: (context, service, child) {
                return TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Paste message or URL to scan for scams...',
                    border: const OutlineInputBorder(),
                    suffixIcon: service.isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _scanMessage,
                          ),
                  ),
                  maxLines: 3,
                  onSubmitted: (_) => _scanMessage(),
                );
              },
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(context, _lastResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, DetectionResult result) {
    final theme = Theme.of(context);

    Color getStatusColor() {
      switch (result.riskLevel) {
        case RiskLevel.critical:
          return Colors.red;
        case RiskLevel.high:
          return Colors.orange;
        case RiskLevel.medium:
          return Colors.yellow.shade800;
        case RiskLevel.low:
          return Colors.blue;
        case RiskLevel.minimal:
          return Colors.green;
      }
    }

    String getStatusEmoji() {
      switch (result.riskLevel) {
        case RiskLevel.critical:
          return '🚨';
        case RiskLevel.high:
          return '⚠️';
        case RiskLevel.medium:
          return '⚡';
        case RiskLevel.low:
          return '🔍';
        case RiskLevel.minimal:
          return '✅';
      }
    }

    return Card(
      color: getStatusColor().withValues(alpha: 26), // 0.1 ≈ 26/255
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.isFallbackResult)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 38),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.hourglass_top, size: 18, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Still calibrating — this is a quick check, not the full result. "
                        "Try again in a minute for a confirmed answer.",
                        style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Text(
                  getStatusEmoji(),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  result.isThreat ? 'Threat Detected!' : 'Content is Safe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.reasoning,
              style: const TextStyle(fontSize: 16),
            ),
            if (result.evidence?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: result.evidence!.entries
                    .map((e) => Chip(
                          label: Text('${e.key}: ${e.value}'),
                          backgroundColor: theme.chipTheme.backgroundColor,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(result.confidence * 100).toInt()}%',
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scanMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final service =
        Provider.of<SmartScamDetectionService>(context, listen: false);

    try {
      debugPrint(
          '🔍 QUICK SCAN: Starting quick scan for message: ${_controller.text.trim()}');
      final result = await service.scanMessage(
        _controller.text.trim(),
        packageName: 'com.elephas.ai.quickscan', // Always pass package name for context
      );
      debugPrint(
          '✅ QUICK SCAN: Result - isThreat=${result.isThreat}, confidence=${result.confidence}, reasoning=${result.reasoning}');

      setState(() {
        _lastResult = result as DetectionResult?;
      });

      // Show appropriate snackbar based on result
      if (!mounted) return;

      if (result.isFallbackResult) {
        // Backend is still warming up its real model - be upfront that
        // this isn't a confirmed verdict yet, instead of a confident claim.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                '⏳ Still calibrating — try again in a minute for a confirmed result.'),
            backgroundColor: Colors.amber.shade800,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else if (result.isThreat && result.riskLevel != RiskLevel.minimal) {
        // Show red snackbar for scam detection
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 SCAM DETECTED: ${result.reasoning}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        // Show green snackbar for safe message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ SAFE: ${result.reasoning}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('💥 QUICK SCAN: Error in quick scan: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
