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
    private var overlayScaleWidth: Int = 0,
    private var overlayScaleHeight: Int = 0,
) {
    /** Called after each overlay attach so stream rotation survives GL filter updates. */
    var onOverlayApplied: (() -> Unit)? = null
    var streamRotationDegrees: (() -> Int)? = null
    private var filter: ImageObjectFilterRender? = null
    private var lastBitmap: android.graphics.Bitmap? = null
    private var overlayAttached = false
    private var updateCount = 0
    private var pendingPng: ByteArray? = null
    private var pendingWidth = 0
    private var pendingHeight = 0

    private fun resolveScaleWidth(): Int {
        if (overlayScaleWidth > 0) return overlayScaleWidth
        val w = rtmpCamera.streamWidth
        val h = rtmpCamera.streamHeight
        if (w > 0 && h > 0) return minOf(w, h)
        return 720
    }

    private fun resolveScaleHeight(): Int {
        if (overlayScaleHeight > 0) return overlayScaleHeight
        val w = rtmpCamera.streamWidth
        val h = rtmpCamera.streamHeight
        if (w > 0 && h > 0) return maxOf(w, h)
        return 1280
    }

    fun setOverlayScale(width: Int, height: Int) {
        if (width > 0 && height > 0) {
            overlayScaleWidth = width
            overlayScaleHeight = height
        }
    }

    fun updateOverlay(pngBytes: ByteArray, width: Int, height: Int) {
        if (pngBytes.isEmpty() || width <= 0 || height <= 0) {
            Log.d(TAG, "updateOverlay skipped — empty payload (${pngBytes.size} bytes, ${width}x$height)")
            clearOverlay()
            pendingPng = null
            return
        }

        pendingPng = pngBytes
        pendingWidth = width
        pendingHeight = height

        if (!rtmpCamera.isStreaming) {
            Log.d(TAG, "updateOverlay queued — not streaming yet (${pngBytes.size} bytes, ${width}x$height)")
            return
        }

        applyPendingOverlay()
    }

    /** Re-attach overlay filter after GL pipeline restart while streaming. */
    fun onEncoderPipelineReady() {
        if (!rtmpCamera.isStreaming) return
        val png = pendingPng
        if (png != null && pendingWidth > 0 && pendingHeight > 0) {
            Log.i(TAG, "Re-applying queued overlay after GL pipeline restore")
            applyPendingOverlay()
            return
        }
        if (lastBitmap != null && overlayAttached) {
            reattachExistingFilter()
        }
    }

    private fun applyPendingOverlay() {
        val pngBytes = pendingPng ?: return
        val width = pendingWidth
        val height = pendingHeight
        if (width <= 0 || height <= 0) return

        val bitmap = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size, BITMAP_OPTS)
        if (bitmap == null) {
            Log.w(TAG, "updateOverlay: failed to decode PNG (${pngBytes.size} bytes)")
            return
        }

        try {
            val streamW = resolveScaleWidth()
            val streamH = resolveScaleHeight()
            val glInterface = rtmpCamera.glInterface
            if (glInterface == null) {
                Log.w(TAG, "updateOverlay skipped — glInterface null")
                bitmap.recycle()
                return
            }

            val filterRender = filter ?: ImageObjectFilterRender().also {
                filter = it
                glInterface.setFilter(it)
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

            PedroCameraBridge.relinkEncoderSurface(rtmpCamera)
            StreamPipelineLog.overlayBurnIn(
                pngW = bitmap.width,
                pngH = bitmap.height,
                scaleW = streamW,
                scaleH = streamH,
                streamRot = streamRotationDegrees?.invoke() ?: 0,
            )
            onOverlayApplied?.invoke()

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

    private fun reattachExistingFilter() {
        val existing = filter ?: return
        val glInterface = rtmpCamera.glInterface ?: return
        try {
            glInterface.setFilter(existing)
            existing.setAlpha(1f)
            PedroCameraBridge.relinkEncoderSurface(rtmpCamera)
            Log.i(TAG, "Overlay GL filter re-attached after pipeline restore")
        } catch (e: Exception) {
            Log.e(TAG, "reattachExistingFilter failed", e)
        }
    }

    fun clearOverlay() {
        pendingPng = null
        pendingWidth = 0
        pendingHeight = 0
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
        pendingPng = null
        pendingWidth = 0
        pendingHeight = 0
        lastBitmap?.recycle()
        lastBitmap = null
    }

    companion object {
        private const val TAG = "StreamOverlayBurnIn"
        private val BITMAP_OPTS = BitmapFactory.Options().apply {
            inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
            inScaled = false
        }
    }
}
