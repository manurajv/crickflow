package com.app.rtmp_publisher

import android.content.Context
import android.util.Log
import com.app.rtmp_publisher.Camera.ResolutionPreset
import kotlin.math.min

/**
 * RTMP encoder output size and rotation metadata for broadcast orientation.
 *
 * Portrait vs landscape is encoded in [StreamOutput.width]/[height] (e.g. 720×1280 vs 1280×720).
 * [streamRotation] stays 0 so YouTube/RTMP players use frame dimensions directly.
 */
object StreamEncoderConfig {
    private const val TAG = "StreamEncoderConfig"

    data class StreamOutput(
        val width: Int,
        val height: Int,
        val streamRotation: Int,
    )

    fun streamOutput(
        context: Context,
        cameraId: String,
        preset: ResolutionPreset,
        broadcastMode: String,
    ): StreamOutput {
        val profile = CameraUtils.getBestAvailableCamcorderProfileForResolutionPreset(
            cameraId,
            preset,
        )
        val (targetW, targetH) = targetLandscapePixels(preset)

        var w = profile.videoFrameWidth
        var h = profile.videoFrameHeight
        if (w > targetW || h > targetH) {
            val scale = min(targetW.toFloat() / w, targetH.toFloat() / h)
            w = even((w * scale).toInt())
            h = even((h * scale).toInt())
        } else {
            w = even(w)
            h = even(h)
        }

        val landscape = PreviewSizeSelector.isLandscapeBroadcast(broadcastMode)
        val output = if (landscape) {
            StreamOutput(w, h, 0)
        } else {
            StreamOutput(h, w, 0)
        }
        Log.i(
            TAG,
            "Stream output mode=$broadcastMode preset=$preset → ${output.width}x${output.height} rot=${output.streamRotation}",
        )
        return output
    }

    private fun targetLandscapePixels(preset: ResolutionPreset): Pair<Int, Int> = when (preset) {
        ResolutionPreset.low, ResolutionPreset.medium -> 854 to 480
        ResolutionPreset.high -> 1280 to 720
        ResolutionPreset.veryHigh -> 1920 to 1080
        ResolutionPreset.ultraHigh -> 2560 to 1440
        ResolutionPreset.max -> 3840 to 2160
        else -> 1280 to 720
    }

    private fun even(v: Int): Int = v and 0xFFFFFFFE.toInt()
}
