import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scam_detection_service.dart';
import '../models/alert_level.dart';
import '../models/scam_detection_models.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          Consumer<SmartScamDetectionService>(
            builder: (context, service, child) {
              return IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: service.scanHistory.isEmpty
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Clear History'),
                            content: const Text(
                                'Are you sure you want to clear all scan history?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  service.clearHistory();
                                  Navigator.pop(context);
                                },
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        );
                      },
              );
            },
          ),
        ],
      ),
      body: Consumer<SmartScamDetectionService>(
        builder: (context, service, child) {
          if (service.scanHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No scan history yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: service.scanHistory.length,
            itemBuilder: (context, index) {
              final result = service.scanHistory[index];
              return _buildHistoryItem(context, result);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, ScamDetectionResult result) {
    final theme = Theme.of(context);

    Color getAlertColor() {
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

    String getAlertEmoji() {
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getAlertColor(),
          child: Text(
            getAlertEmoji(),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          result.isScam ? 'Scam Detected' : 'Safe Content',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: result.isScam ? theme.colorScheme.error : Colors.green,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(result.reason),
            if (result.scamTypes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: result.scamTypes
                    .map((type) => Chip(
                          label: Text(type),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(result.confidence * 100).toInt()}%',
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
