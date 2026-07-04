package com.app.rtmp_publisher

/**
 * Lifecycle-only bridge so the app foreground service can stop RTMP when the
 * task is removed from Recents without touching encoder/camera pipeline setup.
 */
object StreamLifecycleBridge {
    @Volatile
    var emergencyStop: (() -> Unit)? = null

    fun stopActiveStream() {
        emergencyStop?.invoke()
    }
}
