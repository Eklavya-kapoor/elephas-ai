// android/app/src/main/kotlin/com/example/scamshield_flutter_app/BackgroundMonitorService.kt
package com.example.scamshield_flutter_app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import android.provider.Telephony // ADD THIS LINE

class BackgroundMonitorService : Service() {

    private lateinit var telephonyManager: TelephonyManager
    private lateinit var callStateMonitor: CallStateMonitor
    private lateinit var smsReceiver: SmsReceiver

    companion object {
        private const val TAG = "BackgroundMonitorService"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "BackgroundMonitorService onCreate")

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        callStateMonitor = CallStateMonitor(applicationContext)
        telephonyManager.listen(callStateMonitor, PhoneStateListener.LISTEN_CALL_STATE)

        smsReceiver = SmsReceiver()
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        registerReceiver(smsReceiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "BackgroundMonitorService onStartCommand")

        val channelId = "ElephaseAIBackgroundChannel"
        val channelName = "Elephas AI Call/SMS Monitoring"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                channelName,
                android.app.NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notification = android.app.Notification.Builder(this, channelId)
            .setContentTitle("Elephas AI")
            .setContentText("Monitoring calls and messages for scams...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()

        startForeground(101, notification)

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "BackgroundMonitorService onDestroy")
        telephonyManager.listen(callStateMonitor, PhoneStateListener.LISTEN_NONE)
        unregisterReceiver(smsReceiver)
        stopForeground(STOP_FOREGROUND_REMOVE)
    }
}