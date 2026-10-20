# Keep ML Kit related classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Keep OkHttp and Retrofit for API communication
-keepattributes Signature, InnerClasses
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit

# Keep coroutines
-keepclassmembernames class kotlinx.** { volatile <fields>; }
-keepclassmembers class kotlinx.coroutines.** { *; }
-keep class kotlinx.coroutines.android.** { *; }

# Keep any native methods
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep accessibility service classes
-keep class * extends android.accessibilityservice.AccessibilityService

# Keep all app classes - MainActivity, OverlayService, OverlayPlugin, SmsReceiver,
# BackgroundMonitorService, MethodChannelManager, etc are referenced by exact name
# from AndroidManifest.xml and Flutter MethodChannels; renaming any of them breaks
# the whole capture/alert pipeline with a runtime ClassNotFoundException that
# debug builds (unminified) would never surface.
-keep class com.elephas.ai.** { *; }
