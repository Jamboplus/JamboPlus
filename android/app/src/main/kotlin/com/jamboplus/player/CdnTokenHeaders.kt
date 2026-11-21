package com.jamboplus.player

import android.net.Uri
import android.util.Base64
import org.json.JSONObject

/** Azam/Nagra `tok_<jwt>` URLs embed allowed Referer/Origin in the JWT `url` field. */
object CdnTokenHeaders {
    private val tokPattern = Regex("""/tok_([^.]+)\.([^.]+)\.([^/]+)/""")

    fun refererOriginForUrl(rawUrl: String): Pair<String, String>? {
        val match = tokPattern.find(rawUrl.trim()) ?: return null
        val payloadSegment = match.groupValues.getOrNull(2)?.trim().orEmpty()
        if (payloadSegment.isEmpty()) return null
        return try {
            var encoded = payloadSegment.replace('-', '+').replace('_', '/')
            val pad = (4 - encoded.length % 4) % 4
            encoded += "=".repeat(pad)
            val jsonText = String(Base64.decode(encoded, Base64.DEFAULT), Charsets.UTF_8)
            val payload = JSONObject(jsonText)
            val allowed = payload.optString("url")
                .ifBlank { payload.optString("referer") }
                .ifBlank { payload.optString("origin") }
                .trim()
            if (allowed.isEmpty()) return null
            val uri = Uri.parse(allowed)
            if (uri.scheme.isNullOrBlank() || uri.host.isNullOrBlank()) return null
            val port = when (uri.port) {
                -1, 80, 443 -> ""
                else -> ":${uri.port}"
            }
            val origin = "${uri.scheme}://${uri.host}$port"
            val referer = if (origin.endsWith("/")) origin else "$origin/"
            referer to origin
        } catch (_: Exception) {
            null
        }
    }

    fun isTokenizedCdnUrl(rawUrl: String?): Boolean {
        if (rawUrl.isNullOrBlank()) return false
        return tokPattern.containsMatchIn(rawUrl.trim())
    }
}
