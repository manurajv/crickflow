package com.mavixas.crickflow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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
