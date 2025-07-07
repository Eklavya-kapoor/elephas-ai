// widgets/quick_scan_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scam_detection_service.dart';
import '../models/alert_level.dart';
import '../models/scam_detection_models.dart';

class QuickScanCard extends StatefulWidget {
  const QuickScanCard({super.key});

  @override
  QuickScanCardState createState() => QuickScanCardState();
}

class QuickScanCardState extends State<QuickScanCard> {
  final TextEditingController _controller = TextEditingController();
  ScamDetectionResult? _lastResult;

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

  Widget _buildResultCard(BuildContext context, ScamDetectionResult result) {
    final theme = Theme.of(context);

    Color getStatusColor() {
      switch (result.alertLevel) {
        case AlertLevel.critical:
          return Colors.red;
        case AlertLevel.high:
          return Colors.orange;
        case AlertLevel.medium:
          return Colors.yellow.shade800;
        case AlertLevel.none:
          return Colors.green;
      }
    }

    String getStatusEmoji() {
      switch (result.alertLevel) {
        case AlertLevel.critical:
          return '🚨';
        case AlertLevel.high:
          return '⚠️';
        case AlertLevel.medium:
          return '⚡';
        case AlertLevel.none:
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
            Row(
              children: [
                Text(
                  getStatusEmoji(),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  result.isScam ? 'Scam Detected!' : 'Content is Safe',
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
              result.reason,
              style: const TextStyle(fontSize: 16),
            ),
            if (result.scamTypes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: result.scamTypes
                    .map((type) => Chip(
                          label: Text(type),
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
      final result = await service.scanMessage(_controller.text.trim());
      setState(() {
        _lastResult = result;
      });

      if (result.isScam && result.alertLevel != AlertLevel.none) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${result.reason}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
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
