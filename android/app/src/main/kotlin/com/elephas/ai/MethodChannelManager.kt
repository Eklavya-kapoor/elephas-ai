package com.elephas.ai

import io.flutter.plugin.common.MethodChannel

object MethodChannelManager {
    var overlayMethodChannel: MethodChannel? = null
    var screenMonitorMethodChannel: MethodChannel? = null
    var ocrMethodChannel: MethodChannel? = null
    var callMonitorChannel: MethodChannel? = null
    var speechRecognitionChannel: MethodChannel? = null
    var callControlChannel: MethodChannel? = null
    // Add other channels here as needed, e.g., for SMS/Call if they communicate directly
}