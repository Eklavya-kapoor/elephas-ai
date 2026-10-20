package com.elephas.ai;

import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Arrays;
import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Draws the scam-alert banner ON TOP of other apps (WhatsApp, Telegram, etc.)
 * using WindowManager + the "Display over other apps" (SYSTEM_ALERT_WINDOW) permission.
 * Flutter calls methods like "showOverlay" on the "elephas_ai/overlay" channel.
 */
@SuppressWarnings("deprecation") // TYPE_PHONE is only used on Android < 8
public class OverlayPlugin implements FlutterPlugin, ActivityAware,
        MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    private static final String TAG = "OverlayPlugin";
    private static final String CHANNEL = "elephas_ai/overlay";
    private static final int OVERLAY_PERMISSION_REQUEST_CODE = 1004;

    private MethodChannel channel;
    private Context context;
    private ActivityPluginBinding activity;
    private WindowManager windowManager;
    private View overlayView;

    // Result waiting for the user to come back from the permission screen
    private MethodChannel.Result pendingResult;

    // ------------------------------------------------------------------------
    // FlutterPlugin lifecycle
    // ------------------------------------------------------------------------
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        context = binding.getApplicationContext();
        windowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
        }
        removeOverlay(); // remove before clearing windowManager
        context = null;
        windowManager = null;
    }

    // ------------------------------------------------------------------------
    // ActivityAware lifecycle (needed for startActivityForResult)
    // ------------------------------------------------------------------------
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding;
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        if (activity != null) activity.removeActivityResultListener(this);
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding;
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        if (activity != null) activity.removeActivityResultListener(this);
        activity = null;
    }

    // ------------------------------------------------------------------------
    // Calls coming from Flutter
    // ------------------------------------------------------------------------
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Log.d(TAG, "Received method call: " + call.method);
        Log.d(TAG, "Arguments: " + call.arguments);

        switch (call.method) {
            case "requestOverlayPermission":
                requestOverlayPermission(result);
                break;

            case "hasOverlayPermission":
                result.success(hasOverlayPermission());
                break;

            case "showOverlay": {
                String alertType = call.argument("alertType");
                if (alertType == null) alertType = "scam";
                Log.d(TAG, "Showing overlay alert of type: " + alertType);
                showImageOverlay(alertType);
                result.success(true);
                break;
            }

            case "hideOverlay":
                removeOverlay();
                result.success(true);
                break;

            case "showScamAlert": {
                String packageName = call.argument("packageName");
                if (packageName == null) packageName = "unknown";
                Log.d(TAG, "showScamAlert is DISABLED - use showOverlay instead for package: " + packageName);
                result.success(null);
                break;
            }

            case "showMinimalScamAlert": {
                String appName = call.argument("appName");
                if (appName == null) appName = "Unknown App";
                Log.d(TAG, "Showing minimal scam alert for app: " + appName);
                showMinimalScamAlert(appName);
                result.success(null);
                break;
            }

            case "showCustomImageAlert": {
                String appName = call.argument("appName");
                if (appName == null) appName = "Unknown App";
                String packageName = call.argument("packageName");
                if (packageName == null) packageName = appName;
                String message = call.argument("message");
                if (message == null) message = "SCAM DETECTED!";

                Log.d(TAG, "Showing custom image alert for app: " + appName + ", package: " + packageName);

                // Don't show alerts over system apps / launchers / our own app
                if (shouldSkipPackage(packageName)) {
                    Log.d(TAG, "Skipping overlay for excluded package: " + packageName);
                    result.success(null);
                    return;
                }

                showCustomImageAlert(appName, message);
                result.success(null);
                break;
            }

            case "hideScamAlert":
                Log.d(TAG, "Hiding scam alert");
                hideScamAlert();
                result.success(null);
                break;

            default:
                Log.d(TAG, "Method not implemented: " + call.method);
                result.notImplemented();
        }
    }

    // ------------------------------------------------------------------------
    // Permission handling
    // ------------------------------------------------------------------------
    private void requestOverlayPermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(context)) {
                Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + (context != null ? context.getPackageName() : "")));
                if (activity != null) {
                    activity.getActivity().startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE);
                }
                pendingResult = result; // answered later in onActivityResult
            } else {
                result.success(true);
            }
        } else {
            result.success(true); // Not needed below Android 6
        }
    }

    private boolean hasOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return context != null && Settings.canDrawOverlays(context);
        }
        return true;
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            if (pendingResult != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    pendingResult.success(context != null && Settings.canDrawOverlays(context));
                } else {
                    pendingResult.success(true);
                }
                pendingResult = null;
            }
            return true;
        }
        return false;
    }

    // ------------------------------------------------------------------------
    // Overlay window type helper
    // ------------------------------------------------------------------------
    private int overlayWindowType() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;
    }

    // ------------------------------------------------------------------------
    // 1. Minimal banner: slides down from top, auto-hides after 4 s
    // ------------------------------------------------------------------------
    private void showMinimalScamAlert(String appName) {
        Log.d(TAG, "showMinimalScamAlert called for " + appName);

        if (!hasOverlayPermission() || context == null || windowManager == null) {
            Log.e(TAG, "Cannot show overlay: Permission not granted or null context.");
            return;
        }

        try {
            removeOverlay();

            overlayView = LayoutInflater.from(context).inflate(R.layout.minimal_scam_overlay, null);

            TextView brandName = overlayView.findViewById(R.id.brandName);
            TextView warningText = overlayView.findViewById(R.id.warningText);
            TextView dismissButton = overlayView.findViewById(R.id.dismissButton);
            ImageView logo = overlayView.findViewById(R.id.elephasLogo);

            if (brandName != null) brandName.setText("ELEPHAS AI");
            if (warningText != null) warningText.setText("⚠ Scam detected in " + appName);
            if (dismissButton != null) {
                dismissButton.setOnClickListener(v -> hideScamAlertWithAnimation());
            }

            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    overlayWindowType(),
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                            | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                    PixelFormat.TRANSLUCENT
            );
            params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
            params.y = 0;

            windowManager.addView(overlayView, params);

            // Slide-down animation
            View view = overlayView;
            view.setTranslationY(-view.getHeight());
            view.setAlpha(0f);
            view.animate()
                    .translationY(0f)
                    .alpha(1f)
                    .setDuration(400)
                    .setInterpolator(new DecelerateInterpolator())
                    .start();

            // Auto-hide after 4 seconds
            view.postDelayed(this::hideScamAlertWithAnimation, 4000);
        } catch (Exception e) {
            Log.e(TAG, "Error showing minimal scam alert overlay: " + e, e);
        }
    }

    // ------------------------------------------------------------------------
    // 2. Detailed alert (currently DISABLED from Flutter, kept for reference)
    // ------------------------------------------------------------------------
    private void showScamAlert(String message, String sender, String riskLevel,
                               Double x, Double y, Double width, Double height,
                               Double confidence, String scamReason) {
        Log.d(TAG, "showScamAlert called");

        if (!hasOverlayPermission() || context == null || windowManager == null) {
            Log.e(TAG, "Cannot show overlay: Permission not granted.");
            return;
        }

        try {
            removeOverlay();

            overlayView = LayoutInflater.from(context).inflate(R.layout.custom_image_overlay, null);

            TextView tvMessage = overlayView.findViewById(R.id.messageText);
            TextView tvAppName = overlayView.findViewById(R.id.appName);
            TextView tvRiskLevel = overlayView.findViewById(R.id.riskLevel);
            TextView tvConfidence = overlayView.findViewById(R.id.confidenceScore);
            TextView tvAlertTitle = overlayView.findViewById(R.id.alertTitle);
            TextView tvAlertIcon = overlayView.findViewById(R.id.alertIcon);
            Button dismissButton = overlayView.findViewById(R.id.dismissButton);
            Button blockButton = overlayView.findViewById(R.id.blockButton);

            if (tvMessage != null) tvMessage.setText(message);
            if (tvAppName != null) tvAppName.setText(sender);
            if (tvRiskLevel != null) tvRiskLevel.setText("⚠ " + riskLevel + " RISK - DO NOT CLICK LINKS");
            if (tvConfidence != null) {
                tvConfidence.setText(confidence != null ? confidence.intValue() + "%" : "95%");
            }
            if (tvAlertTitle != null) tvAlertTitle.setText(scamReason != null ? scamReason : "SCAM DETECTED");
            if (tvAlertIcon != null) tvAlertIcon.setText("[emoji]");

            if (dismissButton != null) dismissButton.setOnClickListener(v -> hideScamAlert());
            if (blockButton != null) blockButton.setOnClickListener(v -> hideScamAlert());

            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    (width != null && width > 0) ? width.intValue() : WindowManager.LayoutParams.MATCH_PARENT,
                    (height != null && height > 0) ? height.intValue() : WindowManager.LayoutParams.WRAP_CONTENT,
                    overlayWindowType(),
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                            | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                            | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                            | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                            | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
                    PixelFormat.TRANSLUCENT
            );
            params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
            params.x = (x != null) ? x.intValue() : 0;
            params.y = (y != null) ? y.intValue() : 32;

            windowManager.addView(overlayView, params);
            Log.d(TAG, "Enhanced scam alert overlay shown successfully!");

            overlayView.postDelayed(this::hideScamAlert, 10000);
        } catch (Exception e) {
            Log.e(TAG, "Error showing scam alert overlay: " + e, e);
        }
    }

    // ------------------------------------------------------------------------
    // 3. Custom image alert: only an image, tap to dismiss, auto-hides after 5 s
    // ------------------------------------------------------------------------
    private void showCustomImageAlert(String appName, String message) {
        Log.d(TAG, "showCustomImageAlert called for " + appName);

        if (!hasOverlayPermission() || context == null || windowManager == null) {
            Log.e(TAG, "Cannot show custom image overlay: Permission not granted.");
            return;
        }

        try {
            removeOverlay();

            overlayView = LayoutInflater.from(context).inflate(R.layout.custom_image_overlay, null);

            ImageView customImage = overlayView.findViewById(R.id.customOverlayImage);
            Log.d(TAG, "Custom image view found: " + (customImage != null));

            // Tap anywhere on the overlay to dismiss
            overlayView.setOnClickListener(v -> {
                Log.d(TAG, "Custom image overlay clicked - hiding");
                hideScamAlert();
            });

            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    overlayWindowType(),
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                            | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                            | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                            | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                            | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
                    PixelFormat.RGBA_8888 // supports full transparency
            );
            params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
            params.x = 0;
            params.y = 50; // small margin below status bar

            windowManager.addView(overlayView, params);
            Log.d(TAG, "Custom image overlay shown successfully!");

            overlayView.postDelayed(() -> {
                Log.d(TAG, "Auto-hiding overlay after timeout");
                hideScamAlert();
            }, 5000);
        } catch (Exception e) {
            Log.e(TAG, "Error showing custom image overlay: " + e, e);
        }
    }

    // ------------------------------------------------------------------------
    // 4. Image overlay used by "showOverlay" (scam / url warning), auto-hides after 3 s
    // ------------------------------------------------------------------------
    private void showImageOverlay(String alertType) {
        if (!hasOverlayPermission() || context == null || windowManager == null) {
            Log.e(TAG, "Cannot show overlay: Permission not granted");
            return;
        }

        try {
            removeOverlay();

            overlayView = LayoutInflater.from(context).inflate(R.layout.overlay_alert, null);

            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT, // full width
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    overlayWindowType(),
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                    PixelFormat.TRANSLUCENT
            );
            params.gravity = Gravity.TOP;
            params.y = 0;

            View view = overlayView;
            ImageView alertImage = view.findViewById(R.id.alertImage);
            int imageResId = "url".equals(alertType) ? R.drawable.url_warning : R.drawable.scam_alert;
            alertImage.setImageResource(imageResId);

            windowManager.addView(view, params);

            view.postDelayed(this::removeOverlay, 3000);

            Log.d(TAG, "Successfully showed " + alertType + " overlay");
        } catch (Exception e) {
            Log.e(TAG, "Error showing overlay: " + e.getMessage(), e);
        }
    }

    // ------------------------------------------------------------------------
    // Hiding / removing
    // ------------------------------------------------------------------------
    private void hideScamAlertWithAnimation() {
        Log.d(TAG, "hideScamAlertWithAnimation called");
        try {
            if (overlayView != null) {
                overlayView.animate()
                        .translationY(-overlayView.getHeight())
                        .alpha(0f)
                        .setDuration(300)
                        .setInterpolator(new AccelerateInterpolator())
                        .withEndAction(() -> {
                            removeOverlay();
                            Log.d(TAG, "Scam alert hidden with animation!");
                        })
                        .start();
            } else {
                removeOverlay();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error hiding overlay with animation: " + e, e);
            removeOverlay();
        }
    }

    private void hideScamAlert() {
        Log.d(TAG, "hideScamAlert called");
        try {
            removeOverlay();
            Log.d(TAG, "Scam alert overlay hidden successfully.");
        } catch (Exception e) {
            Log.e(TAG, "Error hiding overlay: " + e, e);
        }
    }

    private void removeOverlay() {
        try {
            if (overlayView != null && windowManager != null) {
                windowManager.removeView(overlayView);
            }
            overlayView = null;
        } catch (Exception e) {
            Log.e(TAG, "Error removing overlay: " + e.getMessage(), e);
        }
    }

    // ------------------------------------------------------------------------
    // Packages where we never show an alert
    // ------------------------------------------------------------------------
    private static final List<String> EXCLUDED_PACKAGES = Arrays.asList(
            "com.example.scamshield_flutter_app",        // Our own app
            "com.example.scamshield_flutter_app.debug",  // Our debug version
            "com.elephas.ai",                            // Elephas package
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
            "com.google.android.googlequicksearchbox"   // Google search/launcher
    );

    private boolean shouldSkipPackage(String packageName) {
        if (packageName == null) return true;
        boolean shouldSkip = EXCLUDED_PACKAGES.contains(packageName)
                || packageName.startsWith("com.android.")
                || packageName.startsWith("android.")
                || packageName.contains("launcher")
                || packageName.contains("systemui")
                || packageName.contains("scamshield")
                || packageName.contains("elephas");

        if (shouldSkip) {
            Log.d(TAG, "Package filtered: " + packageName);
        }
        return shouldSkip;
    }
}
