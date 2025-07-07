package com.example.scamshield_flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (message in smsMessages) {
                val sender = message.originatingAddress ?: "Unknown"
                val body = message.messageBody ?: ""

                Log.d(TAG, "New SMS from: $sender, Body: $body")

                if (body.isNotEmpty()) {
                    // Send to Flutter for analysis via the OverlayService's channel
                    MethodChannelManager.overlayMethodChannel?.let { channel ->
                        channel.invokeMethod(
                            "onIncomingSms", // Use the method name expected by Flutter
                            mapOf(
                                "sender" to sender,
                                "messageBody" to body,
                                "timestamp" to System.currentTimeMillis()
                            )
                        )
                        Log.d(TAG, "Sent SMS to Flutter: Sender=$sender, Message=$body")
                    } ?: run {
                        Log.e(TAG, "Overlay MethodChannel not initialized for SmsReceiver.")
                    }
                }
            }
        }
    }
}