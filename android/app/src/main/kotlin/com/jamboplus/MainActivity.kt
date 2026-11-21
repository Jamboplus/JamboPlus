package com.jamboplus

import android.content.Intent
import com.jamboplus.orizon.PlaybackPreferences
import com.jamboplus.player.NativeStreamPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val NATIVE_PLAYER_REQUEST = 48291
    }

    private var texturePlayer: NativeStreamPlayer? = null
    private var nativeOpenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        texturePlayer?.detach()
        texturePlayer = NativeStreamPlayer(this, flutterEngine).also { it.attach() }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jamboplus/washa_player")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> openWashaPlayer(call.arguments, result)
                    "syncPlaybackPreferences" -> syncPrefs(call.arguments, result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        texturePlayer?.detach()
        texturePlayer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == NATIVE_PLAYER_REQUEST) {
            nativeOpenResult?.success(null)
            nativeOpenResult = null
        }
    }

    private fun openWashaPlayer(arguments: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?>
        if (args == null) {
            result.error("bad_args", "Expected map", null)
            return
        }
        try {
            val intent = Intent(this, OrizonPlayerActivity::class.java)
            intent.putExtra("url", args["url"]?.toString().orEmpty())
            intent.putExtra("licenseUrl", args["licenseUrl"]?.toString().orEmpty())
            intent.putExtra("token", args["token"]?.toString().orEmpty())
            intent.putExtra(
                "drmType",
                args["drmType"]?.toString().orEmpty().ifEmpty { "NONE" },
            )
            val clearKey = sequenceOf(
                args["clearKeyHex"]?.toString(),
                args["drmClearKey"]?.toString(),
            ).firstOrNull { !it.isNullOrBlank() }.orEmpty()
            intent.putExtra("clearKeyHex", clearKey)
            intent.putExtra("headersJson", args["headersJson"]?.toString().orEmpty())
            intent.putExtra(
                "audioLanguage",
                args["audioLanguage"]?.toString().orEmpty().ifEmpty { "sw" },
            )
            intent.putExtra("dataSaver", args["dataSaver"] == true)
            intent.putExtra("defaultQuality", args["defaultQuality"]?.toString().orEmpty())
            intent.putExtra("fallbackStreamsJson", args["fallbackStreamsJson"]?.toString().orEmpty())
            intent.putExtra("playerPolicyJson", args["playerPolicyJson"]?.toString().orEmpty())
            intent.putExtra(
                "videoZoomMode",
                args["videoZoomMode"]?.toString().orEmpty().ifEmpty { "zoom" },
            )
            nativeOpenResult = result
            @Suppress("DEPRECATION")
            startActivityForResult(intent, NATIVE_PLAYER_REQUEST)
        } catch (e: Exception) {
            nativeOpenResult = null
            result.error("native_open_failed", e.message ?: "Failed to open player", null)
        }
    }

    private fun syncPrefs(arguments: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?>
        if (args == null) {
            result.error("bad_args", "Expected map", null)
            return
        }
        PlaybackPreferences.update(
            dataSaver = args["dataSaver"] == true,
            defaultQuality = args["defaultQuality"]?.toString().orEmpty(),
            videoZoomMode = args["videoZoomMode"]?.toString().orEmpty().ifEmpty { "zoom" },
        )
        result.success(null)
    }
}
