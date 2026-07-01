package com.app.rtmp_publisher

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.util.Log
import com.pedro.rtplibrary.rtmp.RtmpCamera2

/**
 * Torch control that works on Samsung devices where the logical preview camera
 * may not report [CameraCharacteristics.FLASH_INFO_AVAILABLE].
 */
object CameraTorchHelper {
    private const val TAG = "CameraTorchHelper"

    private var systemTorchCameraId: String? = null

    fun findBackTorchCameraId(context: Context): String? {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        for (cameraId in cameraManager.cameraIdList) {
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
            val flashAvailable = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE)
            if (facing == CameraMetadata.LENS_FACING_BACK && flashAvailable == true) {
                return cameraId
            }
        }
        return null
    }

    fun setTorch(
        context: Context,
        rtmpCamera: RtmpCamera2,
        activeCameraId: String,
        enabled: Boolean
    ) {
        if (!enabled) {
            disableAll(context, rtmpCamera)
            return
        }

        // Prefer capture-request torch on the active back preview when supported.
        if (!isFrontFacing(context, activeCameraId) && rtmpCamera.isLanternSupported) {
            try {
                disableSystemTorch(context)
                rtmpCamera.enableLantern()
                return
            } catch (e: Exception) {
                Log.w(TAG, "enableLantern failed: ${e.message}")
            }
        }

        disableLantern(rtmpCamera)
        val torchId = findBackTorchCameraId(context) ?: activeCameraId
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraManager.setTorchMode(torchId, true)
        systemTorchCameraId = torchId
    }

    fun disableAll(context: Context, rtmpCamera: RtmpCamera2) {
        disableLantern(rtmpCamera)
        disableSystemTorch(context)
    }

    private fun disableLantern(rtmpCamera: RtmpCamera2) {
        try {
            if (rtmpCamera.isLanternEnabled) {
                rtmpCamera.disableLantern()
            }
        } catch (e: Exception) {
            Log.w(TAG, "disableLantern: ${e.message}")
        }
    }

    private fun disableSystemTorch(context: Context) {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val torchId = systemTorchCameraId ?: findBackTorchCameraId(context) ?: return
        try {
            cameraManager.setTorchMode(torchId, false)
        } catch (e: Exception) {
            Log.w(TAG, "disableSystemTorch: ${e.message}")
        } finally {
            systemTorchCameraId = null
        }
    }

    private fun isFrontFacing(context: Context, cameraId: String): Boolean {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val characteristics = cameraManager.getCameraCharacteristics(cameraId)
        return characteristics.get(CameraCharacteristics.LENS_FACING) ==
            CameraMetadata.LENS_FACING_FRONT
    }
}
