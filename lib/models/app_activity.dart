/// Represents the type of activity
enum ActivityType {
  messageReceived,
  messageDisplayed,
  windowOpened,
  windowClosed,
  other
}

/// Represents an activity in a monitored app
class AppActivity {
  final String packageName;
  final ActivityType type;
  final String? windowTitle;
  final String? textContent;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  AppActivity({
    required this.packageName,
    required this.type,
    this.windowTitle,
    this.textContent,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
