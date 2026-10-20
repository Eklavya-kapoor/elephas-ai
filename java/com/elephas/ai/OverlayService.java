package com.elephas.ai;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.widget.ImageView;

import androidx.core.app.NotificationCompat;

import java.util.HashMap;
import java.util.Map;

public class OverlayService extends Service {

    private static final String TAG = "OverlayService";
    private static final int NOTIFICATION_ID = 1001;
    private static final String NOTIFICATION_CHANNEL_ID = "scamshield_overlay_channel";
    private static final long OVERLAY_DISPLAY_DURATION = 10000L; // 10 seconds display time

    private WindowManager windowManager;
    private View overlayView = null;
    private boolean isOverlayShowing = false;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private Runnable hideOverlayRunnable = null;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "OverlayService onCreate");
        windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
        startForeground();
    }

    private void startForeground() {
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && notificationManager != null) {
            NotificationChannel channel = new NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Elephas AI Overlay Service",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Required for showing scam alerts");
            channel.enableLights(true);
            channel.setLightColor(Color.RED);
            notificationManager.createNotificationChannel(channel);
        }

        Notification notification = new NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("Elephas AI Protection Active")
                .setContentText("Monitoring for scams")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build();

        // For Android 14+ (API 34+), use proper foreground service type
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.getAction() != null) {
            Log.d(TAG, "OverlayService onStartCommand: " + intent.getAction());
            switch (intent.getAction()) {
                case "showOverlay": {
                    String alertType = intent.getStringExtra("alertType");
                    if (alertType == null) alertType = "scam";
                    showOverlay(alertType);
                    break;
                }
                case "hideOverlay":
                    hideOverlay();
                    break;
            }
        }
        return START_STICKY;
    }

    @SuppressWarnings("deprecation")
    private void showOverlay(String alertType) {
        if (isOverlayShowing) {
            hideOverlay();
        }

        LayoutInflater inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        overlayView = inflater.inflate(R.layout.overlay_alert, null);

        int windowType = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                windowType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        params.y = 16; // Small padding from top of screen

        try {
            if (overlayView != null && windowManager != null) {
                ImageView alertImage = overlayView.findViewById(R.id.alertImage);
                int imageResId = "url".equals(alertType) ? R.drawable.url_warning : R.drawable.scam_alert;
                alertImage.setImageResource(imageResId);
                windowManager.addView(overlayView, params);
                isOverlayShowing = true;

                // Schedule hiding the overlay
                hideOverlayRunnable = this::hideOverlay;
                handler.postDelayed(hideOverlayRunnable, OVERLAY_DISPLAY_DURATION);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error showing overlay: " + e.getMessage(), e);
        }
    }

    private void hideOverlay() {
        handler.post(() -> {
            if (overlayView != null && isOverlayShowing && windowManager != null) {
                try {
                    windowManager.removeView(overlayView);
                    overlayView = null;
                    isOverlayShowing = false;

                    // Notify Flutter that overlay is hidden
                    if (MethodChannelManager.overlayMethodChannel != null) {
                        Map<String, Object> map = new HashMap<>();
                        map.put("success", true);
                        MethodChannelManager.overlayMethodChannel.invokeMethod("onOverlayHidden", map);
                    }

                    Log.d(TAG, "Overlay hidden");
                } catch (Exception e) {
                    Log.e(TAG, "Error hiding overlay: " + e.getMessage(), e);
                }
            }
        });
    }

    @Override
    public void onDestroy() {
        hideOverlay();
        Log.d(TAG, "OverlayService destroyed");
        super.onDestroy();
    }
}
