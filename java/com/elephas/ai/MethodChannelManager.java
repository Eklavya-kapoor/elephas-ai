package com.elephas.ai;

import io.flutter.plugin.common.MethodChannel;

/**
 * Holds MethodChannels created in MainActivity so other native classes
 * (services, plugins) can send data back to Flutter.
 * Public static fields work from both Java and Kotlin code.
 */
public final class MethodChannelManager {
    public static MethodChannel overlayMethodChannel;
    public static MethodChannel screenMonitorMethodChannel;
    public static MethodChannel ocrMethodChannel;
    public static MethodChannel callMonitorChannel;
    public static MethodChannel speechRecognitionChannel;
    public static MethodChannel callControlChannel;

    private MethodChannelManager() {
        // Utility class, no instances
    }
}
