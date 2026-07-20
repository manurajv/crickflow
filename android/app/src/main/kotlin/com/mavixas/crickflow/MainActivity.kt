package com.mavixas.crickflow

import android.app.Application
import android.os.Build
import android.os.Bundle
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must run before any WebView is created in a non-default process
        // (FCM background isolate). Prevents AdMob JavascriptEngine failures.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val processName = Application.getProcessName()
            if (packageName != processName) {
                WebView.setDataDirectorySuffix(processName)
            }
        }
        super.onCreate(savedInstanceState)
        // Warm the WebView factory so GMA can obtain a JS engine.
        try {
            WebView(this).apply {
                settings.javaScriptEnabled = true
                destroy()
            }
        } catch (_: Throwable) {
            // Non-fatal — ads widgets already retry on failure.
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLiveForeground" -> {
                    val title = call.argument<String>("title") ?: "CrickFlow Live"
                    StreamForegroundService.start(this, title)
                    result.success(null)
                }
                "stopLiveForeground" -> {
                    StreamForegroundService.stop(this)
                    result.success(null)
                }
                "updateLiveForeground" -> {
                    // Re-start with updated title (notification refresh).
                    val title = call.argument<String>("title") ?: "CrickFlow Live"
                    StreamForegroundService.start(this, title)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "com.mavixas.crickflow/stream_foreground"
    }
}
