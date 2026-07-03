package com.app.rtmp_publisher

import android.content.Context
import android.graphics.SurfaceTexture
import android.util.Log
import android.util.Size
import android.view.Surface
import com.pedro.encoder.input.video.CameraHelper
import com.pedro.encoder.input.video.Camera2ApiManager
import com.pedro.rtplibrary.rtmp.RtmpCamera2
import com.pedro.rtplibrary.view.GlInterface
import com.pedro.rtplibrary.view.OpenGlView

/**
 * Rebuilds the Camera2 preview pipeline after Android destroys the [SurfaceView]
 * surface (lock screen, notification shade, app switch) without stopping RTMP.
 *
 * Pedro's [OpenGlViewBase] stops the GL thread in [android.view.SurfaceHolder.Callback.surfaceDestroyed];
 * [Camera2ApiManager] may still hold abandoned [Surface] / [SurfaceTexture] references unless cleared.
 */
object PreviewSurfaceLifecycle {
    private const val TAG = "PreviewSurfaceLifecycle"

    interface Listener {
        fun onPreviewSurfaceDestroyed(generation: Long)
        fun onPreviewSurfaceAvailable(generation: Long)
    }

    /** Drop Camera2 session + stale surface refs. Does not stop RTMP or encoders. */
    fun detachAfterSurfaceLoss(rtmpCamera: RtmpCamera2) {
        val apiManager = PedroCameraBridge.getCamera2ApiManager(rtmpCamera) ?: return
        try {
            if (apiManager.isRunning) {
                apiManager.closeCamera(true)
            } else {
                invalidateCameraManagerSurfaces(apiManager)
            }
            Log.i(TAG, "Camera detached — abandoned preview surface cleared")
        } catch (e: Exception) {
            Log.e(TAG, "detachAfterSurfaceLoss", e)
            invalidateCameraManagerSurfaces(apiManager)
        }
    }

    /**
     * GL → prepareCamera → openLastCamera → (encoder surface if live).
     * Call only when [OpenGlView.holder.surface] is valid.
     */
    fun reattachPreviewPipeline(
        rtmpCamera: RtmpCamera2,
        glView: OpenGlView,
        previewWidth: Int,
        previewHeight: Int,
        streaming: Boolean,
        context: Context? = null,
        broadcastMode: String = "portrait",
        displayRotationOverride: Int? = null,
    ): Boolean {
        if (previewWidth <= 0 || previewHeight <= 0) return false
        if (!isHolderSurfaceValid(glView)) {
            Log.w(TAG, "reattach skipped — holder surface invalid")
            return false
        }

        val glInterface = getGlInterface(rtmpCamera) ?: return false
        val apiManager = PedroCameraBridge.getCamera2ApiManager(rtmpCamera) ?: return false

        return try {
            // 1) New GL thread + SurfaceTexture (blocks until Pedro semaphore releases).
            glInterface.start()

            if (context != null) {
                val previewSize = Size(previewWidth, previewHeight)
                val displayRotation = displayRotationOverride
                    ?: CameraHelper.getCameraOrientation(context)
                PedroCameraBridge.applyPedroPreviewGlSetup(
                    glInterface,
                    context,
                    previewSize,
                    displayRotation,
                )
            }

            val surfaceTexture: SurfaceTexture = glInterface.surfaceTexture
                ?: run {
                    Log.e(TAG, "GL SurfaceTexture null after start")
                    return false
                }

            if (!isSurfaceTextureUsable(surfaceTexture)) {
                Log.e(TAG, "GL SurfaceTexture released")
                return false
            }

            val fps = getVideoEncoderFps(rtmpCamera) ?: 30
            surfaceTexture.setDefaultBufferSize(previewWidth, previewHeight)

            // 2) Bind camera at preview resolution — GL scales to encoder when streaming.
            apiManager.prepareCamera(surfaceTexture, previewWidth, previewHeight, fps)

            // 3) While streaming, re-link MediaCodec input surface to GL output.
            if (streaming) {
                val encoderSurface = getVideoEncoderInputSurface(rtmpCamera)
                if (encoderSurface != null && encoderSurface.isValid) {
                    glInterface.addMediaCodecSurface(encoderSurface)
                } else {
                    Log.w(TAG, "Encoder input surface invalid during reattach")
                }
            }

            // 4) Open camera on a fresh HandlerThread (Pedro creates one per openCameraId).
            apiManager.openLastCamera()

            setOnPreview(rtmpCamera, true)
            Log.i(TAG, "Preview pipeline reattached (streaming=$streaming)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "reattachPreviewPipeline failed", e)
            false
        }
    }

    fun isHolderSurfaceValid(glView: OpenGlView): Boolean {
        val holder = glView.holder ?: return false
        val surface: Surface? = holder.surface
        val frame = holder.surfaceFrame
        return surface != null && surface.isValid &&
            frame != null && frame.width() > 0 && frame.height() > 0
    }

    private fun isSurfaceTextureUsable(texture: SurfaceTexture): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                !texture.isReleased
            } else {
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun invalidateCameraManagerSurfaces(apiManager: Camera2ApiManager) {
        setField(apiManager, "surfaceEncoder", null)
        setField(apiManager, "builderInputSurface", null)
        setField(apiManager, "cameraCaptureSession", null)
        setField(apiManager, "cameraDevice", null)
        setField(apiManager, "surfaceView", null)
        setField(apiManager, "textureView", null)
        setField(apiManager, "prepared", false)
        setField(apiManager, "running", false)
        setField(apiManager, "cameraHandler", null)
    }

    private fun getGlInterface(rtmpCamera: RtmpCamera2): GlInterface? {
        var clazz: Class<*>? = rtmpCamera.javaClass
        while (clazz != null) {
            try {
                val field = clazz.getDeclaredField("glInterface")
                field.isAccessible = true
                return field.get(rtmpCamera) as? GlInterface
            } catch (_: NoSuchFieldException) {
                clazz = clazz.superclass
            }
        }
        return null
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

    private fun setOnPreview(rtmpCamera: RtmpCamera2, value: Boolean) {
        var clazz: Class<*>? = rtmpCamera.javaClass
        while (clazz != null) {
            try {
                val field = clazz.getDeclaredField("onPreview")
                field.isAccessible = true
                field.setBoolean(rtmpCamera, value)
                return
            } catch (_: NoSuchFieldException) {
                clazz = clazz.superclass
            } catch (_: Exception) {
                return
            }
        }
    }

    private fun setField(target: Any, name: String, value: Any?) {
        try {
            val field = target.javaClass.getDeclaredField(name)
            field.isAccessible = true
            field.set(target, value)
        } catch (_: Exception) {
        }
    }
}
