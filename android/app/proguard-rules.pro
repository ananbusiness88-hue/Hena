# ============================================================
# HENA - R8 / ProGuard rules for the release build
# ============================================================
#
# This file is referenced from android/app/build.gradle.kts:
#
#     proguardFiles(
#         getDefaultProguardFile("proguard-android-optimize.txt"),
#         "proguard-rules.pro"
#     )
#
# It was missing from the repository, which meant the release build either
# failed during R8 or shipped without any application level rules.
#
# Design notes:
#   * The Flutter Gradle plugin already injects its own
#     `flutter_proguard_rules.pro` into the release build type, and it also
#     picks up this file automatically. The rules below therefore focus on
#     what the SDK does NOT cover.
#   * The Android libraries used by this app (Firebase, Play Services,
#     AndroidX, flutter_local_notifications) ship their own consumer
#     ProGuard rules inside their AARs, so they are applied automatically.
#     They are deliberately NOT blanket-kept here, because keeping them
#     would inflate the APK (it already ships ~27 MB of assets).
# ============================================================

# ------------------------------------------------------------
# 1. Flutter engine and plugins
# ------------------------------------------------------------
# The embedding classes are referenced from native code and from the
# plugin registrar, so R8 cannot see those references.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.plugin.**

# ------------------------------------------------------------
# 2. Attributes
# ------------------------------------------------------------
# Generic signatures and annotations are needed by the plugins that
# resolve types reflectively (Gson, Firebase, flutter_local_notifications).
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions
-keepattributes SourceFile,LineNumberTable

# ------------------------------------------------------------
# 3. Gson
# ------------------------------------------------------------
# Used transitively by flutter_local_notifications and by the Firebase
# SDK for its payload mapping.
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ------------------------------------------------------------
# 4. Optional dependencies that are absent at runtime
# ------------------------------------------------------------
# These are referenced by the desugared libraries and by Play Integrity,
# but are not shipped on every device or API level. Without these rules
# R8 aborts the build with "Missing class" warnings.
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.naming.**
-dontwarn sun.misc.**
-dontwarn java.lang.invoke.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.concurrent.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Play Core (deferred components / split install).
#
# The Flutter embedding ships code that talks to the Play Core deferred
# components API (FlutterPlayStoreSplitApplication and
# PlayStoreDeferredComponentManager), but this app does not use deferred
# components, so the Play Core library is not on the classpath.
#
# R8 in strict mode treats those references as an error and aborts the
# release build with:
#   "Missing class com.google.android.play.core.splitinstall.SplitInstallManager"
#
# The rules below are the ones R8 itself generated in
# build/app/outputs/mapping/release/missing_rules.txt, written at package
# level so that any future Play Core API stays covered.
-dontwarn com.google.android.play.core.**

# ------------------------------------------------------------
# 5. Application entry points
# ------------------------------------------------------------
# MainActivity is referenced from AndroidManifest.xml and is therefore
# kept automatically, but it is stated explicitly so that a future
# refactor cannot silently break app start-up.
-keep class com.hena.app.MainActivity { *; }

# ------------------------------------------------------------
# 6. Thermal printer plugin
# ------------------------------------------------------------
# The Bluetooth printer plugin resolves its device classes reflectively
# from the plugin registry.
-keep class com.example.thermal_printer.** { *; }
-dontwarn com.example.thermal_printer.**
