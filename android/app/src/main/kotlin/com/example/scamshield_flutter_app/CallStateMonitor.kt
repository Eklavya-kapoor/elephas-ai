package com.example.scamshield_flutter_app

import android.content.Context
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class CallStateMonitor(private val context: Context) : PhoneStateListener() {

    companion object {
        private const val TAG = "CallStateMonitor"
    }

    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var lastNumber: String? = null

    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
        super.onCallStateChanged(state, phoneNumber)

        if (lastState == state) {
            // Avoid duplicate events if the state hasn't genuinely changed
            return
        }

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                Log.d(TAG, "CALL_STATE_RINGING: From $phoneNumber")
                lastNumber = phoneNumber
                if (phoneNumber != null) {
                    sendCallEventToFlutter("ringing", phoneNumber)
                }
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                Log.d(TAG, "CALL_STATE_OFFHOOK: $phoneNumber (Call Answered or Dialing)")
                if (lastState == TelephonyManager.CALL_STATE_RINGING || lastNumber == null) {
                    // If it moved from ringing, or was a new outgoing call
                    lastNumber = phoneNumber // Update number for outgoing calls
                }
                if (lastNumber != null) {
                    sendCallEventToFlutter("offhook", lastNumber!!)
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                Log.d(TAG, "CALL_STATE_IDLE (Call ended or missed)")
                if (lastState == TelephonyManager.CALL_STATE_OFFHOOK || lastState == TelephonyManager.CALL_STATE_RINGING) {
                    // Call ended or missed
                    if (lastNumber != null) {
                        sendCallEventToFlutter("idle", lastNumber!!)
                    }
                }
                lastNumber = null // Reset for next call
            }
        }
        lastState = state
    }

    private fun sendCallEventToFlutter(callState: String, number: String) {
        MethodChannelManager.overlayMethodChannel?.let { channel ->
            channel.invokeMethod(
                "onIncomingCall", // Use dedicated method for call monitoring
                mapOf(
                    "phoneNumber" to number,
                    "callState" to when(callState) {
                        "ringing" -> 1
                        "offhook" -> 2
                        else -> 0 // idle
                    },
                    "formattedNumber" to formatPhoneNumber(number)
                )
            )
            Log.d(TAG, "Sent call event to Flutter: State=$callState, Number=$number")
        } ?: run {
            Log.e(TAG, "Overlay MethodChannel not initialized for CallStateMonitor.")
        }
    }
    
    private fun formatPhoneNumber(number: String): String {
        // Basic formatting for display purposes
        if (number.length >= 10) {
            return number.replaceFirst("(\\d{3})(\\d{3})(\\d+)".toRegex(), "($1) $2-$3")
        }
        return number
    }
}