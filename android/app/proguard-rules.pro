# Flutter-specific ProGuard rules
# Flutter's engine rules are included via proguard-android-optimize.txt.
# Add any app-specific rules below if needed in the future.

# Keep Hive type adapters
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
