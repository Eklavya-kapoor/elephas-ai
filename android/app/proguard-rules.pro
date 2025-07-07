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
-keep class * extends android.service.notification.NotificationListenerService
