package com.app.rtmp_publisher

import android.content.Context
import android.util.Log
import com.pedro.rtplibrary.view.LightOpenGlView

/**
 * [LightOpenGlView] starts its GL thread in the constructor, before the
 * [SurfaceHolder] is valid (common with Flutter platform views). Wait until
 * the surface is ready before calling into Pedro's EGL setup.
 */
class SafeLightOpenGlView(context: Context) : LightOpenGlView(context) {

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
        private const val TAG = "SafeLightOpenGlView"
        private const val WAIT_MS = 20L
    }
}
