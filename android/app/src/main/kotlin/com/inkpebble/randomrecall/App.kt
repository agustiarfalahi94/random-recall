package com.inkpebble.randomrecall

import android.app.Application
import android.content.Context
import android.content.pm.ApplicationInfo

class App : Application() {
    override fun attachBaseContext(base: Context) {
        // Seed the Firebase App Check debug token BEFORE Firebase initializes.
        // Firebase uses a ContentProvider (FirebaseInitProvider) which runs after
        // attachBaseContext but before onCreate — so this is the earliest safe point.
        // Use .commit() (synchronous) to ensure the write is flushed before Firebase reads it.
        val isDebuggable = (base.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebuggable) {
            base.getSharedPreferences("com.google.firebase.appcheck.debug.store", Context.MODE_PRIVATE)
                .edit()
                .putString("debug_token", "f8555f6b-ccf7-450d-9302-3e135386637f")
                .commit()
        }
        super.attachBaseContext(base)
    }
}
