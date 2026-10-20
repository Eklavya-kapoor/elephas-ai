import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/overlay_service.dart';
import '../core/services/intelligent_protection_service.dart';
import '../core/models/detection_models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final protectionService = Provider.of<IntelligentProtectionService>(context);
    final overlayService = Provider.of<OverlayService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protection Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force rebuild with latest data
          Provider.of<IntelligentProtectionService>(context, listen: false)
              .getDetectionHistory(onlyThreats: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProtectionStatus(overlayService),
              const SizedBox(height: 24),
              _buildStatisticsCard(protectionService),
              const SizedBox(height: 24),
              _buildRecentThreatsCard(protectionService),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtectionStatus(OverlayService overlayService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, size: 32),
                SizedBox(width: 16),
                Text(
                  'Protection Status',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusItem(
              icon: Icons.shield,
              title: 'Real-time Protection',
              subtitle: 'Active and monitoring',
              isActive: true,
            ),
            const Divider(),
            _buildStatusItem(
              icon: Icons.notifications_active,
              title: 'Scam Alerts',
              subtitle: 'Enabled',
              isActive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(IntelligentProtectionService protectionService) {
    final stats = protectionService.getDetectionHistory(onlyThreats: true);
    final todayStats = stats.where((result) => 
      result.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 1)))
    ).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Protection Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  title: 'Today',
                  value: todayStats.toString(),
                  subtitle: 'Threats Blocked',
                ),
                _buildStatItem(
                  title: 'Total',
                  value: stats.length.toString(),
                  subtitle: 'Threats Detected',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentThreatsCard(IntelligentProtectionService protectionService) {
    final recentThreats = protectionService.getDetectionHistory(
      onlyThreats: true,
      since: DateTime.now().subtract(const Duration(days: 7)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Threats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (recentThreats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No threats detected in the last 7 days',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentThreats.take(5).length,
                itemBuilder: (context, index) {
                  final threat = recentThreats[index];
                  return ListTile(
                    leading: Icon(
                      threat.containsUrl ? Icons.link : Icons.warning,
                      color: Colors.red,
                    ),
                    title: Text(
                      threat.containsUrl ? 'Malicious URL Detected' : 'Scam Message Detected',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Risk Level: ${threat.riskLevel.name} • ${_formatTimestamp(threat.timestamp)}',
                    ),
                    onTap: () => _showThreatDetails(context, threat),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showThreatDetails(BuildContext context, DetectionResult threat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0, 
          right: 16.0,
          top: 16.0,
          bottom: 16.0 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Threat Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Threat summary
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.red.withValues(red: 255, green: 0, blue: 0, alpha: 25),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(
                    threat.containsUrl ? Icons.link : Icons.warning,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          threat.containsUrl ? 'Malicious URL Detected' : 'Scam Message Detected',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Risk Level: ${threat.riskLevel.name}',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Threat details
            if (threat.message != null) ...[
              const Text(
                'Message Content',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(threat.message!),
              ),
              const SizedBox(height: 16),
            ],
            // Threat analysis
            const Text(
              'Analysis',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Risk Score', '${(threat.riskScore * 100).toInt()}%'),
            _buildDetailRow('Confidence', '${(threat.confidence * 100).toInt()}%'),
            _buildDetailRow('Type', threat.detectedType ?? 'Unknown'),
            _buildDetailRow('Method', threat.detectionMethod ?? 'AI Analysis'),
            _buildDetailRow('Contains URL', threat.containsUrl ? 'Yes' : 'No'),
            _buildDetailRow('Detection Time', _formatTimestamp(threat.timestamp)),
            const SizedBox(height: 16),
            // Reasoning and evidence
            const Text(
              'Reasoning & Evidence',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(threat.reasoning),
            if (threat.evidence != null && threat.evidence!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Evidence: ${threat.evidence}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
