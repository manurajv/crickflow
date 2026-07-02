package com.app.rtmp_publisher

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class NativeViewFactory(private val activity: Activity) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    var cameraNativeView: CameraNativeView? = null
    var cameraName: String = "0"
    var preset: Camera.ResolutionPreset = Camera.ResolutionPreset.low
    var enableAudio: Boolean = false
    var dartMessenger: DartMessenger? = null

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val existing = cameraNativeView
        if (existing != null && existing.shouldRetainForLiveStream()) {
            existing.onFlutterPlatformViewReattached(context, activity)
            return existing
        }
        existing?.forceRelease()
        cameraNativeView = CameraNativeView(
            context,
            activity,
            enableAudio,
            preset,
            cameraName,
            dartMessenger,
        )
        return cameraNativeView!!
    }
}
