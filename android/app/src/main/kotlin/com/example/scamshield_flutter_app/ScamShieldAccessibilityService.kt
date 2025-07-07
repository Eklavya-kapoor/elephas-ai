// android/app/src/main/kotlin/com/example/scamshield_flutter_app/ScamShie        return android.app.Notification.Builder(this, channelId)
            .setContentTitle("Elephas AI")
            .setContentText("Monitoring for scams in the background...")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build();essibilityService.kt
package com.example.scamshield_flutter_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context // ADD THIS LINE
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ScamShieldAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ScamShieldAccessibility"
        var instance: ScamShieldAccessibilityService? = null
        var currentPackage: String? = null

        var screenMonitorMethodChannel: MethodChannel? = null
    }

    private val textExtractionExecutor = Executors.newSingleThreadScheduledExecutor()
    private var lastExtractedText = ""
    private val MIN_TEXT_LENGTH = 10

    private val messagingApps = setOf(
        "com.whatsapp",
        "com.telegram.messenger",
        "com.android.mms",
        "com.google.android.apps.messaging",
        "com.facebook.orca",
        "com.snapchat.android",
        "com.instagram.android",
        "com.discord",
        "com.skype.raider",
        "com.viber.voip",
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }

        serviceInfo = info
        Log.d(TAG, "Accessibility service connected")

        startForeground(102, createForegroundNotification())
    }

    private fun createForegroundNotification(): android.app.Notification {
        val channelId = "ScamShieldAccessibilityChannel"
        val channelName = "ScamShield Background Monitoring"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                channelName,
                android.app.NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(channel)
        }

        return android.app.Notification.Builder(this, channelId)
            .setContentTitle("ScamShield AI")
            .setContentText("Monitoring for scams in the background...")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let { e ->
            when (e.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    e.packageName?.toString()?.let { packageName ->
                        if (packageName != currentPackage) {
                            currentPackage = packageName
                            Log.d(TAG, "App changed to: $packageName")
                                screenMonitorMethodChannel?.invokeMethod("onAppChanged", mapOf("packageName" to packageName))
                        }
                    }
                }
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    currentPackage?.let { pkg ->
                        if (messagingApps.contains(pkg)) {
                            textExtractionExecutor.schedule({
                                extractTextFromRoot(rootInActiveWindow, pkg)
                            }, 500, TimeUnit.MILLISECONDS)
                        }
                    }
                }
            }
        }
    }

    private fun extractTextFromRoot(node: AccessibilityNodeInfo?, packageName: String) {
        if (node == null) {
            return
        }

        val builder = StringBuilder()
        traverseNodes(node, builder)
        val extractedContent = builder.toString().trim()

        if (extractedContent.isNotEmpty() && extractedContent != lastExtractedText) {
            Log.d(TAG, "Extracted content from $packageName: ${extractedContent.take(100)}...")
            lastExtractedText = extractedContent
            screenMonitorMethodChannel?.invokeMethod("onScreenContent", mapOf("content" to extractedContent, "packageName" to packageName))
        }
    }

    private fun traverseNodes(node: AccessibilityNodeInfo, builder: StringBuilder) {
        node.text?.let {
            val text = it.toString().trim()
            if (text.isNotEmpty()) {
                builder.append(text).append("\n")
            }
        }
        node.contentDescription?.let {
            val description = it.toString().trim()
            if (description.isNotEmpty() && description.length > 5 && !description.contains("button", ignoreCase = true)) {
                builder.append(description).append("\n")
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                traverseNodes(child, builder)
            }
        }
        node.recycle()
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    override fun onDestroy() {
        instance = null
        textExtractionExecutor.shutdownNow()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}