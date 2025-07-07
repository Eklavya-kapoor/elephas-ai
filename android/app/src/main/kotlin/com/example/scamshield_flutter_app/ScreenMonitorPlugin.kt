// android/app/src/main/kotlin/com/scamshield/scamshield_ai/ScreenMonitorPlugin.kt
package com.example.scamshield_flutter_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Display
import android.graphics.ImageFormat
import android.media.Image
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

// Import MethodChannelManager for setting the channel
import com.example.scamshield_flutter_app.MethodChannelManager
import com.example.scamshield_flutter_app.ScamShieldAccessibilityService // Also import your Accessibility Service


class ScreenMonitorPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    
    // Screen capture components
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    
    // Constants
    private val SCREEN_CAPTURE_REQUEST = 1001
    // ACCESSIBILITY_REQUEST and OVERLAY_PERMISSION_REQUEST are typically handled by their own plugins/channels now.
    
    private var screenWidth = 0
    private var screenHeight = 0
    private var screenDensity = 0
    
    companion object {
        private const val TAG = "ScreenMonitorPlugin"
        private const val CHANNEL = "scamshield/screen_monitor"
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext

        // Set the screen monitor channel reference for the Accessibility Service
        // This allows the accessibility service to send back app change and screen content events.
        ScamShieldAccessibilityService.screenMonitorMethodChannel = channel // <--- ADD THIS LINE
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        ScamShieldAccessibilityService.screenMonitorMethodChannel = null // <--- ADD THIS LINE
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        initializeScreenCapture()
    }
    
    override fun onDetachedFromActivity() {
        activity = null
        cleanup()
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    
    private fun initializeScreenCapture() {
        activity?.let { act ->
            mediaProjectionManager = act.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            
            val displayMetrics = act.resources.displayMetrics
            screenWidth = displayMetrics.widthPixels
            screenHeight = displayMetrics.heightPixels
            screenDensity = displayMetrics.densityDpi
            
            Log.d(TAG, "Screen initialized: ${screenWidth}x${screenHeight}, density: $screenDensity")
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestScreenCapturePermission" -> requestScreenCapturePermission(result)
            "requestAccessibilityPermission" -> requestAccessibilityPermission(result) // Still useful if you want a direct link
            "startScreenMonitoring" -> startScreenMonitoring(result)
            "stopScreenMonitoring" -> stopScreenMonitoring(result)
            "captureScreen" -> captureScreen(result)
            "getCurrentApp" -> getCurrentApp(result)
            else -> result.notImplemented()
        }
    }
    
    private fun requestScreenCapturePermission(result: MethodChannel.Result) {
        try {
            mediaProjectionManager?.let { manager ->
                val intent = manager.createScreenCaptureIntent()
                activity?.startActivityForResult(intent, SCREEN_CAPTURE_REQUEST)
                
                // Store result callback for later
                pendingResult = result
            } ?: run {
                result.success(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting screen capture permission", e)
            result.success(false)
        }
    }
    
    private fun requestAccessibilityPermission(result: MethodChannel.Result) {
        // This will now open settings, but the actual check for enabled service is in the service itself.
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            activity?.startActivity(intent)
            
            // Note: Checking isAccessibilityServiceEnabled() immediately after starting activity
            // will likely return false as the user hasn't enabled it yet.
            // Flutter will need to re-check this on resume or via a listener.
            // For now, we'll just indicate we've opened the settings.
            result.success(true) // Indicate that the request was initiated
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting accessibility permission", e)
            result.success(false)
        }
    }
    
    // isAccessibilityServiceEnabled method moved to Accessibility Service itself, or can be a utility
    // private fun isAccessibilityServiceEnabled(): Boolean { ... }

    private fun startScreenMonitoring(result: MethodChannel.Result) {
        if (mediaProjection != null) {
            setupVirtualDisplay()
            result.success(true)
        } else {
            // Need to request screen capture permission first
            result.success(false)
        }
    }
    
    private fun stopScreenMonitoring(result: MethodChannel.Result) {
        cleanup()
        result.success(true)
    }
    
    private fun setupVirtualDisplay() {
        try {
            // Use ImageFormat.RGBA_8888 for better compatibility with Android's Bitmap.copyPixelsFromBuffer
            // Or stick with JPEG if you're compressing immediately
            imageReader = ImageReader.newInstance(screenWidth, screenHeight, PixelFormat.RGBA_8888, 2)
            // Note: Using PixelFormat.RGBA_8888 will require adjusting imageToBitmap for direct buffer copy
            // For now, let's keep JPEG if the OCR expects JPEG. If OCR handles Bitmap directly, then RGBA_8888 is fine.
            // Let's assume JPEG based on your current bitmapToByteArray.

            imageReader = ImageReader.newInstance(screenWidth, screenHeight, ImageFormat.JPEG, 2) // Sticking with JPEG for now
            
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "ScamShield-Screen-Capture",
                screenWidth,
                screenHeight,
                screenDensity,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader?.surface,
                null,
                null
            )
            
            Log.d(TAG, "Virtual display created successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up virtual display", e)
        }
    }
    
    private fun captureScreen(result: MethodChannel.Result) {
        try {
            imageReader?.let { reader ->
                val image = reader.acquireLatestImage()
                if (image != null) {
                    val bitmap = imageToBitmap(image) // Your existing conversion from Image to Bitmap
                    image.close()
                    
                    if (bitmap != null) {
                        val byteArray = bitmapToByteArray(bitmap) // Your existing Bitmap to ByteArray
                        result.success(byteArray)
                        bitmap.recycle()
                    } else {
                        result.success(null)
                    }
                } else {
                    Log.w(TAG, "No image available from ImageReader.")
                    result.success(null)
                }
            } ?: run {
                Log.e(TAG, "ImageReader is null, cannot capture screen.")
                result.success(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing screen: $e")
            result.success(null)
        }
    }
    
    private fun imageToBitmap(image: Image): Bitmap? {
        val planes = image.planes
        val buffer = planes[0].buffer
        val pixelStride = planes[0].pixelStride
        val rowStride = planes[0].rowStride
        val rowPadding = rowStride - pixelStride * image.width

        val bitmap = Bitmap.createBitmap(
            image.width + rowPadding / pixelStride,
            image.height,
            Bitmap.Config.ARGB_8888
        )
        bitmap.copyPixelsFromBuffer(buffer)

        // Crop the bitmap to the actual screen dimensions, removing the padding
        return Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)
    }

    private fun bitmapToByteArray(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        // Compress with JPEG quality for smaller size, adjust quality (80 here) as needed
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
        return stream.toByteArray()
    }
    
    private fun getCurrentApp(result: MethodChannel.Result) {
        // Now correctly gets the current package from the accessibility service
        result.success(ScamShieldAccessibilityService.currentPackage)
    }
    
    private fun cleanup() {
        virtualDisplay?.release()
        imageReader?.close()
        mediaProjection?.stop()
        
        virtualDisplay = null
        imageReader = null
        mediaProjection = null
        Log.d(TAG, "Screen monitoring cleanup complete.")
    }
    
    // Store pending result for activity result callback
    private var pendingResult: MethodChannel.Result? = null
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            SCREEN_CAPTURE_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
                    pendingResult?.success(true)
                } else {
                    pendingResult?.success(false)
                }
                pendingResult = null
                return true
            }
        }
        return false
    }
}