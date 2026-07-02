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
 * Requires [SafeOpenGlView] — [com.pedro.rtplibrary.view.LightOpenGlView.setFilter]
 * is a no-op in pedro rtplibrary 1.9.6.
 */
@RequiresApi(Build.VERSION_CODES.JELLY_BEAN_MR2)
class StreamOverlayBurnIn(
    private val rtmpCamera: RtmpCamera2,
) {
    private var filter: ImageObjectFilterRender? = null
    private var lastBitmap: android.graphics.Bitmap? = null
    private var overlayAttached = false
    private var updateCount = 0

    fun updateOverlay(pngBytes: ByteArray, width: Int, height: Int) {
        if (pngBytes.isEmpty() || width <= 0 || height <= 0) {
            Log.d(TAG, "updateOverlay skipped — empty payload (${pngBytes.size} bytes, ${width}x$height)")
            clearOverlay()
            return
        }

        if (!rtmpCamera.isStreaming) {
            Log.d(TAG, "updateOverlay skipped — not streaming yet (${pngBytes.size} bytes)")
            return
        }

        val bitmap = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
        if (bitmap == null) {
            Log.w(TAG, "updateOverlay: failed to decode PNG (${pngBytes.size} bytes)")
            return
        }

        try {
            val streamW = rtmpCamera.streamWidth.takeIf { it > 0 } ?: width
            val streamH = rtmpCamera.streamHeight.takeIf { it > 0 } ?: height

            val filterRender = filter ?: ImageObjectFilterRender().also {
                filter = it
                rtmpCamera.glInterface.setFilter(it)
                overlayAttached = true
                Log.i(
                    TAG,
                    "Overlay GL filter attached — stream=${streamW}x$streamH png=${bitmap.width}x${bitmap.height}",
                )
            }

            filterRender.setImage(bitmap)
            filterRender.setDefaultScale(streamW, streamH)
            filterRender.setScale(100f, 100f)
            filterRender.setPosition(TranslateTo.CENTER)
            filterRender.setAlpha(1f)

            lastBitmap?.recycle()
            lastBitmap = bitmap

            updateCount++
            if (updateCount <= 3 || updateCount % 25 == 0) {
                Log.d(
                    TAG,
                    "Frame composited #$updateCount — png=${bitmap.width}x${bitmap.height} " +
                        "stream=${streamW}x$streamH bytes=${pngBytes.size}",
                )
            }
        } catch (e: Exception) {
            bitmap.recycle()
            Log.e(TAG, "updateOverlay failed", e)
        }
    }

    fun clearOverlay() {
        if (filter != null) {
            filter?.setAlpha(0f)
            Log.d(TAG, "Overlay cleared (alpha=0)")
        }
    }

    fun release() {
        if (overlayAttached) {
            Log.d(TAG, "Overlay filter released after $updateCount updates")
        }
        filter?.setAlpha(0f)
        filter = null
        overlayAttached = false
        updateCount = 0
        lastBitmap?.recycle()
        lastBitmap = null
    }

    companion object {
        private const val TAG = "StreamOverlayBurnIn"
    }
}
