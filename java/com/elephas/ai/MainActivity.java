package com.elephas.ai;

import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.view.accessibility.AccessibilityManager;

import androidx.annotation.NonNull;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

/**
 * Entry point of the Android side of the app.
 * Flutter (Dart) handles the UI and scam-detection logic; this class is the
 * "bridge" that connects Dart to native Android features using MethodChannels.
 */
public class MainActivity extends FlutterActivity {

    private static final String TAG = "MainActivity";

    // ---- MethodChannel names (must match the names used on the Dart side) ----
    private static final String APP_CONTROL_CHANNEL = "elephas_ai/app_control";
    private static final String OVERLAY_CHANNEL = "elephas_ai/overlay";
    private static final String SCREEN_MONITOR_CHANNEL = "elephas_ai/screen_monitor";
    private static final String OCR_CHANNEL = "elephas_ai/ocr";
    private static final String ACCESSIBILITY_CHANNEL = "com.example.scamshield_flutter_app/accessibility";
    private static final String CALL_MONITOR_CHANNEL = "elephas_ai/call_monitor";
    private static final String SPEECH_RECOGNITION_CHANNEL = "elephas_ai/speech_recognition";
    private static final String CALL_CONTROL_CHANNEL = "elephas_ai/call_control";
    private static final String PERMISSIONS_CHANNEL = "com.example.scamshield_flutter_app/permissions";
    private static final String SMS_CHANNEL = "elephas_ai/sms";

    // ---- Broadcast actions sent by our AccessibilityService ----
    private static final String ACTION_SCREEN_CONTENT = "com.example.scamshield_flutter_app.SCREEN_CONTENT";
    private static final String ACTION_APP_CHANGED = "com.example.scamshield_flutter_app.APP_CHANGED";

    // Caller-ID / call-screen apps are skipped because they cause false positives
    private static final List<String> IGNORED_APPS = Arrays.asList(
            "com.truecaller",
            "com.samsung.android.incallui",
            "com.android.incallui"
    );

    private CallMonitorPlugin callMonitorPlugin;
    private CallAudioProcessor callAudioProcessor;

    /**
     * Receives screen text captured by the AccessibilityService and forwards it
     * to Flutter, where the scam-detection model analyses it.
     */
    private final BroadcastReceiver accessibilityBroadcastReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent == null || intent.getAction() == null) return;

            String packageName = intent.getStringExtra("packageName");
            if (packageName == null) packageName = "";

            // FILTER: skip Truecaller and call UI apps
            if (IGNORED_APPS.contains(packageName)) {
                Log.d(TAG, "SKIPPED: " + packageName + " (caller ID only, not messaging)");
                return;
            }

            MethodChannel screenChannel = MethodChannelManager.screenMonitorMethodChannel;

            switch (intent.getAction()) {
                case ACTION_SCREEN_CONTENT: {
                    String content = intent.getStringExtra("content");
                    if (content == null) content = "";
                    long timestamp = intent.getLongExtra("timestamp", 0L);

                    Log.d(TAG, "BROADCAST RECEIVED: Screen content from " + packageName);
                    Log.d(TAG, "Content length: " + content.length() + " chars");
                    Log.d(TAG, "Content preview: " + content.substring(0, Math.min(100, content.length())) + "...");

                    if (screenChannel != null) {
                        Map<String, Object> args = new HashMap<>();
                        args.put("content", content);
                        args.put("packageName", packageName);
                        args.put("timestamp", timestamp);
                        screenChannel.invokeMethod("onScreenContent", args);
                    }
                    Log.d(TAG, "Content forwarded to Flutter via MethodChannel");
                    break;
                }
                case ACTION_APP_CHANGED: {
                    Log.d(TAG, "BROADCAST RECEIVED: App change to " + packageName);

                    if (screenChannel != null) {
                        Map<String, Object> args = new HashMap<>();
                        args.put("packageName", packageName);
                        screenChannel.invokeMethod("onAppChanged", args);
                    }
                    break;
                }
            }
        }
    };

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();

        // 1. Create shared method channels (used by other native classes to talk to Dart)
        MethodChannelManager.overlayMethodChannel = new MethodChannel(messenger, OVERLAY_CHANNEL);
        MethodChannelManager.screenMonitorMethodChannel = new MethodChannel(messenger, SCREEN_MONITOR_CHANNEL);
        MethodChannelManager.ocrMethodChannel = new MethodChannel(messenger, OCR_CHANNEL);
        MethodChannelManager.callMonitorChannel = new MethodChannel(messenger, CALL_MONITOR_CHANNEL);
        MethodChannelManager.speechRecognitionChannel = new MethodChannel(messenger, SPEECH_RECOGNITION_CHANNEL);
        MethodChannelManager.callControlChannel = new MethodChannel(messenger, CALL_CONTROL_CHANNEL);

        // 2. Register native plugins
        try {
            flutterEngine.getPlugins().add(new ScreenMonitorPlugin());
            flutterEngine.getPlugins().add(new OcrPlugin());
            flutterEngine.getPlugins().add(new OverlayPlugin());

            // Live call monitoring
            callMonitorPlugin = new CallMonitorPlugin(this);
            callAudioProcessor = new CallAudioProcessor(this);

            MethodChannelManager.callMonitorChannel.setMethodCallHandler(callMonitorPlugin);
            MethodChannelManager.speechRecognitionChannel.setMethodCallHandler(callAudioProcessor);
            MethodChannelManager.callControlChannel.setMethodCallHandler(callAudioProcessor);

            Log.d(TAG, "LIVE CALL: All plugins initialized successfully");
        } catch (Exception e) {
            Log.e(TAG, "Error registering plugins", e);
        }

        // 3. Channels handled directly in this activity
        setupAccessibilityChannel(messenger);
        setupAppControlChannel(messenger);
        setupPermissionsChannel(messenger);
        setupSmsChannel(messenger);

        // 4. Listen for screen text from the AccessibilityService
        registerAccessibilityReceiver();
    }

    private void setupAccessibilityChannel(BinaryMessenger messenger) {
        new MethodChannel(messenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "isAccessibilityEnabled":
                    result.success(isAccessibilityServiceEnabled());
                    break;
                case "openAccessibilitySettings":
                    openSettings(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), false,
                            result, "Could not open accessibility settings");
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    private void setupAppControlChannel(BinaryMessenger messenger) {
        new MethodChannel(messenger, APP_CONTROL_CHANNEL).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "startBackgroundMonitoringService": {
                    Intent serviceIntent = new Intent(this, BackgroundMonitorService.class);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent);
                    } else {
                        startService(serviceIntent);
                    }
                    result.success(true);
                    break;
                }
                case "stopBackgroundMonitoringService": {
                    stopService(new Intent(this, BackgroundMonitorService.class));
                    result.success(true);
                    break;
                }
                case "openAccessibilitySettings":
                    openSettings(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), false,
                            result, "Could not open accessibility settings");
                    break;
                case "openDrawOverlaysSettings":
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        openSettings(overlaySettingsIntent(), false, result, "Could not open overlay settings");
                    } else {
                        result.success(true);
                    }
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    private void setupPermissionsChannel(BinaryMessenger messenger) {
        new MethodChannel(messenger, PERMISSIONS_CHANNEL).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "checkAccessibilityPermission":
                    result.success(isAccessibilityServiceEnabled());
                    break;

                case "checkSystemAlertWindowPermission":
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(MainActivity.this));
                    } else {
                        result.success(true);
                    }
                    break;

                case "requestAccessibilityPermission":
                    openSettings(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), true,
                            result, "Could not open accessibility settings");
                    break;

                case "requestSystemAlertWindowPermission":
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        openSettings(overlaySettingsIntent(), true, result, "Could not open overlay settings");
                    } else {
                        result.success(true);
                    }
                    break;

                case "requestStoragePermission":
                case "requestPhonePermission":
                case "requestSmsPermission":
                case "requestContactsPermission":
                case "requestCameraPermission":
                case "requestMicrophonePermission":
                    openSettings(appDetailsSettingsIntent(), true, result, "Could not open app settings");
                    break;

                case "openAccessibilitySettings":
                    openSettings(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), false,
                            result, "Could not open accessibility settings");
                    break;

                case "openSystemAlertWindowSettings":
                    openSettings(overlaySettingsIntent(), false, result, "Could not open overlay settings");
                    break;

                default:
                    result.notImplemented();
            }
        });
    }

    private void setupSmsChannel(BinaryMessenger messenger) {
        new MethodChannel(messenger, SMS_CHANNEL).setMethodCallHandler((call, result) -> {
            if (!"getMessageCount".equals(call.method)) {
                result.notImplemented();
                return;
            }

            Map<String, Object> response = new HashMap<>();
            try {
                String phoneNumber = call.argument("phoneNumber");
                if (phoneNumber == null || phoneNumber.isEmpty()) {
                    response.put("count", 0);
                    response.put("success", false);
                    result.success(response);
                    return;
                }

                // Keep only digits and '+'
                String normalizedNumber = phoneNumber.replaceAll("[^0-9+]", "");

                // Query the SMS content provider
                Cursor cursor = getContentResolver().query(
                        Uri.parse("content://sms"),
                        new String[]{"address", "body"},
                        "address LIKE ?",
                        new String[]{"%" + normalizedNumber + "%"},
                        null
                );

                int count = 0;
                if (cursor != null) {
                    count = cursor.getCount();
                    cursor.close();
                }

                response.put("count", count);
                response.put("success", true);
                result.success(response);
            } catch (Exception e) {
                Log.e(TAG, "Error getting SMS count: " + e.getMessage());
                response.put("count", 0);
                response.put("success", false);
                result.success(response);
            }
        });
    }

    private void registerAccessibilityReceiver() {
        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_SCREEN_CONTENT);
        filter.addAction(ACTION_APP_CHANGED);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(accessibilityBroadcastReceiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            registerReceiver(accessibilityBroadcastReceiver, filter);
        }
        Log.d(TAG, "Broadcast receiver registered for accessibility service");
    }

    private void openSettings(Intent intent, boolean newTask, MethodChannel.Result result, String errorMessage) {
        try {
            if (newTask) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, errorMessage + ": " + e.getMessage());
            result.error("SETTINGS_ERROR", errorMessage, null);
        }
    }

    private Intent overlaySettingsIntent() {
        return new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + getPackageName()));
    }

    private Intent appDetailsSettingsIntent() {
        Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
        intent.setData(Uri.parse("package:" + getPackageName()));
        return intent;
    }

    private boolean isAccessibilityServiceEnabled() {
        AccessibilityManager am = (AccessibilityManager) getSystemService(Context.ACCESSIBILITY_SERVICE);
        if (am == null) return false;
        List<AccessibilityServiceInfo> enabledServices =
                am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK);
        for (AccessibilityServiceInfo info : enabledServices) {
            if (info.getId() != null && info.getId().contains(getPackageName())) return true;
        }
        return false;
    }

    @Override
    protected void onResume() {
        super.onResume();
    }

    @Override
    protected void onDestroy() {
        try {
            unregisterReceiver(accessibilityBroadcastReceiver);
            Log.d(TAG, "Broadcast receiver unregistered");
        } catch (Exception e) {
            Log.e(TAG, "Error unregistering broadcast receiver: " + e.getMessage());
        }
        super.onDestroy();
    }
}
