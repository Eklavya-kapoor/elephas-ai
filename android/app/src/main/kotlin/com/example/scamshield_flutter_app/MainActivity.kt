// android/app/src/main/kotlin/com/example/scamshield_flutter_app/MainActivity.kt
package com.example.scamshield_flutter_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
// Corrected imports for your plugins to match the app's base package
import com.example.scamshield_flutter_app.ScreenMonitorPlugin // UPDATED
import com.example.scamshield_flutter_app.OcrPlugin // UPDATED
import com.example.scamshield_flutter_app.OverlayPlugin // UPDATED

class MainActivity: FlutterActivity() {

    private val APP_CONTROL_CHANNEL = "scamshield/app_control"
    private val OVERLAY_CHANNEL = "scamshield/overlay"
    private val SCREEN_MONITOR_CHANNEL = "scamshield/screen_monitor"
    private val OCR_CHANNEL = "scamshield/ocr"


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannelManager.overlayMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        MethodChannelManager.screenMonitorMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_MONITOR_CHANNEL)
        MethodChannelManager.ocrMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL)

        flutterEngine.plugins.add(ScreenMonitorPlugin())
        flutterEngine.plugins.add(OcrPlugin())
        flutterEngine.plugins.add(OverlayPlugin())

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
                "openNotificationListenerSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
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
    }

    override fun onResume() {
        super.onResume()
    }
}