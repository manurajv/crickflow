# CrickFlow release R8 / ProGuard rules.
# Required when minifyEnabled + shrinkResources are true.

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core / deferred components (Flutter may reference)
-dontwarn com.google.android.play.core.**

# Firebase + Google Play services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Crashlytics (readable stacks when mapping uploaded)
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# AdMob / GMA
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class com.google.android.gms.common.api.internal.** { *; }

# Gson / reflective JSON (plugins)
-keepattributes Signature
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# CrickFlow RTMP / Pedro encoder (path package)
-keep class com.app.rtmp_publisher.** { *; }
-keep class com.pedro.** { *; }
-keep class com.pedro.encoder.input.gl.render.filters.** { *; }
-keep class com.pedro.encoder.input.gl.render.filters.object.** { *; }
-dontwarn com.pedro.**
-dontwarn org.jetbrains.annotations.**
# Facebook Live uses RTMPS — keep OSSRS TLS socket helpers from R8 shrink
-keep class net.ossrs.rtmp.** { *; }
-dontwarn net.ossrs.rtmp.**

# Keep bitmap/PNG decode path used by overlay burn-in
-keep class android.graphics.Bitmap { *; }
-keep class android.graphics.BitmapFactory { *; }

# Image cropper / uCrop
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# WebView / JavaScript bridges
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }
