package com.elephas.ai;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.ImageReader;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.os.Build;
import android.provider.Settings;
import android.util.DisplayMetrics;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

import java.util.Collections;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class ScreenMonitorPlugin implements FlutterPlugin, ActivityAware,
        MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    private static final String TAG = "ScreenMonitorPlugin";
    private static final String CHANNEL = "elephas_ai/screen_monitor";
    private static final int MEDIA_PROJECTION_REQUEST_CODE = 100;

    private MethodChannel channel;
    private Context context;
    private Activity activity;
    private MediaProjectionManager mediaProjectionManager;
    private MediaProjection mediaProjection;
    private VirtualDisplay virtualDisplay;
    private ImageReader imageReader;
    private Intent resultData;
    private int resultCode = 0;
    private MethodChannel.Result pendingResult;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();

        // Store the channel in MethodChannelManager for accessibility service access
        MethodChannelManager.screenMonitorMethodChannel = channel;
        Log.d(TAG, "Screen monitor channel attached via MethodChannelManager");
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
        }
        MethodChannelManager.screenMonitorMethodChannel = null;
        Log.d(TAG, "Screen monitor channel detached");
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
        if (activity != null) {
            mediaProjectionManager = (MediaProjectionManager) activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE);
        }
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
        cleanup();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "requestScreenCapturePermission":
                requestScreenCapturePermission(result);
                break;
            case "startScreenMonitoring":
                startScreenMonitoring(result);
                break;
            case "stopScreenMonitoring":
                stopScreenMonitoring(result);
                break;
            case "captureScreenWithTextPositions":
                captureScreenWithTextPositions(result);
                break;
            case "isAccessibilityServiceEnabled":
                result.success(isAccessibilityServiceEnabled());
                break;
            case "openAccessibilitySettings":
                openAccessibilitySettings(result);
                break;
            case "getCurrentPackage":
                getCurrentPackage(result);
                break;
            default:
                result.notImplemented();
        }
    }

    private void requestScreenCapturePermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (mediaProjectionManager != null && activity != null) {
                Intent captureIntent = mediaProjectionManager.createScreenCaptureIntent();
                pendingResult = result;
                activity.startActivityForResult(captureIntent, MEDIA_PROJECTION_REQUEST_CODE);
            } else {
                result.success(false);
            }
        } else {
            result.success(false);
        }
    }

    private void startScreenMonitoring(MethodChannel.Result result) {
        if (mediaProjection != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                setupVirtualDisplay();
            }
            result.success(true);
        } else {
            result.success(false);
        }
    }

    private void stopScreenMonitoring(MethodChannel.Result result) {
        cleanup();
        result.success(true);
    }

    private void captureScreenWithTextPositions(MethodChannel.Result result) {
        result.success(Collections.emptyMap());
    }

    private boolean isAccessibilityServiceEnabled() {
        try {
            if (context == null) return false;
            int accessibilityEnabled = Settings.Secure.getInt(
                    context.getContentResolver(),
                    Settings.Secure.ACCESSIBILITY_ENABLED
            );
            return accessibilityEnabled == 1;
        } catch (Settings.SettingNotFoundException e) {
            return false;
        }
    }

    private void openAccessibilitySettings(MethodChannel.Result result) {
        try {
            Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if (activity != null) {
                activity.startActivity(intent);
            } else if (context != null) {
                context.startActivity(intent);
            }
            result.success(true);
        } catch (Exception e) {
            result.success(false);
        }
    }

    private void getCurrentPackage(MethodChannel.Result result) {
        result.success(ScamShieldAccessibilityService.currentPackage);
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private void setupVirtualDisplay() {
        if (activity == null || mediaProjection == null) return;

        DisplayMetrics metrics = new DisplayMetrics();
        activity.getWindowManager().getDefaultDisplay().getMetrics(metrics);

        imageReader = ImageReader.newInstance(
                metrics.widthPixels,
                metrics.heightPixels,
                PixelFormat.RGBA_8888,
                1
        );

        virtualDisplay = mediaProjection.createVirtualDisplay(
                "ScreenCapture",
                metrics.widthPixels,
                metrics.heightPixels,
                metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader.getSurface(),
                null,
                null
        );
    }

    private void cleanup() {
        if (virtualDisplay != null) {
            virtualDisplay.release();
            virtualDisplay = null;
        }
        if (imageReader != null) {
            imageReader.close();
            imageReader = null;
        }
        if (mediaProjection != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                mediaProjection.stop();
            }
            mediaProjection = null;
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (requestCode == MEDIA_PROJECTION_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                this.resultCode = resultCode;
                this.resultData = data;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && mediaProjectionManager != null) {
                    mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data);
                }
                if (pendingResult != null) {
                    pendingResult.success(true);
                }
            } else {
                if (pendingResult != null) {
                    pendingResult.success(false);
                }
            }
            pendingResult = null;
            return true;
        }
        return false;
    }
}
