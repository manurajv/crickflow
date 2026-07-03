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
import android.view.View
import android.widget.Toast
import com.pedro.encoder.input.video.CameraHelper.Facing.BACK
import com.pedro.encoder.input.video.CameraHelper.Facing.FRONT
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import com.pedro.rtplibrary.view.OpenGlView
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import net.ossrs.rtmp.ConnectCheckerRtmp
import java.io.*


class CameraNativeView(
    viewContext: Context,
    private var activity: Activity? = null,
    private val enableAudio: Boolean = false,
    private val preset: Camera.ResolutionPreset,
    private var cameraName: String,
    private var dartMessenger: DartMessenger? = null
) :
    PlatformView,
    ConnectCheckerRtmp {

    // OpenGlView required — LightOpenGlView.setFilter() is a no-op (no RTMP burn-in).
    private val glView = SafeOpenGlView(viewContext)
    private val rtmpCamera: RtmpCamera2
    private val overlayBurnIn: StreamOverlayBurnIn

    private var isSurfaceCreated = false
    private var surfaceNeedsRebuild = false
    private var fps = 0
    private var encoderPrepared = false
    private var lockedOrientationMode = "portrait"
    private var reattachPosted = false
    private var pendingZoomLevel: Float? = null
    private var previewOperationInFlight = false

    private val reattachRunnable = Runnable {
        reattachPosted = false
        if (isSurfaceCreated && PreviewSurfaceLifecycle.isHolderSurfaceValid(glView)) {
            reattachPreviewSurface(preserveStream = rtmpCamera.isStreaming)
        }
    }

    private var previewGlLocked = false
    private var lockedGlConfig: BroadcastGlConfig.Config? = null
    private var lastAppliedStreamRotation = 0

    init {
        // Fill the view — letterboxing (isKeepAspectRatio) leaves bars outdoors.
        glView.isKeepAspectRatio = false
        glView.surfaceLifecycleListener = object : PreviewSurfaceLifecycle.Listener {
            override fun onPreviewSurfaceDestroyed(generation: Long) {
                onPreviewSurfaceLost(generation)
            }

            override fun onPreviewSurfaceAvailable(generation: Long) {
                onPreviewSurfaceReady(generation)
            }
        }
        glView.previewSizeChangedListener = { _, _ -> reapplyLockedPreviewGl() }
        // View resize is handled by Pedro OpenGlView.surfaceChanged — do not restart Camera2.
        rtmpCamera = RtmpCamera2(glView, this)
        overlayBurnIn = StreamOverlayBurnIn(rtmpCamera).also {
            it.onOverlayApplied = { applyStreamRotationIfLive() }
            it.streamRotationDegrees = { streamRotationFor(lockedOrientationMode) }
        }
        rtmpCamera.setReTries(10)
        rtmpCamera.setFpsListener { fps = it }
    }

    private fun onPreviewSurfaceLost(generation: Long) {
        isSurfaceCreated = false
        surfaceNeedsRebuild = true
        cancelScheduledReattach()
        PreviewSurfaceLifecycle.detachAfterSurfaceLoss(rtmpCamera)
        Log.i("CameraNativeView", "Preview surface destroyed gen=$generation")
    }

    private fun onPreviewSurfaceReady(@Suppress("UNUSED_PARAMETER") generation: Long) {
        if (!PreviewSurfaceLifecycle.isHolderSurfaceValid(glView)) return
        isSurfaceCreated = true
        Log.i("CameraNativeView", "Preview surface available — waiting to rebuild pipeline")
        schedulePreviewReattach()
    }

    private fun cancelScheduledReattach() {
        val act = activity
        if (act != null) {
            act.runOnUiThread { act.window?.decorView?.removeCallbacks(reattachRunnable) }
        }
        reattachPosted = false
    }

    /** RTMP encoder rotation — preview uses Pedro startPreview; only applied while streaming. */
    private fun streamRotationFor(mode: String): Int {
        val act = activity ?: return 90
        return PreviewOrientationPolicy.streamRotationFor(act, cameraName, mode)
    }

    private fun previewFacing(): com.pedro.encoder.input.video.CameraHelper.Facing =
        if (isFrontFacing(cameraName)) FRONT else BACK

    /** Freeze Pedro GL rotation/size from the first successful preview start. */
    private fun lockPreviewGlAtFirstStart() {
        if (previewGlLocked) return
        val act = activity ?: return
        lockedGlConfig = BroadcastGlConfig.compute(
            act,
            cameraName,
            preset,
            lockedOrientationMode,
        )
        previewGlLocked = true
        reapplyLockedPreviewGl()
        val cfg = lockedGlConfig
        cfg?.let {
            overlayBurnIn.setOverlayScale(it.previewGlWidth, it.previewGlHeight)
            StreamPipelineLog.previewLocked(it, lockedOrientationMode)
        }
    }

    private fun currentGlConfig(): BroadcastGlConfig.Config? {
        lockedGlConfig?.let { return it }
        val act = activity ?: return null
        return BroadcastGlConfig.compute(act, cameraName, preset, lockedOrientationMode)
    }

    /** Re-apply frozen GL setup — identical before and after go-live. */
    private fun applyLockedGlToInterface() {
        if (!previewGlLocked || !rtmpCamera.isOnPreview) return
        val glConfig = lockedGlConfig ?: return
        val glInterface = rtmpCamera.glInterface ?: return
        try {
            PedroCameraBridge.applyPedroGlSetup(
                glInterface,
                glConfig,
                streaming = rtmpCamera.isStreaming,
            )
        } catch (e: Exception) {
            Log.w("CameraNativeView", "applyLockedGlToInterface", e)
        }
    }

    private fun reapplyLockedPreviewGl() {
        applyLockedGlToInterface()
        if (rtmpCamera.isStreaming) {
            linkEncoderPipeline()
        }
    }

    /** Restores GL, sensor-buffer camera, encoder surface, and overlay after go-live. */
    private fun linkEncoderPipeline() {
        if (!rtmpCamera.isStreaming) return
        val glConfig = lockedGlConfig ?: return
        try {
            applyLockedGlToInterface()
            PedroCameraBridge.rebindCameraAtPreviewBuffer(
                rtmpCamera,
                glConfig.cameraBuffer.width,
                glConfig.cameraBuffer.height,
            )
            PedroCameraBridge.relinkEncoderSurface(rtmpCamera)
            val (scaleW, scaleH) = BroadcastGlConfig.overlayScaleFor(glConfig, streaming = true)
            overlayBurnIn.setOverlayScale(scaleW, scaleH)
            applyStreamRotationIfLive()
            overlayBurnIn.onEncoderPipelineReady()
            StreamPipelineLog.pipelineLinked(rtmpCamera, glConfig, lockedOrientationMode)
            Log.i(
                "CameraNativeView",
                "Encoder pipeline linked enc=${rtmpCamera.streamWidth}x${rtmpCamera.streamHeight} " +
                    "camera=${glConfig.cameraBuffer.width}x${glConfig.cameraBuffer.height} " +
                    "previewGl=${glConfig.previewGlWidth}x${glConfig.previewGlHeight} " +
                    "stream=${glConfig.encoderWidth}x${glConfig.encoderHeight} " +
                    "encRot=${glConfig.videoEncoderRotation} bitrate=${rtmpCamera.bitrate}",
            )
        } catch (e: Exception) {
            Log.e("CameraNativeView", "linkEncoderPipeline", e)
        }
    }

    private fun resetPreviewGlLock() {
        previewGlLocked = false
        lockedGlConfig = null
    }

    private fun configurePreviewForOrientation() {
        val act = activity ?: return
        PreviewPipeline.configureForBroadcastOrientation(
            rtmpCamera,
            glView,
            act,
            cameraName,
            preset,
            lockedOrientationMode,
            previewFacing(),
            preserveStream = rtmpCamera.isStreaming,
        )
        invokeSwitchCameraByIdIfNeeded(cameraName)
    }

    private fun scheduleOrientationPreviewRefresh() {
        val act = activity ?: return
        act.runOnUiThread {
            act.window?.decorView?.post {
                if (!isSurfaceCreated ||
                    !PreviewSurfaceLifecycle.isHolderSurfaceValid(glView)
                ) {
                    return@post
                }
                configurePreviewForOrientation()
                applyStreamRotationIfLive()
                runWhenSessionReady { applyPendingControls() }
            }
        }
    }

    private fun applyStreamRotationIfLive() {
        if (!rtmpCamera.isStreaming) return
        val act = activity ?: return
        act.runOnUiThread {
            try {
                val rot = streamRotationFor(lockedOrientationMode)
                rtmpCamera.glInterface.setStreamRotation(rot)
                lastAppliedStreamRotation = rot
                StreamPipelineLog.streamRotationApplied(rot, lockedOrientationMode)
            } catch (e: Exception) {
                Log.e("CameraNativeView", "applyStreamRotationIfLive", e)
            }
        }
    }

    fun setOrientationMode(
        @Suppress("UNUSED_PARAMETER") autoRotate: Boolean,
        mode: String,
        result: MethodChannel.Result,
    ) {
        runOnMain(result) {
            try {
                lockedOrientationMode = mode
                val act = activity
                if (act != null && !rtmpCamera.isStreaming) {
                    val updated = BroadcastGlConfig.compute(
                        act,
                        cameraName,
                        preset,
                        mode,
                    )
                    if (previewGlLocked) {
                        lockedGlConfig = updated
                        reapplyLockedPreviewGl()
                        Log.i(
                            "CameraNativeView",
                            "Orientation mode updated pre-live → gl=${updated.encoderWidth}x${updated.encoderHeight}",
                        )
                    }
                }
                applyStreamRotationIfLive()
                result.success(null)
            } catch (e: Exception) {
                Log.e("CameraNativeView", "setOrientationMode", e)
                result.error("orientationFailed", e.message, null)
            }
        }
    }

    private fun schedulePreviewReattach() {
        val act = activity ?: return
        if (reattachPosted) return
        reattachPosted = true
        act.runOnUiThread {
            act.window?.decorView?.removeCallbacks(reattachRunnable)
            act.window?.decorView?.postDelayed(reattachRunnable, 120)
        }
    }

    private fun waitForValidSurface(maxAttempts: Int = 40, onReady: () -> Unit) {
        val act = activity
        if (act == null) {
            onReady()
            return
        }
        var attempts = 0
        val poll = object : Runnable {
            override fun run() {
                if (PreviewSurfaceLifecycle.isHolderSurfaceValid(glView) || attempts >= maxAttempts) {
                    onReady()
                } else {
                    attempts++
                    act.window?.decorView?.postDelayed(this, 25)
                }
            }
        }
        act.runOnUiThread { poll.run() }
    }

    /**
     * Rebind preview — encoder/RTMP stay alive when [preserveStream] is true.
     * After Android abandons the surface, rebuild GL → camera → capture session in order.
     */
    private fun reattachPreviewSurface(preserveStream: Boolean) {
        if (!isSurfaceCreated || previewOperationInFlight) return
        if (!PreviewSurfaceLifecycle.isHolderSurfaceValid(glView)) return

        val act = activity
        val previewSize = if (act != null) {
            PreviewPipeline.selectedPreviewSize(act, cameraName, preset, lockedOrientationMode, glView)
        } else {
            CameraUtils.computeBestPreviewSize(cameraName, preset)
        }
        val streaming = preserveStream && rtmpCamera.isStreaming
        val sessionReady = PedroCameraBridge.isCaptureSessionReady(rtmpCamera)
        val mustRebuildPipeline = surfaceNeedsRebuild ||
            (streaming && !sessionReady) ||
            (streaming && !rtmpCamera.isOnPreview)
        val glConfig = currentGlConfig()

        previewOperationInFlight = true
        try {
            if (mustRebuildPipeline) {
                if (glConfig == null) {
                    Log.w("CameraNativeView", "Preview pipeline rebuild skipped — no GL config")
                    return
                }
                val ok = PreviewSurfaceLifecycle.reattachPreviewPipeline(
                    rtmpCamera,
                    glView,
                    previewSize.width,
                    previewSize.height,
                    streaming = streaming,
                    glConfig = glConfig,
                )
                if (ok) {
                    surfaceNeedsRebuild = false
                    invokeSwitchCameraByIdIfNeeded(cameraName)
                    lockPreviewGlAtFirstStart()
                    reapplyLockedPreviewGl()
                    if (streaming) {
                        linkEncoderPipeline()
                    } else {
                        applyStreamRotationIfLive()
                    }
                    runWhenSessionReady { applyPendingControls() }
                    Log.i(
                        "CameraNativeView",
                        "Preview pipeline rebuilt (streaming=$streaming)",
                    )
                } else {
                    Log.w("CameraNativeView", "Preview pipeline rebuild failed")
                }
                return
            }

            if (act != null) {
                if (!streaming && rtmpCamera.isOnPreview) {
                    runWhenSessionReady { applyPendingControls() }
                    return
                }
                PreviewPipeline.configureForBroadcastOrientation(
                    rtmpCamera,
                    glView,
                    act,
                    cameraName,
                    preset,
                    lockedOrientationMode,
                    previewFacing(),
                    preserveStream = streaming,
                )
                invokeSwitchCameraByIdIfNeeded(cameraName)
                applyStreamRotationIfLive()
                runWhenSessionReady { applyPendingControls() }
                return
            }

            if (rtmpCamera.isOnPreview) {
                runWhenSessionReady { applyPendingControls() }
                return
            }

            val facing = previewFacing()
            val glConfig = currentGlConfig()
            if (glConfig != null) {
                rtmpCamera.startPreview(
                    facing,
                    previewSize.width,
                    previewSize.height,
                    glConfig.previewStartRotation,
                )
                PedroCameraBridge.applyPedroPreviewGlSetup(rtmpCamera.glInterface!!, glConfig)
            } else {
                rtmpCamera.startPreview(facing, previewSize.width, previewSize.height)
            }
            invokeSwitchCameraByIdIfNeeded(cameraName)
            runWhenSessionReady { applyPendingControls() }
            Log.i("CameraNativeView", "Preview restarted")
        } catch (e: Exception) {
            Log.e("CameraNativeView", "reattachPreviewSurface", e)
        } finally {
            previewOperationInFlight = false
        }
    }

    private fun ensurePreviewRunning() {
        if (!isSurfaceCreated || !PreviewSurfaceLifecycle.isHolderSurfaceValid(glView)) return
        if (previewOperationInFlight) return

        if (surfaceNeedsRebuild) {
            schedulePreviewReattach()
            return
        }

        if (rtmpCamera.isOnPreview) {
            invokeSwitchCameraByIdIfNeeded(cameraName)
            runWhenSessionReady { applyPendingControls() }
            return
        }

        previewOperationInFlight = true
        try {
            val act = activity ?: return
            PreviewPipeline.configureForBroadcastOrientation(
                rtmpCamera,
                glView,
                act,
                cameraName,
                preset,
                lockedOrientationMode,
                previewFacing(),
                preserveStream = rtmpCamera.isStreaming,
            )
            invokeSwitchCameraByIdIfNeeded(cameraName)
            Log.i("CameraNativeView", "Camera started")
            lockPreviewGlAtFirstStart()
            runWhenSessionReady { applyPendingControls() }
        } catch (e: CameraAccessException) {
            activity?.runOnUiThread {
                dartMessenger?.send(DartMessenger.EventType.ERROR, "CameraAccessException")
            }
        } catch (e: Exception) {
            Log.e("CameraNativeView", "ensurePreviewRunning failed", e)
            activity?.runOnUiThread {
                dartMessenger?.send(
                    DartMessenger.EventType.ERROR,
                    e.message ?: "Preview failed",
                )
            }
        } finally {
            previewOperationInFlight = false
        }
    }

    private fun runWhenSessionReady(maxAttempts: Int = 80, action: () -> Unit) {
        val act = activity
        if (act == null) {
            action()
            return
        }
        var attempts = 0
        val poll = object : Runnable {
            override fun run() {
                if (PedroCameraBridge.isCaptureSessionReady(rtmpCamera) || attempts >= maxAttempts) {
                    if (PedroCameraBridge.isCaptureSessionReady(rtmpCamera)) {
                        action()
                    }
                    return
                }
                attempts++
                act.window?.decorView?.postDelayed(this, 50)
            }
        }
        act.runOnUiThread { poll.run() }
    }

    private fun applyPendingControls() {
        val zoom = pendingZoomLevel ?: return
        if (PedroCameraBridge.setZoom(rtmpCamera, zoom)) {
            pendingZoomLevel = null
        }
    }

    private fun requestZoom(level: Float) {
        pendingZoomLevel = level
        if (PedroCameraBridge.setZoom(rtmpCamera, level)) {
            pendingZoomLevel = null
        }
    }

    fun shouldRetainForLiveStream(): Boolean =
        rtmpCamera.isStreaming || rtmpCamera.isRecording

    fun onFlutterPlatformViewReattached(context: Context, act: Activity) {
        activity = act
        isSurfaceCreated = PreviewSurfaceLifecycle.isHolderSurfaceValid(glView)
        Log.i("CameraNativeView", "Platform view reattached — recovering preview")
        if (!rtmpCamera.isStreaming) {
            overlayBurnIn.release()
        }
        if (isSurfaceCreated) {
            schedulePreviewReattach()
        }
    }

    fun forceRelease() {
        try {
            overlayBurnIn.release()
        } catch (_: Exception) {
        }
        resetPreviewGlLock()
        encoderPrepared = false
    }

    override fun onAuthSuccessRtmp() {
    }

    override fun onNewBitrateRtmp(bitrate: Long) {
    }

    override fun onConnectionSuccessRtmp() {
        Log.i("CameraNativeView", "RTMP connected")
        activity?.runOnUiThread {
            linkEncoderPipeline()
            dartMessenger?.send(DartMessenger.EventType.RTMP_CONNECTED, null)
        }
    }

    override fun onConnectionFailedRtmp(reason: String) {
        Log.e("CameraNativeView", "RTMP disconnected: $reason")
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
        Log.i("CameraNativeView", "RTMP disconnected")
        activity?.runOnUiThread {
            dartMessenger?.send(DartMessenger.EventType.RTMP_STOPPED, "Disconnected")
        }
    }

    fun close() {
        Log.i("CameraNativeView", "Camera stopped")
    }

    fun takePicture(filePath: String, result: MethodChannel.Result) {
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


    fun startVideoStreaming(
        url: String?,
        bitrate: Int?,
        micEnabled: Boolean = true,
        result: MethodChannel.Result
    ) {
        if (url == null) {
            result.error("startVideoStreaming", "Must specify a url.", null)
            return
        }

        try {
            if (!rtmpCamera.isStreaming) {
                val act = activity
                if (act == null) {
                    result.error("videoStreamingFailed", "Activity unavailable", null)
                    return
                }
                if (!previewGlLocked) {
                    lockPreviewGlAtFirstStart()
                }
                val glConfig = lockedGlConfig ?: BroadcastGlConfig.compute(
                    act,
                    cameraName,
                    preset,
                    lockedOrientationMode,
                )
                // GL output must already match prepareVideo dimensions (Pedro constraint).
                reapplyLockedPreviewGl()
                val profile = CameraUtils.getBestAvailableCamcorderProfileForResolutionPreset(
                    cameraName,
                    preset,
                )
                val videoBitrate = bitrate ?: profile.videoBitRate
                val landscape = PreviewSizeSelector.isLandscapeBroadcast(lockedOrientationMode)
                // Landscape: 16:9 encoder fills YouTube width; portrait: same preview GL as app.
                val encW = if (landscape) glConfig.encoderWidth else glConfig.previewGlWidth
                val encH = if (landscape) glConfig.encoderHeight else glConfig.previewGlHeight
                val streamRot = streamRotationFor(lockedOrientationMode)
                StreamPipelineLog.goLive(
                    mode = lockedOrientationMode,
                    encW = encW,
                    encH = encH,
                    encRot = glConfig.videoEncoderRotation,
                    streamRot = streamRot,
                    previewGlW = glConfig.previewGlWidth,
                    previewGlH = glConfig.previewGlHeight,
                    glRot = glConfig.glRotation,
                )
                val encRot = glConfig.videoEncoderRotation
                val prepared = if (rtmpCamera.isRecording) {
                    rtmpCamera.prepareVideo(
                        encW,
                        encH,
                        30,
                        videoBitrate,
                        2,
                        encRot,
                    )
                } else {
                    rtmpCamera.prepareAudio() && rtmpCamera.prepareVideo(
                        encW,
                        encH,
                        30,
                        videoBitrate,
                        2,
                        encRot,
                    )
                }
                if (!prepared) {
                    encoderPrepared = false
                    result.error(
                        "videoStreamingFailed",
                        "Error preparing stream, This device cant do it",
                        null,
                    )
                    return
                }
                encoderPrepared = true
                if (!micEnabled) {
                    rtmpCamera.disableAudio()
                }
                rtmpCamera.startStream(url)
                applyStreamRotationIfLive()
                linkEncoderPipeline()
            } else {
                rtmpCamera.stopStream()
                encoderPrepared = false
            }
            Log.i("CameraNativeView", "Encoder started")
            result.success(null)
        } catch (e: CameraAccessException) {
            result.error("videoStreamingFailed", e.message, null)
        } catch (e: IOException) {
            result.error("videoStreamingFailed", e.message, null)
        }
    }

    fun startVideoRecordingAndStreaming(
        filePath: String?,
        url: String?,
        bitrate: Int?,
        micEnabled: Boolean = true,
        result: MethodChannel.Result
    ) {
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
            startVideoStreaming(url, bitrate, micEnabled, result)
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
        runOnMain(result) {
            try {
                overlayBurnIn.release()
                rtmpCamera.apply {
                    if (isStreaming) stopStream()
                    if (isRecording) stopRecord()
                }
                encoderPrepared = false
                if (isSurfaceCreated) {
                    configurePreviewForOrientation()
                }
                result.success(null)
            } catch (e: CameraAccessException) {
                result.error("videoRecordingFailed", e.message, null)
            } catch (e: IllegalStateException) {
                result.error("videoRecordingFailed", e.message, null)
            }
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
        if (!cameraNameArg.isNullOrEmpty()) {
            cameraName = cameraNameArg
        }
        ensurePreviewRunning()
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
                if (!isSurfaceCreated) {
                    result.success(null)
                    return@runOnMain
                }
                val switched = invokeSwitchCameraById(cameraId)
                if (!switched && !rtmpCamera.isStreaming) {
                    configurePreviewForOrientation()
                    invokeSwitchCameraById(cameraId)
                }
                runWhenSessionReady { requestZoom(1f) }
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
                    runWhenSessionReady { requestZoom(1f) }
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

    fun setMicMuted(muted: Boolean, result: MethodChannel.Result) {
        runOnMain(result) {
            try {
                if (muted) {
                    rtmpCamera.disableAudio()
                } else {
                    rtmpCamera.enableAudio()
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e("CameraNativeView", "setMicMuted", e)
                result.error("micFailed", e.message, null)
            }
        }
    }

    fun restartPreview(result: MethodChannel.Result) {
        runOnMain(result) {
            waitForValidSurface {
                try {
                    reattachPreviewSurface(preserveStream = rtmpCamera.isStreaming)
                    result.success(null)
                } catch (e: Exception) {
                    Log.e("CameraNativeView", "restartPreview", e)
                    result.error("previewFailed", e.message, null)
                }
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
                pendingZoomLevel = level
                if (!rtmpCamera.isOnPreview && !rtmpCamera.isStreaming) {
                    result.error("zoomFailed", "Camera preview not ready", null)
                    return@runOnMain
                }
                if (PedroCameraBridge.setZoom(rtmpCamera, level)) {
                    pendingZoomLevel = null
                }
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
        val cfg = lockedGlConfig
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
        ret["broadcastMode"] = lockedOrientationMode
        ret["previewGlLocked"] = previewGlLocked
        ret["isStreaming"] = rtmpCamera.isStreaming
        if (cfg != null) {
            ret["glOutputWidth"] = cfg.previewGlWidth
            ret["glOutputHeight"] = cfg.previewGlHeight
            ret["streamOutputWidth"] = cfg.encoderWidth
            ret["streamOutputHeight"] = cfg.encoderHeight
            ret["glRotation"] = cfg.glRotation
            ret["videoEncoderRotation"] = cfg.videoEncoderRotation
            ret["previewStartRotation"] = cfg.previewStartRotation
            ret["cameraBufferWidth"] = cfg.cameraBuffer.width
            ret["cameraBufferHeight"] = cfg.cameraBuffer.height
            ret["displayRotation"] = cfg.displayRotation
            ret["streamRotationApplied"] = lastAppliedStreamRotation
        }
        val viewFrame = glView.holder?.surfaceFrame
        if (viewFrame != null) {
            ret["previewSurfaceWidth"] = viewFrame.width()
            ret["previewSurfaceHeight"] = viewFrame.height()
        }
        result.success(ret)
    }

    override fun getView(): View {
        return glView
    }

    override fun dispose() {
        cancelScheduledReattach()
        isSurfaceCreated = false

        if (shouldRetainForLiveStream()) {
            Log.i("CameraNativeView", "Preview detached — stream session retained")
            return
        }

        Log.i("CameraNativeView", "Preview detached")
        forceRelease()
        activity = null
    }

    private fun isFrontFacing(cameraName: String): Boolean {
        val cameraManager = activity?.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val characteristics = cameraManager.getCameraCharacteristics(cameraName)
        return characteristics.get(CameraCharacteristics.LENS_FACING) == CameraMetadata.LENS_FACING_FRONT
    }
}
