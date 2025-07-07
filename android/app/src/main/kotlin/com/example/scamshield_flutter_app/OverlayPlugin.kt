// android/app/src/main/kotlin/com/example/scamshield_flutter_app/OverlayPlugin.kt
package com.example.scamshield_flutter_app // Ensure this package name is correct

import android.app.Service // Keep this if used, although OverlayPlugin is not a Service itself, it uses Context
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings // Explicitly import from android.provider
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button // Explicitly import from android.widget
import android.widget.TextView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import com.example.scamshield_flutter_app.R // Make sure this R points to your app's R file for layout reference
import com.example.scamshield_flutter_app.MethodChannelManager // Import MethodChannelManager

class OverlayPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: ActivityPluginBinding? = null
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    private val OVERLAY_PERMISSION_REQUEST_CODE = 1004

    companion object {
        private const val TAG = "OverlayPlugin"
        private const val CHANNEL = "scamshield/overlay"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        windowManager = context?.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
        windowManager = null
        removeOverlay() // Ensure overlay is removed when engine detaches
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity?.removeActivityResultListener(this)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity?.removeActivityResultListener(this)
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestOverlayPermission" -> requestOverlayPermission(result)
            "hasOverlayPermission" -> result.success(hasOverlayPermission())
            "showScamAlert" -> {
                val message = call.argument<String>("message") ?: "Scam Alert!"
                val sender = call.argument<String>("sender") ?: "Unknown Sender"
                val riskLevel = call.argument<String>("riskLevel") ?: "HIGH"
                showScamAlert(message, sender, riskLevel)
                result.success(null)
            }
            "hideScamAlert" -> {
                hideScamAlert()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestOverlayPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(context)) { // Use fully qualified name if still ambiguous after imports
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context?.packageName}"))
                activity?.activity?.startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                // Store result for onActivityResult
                pendingResult = result
            } else {
                result.success(true)
            }
        } else {
            result.success(true) // Permission not needed for older Android versions
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context) // Use fully qualified name if still ambiguous
        } else {
            true
        }
    }

    private fun showScamAlert(message: String, sender: String, riskLevel: String) {
        if (!hasOverlayPermission()) {
            Log.e(TAG, "Cannot show overlay: Permission not granted.")
            return
        }

        activity?.activity?.runOnUiThread {
            try {
                // Remove existing overlay if any
                removeOverlay()

                val inflater = context?.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
                // IMPORTANT: Change R.layout.overlay_alert_layout to R.layout.your_existing_layout_name (e.g., scam_alert_overlay)
                overlayView = inflater.inflate(R.layout.scam_alert_overlay, null)

                // IMPORTANT: Update these findViewById calls to use YOUR layout's IDs
                val tvMessage = overlayView?.findViewById<TextView>(R.id.messageText)
                val tvSender = overlayView?.findViewById<TextView>(R.id.senderText)
                val tvRiskLevel = overlayView?.findViewById<TextView>(R.id.riskLevel)
                val dismissButton = overlayView?.findViewById<Button>(R.id.dismissButton) // This uses android.widget.Button
                val blockButton = overlayView?.findViewById<Button>(R.id.blockButton)    // This uses android.widget.Button

                // Set text values
                tvMessage?.text = message
                tvSender?.text = "From: $sender"
                tvRiskLevel?.text = "Risk: $riskLevel"

                // Set up button listeners
                dismissButton?.setOnClickListener {
                    hideScamAlert()
                }

                blockButton?.setOnClickListener {
                    // Implement your blocking logic here, e.g., send event back to Flutter
                    // MethodChannelManager.overlayMethodChannel?.invokeMethod("onBlockAction", {"sender": sender})
                    hideScamAlert()
                }


                val layoutParamsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    layoutParamsType,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED, // Show over lock screen
                    PixelFormat.TRANSLUCENT
                )

                params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                params.y = 100 // Offset from top

                windowManager?.addView(overlayView, params)
                Log.d(TAG, "Scam alert overlay shown.")

                // Automatically hide after a few seconds (optional, but good UX)
                overlayView?.postDelayed({
                    hideScamAlert()
                }, 5000) // Hide after 5 seconds
            } catch (e: Exception) {
                Log.e(TAG, "Error showing scam alert overlay: $e")
            }
        }
    }

    private fun hideScamAlert() {
        activity?.activity?.runOnUiThread {
            removeOverlay()
            Log.d(TAG, "Scam alert overlay hidden.")
        }
    }

    private fun removeOverlay() {
        if (overlayView != null && windowManager != null) {
            try {
                windowManager?.removeView(overlayView)
                overlayView = null
            } catch (e: IllegalArgumentException) {
                // View not attached, ignore
                Log.e(TAG, "Overlay view not attached to window manager, or already removed: $e")
            }
        }
    }

    // Store pending result for activity result callback
    private var pendingResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            pendingResult?.success(Settings.canDrawOverlays(context))
            pendingResult = null
            return true
        }
        return false
    }
}