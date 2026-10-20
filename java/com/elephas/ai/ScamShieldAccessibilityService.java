package com.elephas.ai;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;

import io.flutter.plugin.common.MethodChannel;

public class ScamShieldAccessibilityService extends AccessibilityService {

    private static final String TAG = "ElephASAccessibility";
    public static ScamShieldAccessibilityService instance = null;
    public static String currentPackage = null;
    private static String currentScreenId = null;
    public static MethodChannel flutterChannel = null;

    private final ScheduledExecutorService textExtractionExecutor = Executors.newSingleThreadScheduledExecutor();
    private String lastExtractedText = "";
    private static final int MIN_TEXT_LENGTH = 5;

    // FOCUSED: only the highest-scale scam vectors in India - WhatsApp, Telegram, SMS.
    private static final Set<String> TARGETED_SCAM_APPS = new HashSet<>(Arrays.asList(
            "com.whatsapp",
            "org.telegram.messenger",
            "com.android.mms",
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.messaging"
    ));

    private static final List<String> EXCLUDED_PACKAGES = Arrays.asList(
            "com.example.scamshield_flutter_app",
            "com.example.scamshield_flutter_app.debug",
            "com.elephas.ai",
            "android",
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.android.settings",
            "com.mi.android.globallauncher",
            "com.miui.home",
            "com.huawei.android.launcher",
            "com.samsung.android.app.launcher",
            "com.oppo.launcher",
            "com.oneplus.launcher",
            "com.lge.launcher2",
            "com.sony.android.launcher",
            "com.android.permissioncontroller",
            "com.android.packageinstaller",
            "com.google.android.googlequicksearchbox",
            "com.truecaller",
            "com.samsung.android.incallui",
            "com.android.incallui"
    );

    private static final List<Pattern> UI_PATTERNS = Arrays.asList(
            Pattern.compile("^[0-9]{1,2}:[0-9]{2}\\s?(AM|PM)?$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(Today|Yesterday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday).*", Pattern.CASE_INSENSITIVE),
            Pattern.compile(".*(online|last seen|typing\\.\\.\\.|recording\\.\\.\\.).*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Business Account$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Business info$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^More business info$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Typically replies within.*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Working hours:.*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Address:.*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Email:.*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Website:.*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Description:.*", Pattern.CASE_INSENSITIVE),
            Pattern.compile(".*(Block|Report|Add to contacts|Delete chat).*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(Message|Search)$", Pattern.CASE_INSENSITIVE),
            Pattern.compile(".*(end-to-end encrypted).*", Pattern.CASE_INSENSITIVE),
            Pattern.compile(".*(won't see if you read).*", Pattern.CASE_INSENSITIVE),
            Pattern.compile(".*(add them as a contact).*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(delivered|sent|read)$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Messages and calls are.*", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^More options$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Menu$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Attach$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Gallery$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^Camera$", Pattern.CASE_INSENSITIVE)
    );

    private void sendContentToFlutter(String content, String packageName) {
        if (shouldSkipPackage(packageName)) {
            Log.d(TAG, "SKIPPED package: " + packageName + " (filtered)");
            return;
        }

        try {
            Log.d(TAG, "SENDING TO FLUTTER: Package=" + packageName);
            Log.d(TAG, "CONTENT LENGTH: " + content.length() + " characters");
            Log.d(TAG, "CONTENT PREVIEW: " + content.substring(0, Math.min(100, content.length())) + "...");

            Intent intent = new Intent("com.example.scamshield_flutter_app.SCREEN_CONTENT");
            intent.putExtra("content", content);
            intent.putExtra("packageName", packageName);
            intent.putExtra("timestamp", System.currentTimeMillis());
            sendBroadcast(intent);

            Log.d(TAG, "Content sent to Flutter via broadcast successfully!");
        } catch (Exception e) {
            Log.e(TAG, "Failed to send content to Flutter: " + e.getMessage());
        }
    }

    private boolean shouldSkipPackage(String packageName) {
        if (packageName == null) return true;

        boolean isSystemPackage = EXCLUDED_PACKAGES.contains(packageName)
                || packageName.startsWith("com.android.")
                || packageName.startsWith("android.")
                || packageName.contains("launcher")
                || packageName.contains("systemui")
                || packageName.contains("scamshield")
                || packageName.contains("elephas");

        boolean isNotTargetedApp = !TARGETED_SCAM_APPS.contains(packageName);

        return isSystemPackage || isNotTargetedApp;
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        instance = this;

        AccessibilityServiceInfo info = new AccessibilityServiceInfo();
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
                | AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
                | AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
                | AccessibilityEvent.TYPE_VIEW_CLICKED
                | AccessibilityEvent.TYPE_VIEW_FOCUSED
                | AccessibilityEvent.TYPE_VIEW_SELECTED
                | AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
                | AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
                | AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                | AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY
                | AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS;
        info.notificationTimeout = 50;
        info.packageNames = TARGETED_SCAM_APPS.toArray(new String[0]);

        setServiceInfo(info);
        Log.d(TAG, "FOCUSED Accessibility service connected - monitoring communication apps only");
        Log.d(TAG, "Targeted apps: " + TARGETED_SCAM_APPS.size() + " communication platforms");

        startForeground(102, createForegroundNotification());
    }

    private Notification createForegroundNotification() {
        String channelId = "ElephASAccessibilityChannel";
        String channelName = "Elephas AI Background Monitoring";
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && notificationManager != null) {
            NotificationChannel channel = new NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW
            );
            notificationManager.createNotificationChannel(channel);
        }

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, channelId);
        } else {
            builder = new Notification.Builder(this);
        }

        return builder.setContentTitle("Elephas AI")
                .setContentText("Protecting you from scams in the background...")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .build();
    }

    private String generateScreenId(AccessibilityEvent event) {
        int windowId = event.getWindowId();
        String packageName = event.getPackageName() != null ? event.getPackageName().toString() : "unknown";
        String className = event.getClassName() != null ? event.getClassName().toString() : "unknown";
        return packageName + ":" + className + ":" + windowId;
    }

    private void notifyScreenChanged(String screenId) {
        if (flutterChannel != null) {
            flutterChannel.invokeMethod("onScreenChanged", screenId);
        }
    }

    private void sendAppChangeToFlutter(String packageName) {
        try {
            Log.d(TAG, "App changed to: " + packageName);
            Intent intent = new Intent("com.example.scamshield_flutter_app.APP_CHANGED");
            intent.putExtra("packageName", packageName);
            intent.putExtra("timestamp", System.currentTimeMillis());
            sendBroadcast(intent);
            Log.d(TAG, "App change broadcast sent successfully");
        } catch (Exception e) {
            Log.e(TAG, "Failed to send app change: " + e.getMessage());
        }
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null) return;
        CharSequence pkgChar = event.getPackageName();
        final String packageName = pkgChar != null ? pkgChar.toString() : null;

        switch (event.getEventType()) {
            case AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED:
                if (packageName != null && !packageName.equals(currentPackage)) {
                    currentPackage = packageName;
                    if (!shouldSkipPackage(packageName)) {
                        sendAppChangeToFlutter(packageName);
                    }
                }
                break;

            case AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED:
            case AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED:
                if (packageName != null && !shouldSkipPackage(packageName)) {
                    textExtractionExecutor.schedule(() -> {
                        try {
                            AccessibilityNodeInfo root = getRootInActiveWindow();
                            extractTextFromRoot(root, packageName);
                        } catch (Exception e) {
                            Log.e(TAG, "Error in scheduled text extraction: " + e.getMessage());
                        }
                    }, 100, TimeUnit.MILLISECONDS);
                }
                break;
        }

        String screenId = generateScreenId(event);
        if (!screenId.equals(currentScreenId)) {
            currentScreenId = screenId;
            notifyScreenChanged(screenId);
        }
    }

    private void extractTextFromRoot(AccessibilityNodeInfo node, String packageName) {
        if (node == null) return;

        StringBuilder builder = new StringBuilder();
        traverseNodes(node, builder);
        String extractedContent = builder.toString().trim();

        if (extractedContent.length() >= MIN_TEXT_LENGTH && !extractedContent.equals(lastExtractedText)) {
            if ("com.whatsapp".equals(packageName)
                    && (extractedContent.toLowerCase().contains("end-to-end encrypted")
                    || extractedContent.toLowerCase().contains("messages and calls are end-to-end"))) {
                Log.d(TAG, "Skipping WhatsApp security placeholder, trying to extract actual messages...");
                String actualMessages = extractWhatsAppMessages(node);
                if (!actualMessages.isEmpty()) {
                    Log.d(TAG, "Found actual WhatsApp messages: " + actualMessages.substring(0, Math.min(100, actualMessages.length())) + "...");
                    sendContentToFlutter(actualMessages, packageName);
                    lastExtractedText = actualMessages;
                } else {
                    Log.d(TAG, "No actual WhatsApp messages found, content is encrypted/protected");
                }
                return;
            }

            Log.d(TAG, "Extracted content from " + packageName + ": " + extractedContent.substring(0, Math.min(100, extractedContent.length())) + "...");
            lastExtractedText = extractedContent;
            sendContentToFlutter(extractedContent, packageName);
        }
    }

    private String extractWhatsAppMessages(AccessibilityNodeInfo node) {
        if (node == null) return "";

        StringBuilder messageBuilder = new StringBuilder();
        List<String> messages = new ArrayList<>();
        extractMessagesFromNode(node, messages);

        for (String message : messages) {
            String cleaned = cleanWhatsAppMessage(message);
            if (!cleaned.isEmpty()) {
                if (messageBuilder.length() > 0) messageBuilder.append("\n");
                messageBuilder.append(cleaned);
            }
        }

        return messageBuilder.toString().trim();
    }

    private void extractMessagesFromNode(AccessibilityNodeInfo node, List<String> messages) {
        try {
            String viewId = node.getViewIdResourceName();
            CharSequence textChar = node.getText();
            String text = textChar != null ? textChar.toString() : "";

            boolean isBusinessInfo = (viewId != null && viewId.contains("business_info"))
                    || text.toLowerCase().contains("business account");

            if (!isBusinessInfo) {
                if (isMessageBubbleNode(node)) {
                    String textStr = text.trim();
                    if (!textStr.isEmpty() && !isUIElement(textStr)) {
                        Log.d(TAG, "Found message text: " + textStr);
                        messages.add(textStr);
                    }
                }

                if (viewId != null && (viewId.contains("message_text")
                        || viewId.contains("conversation_text")
                        || viewId.contains("chat_msg"))) {
                    String textStr = text.trim();
                    if (!textStr.isEmpty() && !isUIElement(textStr)) {
                        Log.d(TAG, "Found message by ID: " + textStr);
                        messages.add(textStr);
                    }
                }
            }

            for (int i = 0; i < node.getChildCount(); i++) {
                AccessibilityNodeInfo child = node.getChild(i);
                if (child != null) {
                    extractMessagesFromNode(child, messages);
                    child.recycle();
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error extracting messages: " + e.getMessage());
        }
    }

    private boolean isMessageBubbleNode(AccessibilityNodeInfo node) {
        CharSequence classChar = node.getClassName();
        String className = classChar != null ? classChar.toString() : "";

        boolean isMessageContainer = false;
        AccessibilityNodeInfo parent = node.getParent();
        if (parent != null) {
            CharSequence parentClassChar = parent.getClassName();
            String parentClass = parentClassChar != null ? parentClassChar.toString() : "";
            isMessageContainer = parentClass.toLowerCase().contains("messagecontainer")
                    || parentClass.toLowerCase().contains("chatlayout")
                    || parentClass.toLowerCase().contains("conversationlayout")
                    || parentClass.toLowerCase().contains("businessmessagelayout");
        }

        boolean isTextNode = className.toLowerCase().contains("textview")
                && !node.isClickable()
                && node.getText() != null
                && !isUIElement(node.getText().toString());

        boolean isBusinessMessage = false;
        if (parent != null) {
            String parentViewId = parent.getViewIdResourceName();
            isBusinessMessage = parentViewId != null && (parentViewId.contains("business_message") || parentViewId.contains("message_text"));
        }

        return isTextNode && (isMessageContainer || isBusinessMessage);
    }

    private boolean isUIElement(String text) {
        if (text == null) return false;
        String trimmed = text.trim();
        for (Pattern pattern : UI_PATTERNS) {
            if (pattern.matcher(trimmed).matches()) return true;
        }
        return false;
    }

    private String cleanWhatsAppMessage(String message) {
        if (message == null) return "";
        String cleaned = message.trim()
                .replaceAll("(?i)\\b(online|last seen|typing\\.\\.\\.)", "")
                .replaceAll("\\b\\d{1,2}:\\d{2}\\s?(?:AM|PM)?\\b", "")
                .replaceAll("\\b(Today|Yesterday)\\b", "")
                .replaceAll("\\b(Block|Report|Add to contacts)\\b", "")
                .replaceAll("(?i)\\b(delivered|sent|read)\\b", "")
                .replaceAll("\\b(Message|Search)\\b", "")
                .replaceAll("The business won't see.*contact", "")
                .replace("...", "")
                .replaceAll("\\s+", " ")
                .trim();

        return (cleaned.length() > 2 && !isUIElement(cleaned)) ? cleaned : "";
    }

    private void traverseNodes(AccessibilityNodeInfo node, StringBuilder builder) {
        CharSequence textChar = node.getText();
        if (textChar != null) {
            String textStr = textChar.toString().trim();
            if (textStr.length() > 1) {
                if (!textStr.matches("^[0-9]{1,2}:[0-9]{2}\\s?(AM|PM)?$")
                        && !textStr.equalsIgnoreCase("Send")
                        && !textStr.equalsIgnoreCase("Type a message")
                        && !textStr.equalsIgnoreCase("Search")
                        && !textStr.equalsIgnoreCase("Camera")
                        && !textStr.equalsIgnoreCase("Gallery")
                        && !textStr.equalsIgnoreCase("Attach")
                        && !textStr.equalsIgnoreCase("More")
                        && !textStr.equalsIgnoreCase("Back")
                        && textStr.length() > 2) {
                    builder.append(textStr).append(" ");
                }
            }
        }

        CharSequence descChar = node.getContentDescription();
        if (descChar != null) {
            String description = descChar.toString().trim();
            if (description.length() > 5
                    && !description.toLowerCase().contains("button")
                    && !description.toLowerCase().contains("icon")
                    && !description.toLowerCase().contains("image")
                    && !description.toLowerCase().contains("tab")
                    && !description.toLowerCase().contains("navigation")) {
                builder.append(description).append(" ");
            }
        }

        CharSequence hintChar = node.getHintText();
        if (hintChar != null) {
            String hintStr = hintChar.toString().trim();
            if (hintStr.length() > 2) {
                builder.append(hintStr).append(" ");
            }
        }

        CharSequence errorChar = node.getError();
        if (errorChar != null) {
            String errorStr = errorChar.toString().trim();
            if (!errorStr.isEmpty()) {
                builder.append(errorStr).append(" ");
            }
        }

        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo child = node.getChild(i);
            if (child != null) {
                traverseNodes(child, builder);
                child.recycle();
            }
        }
    }

    @Override
    public void onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted");
    }

    @Override
    public void onDestroy() {
        instance = null;
        textExtractionExecutor.shutdownNow();
        stopForeground(true);
        super.onDestroy();
    }
}
