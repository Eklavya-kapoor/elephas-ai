package com.elephas.ai;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.provider.Telephony;
import android.telephony.SmsMessage;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;

public class SmsReceiver extends BroadcastReceiver {

    private static final String TAG = "SmsReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent != null && Telephony.Sms.Intents.SMS_RECEIVED_ACTION.equals(intent.getAction())) {
            SmsMessage[] smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent);
            if (smsMessages == null) return;

            for (SmsMessage message : smsMessages) {
                if (message == null) continue;
                String sender = message.getOriginatingAddress();
                if (sender == null) sender = "Unknown";
                String body = message.getMessageBody();
                if (body == null) body = "";

                Log.d(TAG, "New SMS from: " + sender + ", Body: " + body);

                if (!body.isEmpty()) {
                    if (MethodChannelManager.overlayMethodChannel != null) {
                        Map<String, Object> map = new HashMap<>();
                        map.put("sender", sender);
                        map.put("messageBody", body);
                        map.put("timestamp", System.currentTimeMillis());

                        MethodChannelManager.overlayMethodChannel.invokeMethod("onIncomingSms", map);
                        Log.d(TAG, "Sent SMS to Flutter: Sender=" + sender + ", Message=" + body);
                    } else {
                        Log.e(TAG, "Overlay MethodChannel not initialized for SmsReceiver.");
                    }
                }
            }
        }
    }
}
