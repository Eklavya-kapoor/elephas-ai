package com.elephas.ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class ScreenMonitorPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        private const val TAG = "ScreenMonitorPlugin"
        private const val CHANNEL = "elephas_ai/screen_monitor"
        private const val MEDIA_PROJECTION_REQUEST_CODE = 100
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var resultData: Intent? = null
    private var resultCode: Int = 0
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext

        // Store the channel in MethodChannelManager for accessibility service access
        MethodChannelManager.screenMonitorMethodChannel = channel
        Log.d(TAG, "Screen monitor channel attached via MethodChannelManager")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        MethodChannelManager.screenMonitorMethodChannel = null
        Log.d(TAG, "Screen monitor channel detached")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        mediaProjectionManager = activity?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager?
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

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestScreenCapturePermission" -> requestScreenCapturePermission(result)
            "startScreenMonitoring" -> startScreenMonitoring(result)
            "stopScreenMonitoring" -> stopScreenMonitoring(result)
            "captureScreenWithTextPositions" -> captureScreenWithTextPositions(result)
            "isAccessibilityServiceEnabled" -> result.success(isAccessibilityServiceEnabled())
            "openAccessibilitySettings" -> openAccessibilitySettings(result)
            "getCurrentPackage" -> getCurrentPackage(result)
            else -> result.notImplemented()
        }
    }

    private fun requestScreenCapturePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (mediaProjectionManager != null && activity != null) {
                val captureIntent = mediaProjectionManager!!.createScreenCaptureIntent()
                pendingResult = result
                activity!!.startActivityForResult(captureIntent, MEDIA_PROJECTION_REQUEST_CODE)
            } else {
                result.success(false)
            }
        } else {
            result.success(false)
        }
    }

    private fun startScreenMonitoring(result: MethodChannel.Result) {
        if (mediaProjection != null) {
            setupVirtualDisplay()
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun stopScreenMonitoring(result: MethodChannel.Result) {
        cleanup()
        result.success(true)
    }

    private fun captureScreenWithTextPositions(result: MethodChannel.Result) {
        // This would typically use OCR to identify text positions
        // For now, return empty result
        result.success(mapOf<String, Any>())
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val accessibilityEnabled = Settings.Secure.getInt(
                context?.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED
            )
            accessibilityEnabled == 1
        } catch (e: Settings.SettingNotFoundException) {
            false
        }
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            activity?.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun getCurrentPackage(result: MethodChannel.Result) {
        result.success(ScamShieldAccessibilityService.currentPackage)
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun setupVirtualDisplay() {
        val metrics = DisplayMetrics()
        activity?.windowManager?.defaultDisplay?.getMetrics(metrics)

        imageReader = ImageReader.newInstance(
            metrics.widthPixels,
            metrics.heightPixels,
            PixelFormat.RGBA_8888,
            1
        )

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            metrics.widthPixels,
            metrics.heightPixels,
            metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null
        )
    }

    private fun cleanup() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == MEDIA_PROJECTION_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                this.resultCode = resultCode
                this.resultData = data
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
                }
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
            return true
        }
        return false
    }
}