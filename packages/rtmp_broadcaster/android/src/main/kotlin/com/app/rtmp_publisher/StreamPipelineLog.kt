package com.app.rtmp_publisher

import android.util.Log
import com.pedro.rtplibrary.rtmp.RtmpCamera2

/**
 * Filter logcat with: adb logcat -s CrickFlowStream
 *
 * Logs preview GL vs RTMP encoder state so you can verify landscape = same preview + rotate left.
 */
object StreamPipelineLog {
    const val TAG = "CrickFlowStream"

    fun previewLocked(config: BroadcastGlConfig.Config, mode: String) {
        Log.i(
            TAG,
            "PREVIEW_LOCKED mode=$mode " +
                "previewGl=${config.previewGlWidth}x${config.previewGlHeight} glRot=${config.glRotation} " +
                "cameraBuf=${config.cameraBuffer.width}x${config.cameraBuffer.height} " +
                "targetStream=${config.encoderWidth}x${config.encoderHeight}",
        )
    }

    fun goLive(
        mode: String,
        encW: Int,
        encH: Int,
        encRot: Int,
        streamRot: Int,
        previewGlW: Int,
        previewGlH: Int,
        glRot: Int,
    ) {
        val landscape = PreviewSizeSelector.isLandscapeBroadcast(mode)
        Log.i(
            TAG,
            "GO_LIVE mode=$mode landscape=$landscape " +
                "prepareVideo=${encW}x${encH} encRot=$encRot " +
                "setStreamRotation=$streamRot " +
                "(same previewGl=${previewGlW}x${previewGlH} glRot=$glRot; " +
                if (landscape) {
                    "landscape=streamGl16x9+rotate90left"
                } else {
                    "portrait=preview as-is"
                } + ")",
        )
    }

    fun streamRotationApplied(degrees: Int, mode: String) {
        Log.i(TAG, "STREAM_ROTATION mode=$mode degrees=$degrees")
    }

    fun pipelineLinked(
        rtmpCamera: RtmpCamera2,
        config: BroadcastGlConfig.Config,
        mode: String,
    ) {
        Log.i(
            TAG,
            "PIPELINE_LINKED mode=$mode " +
                "rtmpAdvertised=${rtmpCamera.streamWidth}x${rtmpCamera.streamHeight} " +
                "previewGl=${config.previewGlWidth}x${config.previewGlHeight} glRot=${config.glRotation} " +
                "cameraBuf=${config.cameraBuffer.width}x${config.cameraBuffer.height} " +
                "streaming=${rtmpCamera.isStreaming}",
        )
    }

    fun overlayBurnIn(
        pngW: Int,
        pngH: Int,
        scaleW: Int,
        scaleH: Int,
        streamRot: Int,
    ) {
        Log.i(
            TAG,
            "OVERLAY_BURNIN png=${pngW}x$pngH scaleTo=${scaleW}x$scaleH streamRot=$streamRot",
        )
    }
}
