// lib/core/models/monitored_app.dart
class MonitoredApp {
  final String packageName;
  final String displayName;
  final bool isEnabled;
  final bool requiresOverlay;
  final bool requiresBackend;
  final int priorityLevel;

  const MonitoredApp({
    required this.packageName,
    required this.displayName,
    this.isEnabled = true,
    this.requiresOverlay = true,
    this.requiresBackend = true,
    this.priorityLevel = 1,
  });

  MonitoredApp copyWith({
    String? packageName,
    String? displayName,
    bool? isEnabled,
    bool? requiresOverlay,
    bool? requiresBackend,
    int? priorityLevel,
  }) {
    return MonitoredApp(
      packageName: packageName ?? this.packageName,
      displayName: displayName ?? this.displayName,
      isEnabled: isEnabled ?? this.isEnabled,
      requiresOverlay: requiresOverlay ?? this.requiresOverlay,
      requiresBackend: requiresBackend ?? this.requiresBackend,
      priorityLevel: priorityLevel ?? this.priorityLevel,
    );
  }

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'displayName': displayName,
    'isEnabled': isEnabled,
    'requiresOverlay': requiresOverlay,
    'requiresBackend': requiresBackend,
    'priorityLevel': priorityLevel,
  };

  factory MonitoredApp.fromJson(Map<String, dynamic> json) => MonitoredApp(
    packageName: json['packageName'] as String,
    displayName: json['displayName'] as String,
    isEnabled: json['isEnabled'] as bool? ?? true,
    requiresOverlay: json['requiresOverlay'] as bool? ?? true,
    requiresBackend: json['requiresBackend'] as bool? ?? true,
    priorityLevel: json['priorityLevel'] as int? ?? 1,
  );

  static List<MonitoredApp> get defaultApps => [
    const MonitoredApp(
      packageName: 'com.whatsapp',
      displayName: 'WhatsApp',
      priorityLevel: 1,
    ),
    const MonitoredApp(
      packageName: 'com.facebook.orca',
      displayName: 'Facebook Messenger',
      priorityLevel: 2,
    ),
    const MonitoredApp(
      packageName: 'com.instagram.android',
      displayName: 'Instagram',
      priorityLevel: 2,
    ),
    const MonitoredApp(
      packageName: 'com.android.messaging',
      displayName: 'SMS',
      priorityLevel: 1,
    ),
    const MonitoredApp(
      packageName: 'org.telegram.messenger',
      displayName: 'Telegram',
      priorityLevel: 2,
    ),
  ];

  @override
  String toString() => 'MonitoredApp($displayName, enabled: $isEnabled)';

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is MonitoredApp &&
    runtimeType == other.runtimeType &&
    packageName == other.packageName &&
    displayName == other.displayName &&
    isEnabled == other.isEnabled &&
    requiresOverlay == other.requiresOverlay &&
    requiresBackend == other.requiresBackend &&
    priorityLevel == other.priorityLevel;

  @override
  int get hashCode => packageName.hashCode ^
    displayName.hashCode ^
    isEnabled.hashCode ^
    requiresOverlay.hashCode ^
    requiresBackend.hashCode ^
    priorityLevel.hashCode;
}
