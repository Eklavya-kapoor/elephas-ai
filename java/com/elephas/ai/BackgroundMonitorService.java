package com.elephas.ai;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.IBinder;
import android.provider.Telephony;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import android.util.Log;

public class BackgroundMonitorService extends Service {

    private static final String TAG = "BackgroundMonitorService";

    private TelephonyManager telephonyManager;
    private CallStateMonitor callStateMonitor;
    private SmsReceiver smsReceiver;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "BackgroundMonitorService onCreate");

        telephonyManager = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
        callStateMonitor = new CallStateMonitor(getApplicationContext());
        if (telephonyManager != null) {
            telephonyManager.listen(callStateMonitor, PhoneStateListener.LISTEN_CALL_STATE);
        }

        smsReceiver = new SmsReceiver();
        IntentFilter filter = new IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION);
        registerReceiver(smsReceiver, filter);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "BackgroundMonitorService onStartCommand");

        String channelId = "ElephaseAIBackgroundChannel";
        String channelName = "Elephas AI Call/SMS Monitoring";
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && notificationManager != null) {
            NotificationChannel channel = new NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW
            );
            notificationManager.createNotificationChannel(channel);
        }

        Notification notification;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notification = new Notification.Builder(this, channelId)
                    .setContentTitle("Elephas AI")
                    .setContentText("Monitoring calls and messages for scams...")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .build();
        } else {
            notification = new Notification.Builder(this)
                    .setContentTitle("Elephas AI")
                    .setContentText("Monitoring calls and messages for scams...")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .build();
        }

        startForeground(101, notification);

        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "BackgroundMonitorService onDestroy");
        if (telephonyManager != null && callStateMonitor != null) {
            telephonyManager.listen(callStateMonitor, PhoneStateListener.LISTEN_NONE);
        }
        if (smsReceiver != null) {
            try {
                unregisterReceiver(smsReceiver);
            } catch (Exception e) {
                Log.e(TAG, "Error unregistering smsReceiver: " + e.getMessage());
            }
        }
        stopForeground(true);
    }
}
