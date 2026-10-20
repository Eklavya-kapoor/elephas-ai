import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/intelligent_protection_service.dart';
import '../core/models/detection_models.dart';
import '../core/models/alert_types.dart';

// Extension for color manipulation
extension ColorOpacity on Color {
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromRGBO(
      red ?? r.toInt(),
      green ?? g.toInt(),
      blue ?? b.toInt(),
      alpha ?? a,
    );
  }
}

class ScamHistoryWidget extends StatelessWidget {
  final int maxItems;
  final bool showTitle;
  final VoidCallback? onViewAll;

  const ScamHistoryWidget({
    super.key,
    this.maxItems = 5,
    this.showTitle = true,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<IntelligentProtectionService>(
      builder: (context, service, child) {
        final history = service.detectionHistory;
        final displayHistory = maxItems > 0 && history.isNotEmpty
            ? history.take(maxItems).toList()
            : history;

        return Card(
          elevation: 4,
          margin: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          const Text(
                            'Recent Scam Alerts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (onViewAll != null && history.length > maxItems)
                        TextButton(
                          onPressed: onViewAll,
                          child: const Text('View All'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
              if (displayHistory.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 48,
                          color: Colors.green,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No scam alerts yet!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Elephas AI is protecting you',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayHistory.length,
                  itemBuilder: (context, index) {
                    final detection = displayHistory[index];
                    return _buildHistoryItem(context, detection);
                  },
                ),
              if (history.isNotEmpty && showTitle)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield,
                        size: 16,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${history.length} threats blocked by Elephas AI',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(BuildContext context, DetectionResult detection) {
    final (alertColor, alertIcon, alertText) =
        _getAlertInfo(detection.riskLevel);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: alertColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: alertColor.withValues(alpha: 0.3)),
        ),
        child: Icon(
          alertIcon,
          color: alertColor,
          size: 20,
        ),
      ),
      title: Text(
        detection.message?.isNotEmpty == true
            ? detection.message!
            : detection.reasoning,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: alertColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  alertText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: alertColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(detection.confidence * 100).toInt()}% confident',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              if (detection.detectedType != null) ...[
                const SizedBox(width: 8),
                Text(
                  detection.detectedType!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _formatTimestamp(detection.timestamp),
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: detection.isThreat
          ? Icon(
              Icons.block,
              color: alertColor,
              size: 18,
            )
          : Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 18,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      dense: true,
    );
  }

  (Color, IconData, String) _getAlertInfo(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.critical:
        return (Colors.red, Icons.dangerous, 'CRITICAL');
      case RiskLevel.high:
        return (Colors.orange, Icons.warning, 'HIGH RISK');
      case RiskLevel.medium:
        return (Colors.yellow.shade700, Icons.info, 'MEDIUM');
      case RiskLevel.low:
        return (Colors.blue, Icons.info_outline, 'LOW RISK');
      case RiskLevel.minimal:
        return (Colors.grey, Icons.check_circle_outline, 'INFO');
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
