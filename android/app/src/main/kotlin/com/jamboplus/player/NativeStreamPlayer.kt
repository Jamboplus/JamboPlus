package com.jamboplus.player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.view.Surface
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import androidx.media3.exoplayer.drm.LocalMediaDrmCallback
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.trackselection.AdaptiveTrackSelection
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import org.json.JSONArray
import org.json.JSONObject

/**
 * Texture-backed ExoPlayer. Headers go out on OkHttp (WebView cannot set
 * Referer/Origin on media requests). One steady buffer, no mid-play restart.
 */
@OptIn(UnstableApi::class)
class NativeStreamPlayer(
    private val context: Context,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, Player.Listener {

    private val textureRegistry: TextureRegistry = flutterEngine.renderer
    private val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD)
    private val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var exoPlayer: ExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null
    private var activeTextureId: Long = -1
    private var session = 0
    private var recoveries = 0
    private var pendingLanguage = "sw"
    private var pendingQuality = "Auto"
    private var lastHeightsKey = ""
    private var released = false
    private var currentUrl = ""
    private var currentHeaders: Map<String, String> = emptyMap()
    private var currentFormat = Format.HLS
    private var currentDrm = ""
    private var currentClearKey = ""
    private var currentLicenseUrl = ""
    private var triedPageHeaders = false
    private var triedOtherFormat = false

    private val tick = object : Runnable {
        override fun run() {
            if (released) return
            emitState(force = false)
            mainHandler.postDelayed(this, 800)
        }
    }

    fun attach() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    fun detach() {
        released = true
        mainHandler.removeCallbacks(tick)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        releasePlayer()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                try {
                    val id = open(call)
                    result.success(id)
                } catch (e: Exception) {
                    Log.e(TAG, "open failed", e)
                    result.error("open_failed", e.message ?: "Imeshindwa kufungua stream", null)
                }
            }
            "play" -> {
                exoPlayer?.playWhenReady = true
                result.success(null)
            }
            "pause" -> {
                exoPlayer?.playWhenReady = false
                result.success(null)
            }
            "seek" -> {
                val seconds = call.argument<Double>("seconds") ?: 0.0
                exoPlayer?.seekTo((seconds * 1000).toLong())
                result.success(null)
            }
            "setQuality" -> {
                val quality = call.argument<String>("quality") ?: "Auto"
                pendingQuality = quality
                applyQuality(quality)
                result.success(null)
            }
            "setLanguage" -> {
                val language = call.argument<String>("language") ?: "sw"
                pendingLanguage = if (language.lowercase().startsWith("en")) "en" else "sw"
                applyLanguage(pendingLanguage)
                result.success(null)
            }
            "dispose" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                if (textureId == null || textureId == activeTextureId) {
                    session++
                    releasePlayer()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun open(call: MethodCall): Long {
        val mine = ++session
        val url = call.argument<String>("url")?.trim().orEmpty()
        if (url.isEmpty()) throw IllegalArgumentException("URL is empty")
        @Suppress("UNCHECKED_CAST")
        val incoming = (call.argument<Map<String, Any?>>("headers") ?: emptyMap())
            .mapNotNull { (key, value) ->
                val text = value?.toString()?.trim().orEmpty()
                if (key.isBlank() || text.isEmpty()) null else key to text
            }
            .toMap()
        val headers = PlaybackHttpHeaders.merge(incoming, url)
        val drm = call.argument<String>("drm")?.lowercase().orEmpty()
        val clearKey = call.argument<String>("clearKey").orEmpty()
        val licenseUrl = call.argument<String>("licenseUrl").orEmpty()
        pendingQuality = call.argument<String>("quality")?.takeIf { it.isNotBlank() } ?: "360p"
        pendingLanguage = if ((call.argument<String>("language") ?: "sw").lowercase().startsWith("en")) {
            "en"
        } else {
            "sw"
        }
        currentUrl = url
        currentHeaders = headers
        currentFormat = classify(url)
        currentDrm = drm
        currentClearKey = clearKey
        currentLicenseUrl = licenseUrl
        triedPageHeaders = headers.keys.any { it.equals("Referer", ignoreCase = true) }
        triedOtherFormat = false
        Log.i(TAG, "open format=$currentFormat headerKeys=${headers.keys.sorted()}")

        releasePlayer()
        if (mine != session) return -1

        val entry = textureRegistry.createSurfaceTexture()
        val surfaceTexture = entry.surfaceTexture()
        surfaceTexture.setDefaultBufferSize(1920, 1080)
        val videoSurface = Surface(surfaceTexture)
        textureEntry = entry
        surface = videoSurface
        activeTextureId = entry.id()

        val selector = DefaultTrackSelector(
            context,
            AdaptiveTrackSelection.Factory(
                /* minDurationForQualityIncreaseMs = */ 12_000,
                /* maxDurationForQualityDecreaseMs = */ 8_000,
                /* minDurationToRetainAfterDiscardMs = */ 15_000,
                /* bandwidthFraction = */ 0.7f,
            ),
        )
        selector.parameters = selector.buildUponParameters()
            .setForceHighestSupportedBitrate(false)
            .setTunnelingEnabled(false)
            .setMaxVideoSize(Int.MAX_VALUE, DEFAULT_MAX_HEIGHT)
            .setMaxVideoBitrate(DEFAULT_MAX_BITRATE)
            .setPreferredAudioLanguages(*audioAliases(pendingLanguage))
            .build()
        trackSelector = selector

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                MIN_BUFFER_MS,
                MAX_BUFFER_MS,
                BUFFER_FOR_PLAYBACK_MS,
                BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .setBackBuffer(BACK_BUFFER_MS, false)
            .build()

        val renderers = DefaultRenderersFactory(context).apply {
            setEnableDecoderFallback(true)
            setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
        }

        val player = ExoPlayer.Builder(context)
            .setRenderersFactory(renderers)
            .setTrackSelector(selector)
            .setLoadControl(loadControl)
            .setWakeMode(C.WAKE_MODE_LOCAL)
            .setHandleAudioBecomingNoisy(true)
            .build()
        player.setVideoSurface(videoSurface)
        player.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build(),
            /* handleAudioFocus = */ true,
        )
        player.videoScalingMode = C.VIDEO_SCALING_MODE_SCALE_TO_FIT
        player.addListener(this)
        player.playWhenReady = true
        exoPlayer = player
        recoveries = 0
        lastHeightsKey = ""

        if (mine != session) {
            releasePlayer()
            return -1
        }

        applyQuality(pendingQuality)
        applyLanguage(pendingLanguage)
        loadSource(player, currentHeaders, currentFormat)
        mainHandler.removeCallbacks(tick)
        mainHandler.postDelayed(tick, 800)
        emitState(force = true)
        return entry.id()
    }

    private fun buildMediaItem(
        url: String,
        format: Format,
        drm: String,
        clearKey: String,
        licenseUrl: String,
        headers: Map<String, String>,
    ): MediaItem {
        val builder = MediaItem.Builder().setUri(url)
        when (format) {
            Format.HLS -> {
                builder.setMimeType("application/x-mpegurl")
                builder.setLiveConfiguration(
                    MediaItem.LiveConfiguration.Builder()
                        .setTargetOffsetMs(4_000)
                        .setMinOffsetMs(1_000)
                        .setMaxOffsetMs(8_000)
                        .setMinPlaybackSpeed(1f)
                        .setMaxPlaybackSpeed(1f)
                        .build(),
                )
            }
            Format.DASH -> builder.setMimeType("application/dash+xml")
            Format.PROGRESSIVE -> {
                val path = url.substringBefore('?').substringBefore('#').lowercase()
                if (path.endsWith(".ts")) builder.setMimeType("video/mp2t")
            }
        }
        if (drm == "clearkey" || drm == "clear_key") {
            val json = clearKeyLicense(clearKey)
            if (json != null) {
                builder.setDrmConfiguration(
                    MediaItem.DrmConfiguration.Builder(C.CLEARKEY_UUID)
                        .setMultiSession(false)
                        .build(),
                )
            }
        } else if (drm.startsWith("widevine") && licenseUrl.isNotBlank()) {
            builder.setDrmConfiguration(
                MediaItem.DrmConfiguration.Builder(C.WIDEVINE_UUID)
                    .setLicenseUri(licenseUrl)
                    .setLicenseRequestHeaders(headers)
                    .setMultiSession(false)
                    .build(),
            )
        }
        return builder.build()
    }

    private fun attachDrm(
        factory: androidx.media3.exoplayer.source.MediaSource.Factory,
        drm: String,
        clearKey: String,
        licenseUrl: String,
        headers: Map<String, String>,
    ) {
        val manager = when {
            drm == "clearkey" || drm == "clear_key" -> {
                val json = clearKeyLicense(clearKey) ?: return
                DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(C.CLEARKEY_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
                    .setPlayClearSamplesWithoutKeys(true)
                    .build(LocalMediaDrmCallback(json))
            }
            drm.startsWith("widevine") && licenseUrl.isNotBlank() -> {
                val callback = HttpMediaDrmCallback(
                    licenseUrl,
                    StreamHttpClient.dataSourceFactory(headers),
                )
                headers.forEach { (name, value) ->
                    if (value.isNotBlank()) callback.setKeyRequestProperty(name, value)
                }
                DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(C.WIDEVINE_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
                    .setPlayClearSamplesWithoutKeys(true)
                    .build(callback)
            }
            else -> return
        }
        factory.setDrmSessionManagerProvider { manager }
    }

    private enum class Format { DASH, HLS, PROGRESSIVE }

    private fun classify(url: String): Format {
        val trimmed = url.trim()
        val path = trimmed.substringBefore('?').substringBefore('#').lowercase()
        return when {
            path.endsWith(".mpd") -> Format.DASH
            path.endsWith(".m3u8") || path.endsWith(".m3u") -> Format.HLS
            path.endsWith(".mp4") || path.endsWith(".m4v") || path.endsWith(".webm") ||
                path.endsWith(".mkv") || path.endsWith(".ts") -> Format.PROGRESSIVE
            trimmed.contains(".mpd", ignoreCase = true) &&
                !trimmed.contains(".m3u8", ignoreCase = true) -> Format.DASH
            trimmed.contains(".m3u8", ignoreCase = true) ||
                trimmed.contains(".m3u", ignoreCase = true) -> Format.HLS
            isRawTransportStream(trimmed) -> Format.PROGRESSIVE
            else -> Format.HLS
        }
    }

    /** Xtream and extension-less HTTP links are raw TS, not an HLS playlist. */
    private fun isRawTransportStream(url: String): Boolean {
        val uri = runCatching { Uri.parse(url) }.getOrNull() ?: return false
        val path = uri.path?.lowercase().orEmpty()
        if (uri.scheme.equals("http", ignoreCase = true) && !path.contains('.')) return true
        return Regex(
            """^https?://[^/]+/(live|stream)/[^/]+/[^/]+/[^/?#]+$""",
            RegexOption.IGNORE_CASE,
        ).containsMatchIn(url.substringBefore('#'))
    }

    private fun loadSource(player: ExoPlayer, headers: Map<String, String>, format: Format) {
        val dataSource = StreamHttpClient.dataSourceFactory(headers)
        val mediaItem = buildMediaItem(
            currentUrl,
            format,
            currentDrm,
            currentClearKey,
            currentLicenseUrl,
            headers,
        )
        val factory = when (format) {
            Format.DASH -> DashMediaSource.Factory(dataSource)
                .setFallbackTargetLiveOffsetMs(12_000)
                .setLoadErrorHandlingPolicy(retryPolicy())
            Format.HLS -> HlsMediaSource.Factory(dataSource)
                .setAllowChunklessPreparation(true)
                .setLoadErrorHandlingPolicy(hlsRetryPolicy())
            Format.PROGRESSIVE -> ProgressiveMediaSource.Factory(dataSource)
                .setLoadErrorHandlingPolicy(retryPolicy())
        }
        attachDrm(factory, currentDrm, currentClearKey, currentLicenseUrl, headers)
        player.setMediaSource(factory.createMediaSource(mediaItem))
        player.prepare()
        player.playWhenReady = true
    }

    private fun pageHeaders(headers: Map<String, String>, url: String): Map<String, String>? {
        if (headers.keys.any { it.equals("Referer", ignoreCase = true) }) return null
        val uri = runCatching { Uri.parse(url) }.getOrNull() ?: return null
        if (uri.scheme.isNullOrBlank() || uri.host.isNullOrBlank()) return null
        val port = when (uri.port) {
            -1, 80, 443 -> ""
            else -> ":${uri.port}"
        }
        val origin = "${uri.scheme}://${uri.host}$port"
        return LinkedHashMap(headers).apply {
            put("Origin", origin)
            put("Referer", "$origin/")
        }
    }

    private fun applyQuality(quality: String) {
        val selector = trackSelector ?: return
        val builder = selector.parameters.buildUpon().clearOverridesOfType(C.TRACK_TYPE_VIDEO)
        if (quality.equals("Auto", ignoreCase = true)) {
            builder
                .setMaxVideoSize(Int.MAX_VALUE, AUTO_MAX_HEIGHT)
                .setMaxVideoBitrate(AUTO_MAX_BITRATE)
                .setForceHighestSupportedBitrate(false)
        } else {
            val height = quality.filter { it.isDigit() }.toIntOrNull() ?: DEFAULT_MAX_HEIGHT
            val bitrate = when {
                height <= 240 -> 400_000
                height <= 360 -> 900_000
                height <= 480 -> 1_600_000
                height <= 720 -> 3_500_000
                else -> Int.MAX_VALUE
            }
            builder
                .setMaxVideoSize(Int.MAX_VALUE, height)
                .setMaxVideoBitrate(bitrate)
                .setForceHighestSupportedBitrate(false)
        }
        selector.parameters = builder.build()
    }

    private fun applyLanguage(language: String) {
        val selector = trackSelector ?: return
        selector.parameters = selector.parameters.buildUpon()
            .setPreferredAudioLanguages(*audioAliases(language))
            .build()
    }

    private fun audioAliases(language: String): Array<String> {
        return if (language.lowercase().startsWith("en")) {
            arrayOf("en", "eng", "en-us", "en-gb")
        } else {
            arrayOf("sw", "swa", "swh", "sw-tz", "sw-ke")
        }
    }

    private fun retryPolicy(): LoadErrorHandlingPolicy = DefaultLoadErrorHandlingPolicy(6)

    private fun hlsRetryPolicy(): LoadErrorHandlingPolicy {
        return object : DefaultLoadErrorHandlingPolicy(6) {
            override fun getRetryDelayMsFor(loadErrorInfo: LoadErrorHandlingPolicy.LoadErrorInfo): Long {
                val code = (loadErrorInfo.exception as? HttpDataSource.InvalidResponseCodeException)?.responseCode
                if (code == 404 || code == 410) return C.TIME_UNSET
                return super.getRetryDelayMsFor(loadErrorInfo)
            }
        }
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        emitState(force = true)
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        if (isPlaying) recoveries = 0
        emitState(force = true)
    }

    override fun onTracksChanged(tracks: Tracks) {
        val heights = linkedSetOf<Int>()
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_VIDEO) continue
            for (i in 0 until group.length) {
                if (!group.isTrackSupported(i)) continue
                val height = group.getTrackFormat(i).height
                if (height > 0) heights.add(height)
            }
        }
        val key = heights.sorted().joinToString(",")
        if (key == lastHeightsKey) return
        lastHeightsKey = key
        val qualities = heights.sorted().map { "${it}p" } + "Auto"
        emit(
            mapOf(
                "type" to "tracks",
                "qualities" to qualities,
                "languages" to listOf("sw", "en"),
                "activeQuality" to pendingQuality,
                "activeLanguage" to pendingLanguage,
            ),
        )
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        if (videoSize.width <= 0 || videoSize.height <= 0) return
        emit(
            mapOf(
                "type" to "videoSize",
                "width" to videoSize.width,
                "height" to videoSize.height,
            ),
        )
    }

    override fun onPlayerError(error: PlaybackException) {
        val player = exoPlayer
        val recoverable = error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW ||
            generateSequence(error as Throwable) { it.cause }
                .any { it.javaClass.simpleName == "PlaylistResetException" }
        if (player != null && recoverable && recoveries < 3) {
            recoveries++
            Log.w(TAG, "recover live playback #${recoveries}")
            player.seekToDefaultPosition()
            player.prepare()
            player.playWhenReady = true
            return
        }
        val code = httpStatus(error)
        if (player != null && (code == 403 || code == 404) && !triedPageHeaders) {
            val withPage = pageHeaders(currentHeaders, currentUrl)
            if (withPage != null) {
                triedPageHeaders = true
                currentHeaders = withPage
                Log.i(TAG, "retry with page headers after HTTP $code keys=${withPage.keys.sorted()}")
                loadSource(player, withPage, currentFormat)
                return
            }
        }
        val badContainer = error.errorCode == PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED ||
            error.errorCode == PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED ||
            error.errorCode == PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED ||
            code == 404
        if (player != null && badContainer && !triedOtherFormat && currentFormat != Format.DASH) {
            triedOtherFormat = true
            currentFormat = if (currentFormat == Format.HLS) Format.PROGRESSIVE else Format.HLS
            Log.i(TAG, "retry format=$currentFormat after ${code ?: error.errorCode}")
            loadSource(player, currentHeaders, currentFormat)
            return
        }
        Log.e(TAG, "playback failed code=$code", error)
        emit(mapOf("type" to "error", "message" to "Video haikuweza kuchezwa."))
    }

    private fun httpStatus(error: PlaybackException): Int? {
        return generateSequence(error as Throwable) { it.cause }
            .filterIsInstance<HttpDataSource.InvalidResponseCodeException>()
            .firstOrNull()
            ?.responseCode
    }

    private fun emitState(force: Boolean) {
        val player = exoPlayer ?: return
        val buffering = player.playbackState == Player.STATE_BUFFERING && !player.isPlaying
        emit(
            mapOf(
                "type" to "state",
                "playing" to player.isPlaying,
                "buffering" to buffering,
                "position" to player.currentPosition / 1000.0,
                "duration" to if (player.duration > 0 && player.duration != C.TIME_UNSET) {
                    player.duration / 1000.0
                } else {
                    0.0
                },
                "force" to force,
            ),
        )
    }

    private fun emit(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        if (Looper.myLooper() == Looper.getMainLooper()) {
            sink.success(payload)
        } else {
            mainHandler.post { eventSink?.success(payload) }
        }
    }

    private fun releasePlayer() {
        mainHandler.removeCallbacks(tick)
        exoPlayer?.removeListener(this)
        exoPlayer?.clearVideoSurface()
        exoPlayer?.release()
        exoPlayer = null
        trackSelector = null
        surface?.release()
        surface = null
        textureEntry?.release()
        textureEntry = null
        activeTextureId = -1
    }

    private fun clearKeyLicense(raw: String): ByteArray? {
        val parts = raw.split(':')
        if (parts.size != 2) return null
        val kid = hexToBase64Url(parts[0]) ?: return null
        val key = hexToBase64Url(parts[1]) ?: return null
        val keys = JSONArray().put(
            JSONObject()
                .put("kty", "oct")
                .put("kid", kid)
                .put("k", key),
        )
        return JSONObject()
            .put("keys", keys)
            .put("type", "temporary")
            .toString()
            .toByteArray(Charsets.UTF_8)
    }

    private fun hexToBase64Url(raw: String): String? {
        val hex = raw.trim().replace("-", "")
        if (hex.length < 2 || hex.length % 2 != 0) return null
        return try {
            val bytes = ByteArray(hex.length / 2)
            for (i in bytes.indices) {
                bytes[i] = hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
            }
            Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val TAG = "JamboPlayer"
        private const val METHOD = "jamboplus/native_player"
        private const val EVENTS = "jamboplus/native_player_events"
        private const val MIN_BUFFER_MS = 15_000
        private const val MAX_BUFFER_MS = 50_000
        private const val BUFFER_FOR_PLAYBACK_MS = 2_500
        private const val BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 5_000
        private const val BACK_BUFFER_MS = 0
        private const val DEFAULT_MAX_HEIGHT = 360
        private const val DEFAULT_MAX_BITRATE = 900_000
        private const val AUTO_MAX_HEIGHT = 720
        private const val AUTO_MAX_BITRATE = 3_500_000
    }
}
