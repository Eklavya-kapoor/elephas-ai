package com.elephas.ai;

import android.content.Context;
import android.content.Intent;
import android.media.MediaRecorder;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class CallAudioProcessor implements MethodChannel.MethodCallHandler, RecognitionListener {

    private static final String TAG = "CallAudioProcessor";

    private final Context context;
    private SpeechRecognizer speechRecognizer;
    private MediaRecorder mediaRecorder;
    private boolean isListening = false;
    private boolean isRecording = false;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public CallAudioProcessor(Context context) {
        this.context = context;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "startListening": {
                String language = call.argument("language");
                if (language == null) language = "en-US";
                Boolean continuous = call.argument("continuous");
                if (continuous == null) continuous = true;
                Boolean partialResults = call.argument("partialResults");
                if (partialResults == null) partialResults = true;
                Boolean separateSpeakers = call.argument("separateSpeakers");
                if (separateSpeakers == null) separateSpeakers = false;

                startListening(language, continuous, partialResults, separateSpeakers);
                result.success(null);
                break;
            }
            case "stopListening":
                stopListening();
                result.success(null);
                break;
            case "startRecording":
                startRecording();
                result.success(null);
                break;
            case "stopRecording":
                stopRecording();
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    private void startListening(String language, boolean continuous, boolean partialResults, boolean separateSpeakers) {
        if (isListening) {
            Log.w(TAG, "Already listening");
            return;
        }

        try {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context);
            speechRecognizer.setRecognitionListener(this);

            Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "auto".equals(language) ? Locale.getDefault() : Locale.forLanguageTag(language));
            intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResults);
            intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
            intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1000);
            intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1000);

            speechRecognizer.startListening(intent);
            isListening = true;
            Log.d(TAG, "LIVE CALL: Started speech recognition");
        } catch (Exception e) {
            Log.e(TAG, "Error starting speech recognition", e);
            if (MethodChannelManager.speechRecognitionChannel != null) {
                Map<String, Object> errorMap = new HashMap<>();
                errorMap.put("error", e.getMessage());
                MethodChannelManager.speechRecognitionChannel.invokeMethod("onSpeechError", errorMap);
            }
        }
    }

    private void stopListening() {
        if (!isListening) return;

        try {
            if (speechRecognizer != null) {
                speechRecognizer.stopListening();
                speechRecognizer.destroy();
                speechRecognizer = null;
            }
            isListening = false;
            Log.d(TAG, "LIVE CALL: Stopped speech recognition");
        } catch (Exception e) {
            Log.e(TAG, "Error stopping speech recognition", e);
        }
    }

    private void startRecording() {
        if (isRecording) return;

        try {
            mediaRecorder = new MediaRecorder();
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.VOICE_CALL);
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);

            File externalDir = context.getExternalFilesDir(null);
            String filePath = (externalDir != null ? externalDir.getAbsolutePath() : context.getFilesDir().getAbsolutePath())
                    + "/call_recording_" + System.currentTimeMillis() + ".3gp";

            mediaRecorder.setOutputFile(filePath);
            mediaRecorder.prepare();
            mediaRecorder.start();
            isRecording = true;
            Log.d(TAG, "LIVE CALL: Started call recording");
        } catch (Exception e) {
            Log.e(TAG, "Error starting call recording", e);
            mediaRecorder = null;
        }
    }

    private void stopRecording() {
        if (!isRecording) return;

        try {
            if (mediaRecorder != null) {
                mediaRecorder.stop();
                mediaRecorder.release();
                mediaRecorder = null;
            }
            isRecording = false;
            Log.d(TAG, "LIVE CALL: Stopped call recording");
        } catch (Exception e) {
            Log.e(TAG, "Error stopping call recording", e);
        }
    }

    @Override
    public void onReadyForSpeech(Bundle params) {
        Log.d(TAG, "LIVE CALL: Speech recognizer ready");
    }

    @Override
    public void onBeginningOfSpeech() {
        Log.d(TAG, "LIVE CALL: Speech detection started");
    }

    @Override
    public void onRmsChanged(float rmsdB) {
        // Audio level monitoring
    }

    @Override
    public void onBufferReceived(byte[] buffer) {
        // Raw audio buffer
    }

    @Override
    public void onEndOfSpeech() {
        Log.d(TAG, "LIVE CALL: Speech detection ended");
    }

    @Override
    public void onError(int error) {
        String errorMessage;
        switch (error) {
            case SpeechRecognizer.ERROR_AUDIO:
                errorMessage = "Audio recording error";
                break;
            case SpeechRecognizer.ERROR_CLIENT:
                errorMessage = "Client side error";
                break;
            case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                errorMessage = "Insufficient permissions";
                break;
            case SpeechRecognizer.ERROR_NETWORK:
                errorMessage = "Network error";
                break;
            case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                errorMessage = "Network timeout";
                break;
            case SpeechRecognizer.ERROR_NO_MATCH:
                errorMessage = "No match found";
                break;
            case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                errorMessage = "RecognitionService busy";
                break;
            case SpeechRecognizer.ERROR_SERVER:
                errorMessage = "Server error";
                break;
            case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                errorMessage = "Speech timeout";
                break;
            default:
                errorMessage = "Unknown error: " + error;
        }

        Log.e(TAG, "LIVE CALL: Speech recognition error: " + errorMessage);
        if (MethodChannelManager.speechRecognitionChannel != null) {
            Map<String, Object> errorMap = new HashMap<>();
            errorMap.put("error", errorMessage);
            MethodChannelManager.speechRecognitionChannel.invokeMethod("onSpeechError", errorMap);
        }

        if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
            mainHandler.postDelayed(() -> {
                if (isListening) {
                    startListening("auto", true, true, true);
                }
            }, 1000);
        }
    }

    @Override
    public void onResults(Bundle results) {
        if (results != null) {
            ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            float[] confidenceScores = results.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES);

            if (matches != null && !matches.isEmpty()) {
                String text = matches.get(0);
                double confidence = (confidenceScores != null && confidenceScores.length > 0)
                        ? (double) confidenceScores[0]
                        : 0.8;

                Log.d(TAG, "LIVE CALL: Speech result: \"" + text + "\" (confidence: " + confidence + ")");

                if (MethodChannelManager.speechRecognitionChannel != null) {
                    Map<String, Object> resultMap = new HashMap<>();
                    resultMap.put("text", text);
                    resultMap.put("speaker", "caller");
                    resultMap.put("confidence", confidence);
                    MethodChannelManager.speechRecognitionChannel.invokeMethod("onSpeechResult", resultMap);
                }
            }
        }

        if (isListening) {
            mainHandler.postDelayed(() -> startListening("auto", true, true, true), 100);
        }
    }

    @Override
    public void onPartialResults(Bundle partialResults) {
        if (partialResults != null) {
            ArrayList<String> matches = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            if (matches != null && !matches.isEmpty()) {
                String text = matches.get(0);
                Log.d(TAG, "LIVE CALL: Partial speech result: \"" + text + "\"");

                if (MethodChannelManager.speechRecognitionChannel != null) {
                    Map<String, Object> resultMap = new HashMap<>();
                    resultMap.put("text", text);
                    resultMap.put("speaker", "caller");
                    resultMap.put("confidence", 0.7);
                    resultMap.put("partial", true);
                    MethodChannelManager.speechRecognitionChannel.invokeMethod("onSpeechResult", resultMap);
                }
            }
        }
    }

    @Override
    public void onEvent(int eventType, Bundle params) {
        Log.d(TAG, "LIVE CALL: Speech event: " + eventType);
    }

    public void cleanup() {
        stopListening();
        stopRecording();
    }
}
