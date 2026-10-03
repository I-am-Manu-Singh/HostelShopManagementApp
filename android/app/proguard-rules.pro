
# ==============================================================================
# STRIP LOG STATEMENTS IN RELEASE BUILDS
# (Runs only in release builds where minification & R8 optimization are enabled.
#  Debug builds remain unaffected so logs continue to work normally during testing.)
# ==============================================================================
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int println(...);
}

-assumenosideeffects class java.io.PrintStream {
    public void println(java.lang.String);
    public void println(java.lang.Object);
    public void println(boolean);
    public void println(char);
    public void println(char[]);
    public void println(double);
    public void println(float);
    public void println(int);
    public void println(long);
    public void print(java.lang.String);
    public void print(java.lang.Object);
    public void print(boolean);
    public void print(char);
    public void print(char[]);
    public void print(double);
    public void print(float);
    public void print(int);
    public void print(long);
}

# Keep Kotlin Multiplatform & Compose attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep Serialization
-keepclassmembers class * {
    @kotlinx.serialization.Serializable *;
}
-keep class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**

# Keep Firebase, Google Play & Play Integrity
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.integrity.**

# Flutter and Flutter plugins keep rules
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.**  { *; }

# Google ML Kit and Camera
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Local Auth / Biometrics
-keep class androidx.biometric.** { *; }

# Just Audio Background
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# ESC POS and Bluetooth Printer
-dontwarn com.journeyapps.barcodescanner.**
-dontwarn com.google.zxing.**


