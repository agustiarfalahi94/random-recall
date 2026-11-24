# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase / Google Play services are NOT kept here on purpose: every one of
# those AARs ships its own consumer ProGuard rules (e.g.
# firebase-common-22.2.0/proguard.txt) that keep exactly the reflective entry
# points. Blanket keeping `com.google.firebase.**` and `com.google.android.gms.**`
# left their whole codebase unrenamed, which is what pushed Play's DEX
# obfuscation metric down to 18% (the threshold is 25%).

# Keep crash stack traces readable (de-obfuscate using build/debug-info/)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter Play Store split install stubs (not used, suppress R8 missing class warnings)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
