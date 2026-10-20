// android/app/src/main/kotlin/com/example/scamshield_flutter_app/OverlayService.kt
package com.elephas.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var isOverlayShowing = false
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "OverlayService"
        private const val NOTIFICATION_ID = 1001
        private const val NOTIFICATION_CHANNEL_ID = "scamshield_overlay_channel"
        private const val OVERLAY_DISPLAY_DURATION = 10000L // 10 seconds display time
    }

    private var hideOverlayRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "OverlayService onCreate")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForeground()
    }

    private fun startForeground() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Elephas AI Overlay Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Required for showing scam alerts"
                enableLights(true)
                lightColor = Color.RED
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Elephas AI Protection Active")
            .setContentText("Monitoring for scams")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        // For Android 14+ (API 34+), use proper foreground service type
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // This service doesn't allow binding
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "OverlayService onStartCommand: ${intent?.action}")

        when (intent?.action) {
            "showOverlay" -> {
                val alertType = intent.getStringExtra("alertType") ?: "scam"
                showOverlay(alertType)
            }
            "hideOverlay" -> {
                hideOverlay()
            }
        }

        return START_STICKY // Restart if killed by system
    }

    private fun showOverlay(alertType: String) {
        if (isOverlayShowing) {
            hideOverlay()
        }

        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        overlayView = inflater.inflate(R.layout.overlay_alert, null)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 16 // Small padding from top of screen
        }

        try {
            overlayView?.let { view ->
                val alertImage = view.findViewById<ImageView>(R.id.alertImage)
                val imageResId = when (alertType) {
                    "url" -> R.drawable.url_warning
                    else -> R.drawable.scam_alert
                }
                alertImage.setImageResource(imageResId)
                windowManager.addView(view, params)
                isOverlayShowing = true

                // Schedule hiding the overlay
                hideOverlayRunnable = Runnable {
                    hideOverlay()
                }.also {
                    handler.postDelayed(it, OVERLAY_DISPLAY_DURATION)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error showing overlay: ${e.message}")
        }
    }

    private fun hideOverlay() {
        handler.post {
            if (overlayView != null && isOverlayShowing) {
                try {
                    windowManager.removeView(overlayView)
                    overlayView = null
                    isOverlayShowing = false
                    
                    // Notify Flutter that overlay is hidden
                    MethodChannelManager.overlayMethodChannel?.invokeMethod(
                        "onOverlayHidden",
                        mapOf("success" to true)
                    )
                    
                    Log.d(TAG, "Overlay hidden")
                } catch (e: Exception) {
                    Log.e(TAG, "Error hiding overlay: ${e.message}", e)
                }
            }
        }
    }

    override fun onDestroy() {
        hideOverlay()
        Log.d(TAG, "OverlayService destroyed")
        super.onDestroy()
    }
}
