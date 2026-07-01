package com.app.rtmp_publisher

import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.pedro.encoder.input.gl.render.filters.`object`.ImageObjectFilterRender
import com.pedro.encoder.utils.gl.TranslateTo
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import com.pedro.rtplibrary.view.OpenGlView
import com.pedro.rtplibrary.view.OpenGlViewBase

/**
 * Burns Flutter-rendered PNG overlays into the outgoing RTMP video.
 *
 * Full [OpenGlView] supports GL filters; [LightOpenGlView] keeps preview stable
 * but overlay burn-in is skipped until streaming on a filter-capable view.
 */
@RequiresApi(Build.VERSION_CODES.JELLY_BEAN_MR2)
class StreamOverlayBurnIn(
    private val rtmpCamera: RtmpCamera2,
    private val glView: OpenGlViewBase
) {
    private var filter: ImageObjectFilterRender? = null

    fun updateOverlay(pngBytes: ByteArray, width: Int, height: Int) {
        if (pngBytes.isEmpty() || width <= 0 || height <= 0) {
            clearOverlay()
            return
        }

        val openGlView = glView as? OpenGlView
        if (openGlView == null) {
            Log.d(TAG, "Overlay burn-in skipped — preview uses LightOpenGlView")
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
                openGlView.setFilter(it)
            }

            val streamW = rtmpCamera.streamWidth.takeIf { it > 0 } ?: width
            val streamH = rtmpCamera.streamHeight.takeIf { it > 0 } ?: height

            filterRender.setImage(bitmap)
            filterRender.setDefaultScale(streamW, streamH)
            filterRender.setPosition(TranslateTo.CENTER)
            filterRender.setAlpha(1f)
        } finally {
            bitmap.recycle()
        }
    }

    fun clearOverlay() {
        filter?.setAlpha(0f)
    }

    fun release() {
        filter = null
    }

    companion object {
        private const val TAG = "StreamOverlayBurnIn"
    }
}
