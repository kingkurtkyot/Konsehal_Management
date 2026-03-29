# Flutter Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Generative AI (Gemini) - Keep models and JSON classes
-keep class com.google.generativeai.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Fix for some Kotlin coroutine issues in R8
-keepclassmembers class kotlinx.coroutines.** {
    public *** *;
}

# Google Play Core (Fixes R8 missing class errors)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Google Play Core (Fixes R8 missing class errors)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Standard Android keep rules
-dontwarn android.util.Log
-dontwarn android.os.Bundle
-dontwarn android.view.View
-dontwarn android.view.ViewGroup
-dontwarn android.widget.**
