package com.app.rtmp_publisher

import android.content.Context
import android.util.Size
import com.app.rtmp_publisher.Camera.ResolutionPreset

/**
 * Preview resolution for Stream Studio.
 *
 * Uses the same camcorder profile size in portrait and landscape so field-of-view, zoom, and
 * framing stay identical when the device rotates — matching the stock camera app, which does not
 * swap to a different sensor output size on rotation.
 */
object PreviewSizeSelector {
    fun isLandscapeBroadcast(mode: String): Boolean =
        mode == "landscape" || mode == "landscapeLeft" || mode == "landscapeRight"

    fun selectPreviewSize(
        context: Context,
        cameraId: String,
        preset: ResolutionPreset,
        @Suppress("UNUSED_PARAMETER") broadcastMode: String,
        @Suppress("UNUSED_PARAMETER") viewWidth: Int,
        @Suppress("UNUSED_PARAMETER") viewHeight: Int,
    ): Size = CameraUtils.computeBestPreviewSize(cameraId, preset)
}
