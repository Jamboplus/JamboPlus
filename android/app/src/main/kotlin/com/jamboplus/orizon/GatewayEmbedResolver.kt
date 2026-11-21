package com.jamboplus.orizon

import android.net.Uri
import android.util.Log
import com.jamboplus.orizon.model.DrmType
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * Resolves PHP/embed gateway pages (e.g. sokamax embed.php) into a direct
 * DASH/HLS URL + optional Widevine license so ExoPlayer can play them.
 *
 * Mirrors Washa [GatewayEmbedResolver]: warm the embed page (cookies +
 * X-Requested-With), reject "App Haijatambuliwa", then hit player.php?api=1.
 */
object GatewayEmbedResolver {
    private const val TAG = "GatewayEmbed"
    private const val CACHE_TTL_MS = 60_000L

    data class Resolved(
        val streamUrl: String,
        val licenseUrl: String = "",
        val authToken: String = "",
        val drmType: DrmType = DrmType.NONE,
        val referer: String = "",
        val origin: String = "",
    )

    private data class CacheEntry(val resolved: Resolved, val atMs: Long)

    private val cache = ConcurrentHashMap<String, CacheEntry>()

    fun resolve(gatewayUrl: String): Resolved? {
        val url = gatewayUrl.trim()
        if (url.isEmpty()) return null

        val cached = cache[url]
        if (cached != null && System.currentTimeMillis() - cached.atMs < CACHE_TTL_MS) {
            return cached.resolved
        }

        // Sokamax rate-limits intermittently — one quick retry helps.
        var last: Resolved? = null
        repeat(2) { attempt ->
            last = resolveOnce(url)
            if (last != null) {
                cache[url] = CacheEntry(last!!, System.currentTimeMillis())
                return last
            }
            if (attempt == 0) {
                runCatching { Thread.sleep(1_500) }
            }
        }
        return last
    }

    private fun resolveOnce(url: String): Resolved? {
        val client = newClient()
        val headers = PlaybackHttpHeaders.merge(emptyMap(), url)
        // Warm cookies / app gate (X-Requested-With) on the embed page.
        val pageHtml = fetchText(client, url, headers) ?: return null
        if (pageHtml.contains("App Haijatambuliwa", ignoreCase = true)) {
            Log.w(TAG, "gateway blocked app recognition url=${url.take(160)}")
            return null
        }

        val apiUrl = findApiUrl(url, pageHtml) ?: return null
        Log.i(TAG, "api=${apiUrl.take(160)}")

        val apiHeaders = LinkedHashMap(headers).apply {
            put("Accept", "application/json")
            put("X-Requested-With", OrizonStreamClient.PLAYBACK_APP_PACKAGE)
        }
        val apiBody = fetchText(client, apiUrl, apiHeaders) ?: return null
        return parseApiJson(apiBody, url)
    }

    private fun parseApiJson(body: String, gatewayUrl: String): Resolved? {
        return try {
            val json = JSONObject(body)
            if (json.optBoolean("success", true).not() && !json.has("mpdPath")) {
                Log.w(TAG, "api error=${json.optString("error")}")
                return null
            }
            val mpd = json.optString("mpdPath").trim()
                .ifEmpty { json.optString("streamUrl").trim() }
                .ifEmpty { json.optString("url").trim() }
            if (mpd.isEmpty() || !mpd.startsWith("http")) {
                Log.w(TAG, "api missing stream url")
                return null
            }
            val license = json.optString("licenseUrl").trim()
            val auth = json.optString("authXmlToken").trim()
                .ifEmpty { json.optString("authToken").trim() }
            val drmRaw = json.optString("drmType", "none").trim().lowercase()
            val drm = when {
                drmRaw.contains("clearkey") || drmRaw.contains("clear_key") -> DrmType.CLEARKEY
                drmRaw.contains("widevine") || license.isNotEmpty() -> DrmType.WIDEVINE
                else -> DrmType.NONE
            }
            val base = Uri.parse(gatewayUrl)
            val origin = "${base.scheme}://${base.authority}"
            Resolved(
                streamUrl = mpd,
                licenseUrl = license,
                authToken = auth,
                drmType = if (drm == DrmType.WIDEVINE && license.isEmpty()) DrmType.NONE else drm,
                referer = "$origin/",
                origin = origin,
            )
        } catch (e: Exception) {
            Log.w(TAG, "api parse failed: ${e.message}")
            null
        }
    }

    private fun findApiUrl(gatewayUrl: String, html: String): String? {
        // Inline player script: API_URL = "player.php?app=…&key=…&api=1"
        val inline = Regex(
            """API_URL\s*=\s*["']([^"']+)["']""",
            RegexOption.IGNORE_CASE,
        ).find(html)?.groupValues?.getOrNull(1)?.trim().orEmpty()
        if (inline.isNotEmpty()) {
            return absolutize(gatewayUrl, unescapeJsonUrl(inline))
        }

        val base = Uri.parse(gatewayUrl)
        val path = base.path.orEmpty().lowercase()
        if (path.contains("embed.php") || path.contains("player.php")) {
            val app = base.getQueryParameter("app").orEmpty()
            val key = base.getQueryParameter("key").orEmpty()
            if (app.isNotEmpty() && key.isNotEmpty()) {
                return base.buildUpon()
                    .path(base.path!!.replace(Regex("""(?i)embed\.php"""), "player.php"))
                    .clearQuery()
                    .appendQueryParameter("app", app)
                    .appendQueryParameter("key", key)
                    .appendQueryParameter("api", "1")
                    .appendQueryParameter("t", System.currentTimeMillis().toString())
                    .build()
                    .toString()
            }
        }

        // Relative player.php links in the page.
        val href = Regex(
            """(?:href|src)=["']([^"']*player\.php\?[^"']+)["']""",
            RegexOption.IGNORE_CASE,
        ).find(html)?.groupValues?.getOrNull(1)?.trim().orEmpty()
        if (href.isNotEmpty()) {
            val abs = absolutize(gatewayUrl, href)
            return if (abs.contains("api=")) {
                abs
            } else {
                Uri.parse(abs).buildUpon()
                    .appendQueryParameter("api", "1")
                    .appendQueryParameter("t", System.currentTimeMillis().toString())
                    .build()
                    .toString()
            }
        }
        return null
    }

    private fun unescapeJsonUrl(raw: String): String =
        raw.replace("\\u0026", "&").replace("\\/", "/")

    private fun absolutize(baseUrl: String, maybeRelative: String): String {
        val t = maybeRelative.trim()
        if (t.startsWith("http://") || t.startsWith("https://")) return t
        val base = Uri.parse(baseUrl)
        return if (t.startsWith("/")) {
            "${base.scheme}://${base.authority}$t"
        } else {
            val parent = base.path?.substringBeforeLast('/') ?: ""
            "${base.scheme}://${base.authority}$parent/$t"
        }
    }

    private fun fetchText(
        client: OkHttpClient,
        url: String,
        headers: Map<String, String>,
    ): String? {
        return try {
            val req = Request.Builder().url(url).get()
            headers.forEach { (k, v) -> req.header(k, v) }
            if (headers.keys.none { it.equals("User-Agent", ignoreCase = true) }) {
                req.header("User-Agent", OrizonStreamClient.USER_AGENT)
            }
            client.newCall(req.build()).execute().use { resp ->
                if (!resp.isSuccessful) {
                    Log.w(TAG, "HTTP ${resp.code} url=${url.take(160)}")
                    return null
                }
                resp.body?.string()
            }
        } catch (e: Exception) {
            Log.w(TAG, "fetch failed url=${url.take(160)}: ${e.message}")
            null
        }
    }

    private fun newClient(): OkHttpClient {
        val jar = object : CookieJar {
            private val store = ConcurrentHashMap<String, List<Cookie>>()
            override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
                store[url.host] = cookies
            }

            override fun loadForRequest(url: HttpUrl): List<Cookie> =
                store[url.host].orEmpty()
        }
        return OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .writeTimeout(15, TimeUnit.SECONDS)
            .followRedirects(true)
            .followSslRedirects(true)
            .cookieJar(jar)
            .build()
    }
}
