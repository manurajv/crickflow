package com.app.rtmp_publisher

import android.content.Context
import android.graphics.Rect
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.util.Log
import android.util.Size
import android.view.Surface
import com.pedro.encoder.input.video.Camera2ApiManager
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import com.pedro.rtplibrary.view.GlInterface
import kotlin.math.roundToInt

/**
 * Accesses pedro [Camera2ApiManager] internals for zoom and physical camera switching
 * (not exposed on [RtmpCamera2] 1.9.6 beyond front/back toggle).
 */
object PedroCameraBridge {
    private const val TAG = "PedroCameraBridge"
    private val encoderSurfaceLock = Any()

    fun getCamera2ApiManager(rtmpCamera: RtmpCamera2): Camera2ApiManager? {
        var clazz: Class<*>? = rtmpCamera.javaClass
        while (clazz != null) {
            try {
                val field = clazz.getDeclaredField("cameraManager")
                field.isAccessible = true
                return field.get(rtmpCamera) as Camera2ApiManager
            } catch (_: NoSuchFieldException) {
                clazz = clazz.superclass
            } catch (e: Exception) {
                Log.e(TAG, "getCamera2ApiManager", e)
                return null
            }
        }
        return null
    }

    private fun getBuilderInputSurface(apiManager: Camera2ApiManager): CaptureRequest.Builder? {
        return try {
            val field = apiManager.javaClass.getDeclaredField("builderInputSurface")
            field.isAccessible = true
            field.get(apiManager) as CaptureRequest.Builder?
        } catch (e: Exception) {
            null
        }
    }

    private fun getCaptureSession(apiManager: Camera2ApiManager): android.hardware.camera2.CameraCaptureSession? {
        return try {
            val field = apiManager.javaClass.getDeclaredField("cameraCaptureSession")
            field.isAccessible = true
            field.get(apiManager) as android.hardware.camera2.CameraCaptureSession?
        } catch (e: Exception) {
            null
        }
    }

    /** True when Camera2 capture session and request builder are ready for controls. */
    fun isCaptureSessionReady(rtmpCamera: RtmpCamera2): Boolean {
        if (!rtmpCamera.isOnPreview && !rtmpCamera.isStreaming) return false
        val apiManager = getCamera2ApiManager(rtmpCamera) ?: return false
        if (!apiManager.isRunning) return false
        if (!isCameraHandlerAlive(apiManager)) return false
        return getBuilderInputSurface(apiManager) != null &&
            getCaptureSession(apiManager) != null
    }

    private fun isCameraHandlerAlive(apiManager: Camera2ApiManager): Boolean {
        return try {
            val field = apiManager.javaClass.getDeclaredField("cameraHandler")
            field.isAccessible = true
            val handler = field.get(apiManager) as? android.os.Handler ?: return false
            handler.looper.thread.isAlive
        } catch (_: Exception) {
            true
        }
    }

    private fun repeatPreview(apiManager: Camera2ApiManager) {
        val builder = getBuilderInputSurface(apiManager) ?: return
        val session = getCaptureSession(apiManager) ?: return
        try {
            session.setRepeatingRequest(builder.build(), null, null)
        } catch (e: Exception) {
            Log.w(TAG, "repeatPreview failed", e)
        }
    }

    fun switchToCameraId(rtmpCamera: RtmpCamera2, cameraId: String): Boolean {
        if (!isCaptureSessionReady(rtmpCamera) && !rtmpCamera.isOnPreview) return false
        val apiManager = getCamera2ApiManager(rtmpCamera) ?: return false
        val id = cameraId.toIntOrNull() ?: return false
        return try {
            val reOpenMethod = Camera2ApiManager::class.java.getDeclaredMethod(
                "reOpenCamera",
                Int::class.javaPrimitiveType
            )
            reOpenMethod.isAccessible = true
            reOpenMethod.invoke(apiManager, id)
            true
        } catch (e: Exception) {
            Log.w(TAG, "reOpenCamera failed for id=$cameraId: ${e.message}")
            try {
                apiManager.openCameraId(id)
                true
            } catch (e2: Exception) {
                Log.e(TAG, "openCameraId failed for id=$cameraId", e2)
                false
            }
        }
    }

    fun flipCamera(rtmpCamera: RtmpCamera2): Boolean {
        return try {
            rtmpCamera.switchCamera()
            true
        } catch (e: Exception) {
            Log.e(TAG, "flipCamera", e)
            false
        }
    }

    /**
     * Rebuilds the Camera2 preview session for the current display orientation while streaming.
     * Encoder dimensions and RTMP are unchanged — mirrors Pedro [startPreview] GL setup using
     * [CameraHelper.getCameraOrientation] (display rotation), not encoder rotation.
     */
    fun reconfigurePreviewForDisplay(
        rtmpCamera: RtmpCamera2,
        context: Context,
        previewSize: Size,
        glConfig: BroadcastGlConfig.Config,
    ): Boolean {
        val glInterface = rtmpCamera.glInterface ?: return false
        val apiManager = getCamera2ApiManager(rtmpCamera) ?: return false

        applyPedroGlSetup(glInterface, glConfig, rtmpCamera.isStreaming)

        val fps = getVideoEncoderFps(rtmpCamera) ?: 30
        val prepW = previewSize.width
        val prepH = previewSize.height

        return try {
            if (apiManager.isRunning) {
                apiManager.closeCamera(true)
            }
            if (!isGlThreadRunning(glInterface)) {
                glInterface.start()
            }
            val surfaceTexture: SurfaceTexture = glInterface.surfaceTexture ?: return false
            surfaceTexture.setDefaultBufferSize(prepW, prepH)
            apiManager.prepareCamera(surfaceTexture, prepW, prepH, fps)
            val encoderSurface = getVideoEncoderInputSurface(rtmpCamera)
            if (encoderSurface != null && encoderSurface.isValid) {
                try {
                    glInterface.removeMediaCodecSurface()
                } catch (_: Exception) {
                }
                glInterface.addMediaCodecSurface(encoderSurface)
            }
            apiManager.openLastCamera()
            true
        } catch (e: Exception) {
            Log.e(TAG, "reconfigurePreviewForDisplay", e)
            false
        }
    }

    /**
     * Applies locked broadcast GL output. Never switches to encoder dimensions while live —
     * preview and stream share the same GL frame size in Pedro RtmpCamera2.
     */
    fun applyPedroPreviewGlSetup(
        glInterface: GlInterface,
        glConfig: BroadcastGlConfig.Config,
    ) {
        BroadcastGlConfig.applyPreviewGlToInterface(glInterface, glConfig)
    }

    fun applyPedroGlSetup(
        glInterface: GlInterface,
        glConfig: BroadcastGlConfig.Config,
        streaming: Boolean,
    ) {
        BroadcastGlConfig.applyGlToInterface(glInterface, glConfig, streaming)
    }

    /** Re-attach MediaCodec input surface after GL preview reconfiguration while live. */
    fun relinkEncoderSurface(rtmpCamera: RtmpCamera2): Boolean {
        if (!rtmpCamera.isStreaming) return false
        val glInterface = rtmpCamera.glInterface ?: return false
        val encoderSurface = getVideoEncoderInputSurface(rtmpCamera) ?: return false
        if (!encoderSurface.isValid) {
            Log.w(TAG, "relinkEncoderSurface skipped — invalid encoder surface")
            return false
        }
        if (!isGlThreadRunning(glInterface)) {
            Log.w(TAG, "relinkEncoderSurface skipped — GL thread not running")
            return false
        }
        synchronized(encoderSurfaceLock) {
            return try {
                // Pedro throws EGL_BAD_ALLOC if the encoder surface is already connected.
                try {
                    glInterface.removeMediaCodecSurface()
                } catch (e: Exception) {
                    Log.w(TAG, "removeMediaCodecSurface before relink", e)
                }
                glInterface.addMediaCodecSurface(encoderSurface)
                Log.i(TAG, "Encoder surface re-linked to GL")
                true
            } catch (e: Exception) {
                Log.e(TAG, "relinkEncoderSurface", e)
                false
            }
        }
    }

    /**
     * Pedro prepareGlView() re-binds Camera2 at encoder dimensions (e.g. 720×1280) which stretches
     * a 1280×720 sensor buffer. Restore capture at [bufferWidth]×[bufferHeight] after go-live.
     */
    fun rebindCameraAtPreviewBuffer(
        rtmpCamera: RtmpCamera2,
        bufferWidth: Int,
        bufferHeight: Int,
    ): Boolean {
        if (bufferWidth <= 0 || bufferHeight <= 0) return false
        val glInterface = rtmpCamera.glInterface ?: return false
        val apiManager = getCamera2ApiManager(rtmpCamera) ?: return false
        val surfaceTexture = glInterface.surfaceTexture ?: return false
        val fps = getVideoEncoderFps(rtmpCamera) ?: 30
        return try {
            surfaceTexture.setDefaultBufferSize(bufferWidth, bufferHeight)
            if (apiManager.isRunning) {
                apiManager.closeCamera(true)
            }
            apiManager.prepareCamera(surfaceTexture, bufferWidth, bufferHeight, fps)
            apiManager.openLastCamera()
            Log.i(
                TAG,
                "Camera rebound at sensor buffer ${bufferWidth}x$bufferHeight (streaming=${rtmpCamera.isStreaming})",
            )
            true
        } catch (e: Exception) {
            Log.e(TAG, "rebindCameraAtPreviewBuffer", e)
            false
        }
    }

    private fun isGlThreadRunning(glInterface: GlInterface): Boolean {
        return try {
            val field = glInterface.javaClass.superclass?.getDeclaredField("running")
                ?: glInterface.javaClass.getDeclaredField("running")
            field.isAccessible = true
            field.getBoolean(glInterface)
        } catch (_: Exception) {
            true
        }
    }

    private fun getVideoEncoder(rtmpCamera: RtmpCamera2): Any? {
        var clazz: Class<*>? = rtmpCamera.javaClass
        while (clazz != null) {
            try {
                val field = clazz.getDeclaredField("videoEncoder")
                field.isAccessible = true
                return field.get(rtmpCamera)
            } catch (_: NoSuchFieldException) {
                clazz = clazz.superclass
            }
        }
        return null
    }

    private fun getVideoEncoderInputSurface(rtmpCamera: RtmpCamera2): Surface? {
        val encoder = getVideoEncoder(rtmpCamera) ?: return null
        return try {
            val method = encoder.javaClass.getMethod("getInputSurface")
            method.invoke(encoder) as? Surface
        } catch (_: Exception) {
            null
        }
    }

    private fun getVideoEncoderFps(rtmpCamera: RtmpCamera2): Int? {
        val encoder = getVideoEncoder(rtmpCamera) ?: return null
        return try {
            val method = encoder.javaClass.getMethod("getFps")
            method.invoke(encoder) as? Int
        } catch (_: Exception) {
            null
        }
    }

    private fun getVideoEncoderWidth(rtmpCamera: RtmpCamera2): Int? {
        val encoder = getVideoEncoder(rtmpCamera) ?: return null
        return try {
            val method = encoder.javaClass.getMethod("getWidth")
            method.invoke(encoder) as? Int
        } catch (_: Exception) {
            null
        }
    }

    private fun getVideoEncoderHeight(rtmpCamera: RtmpCamera2): Int? {
        val encoder = getVideoEncoder(rtmpCamera) ?: return null
        return try {
            val method = encoder.javaClass.getMethod("getHeight")
            method.invoke(encoder) as? Int
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Applies zoom only when the Camera2 session is ready.
     * @return true if applied immediately, false if deferred or skipped.
     */
    fun setZoom(rtmpCamera: RtmpCamera2, level: Float): Boolean {
        if (!isCaptureSessionReady(rtmpCamera)) {
            Log.w(TAG, "setZoom deferred — capture session not ready")
            return false
        }
        val clamped = level.coerceAtLeast(1f)
        try {
            rtmpCamera.setZoom(clamped)
            return true
        } catch (e: Exception) {
            Log.w(TAG, "rtmpCamera.setZoom failed, trying cameraManager", e)
        }
        val apiManager = getCamera2ApiManager(rtmpCamera) ?: return false
        val builder = getBuilderInputSurface(apiManager)
        if (builder == null) {
            Log.w(TAG, "setZoom skipped — CaptureRequest.Builder null")
            return false
        }
        return try {
            val method = apiManager.javaClass.getMethod(
                "setZoom",
                Float::class.javaPrimitiveType
            )
            method.invoke(apiManager, clamped)
            true
        } catch (e: Exception) {
            Log.e(TAG, "setZoom", e)
            false
        }
    }

    fun getMaxZoom(rtmpCamera: RtmpCamera2): Float {
        return try {
            rtmpCamera.maxZoom.coerceAtLeast(1f)
        } catch (e: Exception) {
            1f
        }
    }

    fun setExposureCompensation(rtmpCamera: RtmpCamera2, ev: Float): Boolean {
        if (!isCaptureSessionReady(rtmpCamera)) return false
        val apiManager = getCamera2ApiManager(rtmpCamera) ?: return false
        val builder = getBuilderInputSurface(apiManager) ?: return false
        return try {
            val characteristics = apiManager.getCameraCharacteristics() ?: return false
            val range = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
                ?: return false
            val step = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
                ?: android.util.Rational(1, 1)
            val stepFloat = step.numerator.toFloat() / step.denominator.toFloat()
            val targetSteps = (ev / stepFloat).roundToInt()
            val clamped = targetSteps.coerceIn(range.lower, range.upper)
            builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, clamped)
            repeatPreview(apiManager)
            true
        } catch (e: Exception) {
            Log.e(TAG, "setExposureCompensation", e)
            false
        }
    }

    fun setFocusLock(rtmpCamera: RtmpCamera2, locked: Boolean): Boolean {
        if (!isCaptureSessionReady(rtmpCamera)) return false
        return try {
            if (locked) {
                rtmpCamera.disableAutoFocus()
            } else {
                rtmpCamera.enableAutoFocus()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "setFocusLock", e)
            false
        }
    }

    fun tapToFocus(rtmpCamera: RtmpCamera2, x: Float, y: Float): Boolean {
        if (!isCaptureSessionReady(rtmpCamera)) return false
        val apiManager = getCamera2ApiManager(rtmpCamera) ?: return false
        val builder = getBuilderInputSurface(apiManager) ?: return false
        return try {
            val characteristics = apiManager.getCameraCharacteristics() ?: return false
            val sensorRect = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
                ?: return false
            val focusX = (sensorRect.width() * x).toInt().coerceIn(0, sensorRect.width())
            val focusY = (sensorRect.height() * y).toInt().coerceIn(0, sensorRect.height())
            val size = (sensorRect.width() * 0.08f).toInt().coerceAtLeast(100)
            val half = size / 2
            val focusRect = Rect(
                (focusX - half).coerceAtLeast(0),
                (focusY - half).coerceAtLeast(0),
                (focusX + half).coerceAtMost(sensorRect.width()),
                (focusY + half).coerceAtMost(sensorRect.height())
            )
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
            builder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(
                android.hardware.camera2.params.MeteringRectangle(
                    focusRect, android.hardware.camera2.params.MeteringRectangle.METERING_WEIGHT_MAX
                )
            ))
            builder.set(
                CaptureRequest.CONTROL_AF_TRIGGER,
                CameraMetadata.CONTROL_AF_TRIGGER_START
            )
            repeatPreview(apiManager)
            builder.set(
                CaptureRequest.CONTROL_AF_TRIGGER,
                CameraMetadata.CONTROL_AF_TRIGGER_IDLE
            )
            true
        } catch (e: Exception) {
            Log.e(TAG, "tapToFocus", e)
            false
        }
    }
}
