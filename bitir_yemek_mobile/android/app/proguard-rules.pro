# Flutter-safe ProGuard / R8 keep rules.
# Flutter ships its own rules via the Gradle plugin, but these guard against
# common stripping issues with the engine, plugins and reflection.

# --- Flutter engine & embedding ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Keep annotations & generic signatures (needed by some plugins) ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# --- Mapbox (uses reflection / native bindings) ---
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

# --- Google Sign-In / Play Services ---
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Suppress common warnings for optional/desugared deps ---
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
