// android/app/src/main/kotlin/com/example/scamshield_flutter_app/OverlayService.kt
package com.example.scamshield_flutter_app

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
import android.widget.Button
import android.widget.TextView
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
    }

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

        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // This service doesn't allow binding
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "OverlayService onStartCommand: ${intent?.action}")

        when (intent?.action) {
            "showOverlay" -> {
                val message = intent.getStringExtra("message") ?: "Scam Detected!"
                val alertType = intent.getStringExtra("alertType") ?: "warning"
                showOverlay(message, alertType)
            }
            "hideOverlay" -> {
                hideOverlay()
            }
        }

        return START_STICKY // Restart if killed by system
    }

    private fun showOverlay(message: String, alertType: String) {
        handler.post {
            if (isOverlayShowing && overlayView != null) {
                // Update existing overlay
                overlayView?.findViewById<TextView>(R.id.tvScamMessage)?.text = message
                return@post
            }

            try {
                val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
                overlayView = inflater.inflate(R.layout.overlay_alert, null)

                // Set message text
                overlayView?.findViewById<TextView>(R.id.tvScamMessage)?.text = message

                // Set appropriate styling based on alert type
                when (alertType) {
                    "critical_blocking" -> {
                        overlayView?.setBackgroundColor(Color.RED)
                        overlayView?.findViewById<TextView>(R.id.tvScamTitle)?.text = "CRITICAL SCAM ALERT"
                    }
                    "high_warning" -> {
                        overlayView?.setBackgroundColor(Color.parseColor("#FF8000")) // Orange
                        overlayView?.findViewById<TextView>(R.id.tvScamTitle)?.text = "POTENTIAL SCAM DETECTED"
                    }
                    else -> {
                        overlayView?.setBackgroundColor(Color.YELLOW)
                        overlayView?.findViewById<TextView>(R.id.tvScamTitle)?.text = "SCAM WARNING"
                    }
                }

                // Set up dismiss button
                overlayView?.findViewById<Button>(R.id.btnDismiss)?.setOnClickListener {
                    hideOverlay()
                }

                // Create overlay layout parameters
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                )
                params.gravity = Gravity.TOP
                
                windowManager.addView(overlayView, params)
                isOverlayShowing = true
                
                Log.d(TAG, "Overlay shown: $message")

                // Notify Flutter that overlay is shown
                MethodChannelManager.overlayMethodChannel?.invokeMethod(
                    "onOverlayShown",
                    mapOf("message" to message, "alertType" to alertType)
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error showing overlay: ${e.message}", e)
            }
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
