import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/elephas_main_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _messagingProtection = true;
  bool _notifications = true;
  bool _realTimeAlerts = true;
  String _sensitivityLevel = 'High';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Protection Status Card
            Consumer<ElephasMainService>(
              builder: (context, elephas, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: elephas.isActive 
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        elephas.isActive ? Icons.shield : Icons.shield_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              elephas.isActive ? 'Protection Active' : 'Protection Inactive',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              elephas.isActive 
                                  ? 'Elephas AI is monitoring your messages'
                                  : 'Protection is currently disabled',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Protection Settings
            _buildSectionTitle('Protection Settings'),
            const SizedBox(height: 16),
            
            _buildSettingCard(
              title: 'Messaging Protection',
              subtitle: 'Monitor WhatsApp, Telegram, SMS and other messaging apps',
              value: _messagingProtection,
              onChanged: (value) {
                setState(() {
                  _messagingProtection = value;
                });
              },
              icon: Icons.message_outlined,
              iconColor: const Color(0xFF10B981),
            ),
            
            const SizedBox(height: 12),
            
            _buildSettingCard(
              title: 'Real-time Alerts',
              subtitle: 'Get instant notifications when threats are detected',
              value: _realTimeAlerts,
              onChanged: (value) {
                setState(() {
                  _realTimeAlerts = value;
                });
              },
              icon: Icons.notifications_active_outlined,
              iconColor: const Color(0xFF3B82F6),
            ),
            
            const SizedBox(height: 12),
            
            _buildSettingCard(
              title: 'Push Notifications',
              subtitle: 'Allow Elephas AI to send you security notifications',
              value: _notifications,
              onChanged: (value) {
                setState(() {
                  _notifications = value;
                });
              },
              icon: Icons.notifications_outlined,
              iconColor: const Color(0xFF8B5CF6),
            ),
            
            const SizedBox(height: 32),
            
            // Detection Settings
            _buildSectionTitle('Detection Settings'),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sensitivity Level',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              'Adjust how sensitive the AI detection should be',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Sensitivity Options
                  ...['Low', 'Medium', 'High', 'Maximum'].map((level) {
                    return RadioListTile<String>(
                      title: Text(level),
                      subtitle: Text(_getSensitivityDescription(level)),
                      value: level,
                      groupValue: _sensitivityLevel,
                      onChanged: (value) {
                        setState(() {
                          _sensitivityLevel = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // About Section
            _buildSectionTitle('About'),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoRow('App Version', '1.0.0'),
                  const Divider(),
                  _buildInfoRow('AI Model', 'Elephas v2.1'),
                  const Divider(),
                  _buildInfoRow('Last Updated', 'Today'),
                  const Divider(),
                  _buildInfoRow('Protection Status', 'Active'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
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
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  String _getSensitivityDescription(String level) {
    switch (level) {
      case 'Low':
        return 'Only detect obvious scams';
      case 'Medium':
        return 'Balanced detection (Recommended)';
      case 'High':
        return 'Detect subtle threats';
      case 'Maximum':
        return 'Maximum protection, may have more alerts';
      default:
        return '';
    }
  }
}
