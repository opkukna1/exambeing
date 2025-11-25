# ----------------------------------------------------------
# 1. FLUTTER WRAPPER RULES (Standard)
# ----------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ----------------------------------------------------------
# 2. SMART AUTH PLUGIN FIX (Most Important)
# ----------------------------------------------------------
# Yeh line batati hai ki SmartAuth plugin ke code ko delete na kare
-keep class fman.ge.smart_auth.** { *; }
-dontwarn fman.ge.smart_auth.**

# ----------------------------------------------------------
# 3. GOOGLE PLAY SERVICES AUTH (Credentials)
# ----------------------------------------------------------
# Yeh lines Google Auth ki files ko safe rakhti hain
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep class com.google.android.gms.auth.api.phone.** { *; }
-dontwarn com.google.android.gms.auth.api.credentials.**
-dontwarn com.google.android.gms.auth.api.phone.**

# ----------------------------------------------------------
# 4. GOOGLE COMMON & TASKS (Dependencies)
# ----------------------------------------------------------
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# ----------------------------------------------------------
# 5. ANDROID CREDENTIALS MANAGER (Newer Android versions)
# ----------------------------------------------------------
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**
