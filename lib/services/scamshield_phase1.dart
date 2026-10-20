/// Billion-dollar grade scam protection system
/// Phase 1: Zero false positives, channel-specific, context-aware detection
library scamshield_phase1;

export '../core/intelligent_protection_service.dart';
export '../core/models/detection_models.dart';
export '../core/detection/zero_false_positive_detector.dart';
export '../core/intelligence/contact_intelligence_service.dart';
export '../core/intelligence/conversation_context_analyzer.dart';
export '../core/monitoring/channel_specific_monitor.dart';

/// 
/// Usage:
/// ```dart
/// final protection = IntelligentProtectionService();
/// await protection.initialize();
/// await protection.startProtection();
/// 
/// // Listen for alerts
/// protection.alertStream.listen((alert) {
///   if (alert.isThreat) {
///     // Show user alert with high confidence
///     showScamAlert(alert);
///   }
/// });
/// 
/// // Manual analysis
/// final result = await protection.analyzeMessage(
///   message: "Urgent! Send money now!",
///   contactId: "unknown_contact_123",
///   appPackage: "com.whatsapp",
/// );
/// ```
