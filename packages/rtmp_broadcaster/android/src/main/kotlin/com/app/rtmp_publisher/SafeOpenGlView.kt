package com.app.rtmp_publisher

import android.content.Context
import android.util.Log
import android.view.SurfaceHolder
import com.pedro.rtplibrary.view.OpenGlView

/**
 * [OpenGlView] is required for RTMP overlay burn-in — [LightOpenGlView.setFilter]
 * is a no-op in pedro rtplibrary 1.9.6, so filters never reach the encoder.
 *
 * Waits until the [SurfaceHolder] is valid before starting Pedro's GL thread.
 * Forwards surface lifecycle to [PreviewSurfaceLifecycle.Listener] so Camera2
 * can detach before GL stops and reattach only after a new valid surface exists.
 */
class SafeOpenGlView(context: Context) : OpenGlView(context) {

    var surfaceLifecycleListener: PreviewSurfaceLifecycle.Listener? = null
    var previewSizeChangedListener: ((width: Int, height: Int) -> Unit)? = null
    private var surfaceGeneration = 0L

    fun currentSurfaceGeneration(): Long = surfaceGeneration

    override fun surfaceCreated(holder: SurfaceHolder) {
        surfaceGeneration++
        val generation = surfaceGeneration
        Log.i(TAG, "surfaceCreated gen=$generation")
        super.surfaceCreated(holder)
        surfaceLifecycleListener?.onPreviewSurfaceAvailable(generation)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        super.surfaceChanged(holder, format, width, height)
        if (width > 0 && height > 0) {
            previewSizeChangedListener?.invoke(width, height)
            surfaceLifecycleListener?.onPreviewSurfaceAvailable(surfaceGeneration)
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        surfaceGeneration++
        val generation = surfaceGeneration
        Log.i(TAG, "surfaceDestroyed gen=$generation")
        // Notify BEFORE super — super stops GL thread and abandons the surface.
        surfaceLifecycleListener?.onPreviewSurfaceDestroyed(generation)
        super.surfaceDestroyed(holder)
    }

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
