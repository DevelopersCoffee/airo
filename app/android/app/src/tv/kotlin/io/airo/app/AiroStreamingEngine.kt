package io.airo.app

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import java.net.InetAddress
import java.util.concurrent.Executors
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
    private const val TAG = "AiroStreamingEngine"

    /** F4.4.5/F4.4.6 (splice plan Task 0). */
    private const val SPLICE_DEADLINE_MS = 3000L
    private const val MUTE_CUT_DURATION_MS = 200L

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
     * live player, which otherwise only the (private) PlatformView holds.
     * @Volatile: Task 2 reads this from `switchSource`'s splice-wait
     * thread, not just the main thread that sets it. */
    @Volatile
    var currentPlayer: ExoPlayer? = null

    /** Set/cleared alongside [currentPlayer] -- Task 1 of the splice plan.
     * Nullable rather than a no-op default: absence means "no boundary
     * data yet" (e.g. right after create, before any segment has loaded),
     * which must read the same as "unknown" to callers, not "zero". */
    @Volatile
    var currentSegmentBoundaryTracker: AiroSegmentBoundaryTracker? = null

    /** Thread-safe snapshot of playback position, refreshed on the main
     * thread only (see `AiroStreamingSurfaceViewFactory`'s position
     * poll). [msUntilNextHlsBoundary] reads this instead of
     * `currentPlayer.currentPosition` directly -- Media3 requires all
     * ExoPlayer access to happen on its own application thread, and
     * Task 2's splice wait runs on a background executor. */
    @Volatile
    private var lastKnownPositionMs: Long = 0L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val spliceExecutor = Executors.newCachedThreadPool()

    /** Called from the main thread only, on every position poll tick. */
    fun reportPlaybackPosition(positionMs: Long) {
        lastKnownPositionMs = positionMs
    }

    /** Task 1 -- how long until the next HLS segment boundary, or null if
     * unknown (no boundary tracked yet, or the tracked boundary is
     * already stale). Safe to call from any thread. */
    fun msUntilNextHlsBoundary(): Long? {
        return currentSegmentBoundaryTracker?.msUntilNextBoundary(lastKnownPositionMs)
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
     * Task 2/5 (splice plan) -- frame-accurate splice-on-keyframe
     * (F4.4.5/F4.4.6). Waits for a splice-safe point via
     * [AiroSpliceDecision]'s deadline-bounded fallback (Task 0) before
     * swapping, instead of v1's immediate basic swap.
     *
     * HLS (segment-boundary-aligned, Tasks 1/2) and TS (PAT/PMT/IDR
     * byte parsing, Tasks 4/5) need genuinely different mechanisms --
     * see the plan's investigation findings. HLS waits on the
     * *outgoing* stream's tracked boundary (segments are pre-existing
     * structure of what's already playing); TS has no such structure,
     * so it instead probes the *incoming* [url] directly for a clean
     * PAT->PMT->video-PID->IDR chain via [AiroTsSplicePointFinder].
     * [isHlsUrl] decides which applies; a source with neither an HLS
     * url nor an active HLS boundary tracker always takes the TS path.
     *
     * Must be called off the main thread -- [AiroSpliceDecision.decide]
     * blocks the calling thread up to [SPLICE_DEADLINE_MS], and blocking
     * the main thread that long risks an ANR. The actual `ExoPlayer`
     * mutation is posted to [mainHandler] regardless of caller thread,
     * since Media3 requires it.
     */
    fun switchSource(url: String): AiroSpliceOutcome {
        val player = currentPlayer ?: return AiroSpliceOutcome.FAILED
        val finder = if (isHlsUrl(url) && currentSegmentBoundaryTracker != null) {
            AiroHlsSplicePointFinder(msUntilNextBoundary = ::msUntilNextHlsBoundary)
        } else {
            AiroTsSplicePointFinder(okHttpClient, url)
        }
        val mode = AiroSpliceDecision.decide(finder, SPLICE_DEADLINE_MS, spliceExecutor)
        Log.d(TAG, "switchSource: mode=$mode url=$url")
        mainHandler.post { performSwap(player, url, mode) }
        return when (mode) {
            AiroSpliceMode.SPLICE -> AiroSpliceOutcome.SPLICED
            AiroSpliceMode.MUTE_CUT_FALLBACK -> AiroSpliceOutcome.FELL_BACK_TO_MUTE_CUT
        }
    }

    /** Runs on the main thread (posted from [switchSource]). Mute-cut
     * fallback silences audio for [MUTE_CUT_DURATION_MS] around the swap
     * per the spec's own fallback (plan's AD-Splice.1); a clean splice
     * swaps at full volume since it already landed on a boundary. */
    private fun performSwap(player: ExoPlayer, url: String, mode: AiroSpliceMode) {
        val position = player.currentPosition
        if (mode == AiroSpliceMode.MUTE_CUT_FALLBACK) player.volume = 0f
        player.setMediaItem(MediaItem.fromUri(url))
        player.prepare()
        player.seekTo(position)
        player.playWhenReady = true
        currentSegmentBoundaryTracker?.reset()
        Log.d(TAG, "performSwap: mode=$mode position=$position")
        if (mode == AiroSpliceMode.MUTE_CUT_FALLBACK) {
            mainHandler.postDelayed({ player.volume = 1f }, MUTE_CUT_DURATION_MS)
        }
    }

    /** Extension-based, same check already used for [TEST_STREAM_URL]-
     * shaped sources in `AiroStreamingSurfaceViewFactory`. Not a
     * content-type sniff -- good enough for this app's own known
     * source shapes (HLS variant playlists always end `.m3u8`), not a
     * general-purpose media type detector. */
    private fun isHlsUrl(url: String): Boolean {
        return url.substringBefore('?').endsWith(".m3u8", ignoreCase = true)
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
