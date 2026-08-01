package com.app.rtmp_publisher

/**
 * Pedro's legacy RTMP client defaults RTMPS without an explicit port to 1935.
 * Facebook Live (and most RTMPS ingest) requires 443.
 */
object RtmpUrlSanitizer {
    fun ensureRtmpsPort(url: String): String {
        val trimmed = url.trim()
        if (!trimmed.startsWith("rtmps://", ignoreCase = true)) return trimmed
        val rest = trimmed.substring("rtmps://".length)
        val slash = rest.indexOf('/')
        val authority = if (slash >= 0) rest.substring(0, slash) else rest
        val path = if (slash >= 0) rest.substring(slash) else ""
        if (authority.contains(":")) return trimmed
        return "rtmps://$authority:443$path"
    }

    /** Collapse accidental `.../rtmp//key` joins from leading-slash keys. */
    fun collapseDuplicateSlashes(url: String): String {
        val schemeIdx = url.indexOf("://")
        if (schemeIdx < 0) return url
        val prefix = url.substring(0, schemeIdx + 3)
        val rest = url.substring(schemeIdx + 3).replace(Regex("/{2,}"), "/")
        return prefix + rest
    }

    fun sanitize(url: String): String =
        ensureRtmpsPort(collapseDuplicateSlashes(url.trim()))
}
