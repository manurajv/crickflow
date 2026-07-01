package com.app.rtmp_publisher

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Point
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.os.Looper
import android.util.Log
import android.view.SurfaceHolder
import android.view.View
import android.widget.Toast
import com.pedro.encoder.input.video.CameraHelper.Facing.BACK
import com.pedro.encoder.input.video.CameraHelper.Facing.FRONT
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import com.pedro.rtplibrary.view.LightOpenGlView
import com.pedro.rtplibrary.view.OpenGlView
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import net.ossrs.rtmp.ConnectCheckerRtmp
import java.io.*


class CameraNativeView(
    private var activity: Activity? = null,
    private var enableAudio: Boolean = false,
    private val preset: Camera.ResolutionPreset,
    private var cameraName: String,
    private var dartMessenger: DartMessenger? = null
) :
    PlatformView,
    SurfaceHolder.Callback,
    ConnectCheckerRtmp {

    private val glView = LightOpenGlView(activity)
    private val rtmpCamera: RtmpCamera2
    private val overlayBurnIn: StreamOverlayBurnIn

    private var isSurfaceCreated = false
    private var fps = 0

    init {
        glView.isKeepAspectRatio = true
        glView.holder.addCallback(this)
        rtmpCamera = RtmpCamera2(glView, this)
        overlayBurnIn = StreamOverlayBurnIn(rtmpCamera, glView)
        rtmpCamera.setReTries(10)
        rtmpCamera.setFpsListener { fps = it }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        Log.d("CameraNativeView", "surfaceCreated")
        isSurfaceCreated = true
        startPreview(cameraName)
    }

    override fun surfaceChanged(p0: SurfaceHolder, p1: Int, p2: Int, p3: Int) {
        // TODO("Not yet implemented")
    }

    override fun surfaceDestroyed(p0: SurfaceHolder) {
        // TODO("Not yet implemented")
    }

    override fun onAuthSuccessRtmp() {
    }

    override fun onNewBitrateRtmp(bitrate: Long) {
    }

    override fun onConnectionSuccessRtmp() {
    }

    override fun onConnectionFailedRtmp(reason: String) {
        activity?.runOnUiThread { //Wait 5s and retry connect stream
            if (rtmpCamera.reTry(5000, reason)) {
                dartMessenger?.send(DartMessenger.EventType.RTMP_RETRY, reason)
            } else {
                dartMessenger?.send(DartMessenger.EventType.RTMP_STOPPED, "Failed retry")
                rtmpCamera.stopStream()
            }
        }
    }

    override fun onAuthErrorRtmp() {
        activity?.runOnUiThread {
            dartMessenger?.send(DartMessenger.EventType.ERROR, "Auth error")
        }
    }

    override fun onDisconnectRtmp() {
        activity?.runOnUiThread {
            dartMessenger?.send(DartMessenger.EventType.RTMP_STOPPED, "Disconnected")
        }
    }

    fun close() {
        Log.d("CameraNativeView", "close")
    }

    fun takePicture(filePath: String, result: MethodChannel.Result) {
        Log.d("CameraNativeView", "takePicture filePath: $filePath result: $result")
        val file: File = File(filePath)
        if (file.exists()) {
            result.error("fileExists", "File at path '$filePath' already exists. Cannot overwrite.", null)
            return
        }
        glView.takePhoto {
            try {
                val outputStream: OutputStream = BufferedOutputStream(FileOutputStream(file))
                it.compress(Bitmap.CompressFormat.JPEG, 100, outputStream)
                outputStream.close()
                view.post { result.success(null) }
            } catch (e: IOException) {
                result.error("IOError", "Failed saving image", null)
            }
        }
    }

    fun startVideoRecording(filePath: String?, result: MethodChannel.Result) {
        if (filePath == null) {
            result.error("fileExists", "Must specify a filePath.", null)
            return
        }

        val file = File(filePath)
        if (file.exists()) {
            result.error("fileExists", "File at path '$filePath' already exists. Cannot overwrite.", null)
            return
        }
        Log.d("CameraNativeView", "startVideoRecording filePath: $filePath result: $result")


        val streamingSize = CameraUtils.getBestAvailableCamcorderProfileForResolutionPreset(cameraName, preset)
        /*if (rtmpCamera.isRecording || rtmpCamera.prepareAudio() && rtmpCamera.prepareVideo(
                streamingSize.videoFrameWidth,
                streamingSize.videoFrameHeight,
                streamingSize.videoBitRate
            )*/

        if (!rtmpCamera.isStreaming()) {
            if (rtmpCamera.prepareAudio() && rtmpCamera.prepareVideo(
                    streamingSize.videoFrameWidth,
                    streamingSize.videoFrameHeight,
                    streamingSize.videoBitRate
                )
            ) {
                rtmpCamera.startRecord(filePath)
            }
        } else {
            rtmpCamera.startRecord(filePath)
        }
    }


    fun startVideoStreaming(url: String?, bitrate: Int?, result: MethodChannel.Result) {
        Log.d("CameraNativeView", "startVideoStreaming url: $url")
        if (url == null) {
            result.error("startVideoStreaming", "Must specify a url.", null)
            return
        }

        try {
            if (!rtmpCamera.isStreaming) {
                val streamingSize = CameraUtils.getBestAvailableCamcorderProfileForResolutionPreset(cameraName, preset)
                if (rtmpCamera.isRecording || rtmpCamera.prepareAudio() && rtmpCamera.prepareVideo(
                        streamingSize.videoFrameWidth,
                        streamingSize.videoFrameHeight,
                        bitrate ?: streamingSize.videoBitRate
                    )
                ) {
                    // ready to start streaming
                    rtmpCamera.startStream(url)
                } else {
                    result.error("videoStreamingFailed", "Error preparing stream, This device cant do it", null)
                    return
                }
            } else {
                rtmpCamera.stopStream()
            }
            result.success(null)
        } catch (e: CameraAccessException) {
            result.error("videoStreamingFailed", e.message, null)
        } catch (e: IOException) {
            result.error("videoStreamingFailed", e.message, null)
        }
    }

    fun startVideoRecordingAndStreaming(filePath: String?, url: String?, bitrate: Int?, result: MethodChannel.Result) {
        if (filePath == null) {
            result.error("fileExists", "Must specify a filePath.", null)
            return
        }
        if (File(filePath).exists()) {
            result.error("fileExists", "File at path '$filePath' already exists.", null)
            return
        }
        if (url == null) {
            result.error("fileExists", "Must specify a url.", null)
            return
        }
        try {
            startVideoRecording(filePath, result)
            startVideoStreaming(url, bitrate, result)
        } catch (e: CameraAccessException) {
            result.error("videoRecordingFailed", e.message, null)
        } catch (e: IOException) {
            result.error("videoRecordingFailed", e.message, null)
        }
    }

    fun pauseVideoStreaming(result: Any) {
        // TODO: Implement pause video streaming
    }

    fun resumeVideoStreaming(result: Any) {
        // TODO: Implement resume video streaming
    }

    fun stopVideoRecordingOrStreaming(result: MethodChannel.Result) {
        try {
            rtmpCamera.apply {
                if (isStreaming) stopStream()
                if (isRecording) stopRecord()
            }
            result.success(null)
        } catch (e: CameraAccessException) {
            result.error("videoRecordingFailed", e.message, null)
        } catch (e: IllegalStateException) {
            result.error("videoRecordingFailed", e.message, null)
        }
    }

    fun stopVideoRecording(result: MethodChannel.Result) {
        try {
            rtmpCamera.apply {
                if (isRecording) stopRecord()
            }
            result.success(null)
        } catch (e: CameraAccessException) {
            result.error("stopVideoRecordingFailed", e.message, null)
        } catch (e: IllegalStateException) {
            result.error("stopVideoRecordingFailed", e.message, null)
        }
    }

    fun stopVideoStreaming(result: MethodChannel.Result) {
        try {
            rtmpCamera.apply {
                if (isStreaming) stopStream()
            }
            result.success(null)
        } catch (e: CameraAccessException) {
            result.error("stopVideoStreamingFailed", e.message, null)
        } catch (e: IllegalStateException) {
            result.error("stopVideoStreamingFailed", e.message, null)
        }
    }

    fun pauseVideoRecording(result: Any) {
        // TODO: Implement pause Video Recording
    }

    fun resumeVideoRecording(result: Any) {
        // TODO: Implement resume video recording
    }

    fun startPreviewWithImageStream(imageStreamChannel: Any) {
        // TODO: Implement start preview with image stream
    }

    fun startPreview(cameraNameArg: String? = null) {
        val targetCamera = if (cameraNameArg.isNullOrEmpty()) {
            cameraName
        } else {
            cameraNameArg
        }
        cameraName = targetCamera
        val previewSize = CameraUtils.computeBestPreviewSize(cameraName, preset)

        Log.d("CameraNativeView", "startPreview: $preset camera=$targetCamera")
        if (isSurfaceCreated) {
            try {
                if (rtmpCamera.isOnPreview || rtmpCamera.isStreaming) {
                    if (!invokeSwitchCameraByIdIfNeeded(targetCamera)) {
                        rtmpCamera.stopPreview()
                        rtmpCamera.startPreview(
                            if (isFrontFacing(targetCamera)) FRONT else BACK,
                            previewSize.width,
                            previewSize.height
                        )
                        invokeSwitchCameraByIdIfNeeded(targetCamera)
                    }
                } else {
                    rtmpCamera.startPreview(
                        if (isFrontFacing(targetCamera)) FRONT else BACK,
                        previewSize.width,
                        previewSize.height
                    )
                    invokeSwitchCameraByIdIfNeeded(targetCamera)
                }
            } catch (e: CameraAccessException) {
                activity?.runOnUiThread { dartMessenger?.send(DartMessenger.EventType.ERROR, "CameraAccessException") }
                return
            } catch (e: Exception) {
                Log.e("CameraNativeView", "startPreview failed", e)
                activity?.runOnUiThread { dartMessenger?.send(DartMessenger.EventType.ERROR, e.message ?: "Preview failed") }
            }
        }
    }

    fun switchCameraById(cameraId: String, result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                val act = activity ?: run {
                    result.error("switchCameraFailed", "Activity unavailable", null)
                    return@runOnMain
                }
                CameraTorchHelper.disableAll(act, rtmpCamera)
                cameraName = cameraId
                val previewSize = CameraUtils.computeBestPreviewSize(cameraName, preset)
                if (!isSurfaceCreated) {
                    result.success(null)
                    return@runOnMain
                }
                val switched = invokeSwitchCameraById(cameraId)
                if (!switched) {
                    if (rtmpCamera.isOnPreview) {
                        rtmpCamera.stopPreview()
                    }
                    rtmpCamera.startPreview(
                        if (isFrontFacing(cameraId)) FRONT else BACK,
                        previewSize.width,
                        previewSize.height
                    )
                    invokeSwitchCameraById(cameraId)
                }
                PedroCameraBridge.setZoom(rtmpCamera, 1f)
                result.success(null)
            } catch (e: Exception) {
                Log.e("CameraNativeView", "switchCameraById", e)
                result.error("switchCameraFailed", e.message, null)
            }
        }
    }

    private fun invokeSwitchCameraByIdIfNeeded(cameraId: String): Boolean {
        if (cameraId.isEmpty()) return false
        val defaultId = resolveDefaultCameraIdForFacing(cameraId)
        if (cameraId == defaultId) return true
        return invokeSwitchCameraById(cameraId)
    }

    private fun invokeSwitchCameraById(cameraId: String): Boolean {
        if (cameraId.isEmpty()) return false
        return PedroCameraBridge.switchToCameraId(rtmpCamera, cameraId)
    }

    private fun resolveDefaultCameraIdForFacing(cameraId: String): String {
        val act = activity ?: return cameraId
        val cameraManager = act.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val wantFront = isFrontFacing(cameraId)
        for (id in cameraManager.cameraIdList) {
            val characteristics = cameraManager.getCameraCharacteristics(id)
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
            if (wantFront && facing == CameraMetadata.LENS_FACING_FRONT) return id
            if (!wantFront && facing == CameraMetadata.LENS_FACING_BACK) return id
        }
        return cameraId
    }

    fun flipCamera(result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                if (PedroCameraBridge.flipCamera(rtmpCamera)) {
                    val act = activity
                    if (act != null) {
                        val wasFront = isFrontFacing(cameraName)
                        val cameraManager =
                            act.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                        for (id in cameraManager.cameraIdList) {
                            val characteristics = cameraManager.getCameraCharacteristics(id)
                            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                            if (!wasFront && facing == CameraMetadata.LENS_FACING_FRONT) {
                                cameraName = id
                                break
                            }
                            if (wasFront && facing == CameraMetadata.LENS_FACING_BACK) {
                                cameraName = id
                                break
                            }
                        }
                    }
                    PedroCameraBridge.setZoom(rtmpCamera, 1f)
                    result.success(null)
                } else {
                    result.error("flipCameraFailed", "Could not switch camera", null)
                }
            } catch (e: Exception) {
                Log.e("CameraNativeView", "flipCamera", e)
                result.error("flipCameraFailed", e.message, null)
            }
        }
    }

    fun setExposureCompensation(ev: Float, result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                if (PedroCameraBridge.setExposureCompensation(rtmpCamera, ev)) {
                    result.success(null)
                } else {
                    result.error("exposureFailed", "Exposure not supported", null)
                }
            } catch (e: Exception) {
                result.error("exposureFailed", e.message, null)
            }
        }
    }

    fun setFocusLock(locked: Boolean, result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                PedroCameraBridge.setFocusLock(rtmpCamera, locked)
                result.success(null)
            } catch (e: Exception) {
                result.error("focusFailed", e.message, null)
            }
        }
    }

    fun tapToFocus(x: Float, y: Float, result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                if (PedroCameraBridge.tapToFocus(rtmpCamera, x, y)) {
                    result.success(null)
                } else {
                    result.error("focusFailed", "Tap to focus not supported", null)
                }
            } catch (e: Exception) {
                result.error("focusFailed", e.message, null)
            }
        }
    }

    private fun runOnMain(result: MethodChannel.Result, block: () -> Unit) {
        val act = activity
        if (act == null) {
            result.success(null)
            return
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            act.runOnUiThread { block() }
        }
    }

    fun setTorch(enabled: Boolean, result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                val act = activity ?: run {
                    result.success(null)
                    return@runOnMain
                }
                CameraTorchHelper.setTorch(act, rtmpCamera, cameraName, enabled)
                result.success(null)
            } catch (e: Exception) {
                Log.e("CameraNativeView", "setTorch", e)
                result.error("torchFailed", e.message, null)
            }
        }
    }

    fun setZoom(level: Float, result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                if (!rtmpCamera.isOnPreview) {
                    result.error("zoomFailed", "Camera preview not ready", null)
                    return@runOnMain
                }
                PedroCameraBridge.setZoom(rtmpCamera, level)
                result.success(null)
            } catch (e: Exception) {
                Log.e("CameraNativeView", "setZoom", e)
                result.error("zoomFailed", e.message, null)
            }
        }
    }

    fun getMaxZoom(result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                val max = if (rtmpCamera.isOnPreview) {
                    PedroCameraBridge.getMaxZoom(rtmpCamera)
                } else {
                    3.0f
                }
                result.success(max.toDouble())
            } catch (e: Exception) {
                result.success(1.0)
            }
        }
    }

    fun updateStreamOverlay(
        pngBytes: ByteArray,
        width: Int,
        height: Int,
        result: MethodChannel.Result
    ) {
        runOnMain(result) {
            try {
                overlayBurnIn.updateOverlay(pngBytes, width, height)
                result.success(null)
            } catch (e: Exception) {
                Log.e("CameraNativeView", "updateStreamOverlay", e)
                result.error("overlayFailed", e.message, null)
            }
        }
    }

    fun clearStreamOverlay(result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                overlayBurnIn.clearOverlay()
                result.success(null)
            } catch (e: Exception) {
                result.error("overlayFailed", e.message, null)
            }
        }
    }

    fun getStreamStatistics(result: MethodChannel.Result) {
        val ret = hashMapOf<String, Any>()
        ret["cacheSize"] = rtmpCamera.cacheSize
        ret["sentAudioFrames"] = rtmpCamera.sentAudioFrames
        ret["sentVideoFrames"] = rtmpCamera.sentVideoFrames
        ret["droppedAudioFrames"] = rtmpCamera.droppedAudioFrames
        ret["droppedVideoFrames"] = rtmpCamera.droppedVideoFrames
        ret["isAudioMuted"] = rtmpCamera.isAudioMuted
        ret["bitrate"] = rtmpCamera.bitrate
        ret["width"] = rtmpCamera.streamWidth
        ret["height"] = rtmpCamera.streamHeight
        ret["fps"] = fps
        result.success(ret)
    }

    override fun getView(): View {
        return glView
    }

    override fun dispose() {
        isSurfaceCreated = false
        overlayBurnIn.release()
        activity = null
    }

    private fun isFrontFacing(cameraName: String): Boolean {
        val cameraManager = activity?.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val characteristics = cameraManager.getCameraCharacteristics(cameraName)
        return characteristics.get(CameraCharacteristics.LENS_FACING) == CameraMetadata.LENS_FACING_FRONT
    }
}
