package com.app.rtmp_publisher

import android.content.Context
import android.util.Size
import com.pedro.encoder.input.video.CameraHelper.Facing
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import com.pedro.rtplibrary.view.OpenGlView

/**
 * Preview-only pipeline — delegates orientation and resolution to [PreviewOrientationPolicy].
 */
object PreviewPipeline {

    fun viewSize(glView: OpenGlView): Size {
        val frame = glView.holder?.surfaceFrame
        return if (frame != null && frame.width() > 0 && frame.height() > 0) {
            Size(frame.width(), frame.height())
        } else {
            Size(0, 0)
        }
    }

    fun selectedPreviewSize(
        context: Context,
        cameraId: String,
        preset: Camera.ResolutionPreset,
        broadcastMode: String,
        glView: OpenGlView,
    ): Size {
        val view = viewSize(glView)
        return PreviewSizeSelector.selectPreviewSize(
            context,
            cameraId,
            preset,
            broadcastMode,
            view.width,
            view.height,
        )
    }

    fun configureForBroadcastOrientation(
        rtmpCamera: RtmpCamera2,
        glView: OpenGlView,
        context: Context,
        cameraId: String,
        preset: Camera.ResolutionPreset,
        broadcastMode: String,
        facing: Facing,
        preserveStream: Boolean = rtmpCamera.isStreaming,
    ): Boolean = PreviewOrientationPolicy.reconfigurePreview(
        rtmpCamera,
        glView,
        context,
        cameraId,
        preset,
        broadcastMode,
        facing,
        preserveStream,
    )
}
