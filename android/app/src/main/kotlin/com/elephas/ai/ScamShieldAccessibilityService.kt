package com.elephas.ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ScamShieldAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ElephASAccessibility"
        var instance: ScamShieldAccessibilityService? = null
        var currentPackage: String? = null
        private var currentScreenId: String? = null
        private var flutterChannel: MethodChannel? = null
    }

    private val textExtractionExecutor = Executors.newSingleThreadScheduledExecutor()
    private var lastExtractedText = ""
    private val MIN_TEXT_LENGTH = 5 // Reduced from 10 to catch shorter scam messages

    // FIX: Use broadcast instead of method channel since AccessibilityService runs in separate process
    private fun sendContentToFlutter(content: String, packageName: String) {
        // CRITICAL: Filter out our own app and system UI to prevent overlays in wrong places
        if (shouldSkipPackage(packageName)) {
            Log.d(TAG, "� SKIPPED package: $packageName (filtered)")
            return
        }
        
        try {
            Log.d(TAG, "�🚀 SENDING TO FLUTTER: Package=$packageName")
            Log.d(TAG, "🚀 CONTENT LENGTH: ${content.length} characters")
            Log.d(TAG, "🚀 CONTENT PREVIEW: ${content.take(100)}...")
            
            val intent = Intent("com.example.scamshield_flutter_app.SCREEN_CONTENT")
            intent.putExtra("content", content)
            intent.putExtra("packageName", packageName)
            intent.putExtra("timestamp", System.currentTimeMillis())
            sendBroadcast(intent)
            
            Log.d(TAG, "✅ Content sent to Flutter via broadcast successfully!")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send content to Flutter: ${e.message}")
        }
    }
    
    // FOCUSED: Only monitor targeted communication apps, not ALL apps
    private fun shouldSkipPackage(packageName: String): Boolean {
        val excludedPackages = listOf(
            "com.example.scamshield_flutter_app",        // Our own app
            "com.example.scamshield_flutter_app.debug",  // Our debug version
            "android",                                   // System android package
            "com.android.systemui",                      // System UI
            "com.android.launcher",                      // Default launcher
            "com.android.launcher3",                     // Launcher3 (Pixel/AOSP)
            "com.android.settings",                      // System settings
            "com.mi.android.globallauncher",             // MIUI launcher
            "com.miui.home",                             // MIUI home launcher
            "com.huawei.android.launcher",               // Huawei launcher
            "com.samsung.android.app.launcher",          // Samsung launcher
            "com.oppo.launcher",                         // OPPO launcher
            "com.oneplus.launcher",                      // OnePlus launcher
            "com.lge.launcher2",                         // LG launcher
            "com.sony.android.launcher",                 // Sony launcher
            "com.android.permissioncontroller",          // Permission controller
            "com.android.packageinstaller",              // Package installer
            "com.google.android.googlequicksearchbox",   // Google search/launcher
            "com.truecaller",                            // Truecaller - caller ID only, causes false positives
            "com.samsung.android.incallui",              // Samsung call UI
            "com.android.incallui"                       // Android call UI
        )
        
        // CRITICAL CHANGE: Only monitor targeted communication apps
        val isSystemPackage = excludedPackages.contains(packageName) || 
                             packageName.startsWith("com.android.") ||
                             packageName.startsWith("android.") ||
                             packageName.contains("launcher") ||
                             packageName.contains("systemui") ||
                             packageName.contains("scamshield")  // Block all versions of our app
        
        // NEW: Skip all apps that aren't in our targeted list
        val isNotTargetedApp = !targetedScamApps.contains(packageName)
        
        val shouldSkip = isSystemPackage || isNotTargetedApp
        
        if (shouldSkip && isNotTargetedApp && !isSystemPackage) {
            Log.d(TAG, "🎯 Non-communication app skipped: $packageName (focused protection)")
        } else if (shouldSkip) {
            Log.d(TAG, "🚫 System package filtered: $packageName")
        } else {
            Log.d(TAG, "✅ Monitoring communication app: $packageName")
        }
        
        return shouldSkip
    }

    // FOCUSED: only the highest-scale scam vectors in India - WhatsApp, Telegram, SMS.
    // Deliberately excludes email (different threat pattern, already has own spam
    // filtering), phone/dialer (screen-scraping has no text to read on a call screen),
    // and lower-scale social DMs (Instagram/Twitter/Snapchat/LinkedIn/Discord/etc).
    private val targetedScamApps = setOf(
        "com.whatsapp",                           // WhatsApp
        "org.telegram.messenger",                 // Telegram
        "com.android.mms",                        // Default SMS
        "com.google.android.apps.messaging",     // Google Messages
        "com.samsung.android.messaging",          // Samsung Messages
        "com.android.messaging",                  // Default SMS (alt package name on some OEMs)

        // ADD YOUR CUSTOM APPS HERE:
        // "com.your.custom.app",                 // Your Custom App

        // REMOVED: Web browsers, games, notes, general apps
        // These cause false positives and aren't primary scam vectors
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        val info = AccessibilityServiceInfo().apply {
            // Monitor ALL event types for maximum coverage in TARGETED apps only
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                    AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED or
                    AccessibilityEvent.TYPE_VIEW_CLICKED or
                    AccessibilityEvent.TYPE_VIEW_FOCUSED or
                    AccessibilityEvent.TYPE_VIEW_SELECTED or
                    AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY or
                    AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            notificationTimeout = 50 // Reduced from 100 for faster response
            // FOCUSED: Target only specific communication apps to prevent false positives
            packageNames = targetedScamApps.toTypedArray()
        }

        serviceInfo = info
        Log.d(TAG, "🎯 FOCUSED Accessibility service connected - monitoring communication apps only")
        Log.d(TAG, "📱 Targeted apps: ${targetedScamApps.size} communication platforms")
        Log.d(TAG, "🛡️ This prevents false positives in notes, games, browsers, etc.")

        startForeground(102, createForegroundNotification())
    }

    private fun createForegroundNotification(): android.app.Notification {
        val channelId = "ElephASAccessibilityChannel"
        val channelName = "Elephas AI Background Monitoring"
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
            .setContentTitle("Elephas AI")
            .setContentText("Protecting you from scams in the background...")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build()
    }

    private fun generateScreenId(event: AccessibilityEvent): String {
        // Create a unique screen identifier based on package and window
        val windowId = event.windowId
        val packageName = event.packageName?.toString() ?: "unknown"
        val className = event.className?.toString() ?: "unknown"
        return "$packageName:$className:$windowId"
    }

    private fun notifyScreenChanged(screenId: String) {
        // Notify Flutter about screen change
        flutterChannel?.invokeMethod("onScreenChanged", screenId)
    }

    private fun sendAppChangeToFlutter(packageName: String) {
        try {
            Log.d(TAG, "📱 App changed to: $packageName")
            val intent = Intent("com.example.scamshield_flutter_app.APP_CHANGED")
            intent.putExtra("packageName", packageName)
            intent.putExtra("timestamp", System.currentTimeMillis())
            sendBroadcast(intent)
            Log.d(TAG, "✅ App change broadcast sent successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send app change: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        event?.let { e ->
            val packageName = e.packageName?.toString()
            
            when (e.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    packageName?.let { pkg ->
                        if (pkg != currentPackage) {
                            currentPackage = pkg
                            // Only notify for non-excluded packages
                            if (!shouldSkipPackage(pkg)) {
                                sendAppChangeToFlutter(pkg)
                            }
                        }
                    }
                }
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                    packageName?.let { pkg ->
                        if (!shouldSkipPackage(pkg)) {
                            textExtractionExecutor.schedule({
                                extractTextFromRoot(rootInActiveWindow, pkg)
                            }, 100, TimeUnit.MILLISECONDS)
                        }
                    }
                }
            }

            val screenId = generateScreenId(e)
            if (screenId != currentScreenId) {
                currentScreenId = screenId
                notifyScreenChanged(screenId)
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

        // FIX: Filter out WhatsApp security placeholders and get actual message content
        if (extractedContent.length >= MIN_TEXT_LENGTH && extractedContent != lastExtractedText) {
            
            // Skip WhatsApp security placeholders
            if (packageName == "com.whatsapp" && 
                (extractedContent.contains("end-to-end encrypted", ignoreCase = true) ||
                 extractedContent.contains("Messages and calls are end-to-end", ignoreCase = true))) {
                Log.d(TAG, "⚠️ Skipping WhatsApp security placeholder, trying to extract actual messages...")
                
                // Try to extract actual message content by looking for specific message patterns
                val actualMessages = extractWhatsAppMessages(node)
                if (actualMessages.isNotEmpty()) {
                    Log.d(TAG, "✅ Found actual WhatsApp messages: ${actualMessages.take(100)}...")
                    sendContentToFlutter(actualMessages, packageName)
                    lastExtractedText = actualMessages
                } else {
                    Log.d(TAG, "❌ No actual WhatsApp messages found, content is encrypted/protected")
                }
                return
            }
            
            Log.d(TAG, "Extracted content from $packageName: ${extractedContent.take(100)}...")
            lastExtractedText = extractedContent
            
            // FIX: Use broadcast instead of method channel for inter-process communication
            sendContentToFlutter(extractedContent, packageName)
        }
    }

    // FIX: Enhanced WhatsApp message extraction
    private fun extractWhatsAppMessages(node: AccessibilityNodeInfo?): String {
        if (node == null) return ""
        
        val messageBuilder = StringBuilder()
        val messages = mutableListOf<String>()
        extractMessagesFromNode(node, messages)
        
        // Process and clean the extracted messages
        messages.forEach { message ->
            val cleaned = cleanWhatsAppMessage(message)
            if (cleaned.isNotEmpty()) {
                if (messageBuilder.isNotEmpty()) messageBuilder.append("\n")
                messageBuilder.append(cleaned)
            }
        }
        
        return messageBuilder.toString().trim()
    }

    private fun extractMessagesFromNode(node: AccessibilityNodeInfo, messages: MutableList<String>) {
        try {
            // Check if this is a business info section
            val isBusinessInfo = node.viewIdResourceName?.contains("business_info") ?: false ||
                               node.text?.toString()?.contains("Business Account", ignoreCase = true) ?: false

            // Skip business info sections but process message content
            if (!isBusinessInfo) {
                // Check for actual message content
                if (isMessageBubbleNode(node)) {
                    node.text?.let { text ->
                        val textStr = text.toString().trim()
                        if (textStr.isNotEmpty() && !isUIElement(textStr)) {
                            Log.d(TAG, "📱 Found message text: $textStr")
                            messages.add(textStr)
                        }
                    }
                }
                
                // Look for message content in specific layouts
                node.viewIdResourceName?.let { id ->
                    if (id.contains("message_text") || 
                        id.contains("conversation_text") || 
                        id.contains("chat_msg")) {
                        node.text?.let { text ->
                            val textStr = text.toString().trim()
                            if (textStr.isNotEmpty() && !isUIElement(textStr)) {
                                Log.d(TAG, "📱 Found message by ID: $textStr")
                                messages.add(textStr)
                            }
                        }
                    }
                }
            }

            // Recursively check child nodes
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    extractMessagesFromNode(child, messages)
                    child.recycle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting messages: ${e.message}")
        }
    }

    private fun isMessageBubbleNode(node: AccessibilityNodeInfo): Boolean {
        // Enhanced message detection for both regular and business accounts
        val className = node.className?.toString() ?: ""
        
        // Check if this is a message container
        val isMessageContainer = node.parent?.let { parent ->
            val parentClass = parent.className?.toString() ?: ""
            parentClass.contains("MessageContainer", ignoreCase = true) ||
            parentClass.contains("ChatLayout", ignoreCase = true) ||
            parentClass.contains("ConversationLayout", ignoreCase = true) ||
            parentClass.contains("BusinessMessageLayout", ignoreCase = true)
        } ?: false

        // Enhanced text node detection
        val isTextNode = className.contains("TextView", ignoreCase = true) &&
                        !node.isClickable &&
                        node.text != null &&
                        !isUIElement(node.text.toString())

        // For business messages, also check specific containers
        val isBusinessMessage = node.parent?.let { parent ->
            parent.viewIdResourceName?.contains("business_message") ?: false ||
            parent.viewIdResourceName?.contains("message_text") ?: false
        } ?: false

        return (isTextNode && (isMessageContainer || isBusinessMessage))
    }

    private fun isUIElement(text: String): Boolean {
        val uiPatterns = listOf(
            // Time and status
            Regex("^[0-9]{1,2}:[0-9]{2}\\s?(AM|PM)?\$"),
            Regex("^(Today|Yesterday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday).*"),
            Regex(".*(online|last seen|typing\\.\\.\\.|recording\\.\\.\\.).*"),
            
            // Business account UI
            Regex("^Business Account\$"),
            Regex("^Business info\$"),
            Regex("^More business info\$"),
            Regex("^Typically replies within.*"),
            Regex("^Working hours:.*"),
            Regex("^Address:.*"),
            Regex("^Email:.*"),
            Regex("^Website:.*"),
            Regex("^Description:.*"),
            
            // Common UI elements
            Regex(".*(Block|Report|Add to contacts|Delete chat).*"),
            Regex("^(Message|Search)\$"),
            Regex(".*(end-to-end encrypted).*"),
            Regex(".*(won't see if you read).*"),
            Regex(".*(add them as a contact).*"),
            Regex("^(delivered|sent|read)\$", RegexOption.IGNORE_CASE),
            Regex("^Messages and calls are.*"),
            Regex("^More options\$"),
            Regex("^Menu\$"),
            Regex("^Attach\$"),
            Regex("^Gallery\$"),
            Regex("^Camera\$")
        )
        
        return uiPatterns.any { it.matches(text.trim()) }
    }

    private fun cleanWhatsAppMessage(message: String): String {
        var cleaned = message.trim()
            .replace(Regex("\\b(online|last seen|typing\\.\\.\\.)", RegexOption.IGNORE_CASE), "") // Status indicators
            .replace(Regex("\\b\\d{1,2}:\\d{2}\\s?(?:AM|PM)?\\b"), "") // Time stamps
            .replace(Regex("\\b(Today|Yesterday)\\b"), "") // Day indicators
            .replace(Regex("\\b(Block|Report|Add to contacts)\\b"), "") // Action buttons
            .replace(Regex("\\b(delivered|sent|read)\\b", RegexOption.IGNORE_CASE), "") // Message status
            .replace(Regex("\\b(Message|Search)\\b"), "") // UI labels
            .replace(Regex("The business won't see.*contact"), "") // Business message disclaimer
            .replace("...", "") // Ellipsis
            .replace(Regex("\\s+"), " ") // Multiple spaces
            .trim()

        // Only return if it's an actual message (not just UI elements)
        return if (cleaned.length > 2 && !isUIElement(cleaned)) cleaned else ""
    }

    private fun traverseNodes(node: AccessibilityNodeInfo, builder: StringBuilder) {
        // ENHANCED: More aggressive text extraction for messaging apps
        node.text?.let { text ->
            val textStr = text.toString().trim()
            if (textStr.isNotEmpty() && textStr.length > 1) {
                // Filter out common UI elements but keep message content
                if (!textStr.matches(Regex("^[0-9]{1,2}:[0-9]{2}\\s?(AM|PM)?\$")) && // Time stamps
                    !textStr.equals("Send", ignoreCase = true) &&
                    !textStr.equals("Type a message", ignoreCase = true) &&
                    !textStr.equals("Search", ignoreCase = true) &&
                    !textStr.equals("Camera", ignoreCase = true) &&
                    !textStr.equals("Gallery", ignoreCase = true) &&
                    !textStr.equals("Attach", ignoreCase = true) &&
                    !textStr.equals("More", ignoreCase = true) &&
                    !textStr.equals("Back", ignoreCase = true) &&
                    textStr.length > 2) {
                    
                    builder.append(textStr).append(" ")
                }
            }
        }
        
        // Extract content descriptions more selectively
        node.contentDescription?.let { desc ->
            val description = desc.toString().trim()
            if (description.isNotEmpty() && description.length > 5 && 
                !description.contains("button", ignoreCase = true) &&
                !description.contains("icon", ignoreCase = true) &&
                !description.contains("image", ignoreCase = true) &&
                !description.contains("tab", ignoreCase = true) &&
                !description.contains("navigation", ignoreCase = true)) {
                builder.append(description).append(" ")
            }
        }

        // Extract hint text (for input fields) - keep this
        node.hintText?.let { hint ->
            val hintStr = hint.toString().trim()
            if (hintStr.isNotEmpty() && hintStr.length > 2) {
                builder.append(hintStr).append(" ")
            }
        }

        // Extract error text (for form validation) - keep this
        node.error?.let { error ->
            val errorStr = error.toString().trim()
            if (errorStr.isNotEmpty()) {
                builder.append(errorStr).append(" ")
            }
        }

        // Recursively traverse child nodes
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                traverseNodes(child, builder)
                child.recycle()
            }
        }
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