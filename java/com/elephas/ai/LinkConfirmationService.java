package com.elephas.ai;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.widget.TextView;

import java.util.Arrays;
import java.util.List;

/**
 * Apple-style Link Confirmation Service
 *
 * Shows a minimal, elegant confirmation dialog when user clicks a suspicious link.
 * Instead of blocking with scary alerts, we gently ask "Open this link?"
 */
public class LinkConfirmationService extends Service {

    private static final String TAG = "LinkConfirmation";

    // Suspicious URL patterns that trigger confirmation
    public static final List<String> SUSPICIOUS_PATTERNS = Arrays.asList(
            "bit.ly", "tinyurl", "goo.gl", "t.co", "ow.ly",
            "is.gd", "buff.ly", "adf.ly", "cutt.ly", "short.gy",
            "rb.gy", "clck.ru", "shorte.st", "bc.vc"
    );

    // Typosquatting patterns for banks
    public static final List<String> TYPOSQUAT_PATTERNS = Arrays.asList(
            "hdfc-", "icici-", "sbi-", "axis-", "kotak-",
            "hdfcbank", "icic1bank", "sb1.in",
            "-verify", "-update", "-kyc", "-secure"
    );

    private WindowManager windowManager;
    private View overlayView = null;
    private View dimBackground = null;
    private boolean isShowing = false;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private String pendingUrl = null;

    public static boolean isSuspiciousUrl(String url) {
        if (url == null) return false;
        String lowerUrl = url.toLowerCase();

        // Check for URL shorteners
        for (String pattern : SUSPICIOUS_PATTERNS) {
            if (lowerUrl.contains(pattern)) return true;
        }

        // Check for typosquatting
        for (String pattern : TYPOSQUAT_PATTERNS) {
            if (lowerUrl.contains(pattern)) return true;
        }

        // Check for suspicious TLDs
        List<String> suspiciousTlds = Arrays.asList(".xyz", ".top", ".club", ".work", ".click", ".link");
        for (String tld : suspiciousTlds) {
            if (lowerUrl.endsWith(tld)) return true;
        }

        return false;
    }

    public static String extractDomain(String url) {
        if (url == null) return "";
        try {
            Uri uri = Uri.parse(url);
            String host = uri.getHost();
            return host != null ? host : (url.length() > 50 ? url.substring(0, 50) : url);
        } catch (Exception e) {
            return url.length() > 50 ? url.substring(0, 50) : url;
        }
    }

    public static String getWarningMessage(String url) {
        if (url == null) return "This link could not be verified as safe.";
        String lowerUrl = url.toLowerCase();

        for (String pattern : SUSPICIOUS_PATTERNS) {
            if (lowerUrl.contains(pattern)) {
                return "This link uses a URL shortener. The actual destination is hidden.";
            }
        }
        for (String pattern : TYPOSQUAT_PATTERNS) {
            if (lowerUrl.contains(pattern)) {
                return "This link may be impersonating a bank website.";
            }
        }
        return "This link could not be verified as safe.";
    }

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "LinkConfirmationService created");
        windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.getAction() != null) {
            switch (intent.getAction()) {
                case "showConfirmation": {
                    String url = intent.getStringExtra("url");
                    if (url != null && !url.isEmpty()) {
                        showConfirmation(url);
                    }
                    break;
                }
                case "hideConfirmation":
                    hideConfirmation();
                    break;
            }
        }
        return START_NOT_STICKY;
    }

    @SuppressWarnings("deprecation")
    private void showConfirmation(String url) {
        if (isShowing) {
            hideConfirmation();
        }

        pendingUrl = url;

        handler.post(() -> {
            try {
                if (windowManager == null) return;

                // Create dim background
                dimBackground = new View(this);
                dimBackground.setBackgroundColor(Color.parseColor("#80000000"));
                dimBackground.setOnClickListener(v -> hideConfirmation());

                int windowType = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                        ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        : WindowManager.LayoutParams.TYPE_PHONE;

                WindowManager.LayoutParams dimParams = new WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT,
                        windowType,
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                        PixelFormat.TRANSLUCENT
                );

                windowManager.addView(dimBackground, dimParams);

                // Inflate the confirmation dialog
                LayoutInflater inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                overlayView = inflater.inflate(R.layout.link_confirmation_overlay, null);

                TextView domainText = overlayView.findViewById(R.id.domainText);
                TextView warningText = overlayView.findViewById(R.id.warningText);
                TextView cancelButton = overlayView.findViewById(R.id.cancelButton);
                TextView continueButton = overlayView.findViewById(R.id.continueButton);

                if (domainText != null) domainText.setText(extractDomain(url));
                if (warningText != null) warningText.setText(getWarningMessage(url));

                if (cancelButton != null) {
                    cancelButton.setOnClickListener(v -> {
                        Log.d(TAG, "User cancelled link: " + url);
                        hideConfirmation();
                    });
                }

                if (continueButton != null) {
                    continueButton.setOnClickListener(v -> {
                        Log.d(TAG, "User continued to link: " + url);
                        hideConfirmation();
                        openUrl(url);
                    });
                }

                WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        windowType,
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                                | WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                        PixelFormat.TRANSLUCENT
                );
                params.gravity = Gravity.CENTER;

                windowManager.addView(overlayView, params);
                isShowing = true;
                Log.d(TAG, "Showing link confirmation for: " + url);

            } catch (Exception e) {
                Log.e(TAG, "Error showing confirmation: " + e.getMessage(), e);
            }
        });
    }

    private void hideConfirmation() {
        handler.post(() -> {
            try {
                if (dimBackground != null && windowManager != null) {
                    windowManager.removeView(dimBackground);
                    dimBackground = null;
                }
                if (overlayView != null && windowManager != null) {
                    windowManager.removeView(overlayView);
                    overlayView = null;
                }
                isShowing = false;
                pendingUrl = null;
            } catch (Exception e) {
                Log.e(TAG, "Error hiding confirmation: " + e.getMessage(), e);
            }
        });
    }

    private void openUrl(String url) {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (Exception e) {
            Log.e(TAG, "Error opening URL: " + e.getMessage(), e);
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        hideConfirmation();
    }
}
