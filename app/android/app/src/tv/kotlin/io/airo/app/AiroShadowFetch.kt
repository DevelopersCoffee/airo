package io.airo.app

import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request

/** Bounds concurrent shadow-fetch probes (F4.4.8 -- max 2 connections
 * total during a shadow fetch, i.e. at most 1 shadow probe alongside the
 * 1 active playback connection). A single shared instance across calls,
 * not per-probe -- otherwise every probe would always succeed at
 * acquiring its own limiter. */
class AiroShadowFetchLimiter {
    private val permit = Semaphore(1)

    fun tryAcquire(): Boolean = permit.tryAcquire()

    fun release() = permit.release()
}

sealed class AiroShadowFetchResult {
    data class Measured(val throughputKbps: Double) : AiroShadowFetchResult()
    data class Failed(val reason: String) : AiroShadowFetchResult()
    object Busy : AiroShadowFetchResult()
}

/**
 * Shadow-fetches a candidate source without disturbing playback (F4.3.2,
 * F4.4.3): a Range GET for the first [maxBytes], measuring sustained
 * throughput, then discards the connection. Never touches the active
 * [androidx.media3.exoplayer.ExoPlayer] -- that's [AiroSourceSwitch]'s job.
 */
object AiroShadowFetch {
    fun probe(
        client: OkHttpClient,
        url: String,
        limiter: AiroShadowFetchLimiter,
        maxBytes: Long = 512 * 1024,
    ): AiroShadowFetchResult {
        if (!limiter.tryAcquire()) return AiroShadowFetchResult.Busy

        return try {
            val request = Request.Builder()
                .url(url)
                .header("Range", "bytes=0-${maxBytes - 1}")
                .build()

            val startNanos = System.nanoTime()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    return AiroShadowFetchResult.Failed("HTTP ${response.code}")
                }
                val bytesRead = response.body.bytes().size
                val elapsedSeconds = (System.nanoTime() - startNanos) / 1_000_000_000.0
                if (elapsedSeconds <= 0 || bytesRead == 0) {
                    AiroShadowFetchResult.Failed("no measurable duration or bytes")
                } else {
                    val kbps = (bytesRead * 8.0 / 1024.0) / elapsedSeconds
                    AiroShadowFetchResult.Measured(kbps)
                }
            }
        } catch (error: Exception) {
            AiroShadowFetchResult.Failed(error.message ?: error.javaClass.simpleName)
        } finally {
            limiter.release()
        }
    }
}
