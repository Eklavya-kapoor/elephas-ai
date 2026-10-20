// android/app/src/main/kotlin/com/example/scamshield_flutter_app/OverlayPlugin.kt
package com.elephas.ai // Ensure this package name is correct

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
import android.widget.ImageView // Added for scam alert overlay icons/animations
import android.widget.TextView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class OverlayPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: ActivityPluginBinding? = null
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    private val OVERLAY_PERMISSION_REQUEST_CODE = 1004

    companion object {
        private const val TAG = "OverlayPlugin"
        private const val CHANNEL = "elephas_ai/overlay"
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
        Log.d(TAG, "🔥 OverlayPlugin: Received method call: ${call.method}")
        Log.d(TAG, "🔥 OverlayPlugin: Arguments: ${call.arguments}")
        
        when (call.method) {
            "requestOverlayPermission" -> requestOverlayPermission(result)
            "hasOverlayPermission" -> result.success(hasOverlayPermission())
            "showOverlay" -> {
                val alertType = call.argument<String>("alertType") ?: "scam"
                Log.d(TAG, "🔥 OverlayPlugin: Showing overlay alert of type: $alertType")
                showImageOverlay(alertType)
                result.success(true)
            }
            "hideOverlay" -> {
                removeOverlay()
                result.success(true)
            }
            "showScamAlert" -> {
                val packageName = call.argument<String>("packageName") ?: "unknown"
                Log.d(TAG, "� OverlayPlugin: showScamAlert is DISABLED - use showOverlay instead for package: $packageName")
                result.success(null)
            }
            "showMinimalScamAlert" -> {
                val appName = call.argument<String>("appName") ?: "Unknown App"
                Log.d(TAG, "🚨 OverlayPlugin: Showing minimal scam alert for app: $appName")
                showMinimalScamAlert(appName)
                result.success(null)
            }
            "showCustomImageAlert" -> {
                val appName = call.argument<String>("appName") ?: "Unknown App" 
                val packageName = call.argument<String>("packageName") ?: appName
                val message = call.argument<String>("message") ?: "🚨 SCAM DETECTED!"
                Log.d(TAG, "🖼️ OverlayPlugin: Showing custom image alert for app: $appName, package: $packageName")
                
                // Filter out system and launcher apps
                if (shouldSkipPackage(packageName)) {
                    Log.d(TAG, "🚫 OverlayPlugin: Skipping overlay for excluded package: $packageName")
                    result.success(null)
                    return
                }
                
                showCustomImageAlert(appName, message)
                result.success(null)
            }
            "hideScamAlert" -> {
                Log.d(TAG, "🚨 OverlayPlugin: Hiding scam alert")
                hideScamAlert()
                result.success(null)
            }
            else -> {
                Log.d(TAG, "❌ OverlayPlugin: Method not implemented: ${call.method}")
                result.notImplemented()
            }
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

    private fun showMinimalScamAlert(appName: String) {
        Log.d(TAG, "🚨 OverlayPlugin: showMinimalScamAlert called for $appName")
        Log.d(TAG, "🚨 OverlayPlugin: Checking overlay permission...")
        
        if (!hasOverlayPermission()) {
            Log.e(TAG, "❌ OverlayPlugin: Cannot show overlay: Permission not granted.")
            return
        }
        
        Log.d(TAG, "✅ OverlayPlugin: Overlay permission granted, creating minimal overlay...")

        try {
            // Remove existing overlay if any
            removeOverlay()

            val inflater = LayoutInflater.from(context)
            overlayView = inflater.inflate(R.layout.minimal_scam_overlay, null)

            // Set up premium minimal banner content
            val brandName = overlayView?.findViewById<TextView>(R.id.brandName)
            val warningText = overlayView?.findViewById<TextView>(R.id.warningText)
            val dismissButton = overlayView?.findViewById<TextView>(R.id.dismissButton)
            val logo = overlayView?.findViewById<ImageView>(R.id.elephasLogo)

            brandName?.text = "ELEPHAS AI"
            warningText?.text = "⚠️ Scam detected in $appName"

            dismissButton?.setOnClickListener {
                hideScamAlertWithAnimation()
            }

            // Window parameters for top of screen
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
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            params.y = 0

            windowManager?.addView(overlayView, params)

            // Slide-down animation
            overlayView?.let { view ->
                view.translationY = -view.height.toFloat()
                view.alpha = 0f
                view.animate()
                    .translationY(0f)
                    .alpha(1f)
                    .setDuration(400)
                    .setInterpolator(android.view.animation.DecelerateInterpolator())
                    .start()
            }

            // Auto-hide after 4 seconds
            overlayView?.postDelayed({
                hideScamAlertWithAnimation()
            }, 4000)
        } catch (e: Exception) {
            Log.e(TAG, "❌ OverlayPlugin: Error showing minimal scam alert overlay: $e", e)
        }
    }

    private fun showScamAlert(message: String, sender: String, riskLevel: String, x: Double? = null, y: Double? = null, width: Double? = null, height: Double? = null, confidence: Double? = null, scamReason: String? = null) {
        Log.d(TAG, "🚨 OverlayPlugin: showScamAlert called")
        Log.d(TAG, "🚨 OverlayPlugin: Checking overlay permission...")
        
        if (!hasOverlayPermission()) {
            Log.e(TAG, "❌ OverlayPlugin: Cannot show overlay: Permission not granted.")
            return
        }
        
        Log.d(TAG, "✅ OverlayPlugin: Overlay permission granted, creating overlay...")

        try {
            Log.d(TAG, "🚨 OverlayPlugin: Creating overlay directly...")
            
            // Remove existing overlay if any
            removeOverlay()

            Log.d(TAG, "🚨 OverlayPlugin: Creating overlay view...")
            val inflater = LayoutInflater.from(context)
            overlayView = inflater.inflate(R.layout.custom_image_overlay, null)

            Log.d(TAG, "🚨 OverlayPlugin: Setting up overlay content...")
            val tvMessage = overlayView?.findViewById<TextView>(R.id.messageText)
            val tvAppName = overlayView?.findViewById<TextView>(R.id.appName)
            val tvRiskLevel = overlayView?.findViewById<TextView>(R.id.riskLevel)
            val tvConfidence = overlayView?.findViewById<TextView>(R.id.confidenceScore)
            val tvAlertTitle = overlayView?.findViewById<TextView>(R.id.alertTitle)
            val tvAlertIcon = overlayView?.findViewById<TextView>(R.id.alertIcon)
            val dismissButton = overlayView?.findViewById<Button>(R.id.dismissButton)
            val blockButton = overlayView?.findViewById<Button>(R.id.blockButton)

            // Set text values with enhanced formatting
            tvMessage?.text = message
            tvAppName?.text = sender
            tvRiskLevel?.text = "⚠️ $riskLevel RISK - DO NOT CLICK LINKS"
            tvConfidence?.text = if (confidence != null) "${confidence.toInt()}%" else "95%"
            tvAlertTitle?.text = scamReason ?: "SCAM DETECTED"
            tvAlertIcon?.text = "🚨"

            Log.d(TAG, "🚨 OverlayPlugin: Setting up button listeners...")
            dismissButton?.setOnClickListener {
                Log.d(TAG, "🚨 OverlayPlugin: Dismiss button clicked")
                hideScamAlert()
            }
            blockButton?.setOnClickListener {
                Log.d(TAG, "🚨 OverlayPlugin: Block button clicked")
                hideScamAlert()
            }

            Log.d(TAG, "🚨 OverlayPlugin: Setting up window parameters...")
            val layoutParamsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                if (width != null && width > 0) width.toInt() else WindowManager.LayoutParams.MATCH_PARENT,
                if (height != null && height > 0) height.toInt() else WindowManager.LayoutParams.WRAP_CONTENT,
                layoutParamsType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            )

            // Use provided x/y or default to top banner
            params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            params.x = x?.toInt() ?: 0
            params.y = y?.toInt() ?: 32

            Log.d(TAG, "🚨 OverlayPlugin: Adding overlay to window manager...")
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "✅ OverlayPlugin: Enhanced scam alert overlay shown successfully!")

            overlayView?.postDelayed({
                hideScamAlert()
            }, 10000)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ OverlayPlugin: Error showing scam alert overlay: $e", e)
        }
    }

    private fun showCustomImageAlert(appName: String, message: String) {
        Log.d(TAG, "🖼️ OverlayPlugin: showCustomImageAlert called for $appName")
        
        if (!hasOverlayPermission()) {
            Log.e(TAG, "❌ OverlayPlugin: Cannot show custom image overlay: Permission not granted.")
            return
        }
        
        Log.d(TAG, "✅ OverlayPlugin: Overlay permission granted, creating custom image overlay...")

        try {
            // Remove existing overlay if any
            removeOverlay()

            val inflater = LayoutInflater.from(context)
            overlayView = inflater.inflate(R.layout.custom_image_overlay, null)

            // Only your image - no text, no buttons, nothing else
            val customImage = overlayView?.findViewById<ImageView>(R.id.customOverlayImage)
            Log.d(TAG, "🖼️ Custom image view found: ${customImage != null}")
            
            // Make overlay clickable to dismiss
            overlayView?.setOnClickListener {
                Log.d(TAG, "👆 Custom image overlay clicked - hiding")
                hideScamAlert()
            }

            // Window parameters for center of screen
            val layoutParamsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutParamsType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
                PixelFormat.RGBA_8888 // Use RGBA for full transparency
            )

            // Position at TOP of screen
            params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            params.x = 0
            params.y = 50 // Small margin from top (status bar)

            Log.d(TAG, "🖼️ Adding custom image overlay to window manager...")
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "✅ Custom image overlay shown successfully!")

            // Auto-hide after 5 seconds (shorter for better UX - no blinking)
            overlayView?.postDelayed({
                Log.d(TAG, "⏰ Auto-hiding overlay after timeout")
                hideScamAlert()
            }, 5000)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ OverlayPlugin: Error showing custom image overlay: $e", e)
        }
    }

    private fun hideScamAlertWithAnimation() {
        Log.d(TAG, "🚨 OverlayPlugin: hideScamAlertWithAnimation called")
        try {
            overlayView?.let { view ->
                // AMAZING slide-up and fade-out animation
                view.animate()
                    .translationY(-view.height.toFloat())
                    .alpha(0f)
                    .setDuration(300)
                    .setInterpolator(android.view.animation.AccelerateInterpolator())
                    .withEndAction {
                        removeOverlay()
                        Log.d(TAG, "✅ OverlayPlugin: AMAZING scam alert hidden with animation!")
                    }
                    .start()
            } ?: run {
                removeOverlay()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ OverlayPlugin: Error hiding overlay with animation: $e", e)
            removeOverlay()
        }
    }

    private fun hideScamAlert() {
        Log.d(TAG, "🚨 OverlayPlugin: hideScamAlert called")
        try {
            removeOverlay()
            Log.d(TAG, "✅ OverlayPlugin: Scam alert overlay hidden successfully.")
        } catch (e: Exception) {
            Log.e(TAG, "❌ OverlayPlugin: Error hiding overlay: $e", e)
        }
    }

    private fun removeOverlay() {
        try {
            overlayView?.let { view ->
                windowManager?.removeView(view)
                overlayView = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error removing overlay: ${e.message}", e)
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
            "com.google.android.googlequicksearchbox"    // Google search/launcher
        )
        
        val shouldSkip = excludedPackages.contains(packageName) || 
                        packageName.startsWith("com.android.") ||
                        packageName.startsWith("android.") ||
                        packageName.contains("launcher") ||
                        packageName.contains("systemui") ||
                        packageName.contains("scamshield")  // Block all versions of our app
        
        if (shouldSkip) {
            Log.d(TAG, "🚫 Package filtered: $packageName")
        }
        
        return shouldSkip
    }

    private fun showImageOverlay(alertType: String) {
        if (!hasOverlayPermission()) {
            Log.e(TAG, "❌ Cannot show overlay: Permission not granted")
            return
        }

        try {
            removeOverlay() // Remove any existing overlay first
            
            overlayView = LayoutInflater.from(context).inflate(R.layout.overlay_alert, null)
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,  // Full width
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else 
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP  // No need for CENTER_HORIZONTAL as we're full width
                y = 0  // No padding needed
            }

            overlayView?.let { view ->
                val alertImage = view.findViewById<ImageView>(R.id.alertImage)
                val imageResId = when (alertType) {
                    "url" -> R.drawable.url_warning
                    else -> R.drawable.scam_alert
                }
                alertImage.setImageResource(imageResId)
                windowManager?.addView(view, params)

                // Auto-hide overlay after 3 seconds
                view.postDelayed({
                    removeOverlay()
                }, 3000)
            }
            
            Log.d(TAG, "✅ Successfully showed $alertType overlay")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing overlay: ${e.message}", e)
        }
    }
}