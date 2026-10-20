package com.elephas.ai;

import android.content.Context;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;

public class CallStateMonitor extends PhoneStateListener {

    private static final String TAG = "CallStateMonitor";

    private final Context context;
    private int lastState = TelephonyManager.CALL_STATE_IDLE;
    private String lastNumber = null;

    public CallStateMonitor(Context context) {
        this.context = context;
    }

    @Override
    public void onCallStateChanged(int state, String phoneNumber) {
        super.onCallStateChanged(state, phoneNumber);

        if (lastState == state) {
            // Avoid duplicate events if the state hasn't genuinely changed
            return;
        }

        switch (state) {
            case TelephonyManager.CALL_STATE_RINGING:
                Log.d(TAG, "CALL_STATE_RINGING: From " + phoneNumber);
                lastNumber = phoneNumber;
                if (phoneNumber != null) {
                    sendCallEventToFlutter("ringing", phoneNumber);
                }
                break;

            case TelephonyManager.CALL_STATE_OFFHOOK:
                Log.d(TAG, "CALL_STATE_OFFHOOK: " + phoneNumber + " (Call Answered or Dialing)");
                if (lastState == TelephonyManager.CALL_STATE_RINGING || lastNumber == null) {
                    lastNumber = phoneNumber; // Update number for outgoing calls
                }
                if (lastNumber != null) {
                    sendCallEventToFlutter("offhook", lastNumber);
                }
                break;

            case TelephonyManager.CALL_STATE_IDLE:
                Log.d(TAG, "CALL_STATE_IDLE (Call ended or missed)");
                if (lastState == TelephonyManager.CALL_STATE_OFFHOOK || lastState == TelephonyManager.CALL_STATE_RINGING) {
                    if (lastNumber != null) {
                        sendCallEventToFlutter("idle", lastNumber);
                    }
                }
                lastNumber = null; // Reset for next call
                break;
        }
        lastState = state;
    }

    private void sendCallEventToFlutter(String callState, String number) {
        if (MethodChannelManager.overlayMethodChannel != null) {
            int stateCode;
            if ("ringing".equals(callState)) {
                stateCode = 1;
            } else if ("offhook".equals(callState)) {
                stateCode = 2;
            } else {
                stateCode = 0; // idle
            }

            Map<String, Object> map = new HashMap<>();
            map.put("phoneNumber", number);
            map.put("callState", stateCode);
            map.put("formattedNumber", formatPhoneNumber(number));

            MethodChannelManager.overlayMethodChannel.invokeMethod("onIncomingCall", map);
            Log.d(TAG, "Sent call event to Flutter: State=" + callState + ", Number=" + number);
        } else {
            Log.e(TAG, "Overlay MethodChannel not initialized for CallStateMonitor.");
        }
    }

    private String formatPhoneNumber(String number) {
        if (number != null && number.length() >= 10) {
            return number.replaceFirst("(\\d{3})(\\d{3})(\\d+)", "($1) $2-$3");
        }
        return number != null ? number : "";
    }
}
