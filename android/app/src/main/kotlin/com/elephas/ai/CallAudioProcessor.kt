package com.elephas.ai

import android.content.Context
import android.media.AudioManager
import android.media.MediaRecorder
import android.os.Build
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.util.*

class CallAudioProcessor(private val context: Context) : MethodCallHandler, RecognitionListener {
    private var speechRecognizer: SpeechRecognizer? = null
    private var mediaRecorder: MediaRecorder? = null
    private var isListening = false
    private var isRecording = false
    private val speechChannel = MethodChannelManager.speechRecognitionChannel
    
    companion object {
        private const val TAG = "CallAudioProcessor"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> {
                val language = call.argument<String>("language") ?: "en-US"
                val continuous = call.argument<Boolean>("continuous") ?: true
                val partialResults = call.argument<Boolean>("partialResults") ?: true
                val separateSpeakers = call.argument<Boolean>("separateSpeakers") ?: false
                
                startListening(language, continuous, partialResults, separateSpeakers)
                result.success(null)
            }
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            "startRecording" -> {
                startRecording()
                result.success(null)
            }
            "stopRecording" -> {
                stopRecording()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startListening(language: String, continuous: Boolean, partialResults: Boolean, separateSpeakers: Boolean) {
        if (isListening) {
            Log.w(TAG, "Already listening")
            return
        }

        try {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
            speechRecognizer?.setRecognitionListener(this)

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, if (language == "auto") Locale.getDefault() else Locale.forLanguageTag(language))
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResults)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1000)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1000)
            }

            speechRecognizer?.startListening(intent)
            isListening = true
            Log.d(TAG, "🎯 LIVE CALL: Started speech recognition")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting speech recognition", e)
            speechChannel?.invokeMethod("onSpeechError", mapOf("error" to e.message))
        }
    }

    private fun stopListening() {
        if (!isListening) return

        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
            speechRecognizer = null
            isListening = false
            Log.d(TAG, "🎯 LIVE CALL: Stopped speech recognition")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping speech recognition", e)
        }
    }

    private fun startRecording() {
        if (isRecording) return

        try {
            mediaRecorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.VOICE_CALL)
                setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
                setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                setOutputFile(context.getExternalFilesDir(null)?.absolutePath + "/call_recording_${System.currentTimeMillis()}.3gp")
                prepare()
                start()
            }
            isRecording = true
            Log.d(TAG, "🎯 LIVE CALL: Started call recording")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting call recording", e)
            mediaRecorder = null
        }
    }

    private fun stopRecording() {
        if (!isRecording) return

        try {
            mediaRecorder?.stop()
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording = false
            Log.d(TAG, "🎯 LIVE CALL: Stopped call recording")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping call recording", e)
        }
    }

    // RecognitionListener implementation
    override fun onReadyForSpeech(params: Bundle?) {
        Log.d(TAG, "🎯 LIVE CALL: Speech recognizer ready")
    }

    override fun onBeginningOfSpeech() {
        Log.d(TAG, "🎯 LIVE CALL: Speech detection started")
    }

    override fun onRmsChanged(rmsdB: Float) {
        // Audio level monitoring - can be used for speaker detection
    }

    override fun onBufferReceived(buffer: ByteArray?) {
        // Raw audio buffer - can be used for advanced processing
    }

    override fun onEndOfSpeech() {
        Log.d(TAG, "🎯 LIVE CALL: Speech detection ended")
    }

    override fun onError(error: Int) {
        val errorMessage = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No match found"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RecognitionService busy"
            SpeechRecognizer.ERROR_SERVER -> "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
            else -> "Unknown error: $error"
        }
        
        Log.e(TAG, "🎯 LIVE CALL: Speech recognition error: $errorMessage")
        speechChannel?.invokeMethod("onSpeechError", mapOf("error" to errorMessage))
        
        // Restart listening if it was a temporary error
        if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
            // Restart after a short delay
            android.os.Handler().postDelayed({
                if (isListening) {
                    startListening("auto", true, true, true)
                }
            }, 1000)
        }
    }

    override fun onResults(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val confidenceScores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
        
        if (matches != null && matches.isNotEmpty()) {
            val text = matches[0]
            val confidence = confidenceScores?.get(0)?.toDouble() ?: 0.8
            
            Log.d(TAG, "🎯 LIVE CALL: Speech result: \"$text\" (confidence: $confidence)")
            
            // For now, assume all speech is from caller
            // In a real implementation, we'd use audio analysis to separate speakers
            speechChannel?.invokeMethod("onSpeechResult", mapOf(
                "text" to text,
                "speaker" to "caller",
                "confidence" to confidence
            ))
        }
        
        // Continue listening for continuous recognition
        if (isListening) {
            android.os.Handler().postDelayed({
                startListening("auto", true, true, true)
            }, 100)
        }
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (matches != null && matches.isNotEmpty()) {
            val text = matches[0]
            Log.d(TAG, "🎯 LIVE CALL: Partial speech result: \"$text\"")
            
            // Send partial results for immediate processing
            speechChannel?.invokeMethod("onSpeechResult", mapOf(
                "text" to text,
                "speaker" to "caller",
                "confidence" to 0.7,
                "partial" to true
            ))
        }
    }

    override fun onEvent(eventType: Int, params: Bundle?) {
        Log.d(TAG, "🎯 LIVE CALL: Speech event: $eventType")
    }

    fun cleanup() {
        stopListening()
        stopRecording()
    }
}
