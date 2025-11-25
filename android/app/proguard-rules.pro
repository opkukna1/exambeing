# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Services Auth
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep class com.google.android.gms.auth.api.phone.** { *; }
-dontwarn com.google.android.gms.auth.api.credentials.**
-dontwarn com.google.android.gms.auth.api.phone.**

# Smart Auth Plugin
-keep class fman.ge.smart_auth.** { *; }
-dontwarn fman.ge.smart_auth.**

# Google Common & Tasks
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# Android Credentials
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**

# 👇 NEW RULES ADDED HERE 👇
# Google Play Feature Delivery (Split Install Fix)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
