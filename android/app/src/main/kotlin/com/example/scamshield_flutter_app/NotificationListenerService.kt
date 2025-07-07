package com.example.scamshield_flutter_app

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log // Import Log for debugging

class NotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotifListenerService"
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        
        sbn?.let { notification ->
            val packageName = notification.packageName
            val extras = notification.notification.extras
            val title = extras.getCharSequence("android.title")?.toString() ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            
            // Check if it's from messaging apps (you can refine this list)
            val messagingApps = listOf(
                "com.android.mms",
                "com.google.android.apps.messaging",
                "com.whatsapp",
                "com.telegram.messenger",
                "com.facebook.orca",
                "com.snapchat.android", // Added from your Dart code
                "com.instagram.android", // Added from your Dart code
                "com.discord", // Added from your Dart code
                "com.skype.raider", // Added from your Dart code
                "com.viber.voip" // Added from your Dart code
            )
            
            Log.d(TAG, "Notification posted: Package=$packageName, Title=$title, Text=$text")

            if (messagingApps.contains(packageName) && text.isNotEmpty()) {
                // Send to Flutter for analysis using the shared MethodChannel
                MethodChannelManager.overlayMethodChannel?.let { channel ->
                    channel.invokeMethod(
                        "onNotificationIntercepted",
                        mapOf(
                            "packageName" to packageName,
                            "title" to title,
                            "text" to text
                        )
                    )
                    Log.d(TAG, "Sent notification to Flutter: Package=$packageName, Text=$text")
                } ?: run {
                    Log.e(TAG, "Overlay MethodChannel not initialized for NotificationListenerService.")
                }
            }
        }
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        // Handle notification removal if needed
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Essential for foreground service on Android 14+
        // You should start a notification here to show the user the service is running.
        // For simplicity, we'll just return START_STICKY for now, but a real app needs a persistent notification.
        return START_STICKY
    }
}