package com.theelefit.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// NOTE: Must extend FlutterFragmentActivity (not FlutterActivity) — the `health`
// plugin's Health Connect permission sheet only launches from a FragmentActivity.
// With plain FlutterActivity, requestAuthorization() silently no-ops on Android.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register FitDays SDK plugin
        flutterEngine.plugins.add(FitDaysPlugin())
    }
}
