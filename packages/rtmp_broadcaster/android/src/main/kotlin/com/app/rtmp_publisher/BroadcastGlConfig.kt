package com.app.rtmp_publisher

import android.content.Context
import android.util.Log
import android.util.Size
import com.app.rtmp_publisher.Camera.ResolutionPreset
import com.pedro.encoder.input.video.CameraHelper

/**
 * Single source of truth for Pedro GL preview, encoder, and RTMP dimensions.
 *
 * On a portrait-locked Activity, Pedro [startPreview] always uses swapped GL size
 * (720×1280 from a 1280×720 sensor) and display-based rotation — regardless of
 * landscape broadcast mode. [previewGlOutput] must match that so go-live never
 * changes the in-app preview.
 *
 * Landscape 16:9 UI uses [StudioLandscapeRotation] for overlays; preview GL stays at
 * [previewGlOutput]. Landscape = same preview + GlInterface.setStreamRotation(270) (90° left).
 */
object BroadcastGlConfig {
    private const val TAG = "BroadcastGlConfig"

    data class Config(
        /** Camera2 capture buffer (camcorder profile, e.g. 1280×720). */
        val cameraBuffer: Size,
        /** RTMP / overlay canvas size (720×1280 portrait or 1280×720 landscape). */
        val streamOutput: Size,
        /** Pedro OpenGlView frame size — must match pre-live startPreview on this Activity. */
        val previewGlOutput: Size,
        /** GlInterface.setRotation — derived from [previewStartRotation], not broadcast mode. */
        val glRotation: Int,
        val streamRotation: Int,
        /** prepareVideo rotation — always 0; preview GL handles display orientation. */
        val videoEncoderRotation: Int,
        val previewStartRotation: Int,
        val broadcastMode: String,
        val displayRotation: Int,
    ) {
        val encoderWidth: Int get() = streamOutput.width
        val encoderHeight: Int get() = streamOutput.height
        val previewGlWidth: Int get() = previewGlOutput.width
        val previewGlHeight: Int get() = previewGlOutput.height
    }

    fun compute(
        context: Context,
        cameraId: String,
        preset: ResolutionPreset,
        broadcastMode: String,
    ): Config {
        val cameraBuffer = CameraUtils.computeBestPreviewSize(cameraId, preset)
        val streamOutput = StreamEncoderConfig.streamOutput(
            context,
            cameraId,
            preset,
            broadcastMode,
        )
        val displayRotation = PreviewOrientationPolicy.displayRotation(context)
        val landscapeBroadcast = PreviewSizeSelector.isLandscapeBroadcast(broadcastMode)
        val previewStartRotation = displayRotation
        val previewGlOutput = previewGlOutputFor(context, cameraBuffer)
        val glRotation = glRotationForPreviewStart(previewStartRotation)
        val videoEncoderRotation = videoEncoderRotationFor(landscapeBroadcast)

        val config = Config(
            cameraBuffer = cameraBuffer,
            streamOutput = Size(streamOutput.width, streamOutput.height),
            previewGlOutput = previewGlOutput,
            glRotation = glRotation,
            streamRotation = streamOutput.streamRotation,
            videoEncoderRotation = videoEncoderRotation,
            previewStartRotation = previewStartRotation,
            broadcastMode = broadcastMode,
            displayRotation = displayRotation,
        )
        Log.i(
            TAG,
            "Computed mode=$broadcastMode preset=$preset " +
                "camera=${cameraBuffer.width}x${cameraBuffer.height} " +
                "stream=${config.encoderWidth}x${config.encoderHeight} " +
                "previewGl=${config.previewGlWidth}x${config.previewGlHeight} " +
                "glRot=$glRotation encRot=$videoEncoderRotation previewRot=$previewStartRotation",
        )
        return config
    }

    /** Pedro startPreview GL size on this Activity (portrait Activity → swap buffer dims). */
    fun previewGlOutputFor(context: Context, cameraBuffer: Size): Size {
        return if (CameraHelper.isPortrait(context)) {
            Size(cameraBuffer.height, cameraBuffer.width)
        } else {
            Size(cameraBuffer.width, cameraBuffer.height)
        }
    }

    /** Pedro startPreview: setRotation(rotation == 0 ? 270 : rotation - 90). */
    fun glRotationForPreviewStart(previewStartRotation: Int): Int {
        return if (previewStartRotation == 0) 270 else previewStartRotation - 90
    }

    /**
     * Always 0 — encoder matches preview GL; no extra stream rotation.
     */
    fun videoEncoderRotationFor(@Suppress("UNUSED_PARAMETER") landscapeBroadcast: Boolean): Int = 0

    fun applyPreviewGlToInterface(
        glInterface: com.pedro.rtplibrary.view.GlInterface,
        config: Config,
    ) {
        applyGlToInterface(glInterface, config, streaming = false)
    }

    /**
     * Preview uses [previewGlOutput]. While streaming landscape, encoder GL uses [streamOutput]
     * (1280×720) so YouTube fills 16:9 width — not pillarboxed 9:16 in a 16:9 frame.
     */
    fun applyGlToInterface(
        glInterface: com.pedro.rtplibrary.view.GlInterface,
        config: Config,
        streaming: Boolean,
    ) {
        val landscape = PreviewSizeSelector.isLandscapeBroadcast(config.broadcastMode)
        if (streaming && landscape) {
            glInterface.setEncoderSize(config.encoderWidth, config.encoderHeight)
            Log.d(
                TAG,
                "Stream GL applied ${config.encoderWidth}x${config.encoderHeight} rot=${config.glRotation}",
            )
        } else {
            glInterface.setEncoderSize(config.previewGlWidth, config.previewGlHeight)
            Log.d(
                TAG,
                "Preview GL applied ${config.previewGlWidth}x${config.previewGlHeight} rot=${config.glRotation}",
            )
        }
        glInterface.setRotation(config.glRotation)
    }

    fun overlayScaleFor(config: Config, streaming: Boolean): Pair<Int, Int> {
        val landscape = PreviewSizeSelector.isLandscapeBroadcast(config.broadcastMode)
        return if (streaming && landscape) {
            config.encoderWidth to config.encoderHeight
        } else {
            config.previewGlWidth to config.previewGlHeight
        }
    }
}
