// android/app/src/main/kotlin/com/example/scamshield_flutter_app/MainActivity.kt
package com.elephas.ai

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity: FlutterActivity() {

    private val APP_CONTROL_CHANNEL = "elephas_ai/app_control"
    private val OVERLAY_CHANNEL = "elephas_ai/overlay"
    private val SCREEN_MONITOR_CHANNEL = "elephas_ai/screen_monitor"
    private val OCR_CHANNEL = "elephas_ai/ocr"
    private val ACCESSIBILITY_CHANNEL = "com.example.scamshield_flutter_app/accessibility"
    private val CALL_MONITOR_CHANNEL = "elephas_ai/call_monitor"
    private val SPEECH_RECOGNITION_CHANNEL = "elephas_ai/speech_recognition"
    private val CALL_CONTROL_CHANNEL = "elephas_ai/call_control"
    private val PERMISSIONS_CHANNEL = "com.example.scamshield_flutter_app/permissions"

    private var callMonitorPlugin: CallMonitorPlugin? = null
    private var callAudioProcessor: CallAudioProcessor? = null
    
    // FIX: Add broadcast receiver for accessibility service communication
    private val accessibilityBroadcastReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: android.content.Intent?) {
            when (intent?.action) {
                "com.example.scamshield_flutter_app.SCREEN_CONTENT" -> {
                    val content = intent.getStringExtra("content") ?: ""
                    val packageName = intent.getStringExtra("packageName") ?: ""
                    val timestamp = intent.getLongExtra("timestamp", 0)
                    
                    // FILTER: Skip Truecaller and call UI apps (causes false positives)
                    val ignoredApps = listOf(
                        "com.truecaller",
                        "com.samsung.android.incallui",
                        "com.android.incallui"
                    )
                    if (ignoredApps.contains(packageName)) {
                        Log.d("MainActivity", "⏭️ SKIPPED: $packageName (caller ID only, not messaging)")
                        return
                    }
                    
                    Log.d("MainActivity", "� BROADCAST RECEIVED: Screen content from $packageName")
                    Log.d("MainActivity", "🔥 Content length: ${content.length} chars")
                    Log.d("MainActivity", "🔥 Content preview: ${content.take(100)}...")
                    
                    // Forward to Flutter via method channel
                    val channelResult = MethodChannelManager.screenMonitorMethodChannel?.invokeMethod("onScreenContent", mapOf(
                        "content" to content,
                        "packageName" to packageName,
                        "timestamp" to timestamp
                    ))
                    
                    Log.d("MainActivity", "🔥 Content forwarded to Flutter via MethodChannel")
                }
                "com.example.scamshield_flutter_app.APP_CHANGED" -> {
                    val packageName = intent.getStringExtra("packageName") ?: ""
                    
                    // FILTER: Skip Truecaller and call UI apps
                    val ignoredApps = listOf(
                        "com.truecaller",
                        "com.samsung.android.incallui",
                        "com.android.incallui"
                    )
                    if (ignoredApps.contains(packageName)) {
                        Log.d("MainActivity", "⏭️ SKIPPED app change: $packageName (caller ID only)")
                        return
                    }
                    
                    Log.d("MainActivity", "� BROADCAST RECEIVED: App change to $packageName")
                    
                    // Forward to Flutter via method channel
                    MethodChannelManager.screenMonitorMethodChannel?.invokeMethod("onAppChanged", mapOf(
                        "packageName" to packageName
                    ))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up method channels
        MethodChannelManager.overlayMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        MethodChannelManager.screenMonitorMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_MONITOR_CHANNEL)
        MethodChannelManager.ocrMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL)
        MethodChannelManager.callMonitorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_MONITOR_CHANNEL)
        MethodChannelManager.speechRecognitionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_RECOGNITION_CHANNEL)
        MethodChannelManager.callControlChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CONTROL_CHANNEL)

        // Initialize plugins
        try {
            flutterEngine.plugins.add(ScreenMonitorPlugin())
            flutterEngine.plugins.add(OcrPlugin())
            flutterEngine.plugins.add(OverlayPlugin())
            
            // Initialize call monitoring
            callMonitorPlugin = CallMonitorPlugin(this)
            callAudioProcessor = CallAudioProcessor(this)
            
            // Set up method call handlers
            MethodChannelManager.callMonitorChannel?.setMethodCallHandler(callMonitorPlugin)
            MethodChannelManager.speechRecognitionChannel?.setMethodCallHandler(callAudioProcessor)
            MethodChannelManager.callControlChannel?.setMethodCallHandler(callAudioProcessor)
            
            Log.d("MainActivity", "🎯 LIVE CALL: All plugins initialized successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error registering plugins", e)
        }

        // Set up the accessibility channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", "Could not open accessibility settings", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundMonitoringService" -> {
                    val serviceIntent = Intent(this, BackgroundMonitorService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }
                "stopBackgroundMonitoringService" -> {
                    val serviceIntent = Intent(this, BackgroundMonitorService::class.java)
                    stopService(serviceIntent)
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "openDrawOverlaysSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Set up the permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibilityPermission" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "checkSystemAlertWindowPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestAccessibilityPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening accessibility settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open accessibility settings", null)
                    }
                }
                "requestSystemAlertWindowPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true) // Permission not needed on older versions
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening overlay settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open overlay settings", null)
                    }
                }
                "requestStoragePermission" -> {
                    // Storage permission is typically handled by Flutter permission_handler plugin
                    // But we can provide a fallback to settings
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open app settings", null)
                    }
                }
                "requestPhonePermission" -> {
                    // Phone permission is typically handled by Flutter permission_handler plugin
                    // But we can provide a fallback to settings
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open app settings", null)
                    }
                }
                "requestSmsPermission" -> {
                    // SMS permission is typically handled by Flutter permission_handler plugin
                    // But we can provide a fallback to settings
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open app settings", null)
                    }
                }
                "requestContactsPermission" -> {
                    // Contacts permission is typically handled by Flutter permission_handler plugin
                    // But we can provide a fallback to settings
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open app settings", null)
                    }
                }
                "requestCameraPermission" -> {
                    // Camera permission is typically handled by Flutter permission_handler plugin
                    // But we can provide a fallback to settings
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open app settings", null)
                    }
                }
                "requestMicrophonePermission" -> {
                    // Microphone permission is typically handled by Flutter permission_handler plugin
                    // But we can provide a fallback to settings
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Could not open app settings", null)
                    }
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", "Could not open accessibility settings", null)
                    }
                }
                "openSystemAlertWindowSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", "Could not open overlay settings", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Add SMS Channel handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elephas_ai/sms").setMethodCallHandler { call, result ->
            when (call.method) {
                "getMessageCount" -> {
                    try {
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                        if (phoneNumber.isEmpty()) {
                            result.success(mapOf(
                                "count" to 0,
                                "success" to false
                            ))
                            return@setMethodCallHandler
                        }

                        val normalizedNumber = phoneNumber.replace("[^0-9+]".toRegex(), "")
                        
                        // Query SMS database
                        val cursor = contentResolver.query(
                            Uri.parse("content://sms"),
                            arrayOf("address", "body"),
                            "address LIKE ?",
                            arrayOf("%$normalizedNumber%"),
                            null
                        )

                        val count = cursor?.count ?: 0
                        cursor?.close()

                        result.success(mapOf(
                            "count" to count,
                            "success" to true
                        ))
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error getting SMS count: ${e.message}")
                        result.success(mapOf(
                            "count" to 0,
                            "success" to false
                        ))
                    }
                }
                else -> result.notImplemented()
            }
        }

        // FIX: Register broadcast receiver for accessibility service communication
        val intentFilter = android.content.IntentFilter().apply {
            addAction("com.example.scamshield_flutter_app.SCREEN_CONTENT")
            addAction("com.example.scamshield_flutter_app.APP_CHANGED")
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                accessibilityBroadcastReceiver,
                intentFilter,
                android.content.Context.RECEIVER_EXPORTED
            )
        } else {
            registerReceiver(accessibilityBroadcastReceiver, intentFilter)
        }
        Log.d("MainActivity", "📱 Broadcast receiver registered for accessibility service")
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        return enabledServices.any { it.id.contains(packageName) }
    }

    override fun onResume() {
        super.onResume()
    }

    override fun onDestroy() {
        // FIX: Unregister broadcast receiver
        try {
            unregisterReceiver(accessibilityBroadcastReceiver)
            Log.d("MainActivity", "📱 Broadcast receiver unregistered")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error unregistering broadcast receiver: ${e.message}")
        }
        super.onDestroy()
    }
}