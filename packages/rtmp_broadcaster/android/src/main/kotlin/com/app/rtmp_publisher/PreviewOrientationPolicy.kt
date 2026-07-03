package com.app.rtmp_publisher

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.util.Log
import android.util.Size
import com.pedro.encoder.input.video.CameraHelper
import com.pedro.encoder.input.video.CameraHelper.Facing
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import com.pedro.rtplibrary.view.OpenGlView

/**
 * Single source of truth for preview orientation, resolution, and session rebuild.
 *
 * Preview is reconfigured by stopping only the Camera2 preview session and calling Pedro's
 * official [RtmpCamera2.startPreview] path (or the streaming-safe equivalent). No Flutter-side
 * rotation, scaling, or matrix hacks are applied to the preview.
 */
object PreviewOrientationPolicy {
    private const val TAG = "PreviewOrientationPolicy"

    fun isLandscapeBroadcast(mode: String): Boolean =
        PreviewSizeSelector.isLandscapeBroadcast(mode)

    fun displayRotation(context: Context): Int =
        CameraHelper.getCameraOrientation(context)

    fun sensorOrientation(context: Context, cameraId: String): Int {
        return try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val characteristics = manager.getCameraCharacteristics(cameraId)
            characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
        } catch (e: Exception) {
            Log.w(TAG, "sensorOrientation fallback", e)
            90
        }
    }

    /**
     * Landscape: same preview pixels as portrait, then encoder rotates 90° left (CCW = 270°)
     * so YouTube receives 16:9. Portrait: 0 (already working).
     */
    fun streamRotationFor(
        @Suppress("UNUSED_PARAMETER") context: Context,
        @Suppress("UNUSED_PARAMETER") cameraId: String,
        broadcastMode: String,
    ): Int = if (PreviewSizeSelector.isLandscapeBroadcast(broadcastMode)) 270 else 0

    fun selectedPreviewSize(
        context: Context,
        cameraId: String,
        preset: Camera.ResolutionPreset,
        broadcastMode: String,
        glView: OpenGlView,
    ): Size = PreviewPipeline.selectedPreviewSize(
        context,
        cameraId,
        preset,
        broadcastMode,
        glView,
    )

    /**
     * Stops preview only (encoder + RTMP stay alive when [preserveStream] is true),
     * keeps the same camcorder preview size, and lets Pedro apply display rotation — same as
     * stock Camera when the phone is rotated to landscape.
     */
    fun reconfigurePreview(
        rtmpCamera: RtmpCamera2,
        glView: OpenGlView,
        context: Context,
        cameraId: String,
        preset: Camera.ResolutionPreset,
        broadcastMode: String,
        facing: Facing,
        preserveStream: Boolean,
    ): Boolean {
        val previewSize = selectedPreviewSize(context, cameraId, preset, broadcastMode, glView)
        val glConfig = BroadcastGlConfig.compute(context, cameraId, preset, broadcastMode)

        return try {
            val ok = if (preserveStream && rtmpCamera.isStreaming) {
                PedroCameraBridge.reconfigurePreviewForDisplay(
                    rtmpCamera,
                    context,
                    previewSize,
                    glConfig,
                )
            } else {
                if (rtmpCamera.isOnPreview) {
                    rtmpCamera.stopPreview()
                }
                rtmpCamera.startPreview(
                    facing,
                    previewSize.width,
                    previewSize.height,
                    glConfig.previewStartRotation,
                )
                rtmpCamera.glInterface?.let {
                    PedroCameraBridge.applyPedroPreviewGlSetup(it, glConfig)
                }
                true
            }
            Log.i(
                TAG,
                "Preview reconfigured mode=$broadcastMode size=${previewSize.width}x${previewSize.height} " +
                    "previewGl=${glConfig.previewGlWidth}x${glConfig.previewGlHeight} " +
                    "stream=${glConfig.encoderWidth}x${glConfig.encoderHeight} glRot=${glConfig.glRotation} " +
                    "streaming=${rtmpCamera.isStreaming} preserve=$preserveStream",
            )
            ok
        } catch (e: Exception) {
            Log.e(TAG, "reconfigurePreview", e)
            false
        }
    }
}
