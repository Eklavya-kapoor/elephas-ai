package com.example.scamshield_flutter_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class OcrPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    // Use default TextRecognizerOptions which supports multiple languages and scripts
    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    
    companion object {
        private const val TAG = "OcrPlugin"
        private const val CHANNEL = "scamshield/ocr"
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        textRecognizer.close()
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "extractText" -> extractTextFromImage(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun extractTextFromImage(call: MethodCall, result: MethodChannel.Result) {
        try {
            val imageBytes = call.argument<ByteArray>("image")
            if (imageBytes == null) {
                result.success("")
                return
            }
            
            // Convert byte array to bitmap
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            if (bitmap == null) {
                result.success("")
                return
            }
            
            // Create InputImage from bitmap
            val inputImage = InputImage.fromBitmap(bitmap, 0)
            
            // Process image with ML Kit
            textRecognizer.process(inputImage)
                .addOnSuccessListener { visionText ->
                    val extractedText = processVisionText(visionText.text)
                    Log.d(TAG, "OCR extracted text length: ${extractedText.length}")
                    result.success(extractedText)
                    bitmap.recycle()
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "OCR failed", e)
                    result.success("")
                    bitmap.recycle()
                }
                
        } catch (e: Exception) {
            Log.e(TAG, "Error in extractTextFromImage", e)
            result.success("")
        }
    }
    
    private fun processVisionText(rawText: String): String {
        // Clean and filter the extracted text
        val lines = rawText.split('\n').map { it.trim() }.filter { it.isNotEmpty() }
        
        // Add debug log for text recognition
        Log.d(TAG, "Raw OCR text: $rawText")
        
        // Filter out common UI elements and noise
        val filteredLines = lines.filter { line ->
            !isUIElement(line) && !isTimestamp(line) && line.length > 3
        }
        
        return filteredLines.joinToString("\n")
    }
    
    private fun isUIElement(text: String): Boolean {
        val uiPatterns = listOf(
            // Common UI elements
            "Search", "Settings", "Back", "Menu", "Home", "Recent",
            "Call", "Video", "Attach", "Send", "Type a message",
            "Online", "Last seen", "Typing", "Recording", "Sending",
            
            // Status indicators
            "Delivered", "Read", "Sent", "Failed", "Retry",
            
            // Navigation
            "←", "→", "↑", "↓", "⋮", "⚙", "📎", "📷", "🎤",
            
            // Single characters or short meaningless text
        ).map { it.lowercase() }
        
        val lowerText = text.lowercase()
        return uiPatterns.any { pattern -> 
            lowerText.contains(pattern) || lowerText == pattern
        } || text.length <= 2
    }
    
    private fun isTimestamp(text: String): Boolean {
        val timePatterns = listOf(
            Regex("""\d{1,2}:\d{2}"""), // 10:30
            Regex("""\d{1,2}:\d{2} (AM|PM)"""), // 10:30 AM
            Regex("""(Today|Yesterday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)"""),
            Regex("""\d{1,2}/\d{1,2}/\d{2,4}"""), // Date formats
            Regex("""\d{1,2}-\d{1,2}-\d{2,4}"""), // Date formats
        )
        
        return timePatterns.any { it.containsMatchIn(text) }
    }
}