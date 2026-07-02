package com.app.rtmp_publisher

import android.content.Context
import android.util.Log
import com.pedro.rtplibrary.view.OpenGlView

/**
 * [OpenGlView] is required for RTMP overlay burn-in — [LightOpenGlView.setFilter]
 * is a no-op in pedro rtplibrary 1.9.6, so filters never reach the encoder.
 *
 * Like [SafeLightOpenGlView], wait until the [SurfaceHolder] is valid before
 * starting Pedro's GL thread (Flutter platform views often lack a surface at
 * construction time).
 */
class SafeOpenGlView(context: Context) : OpenGlView(context) {

    override fun run() {
        while (!Thread.currentThread().isInterrupted) {
            val surfaceHolder = holder
            val surface = surfaceHolder?.surface
            val frame = surfaceHolder?.surfaceFrame
            if (surface != null && surface.isValid &&
                frame != null && frame.width() > 0 && frame.height() > 0
            ) {
                break
            }
            try {
                Thread.sleep(WAIT_MS)
            } catch (_: InterruptedException) {
                return
            }
        }
        if (Thread.currentThread().isInterrupted) return
        try {
            super.run()
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "GL surface not ready", e)
        } catch (e: RuntimeException) {
            Log.e(TAG, "GL thread failed", e)
        }
    }

    companion object {
        private const val TAG = "SafeOpenGlView"
        private const val WAIT_MS = 20L
    }
}
