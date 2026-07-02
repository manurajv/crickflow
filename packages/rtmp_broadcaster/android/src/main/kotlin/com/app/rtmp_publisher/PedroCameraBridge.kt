package com.app.rtmp_publisher

import android.graphics.Rect
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.util.Log
import com.pedro.encoder.input.video.Camera2ApiManager
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import kotlin.math.roundToInt

/**
 * Accesses pedro [Camera2ApiManager] internals for zoom and physical camera switching
 * (not exposed on [RtmpCamera2] 1.9.6 beyond front/back toggle).
 */
object PedroCameraBridge {
    private const val TAG = "PedroCameraBridge"

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
        return getBuilderInputSurface(apiManager) != null &&
            getCaptureSession(apiManager) != null
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
