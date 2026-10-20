package com.elephas.ai;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Handler;
import android.os.Looper;
import android.telecom.TelecomManager;
import android.telephony.TelephonyManager;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class CallMonitorPlugin implements MethodChannel.MethodCallHandler {

    private static final String TAG = "CallMonitorPlugin";

    private final Context context;
    private CallReceiver callReceiver;
    private final CallAudioProcessor callAudioProcessor;
    private final TelecomManager telecomManager;
    private boolean isMonitoring = false;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public CallMonitorPlugin(Context context) {
        this.context = context;
        this.callAudioProcessor = new CallAudioProcessor(context);
        this.telecomManager = (TelecomManager) context.getSystemService(Context.TELECOM_SERVICE);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "startMonitoring":
                startMonitoring();
                result.success(null);
                break;
            case "stopMonitoring":
                stopMonitoring();
                result.success(null);
                break;
            case "hangUp":
                hangUpCall();
                result.success(null);
                break;
            case "startRecording":
                callAudioProcessor.onMethodCall(call, result);
                break;
            case "reportScam": {
                String number = call.argument("number");
                if (number == null) number = "";
                List<String> transcript = call.argument("transcript");
                if (transcript == null) transcript = Collections.emptyList();
                String direction = call.argument("direction");
                if (direction == null) direction = "";
                reportScamCall(number, transcript, direction);
                result.success(null);
                break;
            }
            default:
                result.notImplemented();
        }
    }

    private void startMonitoring() {
        if (isMonitoring) return;

        try {
            callReceiver = new CallReceiver();
            IntentFilter filter = new IntentFilter();
            filter.addAction(TelephonyManager.ACTION_PHONE_STATE_CHANGED);
            filter.addAction(Intent.ACTION_NEW_OUTGOING_CALL);
            context.registerReceiver(callReceiver, filter);
            isMonitoring = true;
            Log.d(TAG, "LIVE CALL: Started call monitoring");
        } catch (Exception e) {
            Log.e(TAG, "Error starting call monitoring", e);
        }
    }

    private void stopMonitoring() {
        if (!isMonitoring) return;

        try {
            if (callReceiver != null) {
                context.unregisterReceiver(callReceiver);
                callReceiver = null;
            }
            callAudioProcessor.cleanup();
            isMonitoring = false;
            Log.d(TAG, "LIVE CALL: Stopped call monitoring");
        } catch (Exception e) {
            Log.e(TAG, "Error stopping call monitoring", e);
        }
    }

    private void hangUpCall() {
        try {
            if (telecomManager != null) {
                telecomManager.endCall();
                Log.d(TAG, "LIVE CALL: Call hung up by user");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error hanging up call", e);
        }
    }

    private void reportScamCall(String number, List<String> transcript, String direction) {
        Log.d(TAG, "LIVE CALL: Reporting scam call from " + number);
        Log.d(TAG, "LIVE CALL: Transcript: " + transcript);

        Map<String, Object> reportData = new HashMap<>();
        reportData.put("number", number);
        reportData.put("transcript", transcript);
        reportData.put("direction", direction);
        reportData.put("timestamp", System.currentTimeMillis());

        Log.d(TAG, "LIVE CALL: Scam report data: " + reportData);
    }

    public class CallReceiver extends BroadcastReceiver {
        private int lastState = TelephonyManager.CALL_STATE_IDLE;
        private String callNumber = "";

        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent == null || intent.getAction() == null) return;
            String action = intent.getAction();
            Log.d(TAG, "LIVE CALL: Received broadcast: " + action);

            if (TelephonyManager.ACTION_PHONE_STATE_CHANGED.equals(action)) {
                String state = intent.getStringExtra(TelephonyManager.EXTRA_STATE);
                String incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER);
                handlePhoneStateChange(state, incomingNumber);
            } else if (Intent.ACTION_NEW_OUTGOING_CALL.equals(action)) {
                String outgoingNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER);
                handleOutgoingCall(outgoingNumber);
            }
        }

        private void handlePhoneStateChange(String state, String incomingNumber) {
            int currentState;
            if (TelephonyManager.EXTRA_STATE_RINGING.equals(state)) {
                currentState = TelephonyManager.CALL_STATE_RINGING;
            } else if (TelephonyManager.EXTRA_STATE_OFFHOOK.equals(state)) {
                currentState = TelephonyManager.CALL_STATE_OFFHOOK;
            } else if (TelephonyManager.EXTRA_STATE_IDLE.equals(state)) {
                currentState = TelephonyManager.CALL_STATE_IDLE;
            } else {
                return;
            }

            if (lastState != currentState) {
                String stateString;
                switch (currentState) {
                    case TelephonyManager.CALL_STATE_RINGING:
                        stateString = "RINGING";
                        break;
                    case TelephonyManager.CALL_STATE_OFFHOOK:
                        stateString = "OFFHOOK";
                        break;
                    case TelephonyManager.CALL_STATE_IDLE:
                        stateString = "IDLE";
                        break;
                    default:
                        stateString = "UNKNOWN";
                }

                if (currentState == TelephonyManager.CALL_STATE_RINGING && incomingNumber != null) {
                    callNumber = incomingNumber;
                }

                Log.d(TAG, "LIVE CALL: State changed to " + stateString + " for " + callNumber);

                if (MethodChannelManager.callMonitorChannel != null) {
                    Map<String, Object> stateMap = new HashMap<>();
                    stateMap.put("state", stateString);
                    stateMap.put("number", callNumber);
                    stateMap.put("direction", "incoming");
                    MethodChannelManager.callMonitorChannel.invokeMethod("onCallStateChanged", stateMap);
                }

                if (currentState == TelephonyManager.CALL_STATE_OFFHOOK) {
                    mainHandler.postDelayed(() -> {
                        if (MethodChannelManager.callMonitorChannel != null) {
                            MethodChannelManager.callMonitorChannel.invokeMethod("onCallAudioReady", Collections.emptyMap());
                        }
                    }, 2000);
                } else if (currentState == TelephonyManager.CALL_STATE_IDLE) {
                    if (MethodChannelManager.callMonitorChannel != null) {
                        MethodChannelManager.callMonitorChannel.invokeMethod("onCallEnded", Collections.emptyMap());
                    }
                    callNumber = "";
                }

                lastState = currentState;
            }
        }

        private void handleOutgoingCall(String outgoingNumber) {
            if (outgoingNumber != null) {
                callNumber = outgoingNumber;
                Log.d(TAG, "LIVE CALL: Outgoing call to " + callNumber);

                if (MethodChannelManager.callMonitorChannel != null) {
                    Map<String, Object> stateMap = new HashMap<>();
                    stateMap.put("state", "OUTGOING");
                    stateMap.put("number", callNumber);
                    stateMap.put("direction", "outgoing");
                    MethodChannelManager.callMonitorChannel.invokeMethod("onCallStateChanged", stateMap);
                }
            }
        }
    }

    public void cleanup() {
        stopMonitoring();
        callAudioProcessor.cleanup();
    }
}
