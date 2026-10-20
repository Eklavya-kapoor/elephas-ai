package com.elephas.ai;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Reads text from a screenshot using Google ML Kit (on-device OCR).
 * The cleaned text is sent back to Flutter, where it is checked for scams.
 */
public class OcrPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {

    private static final String TAG = "OcrPlugin";
    private static final String CHANNEL = "elephas_ai/ocr";

    private MethodChannel channel;
    private Context context;
    private TextRecognizer textRecognizer;
    private BinaryMessenger binaryMessenger;

    // Common UI words that should not be treated as message content
    private static final List<String> UI_PATTERNS = lowercase(Arrays.asList(
            // Common UI elements
            "Search", "Settings", "Back", "Menu", "Home", "Recent",
            "Call", "Video", "Attach", "Send", "Type a message",
            "Online", "Last seen", "Typing", "Recording", "Sending",
            // Status indicators
            "Delivered", "Read", "Sent", "Failed", "Retry",
            // Navigation icons / symbols
            "←", "→", "↑", "↓", "⚙"
    ));

    // Time / date patterns (chat timestamps)
    private static final List<Pattern> TIME_PATTERNS = Arrays.asList(
            Pattern.compile("\\d{1,2}:\\d{2}"),                          // 10:30
            Pattern.compile("\\d{1,2}:\\d{2} (AM|PM)"),                 // 10:30 AM
            Pattern.compile("(Today|Yesterday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)"),
            Pattern.compile("\\d{1,2}/\\d{1,2}/\\d{2,4}"),              // 15/10/2026
            Pattern.compile("\\d{1,2}-\\d{1,2}-\\d{2,4}")               // 15-10-2026
    );

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        context = binding.getApplicationContext();
        textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS);
        binaryMessenger = binding.getBinaryMessenger();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) channel.setMethodCallHandler(null);
        if (textRecognizer != null) textRecognizer.close();
        channel = null;
        context = null;
        textRecognizer = null;
        binaryMessenger = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (textRecognizer == null) {
            result.error("UNAVAILABLE", "OCR is not initialized", null);
            return;
        }
        if ("extractText".equals(call.method)) {
            extractTextFromImage(call, result);
        } else {
            result.notImplemented();
        }
    }

    private void extractTextFromImage(MethodCall call, MethodChannel.Result result) {
        try {
            byte[] imageBytes = call.argument("image");
            if (imageBytes == null) {
                result.success("");
                return;
            }

            final Bitmap bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);
            if (bitmap == null) {
                result.success("");
                return;
            }

            InputImage inputImage = InputImage.fromBitmap(bitmap, 0);

            if (textRecognizer == null) {
                Log.e(TAG, "TextRecognizer not initialized");
                result.error("UNAVAILABLE", "OCR failed to initialize", null);
                bitmap.recycle();
                return;
            }

            textRecognizer.process(inputImage)
                    .addOnSuccessListener(visionText -> {
                        String extractedText = processVisionText(visionText.getText());
                        Log.d(TAG, "OCR extracted text length: " + extractedText.length());
                        result.success(extractedText);

                        // Old event, kept for backward compatibility
                        if (channel != null) {
                            Map<String, Object> args = new HashMap<>();
                            args.put("text", extractedText);
                            args.put("source", "Screen");
                            channel.invokeMethod("onOcrResult", args);
                        }

                        // Send text to the screen-monitor channel for scam scanning
                        if (binaryMessenger != null) {
                            MethodChannel screenMonitorChannel =
                                    new MethodChannel(binaryMessenger, "elephas_ai/screen_monitor");
                            screenMonitorChannel.invokeMethod("onTextExtracted", extractedText);
                        }
                        bitmap.recycle();
                    })
                    .addOnFailureListener(e -> {
                        Log.e(TAG, "OCR failed", e);
                        result.success("");
                        bitmap.recycle();
                    });

        } catch (Exception e) {
            Log.e(TAG, "Error in extractTextFromImage", e);
            result.success("");
        }
    }

    private String processVisionText(String rawText) {
        if (rawText == null) return "";
        Log.d(TAG, "Raw OCR text: " + rawText);

        List<String> filteredLines = new ArrayList<>();
        for (String line : rawText.split("\n")) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            // Drop UI labels, timestamps and very short noise
            if (!isUIElement(trimmed) && !isTimestamp(trimmed) && trimmed.length() > 3) {
                filteredLines.add(trimmed);
            }
        }
        return TextUtils.join("\n", filteredLines);
    }

    private boolean isUIElement(String text) {
        String lowerText = text.toLowerCase();
        for (String pattern : UI_PATTERNS) {
            if (lowerText.contains(pattern) || lowerText.equals(pattern)) return true;
        }
        return text.length() <= 2;
    }

    private boolean isTimestamp(String text) {
        for (Pattern p : TIME_PATTERNS) {
            if (p.matcher(text).find()) return true;
        }
        return false;
    }

    private static List<String> lowercase(List<String> items) {
        List<String> out = new ArrayList<>();
        for (String s : items) out.add(s.toLowerCase());
        return out;
    }
}
