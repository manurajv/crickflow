package com.app.rtmp_publisher

import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.pedro.encoder.input.gl.render.filters.`object`.ImageObjectFilterRender
import com.pedro.encoder.utils.gl.TranslateTo
import com.pedro.rtplibrary.rtmp.RtmpCamera2

/**
 * Burns Flutter-rendered PNG overlays into the outgoing RTMP video via GL filter.
 *
 * Uses [RtmpCamera2.glInterface] so this works with both [OpenGlView] and
 * [LightOpenGlView] preview surfaces.
 */
@RequiresApi(Build.VERSION_CODES.JELLY_BEAN_MR2)
class StreamOverlayBurnIn(
    private val rtmpCamera: RtmpCamera2,
) {
    private var filter: ImageObjectFilterRender? = null
    private var lastBitmap: android.graphics.Bitmap? = null

    fun updateOverlay(pngBytes: ByteArray, width: Int, height: Int) {
        if (pngBytes.isEmpty() || width <= 0 || height <= 0) {
            clearOverlay()
            return
        }

        if (!rtmpCamera.isStreaming) {
            Log.d(TAG, "updateOverlay skipped — not streaming yet")
            return
        }

        val bitmap = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
        if (bitmap == null) {
            Log.w(TAG, "updateOverlay: failed to decode PNG")
            return
        }

        try {
            val filterRender = filter ?: ImageObjectFilterRender().also {
                filter = it
                rtmpCamera.glInterface.setFilter(it)
                Log.d(TAG, "Overlay GL filter attached (stream ${rtmpCamera.streamWidth}x${rtmpCamera.streamHeight})")
            }

            val streamW = rtmpCamera.streamWidth.takeIf { it > 0 } ?: width
            val streamH = rtmpCamera.streamHeight.takeIf { it > 0 } ?: height

            filterRender.setImage(bitmap)
            filterRender.setDefaultScale(streamW, streamH)
            filterRender.setScale(100f, 100f)
            filterRender.setPosition(TranslateTo.CENTER)
            filterRender.setAlpha(1f)

            lastBitmap?.recycle()
            lastBitmap = bitmap
        } catch (e: Exception) {
            bitmap.recycle()
            Log.e(TAG, "updateOverlay failed", e)
        }
    }

    fun clearOverlay() {
        filter?.setAlpha(0f)
    }

    fun release() {
        filter?.setAlpha(0f)
        filter = null
        lastBitmap?.recycle()
        lastBitmap = null
    }

    companion object {
        private const val TAG = "StreamOverlayBurnIn"
    }
}
