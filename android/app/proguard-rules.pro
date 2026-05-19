# Keep ML Kit text recognition classes (dynamic loading)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**

# Keep flutter_local_notifications
-keep class com.dexterous.** { *; }

# Keep workmanager / receive_sharing_intent / overlay
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
