package com.inkpebble.randomrecall

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val BATTERY_CHANNEL = "com.inkpebble.randomrecall/battery"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Pre-seed the Firebase App Check debug token into the native SharedPreferences
        // file that the Firebase App Check debug SDK reads from. This ensures the token
        // matches the one registered in Firebase Console, even after clearing app data.
        // Only applies to debug builds — release builds use Play Integrity.
        val isDebuggable = applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (isDebuggable) {
            getSharedPreferences("com.google.firebase.appcheck.debug.store", Context.MODE_PRIVATE)
                .edit()
                .putString("debug_token", "F8555F6B-CCF7-450D-9302-3E135386637F")
                .apply()
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            // Fallback: open general battery optimization settings
                            val fallback = Intent(
                                Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                            )
                            startActivity(fallback)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
