package com.elephas.ai

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.telephony.TelephonyManager
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class CallMonitorPlugin(private val context: Context) : MethodCallHandler {
    private var callReceiver: CallReceiver? = null
    private var callAudioProcessor: CallAudioProcessor? = null
    private var telecomManager: TelecomManager? = null
    private var isMonitoring = false
    
    companion object {
        private const val TAG = "CallMonitorPlugin"
    }

    init {
        callAudioProcessor = CallAudioProcessor(context)
        telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startMonitoring" -> {
                startMonitoring()
                result.success(null)
            }
            "stopMonitoring" -> {
                stopMonitoring()
                result.success(null)
            }
            "hangUp" -> {
                hangUpCall()
                result.success(null)
            }
            "startRecording" -> {
                callAudioProcessor?.onMethodCall(call, result)
            }
            "reportScam" -> {
                val number = call.argument<String>("number") ?: ""
                val transcript = call.argument<List<String>>("transcript") ?: emptyList()
                val direction = call.argument<String>("direction") ?: ""
                reportScamCall(number, transcript, direction)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startMonitoring() {
        if (isMonitoring) return

        try {
            callReceiver = CallReceiver()
            val filter = IntentFilter().apply {
                addAction(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
                addAction(Intent.ACTION_NEW_OUTGOING_CALL)
            }
            context.registerReceiver(callReceiver, filter)
            isMonitoring = true
            Log.d(TAG, "🎯 LIVE CALL: Started call monitoring")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting call monitoring", e)
        }
    }

    private fun stopMonitoring() {
        if (!isMonitoring) return

        try {
            callReceiver?.let { context.unregisterReceiver(it) }
            callReceiver = null
            callAudioProcessor?.cleanup()
            isMonitoring = false
            Log.d(TAG, "🎯 LIVE CALL: Stopped call monitoring")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping call monitoring", e)
        }
    }

    private fun hangUpCall() {
        try {
            telecomManager?.endCall()
            Log.d(TAG, "🎯 LIVE CALL: Call hung up by user")
        } catch (e: Exception) {
            Log.e(TAG, "Error hanging up call", e)
        }
    }

    private fun reportScamCall(number: String, transcript: List<String>, direction: String) {
        Log.d(TAG, "🎯 LIVE CALL: Reporting scam call from $number")
        Log.d(TAG, "🎯 LIVE CALL: Transcript: $transcript")
        
        // Here you could implement reporting to your scam database
        // For now, just log the scam report
        val reportData = mapOf(
            "number" to number,
            "transcript" to transcript,
            "direction" to direction,
            "timestamp" to System.currentTimeMillis()
        )
        
        // You could send this to your backend API for scam reporting
        Log.d(TAG, "🎯 LIVE CALL: Scam report data: $reportData")
    }

    inner class CallReceiver : BroadcastReceiver() {
        private var lastState = TelephonyManager.CALL_STATE_IDLE
        private var callNumber = ""

        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            Log.d(TAG, "🎯 LIVE CALL: Received broadcast: $action")

            when (action) {
                TelephonyManager.ACTION_PHONE_STATE_CHANGED -> {
                    val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                    val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
                    
                    handlePhoneStateChange(state, incomingNumber)
                }
                Intent.ACTION_NEW_OUTGOING_CALL -> {
                    val outgoingNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
                    handleOutgoingCall(outgoingNumber)
                }
            }
        }

        private fun handlePhoneStateChange(state: String?, incomingNumber: String?) {
            val currentState = when (state) {
                TelephonyManager.EXTRA_STATE_RINGING -> TelephonyManager.CALL_STATE_RINGING
                TelephonyManager.EXTRA_STATE_OFFHOOK -> TelephonyManager.CALL_STATE_OFFHOOK
                TelephonyManager.EXTRA_STATE_IDLE -> TelephonyManager.CALL_STATE_IDLE
                else -> return
            }

            if (lastState != currentState) {
                val stateString = when (currentState) {
                    TelephonyManager.CALL_STATE_RINGING -> "RINGING"
                    TelephonyManager.CALL_STATE_OFFHOOK -> "OFFHOOK"
                    TelephonyManager.CALL_STATE_IDLE -> "IDLE"
                    else -> "UNKNOWN"
                }

                if (currentState == TelephonyManager.CALL_STATE_RINGING && incomingNumber != null) {
                    callNumber = incomingNumber
                }

                Log.d(TAG, "🎯 LIVE CALL: State changed to $stateString for $callNumber")

                // Notify Flutter
                MethodChannelManager.callMonitorChannel?.invokeMethod("onCallStateChanged", mapOf(
                    "state" to stateString,
                    "number" to callNumber,
                    "direction" to "incoming"
                ))

                // Handle audio monitoring
                when (currentState) {
                    TelephonyManager.CALL_STATE_OFFHOOK -> {
                        // Call is active - start audio monitoring
                        android.os.Handler().postDelayed({
                            MethodChannelManager.callMonitorChannel?.invokeMethod("onCallAudioReady", emptyMap<String, Any>())
                        }, 2000) // Wait 2 seconds for call to stabilize
                    }
                    TelephonyManager.CALL_STATE_IDLE -> {
                        // Call ended - stop audio monitoring
                        MethodChannelManager.callMonitorChannel?.invokeMethod("onCallEnded", emptyMap<String, Any>())
                        callNumber = ""
                    }
                }

                lastState = currentState
            }
        }

        private fun handleOutgoingCall(outgoingNumber: String?) {
            if (outgoingNumber != null) {
                callNumber = outgoingNumber
                Log.d(TAG, "🎯 LIVE CALL: Outgoing call to $callNumber")

                // Notify Flutter
                MethodChannelManager.callMonitorChannel?.invokeMethod("onCallStateChanged", mapOf(
                    "state" to "OUTGOING",
                    "number" to callNumber,
                    "direction" to "outgoing"
                ))
            }
        }
    }

    fun cleanup() {
        stopMonitoring()
        callAudioProcessor?.cleanup()
    }
}
