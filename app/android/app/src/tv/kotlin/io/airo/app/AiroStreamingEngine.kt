package io.airo.app

import androidx.media3.common.MediaItem
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import java.net.InetAddress
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

/**
 * Production wiring for the receiver's resolver cache + connection pool
 * (Wave B, F4.1/F4.2) -- one shared instance so pre-warmed connections
 * (F4.2.2) are the same connections playback actually uses, not a
 * separate pool that gets thrown away. [AiroStreamingSurfaceViewFactory]
 * reads [dataSourceFactory]; `AiroStreamingEnginePlugin`'s `preWarm`
 * method channel handler calls [preWarm].
 */
object AiroStreamingEngine {
    // Separate, minimal client for DoH lookups themselves -- it only ever
    // talks to a literal IP (Cloudflare's 1.1.1.1), so it needs no custom
    // Dns and must not depend on the resolver cache it exists to help
    // populate (that would be circular).
    private val dohClient = OkHttpClient()

    private val resolverCache = AiroResolverCache(
        systemResolver = { host ->
            runCatching { InetAddress.getAllByName(host).mapNotNull { it.hostAddress } }.getOrNull()
        },
        dohTransport = { host -> resolveViaDoh(host) },
    )

    val okHttpClient: OkHttpClient by lazy { buildAiroOkHttpClient(resolverCache) }

    val dataSourceFactory: OkHttpDataSource.Factory by lazy {
        OkHttpDataSource.Factory(okHttpClient)
    }

    private val shadowFetchLimiter = AiroShadowFetchLimiter()

    /** Set by the active `AiroStreamingPlatformView` on create, cleared on
     * dispose -- Wave C's method-channel commands need a reference to the
     * live player, which otherwise only the (private) PlatformView holds. */
    var currentPlayer: ExoPlayer? = null

    /** Set/cleared alongside [currentPlayer] -- Task 1 of the splice plan.
     * Nullable rather than a no-op default: absence means "no boundary
     * data yet" (e.g. right after create, before any segment has loaded),
     * which must read the same as "unknown" to callers, not "zero". */
    var currentSegmentBoundaryTracker: AiroSegmentBoundaryTracker? = null

    /** Task 1 -- how long until the next HLS segment boundary, or null if
     * unknown (no player, no boundary tracked yet, or the tracked
     * boundary is already stale). Task 2 will use this to time the
     * splice swap; for now this is read for device-verification logging
     * only. */
    fun msUntilNextHlsBoundary(): Long? {
        val position = currentPlayer?.currentPosition ?: return null
        return currentSegmentBoundaryTracker?.msUntilNextBoundary(position)
    }

    /** F4.3.2/F4.4.3 -- probe a candidate source without disturbing
     * playback. Returns a Dart-codec-friendly map. */
    fun shadowFetch(url: String): Map<String, Any?> {
        return when (val result = AiroShadowFetch.probe(okHttpClient, url, shadowFetchLimiter)) {
            is AiroShadowFetchResult.Measured ->
                mapOf("status" to "measured", "throughputKbps" to result.throughputKbps)
            is AiroShadowFetchResult.Failed ->
                mapOf("status" to "failed", "reason" to result.reason)
            AiroShadowFetchResult.Busy -> mapOf("status" to "busy")
        }
    }

    /**
     * v1 "basic swap" -- rebuilds the `MediaItem` for [url] and resumes at
     * the current position. This is **not yet** the frame-accurate
     * splice-on-keyframe F4.4.5 specifies (PAT/PMT+IDR boundary for TS,
     * next-segment boundary for HLS) -- that is real, separately-scoped
     * follow-up work; the requirements doc's own risk table calls
     * artifact-free splicing the single biggest risk in this feature, and
     * it isn't solved by this function. A basic swap can produce a brief
     * visible glitch and does not yet meet F4.4.6's "no visible
     * interruption" bar -- tracked as a known gap, not silently claimed
     * complete.
     */
    fun switchSource(url: String): Boolean {
        val player = currentPlayer ?: return false
        val position = player.currentPosition
        player.setMediaItem(MediaItem.fromUri(url))
        player.prepare()
        player.seekTo(position)
        player.playWhenReady = true
        return true
    }

    /** F4.2.2 -- open and hold connections while the user browses the
     * channel grid, before playback intent exists. Best-effort per host:
     * a failed pre-warm for one host must not affect any other. */
    fun preWarm(hosts: List<String>) {
        for (host in hosts) {
            Thread {
                runCatching {
                    val request = Request.Builder().url("https://$host/").head().build()
                    okHttpClient.newCall(request).execute().close()
                }
            }.start()
        }
    }

    /** Cloudflare's DoH JSON API (simpler to parse than raw DNS wire
     * format for this scope) -- F4.1.2. Returns null on any failure so
     * the resolver cache's own race/fallback logic (Task 2) decides what
     * happens next; this function never throws. */
    private fun resolveViaDoh(host: String): List<String>? {
        return runCatching {
            val request = Request.Builder()
                .url("https://1.1.1.1/dns-query?name=$host&type=A")
                .header("Accept", "application/dns-json")
                .build()
            dohClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use null
                val body = response.body.string()
                val answers = JSONObject(body).optJSONArray("Answer") ?: return@use null
                val addresses = mutableListOf<String>()
                for (i in 0 until answers.length()) {
                    val entry = answers.getJSONObject(i)
                    if (entry.optInt("type") == 1) { // A record
                        addresses.add(entry.getString("data"))
                    }
                }
                addresses.ifEmpty { null }
            }
        }.getOrNull()
    }
}
