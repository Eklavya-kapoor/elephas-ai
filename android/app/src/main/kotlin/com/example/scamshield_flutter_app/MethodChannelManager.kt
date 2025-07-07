package com.example.scamshield_flutter_app

import io.flutter.plugin.common.MethodChannel

object MethodChannelManager {
    var overlayMethodChannel: MethodChannel? = null
    var screenMonitorMethodChannel: MethodChannel? = null
    var ocrMethodChannel: MethodChannel? = null // <--- ADD THIS LINE
    // Add other channels here as needed, e.g., for SMS/Call if they communicate directly
}