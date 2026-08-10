package io.airo.app

import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Task 5 (splice plan) -- TS-source counterpart to
 * [AiroHlsSplicePointFinder]. Raw TS has no segment structure to wait
 * on the way HLS does (see the plan's investigation findings), so this
 * probes the *incoming* source url instead of timing the outgoing
 * stream: a bounded HTTP GET, feeding bytes into [AiroTsSpliceParser]
 * (Task 4) as they arrive, reporting true the moment a clean
 * PAT->PMT->video-PID->IDR chain resolves -- confirming the new source
 * is splice-safe to switch onto. Doesn't disturb current playback,
 * same non-intrusive probing principle as `AiroShadowFetch` (Wave C
 * Task 1).
 *
 * Lives in `src/tv/kotlin` despite depending only on OkHttp, not
 * Media3 -- OkHttp itself is `isTvVariant`-gated in this app's Gradle
 * setup (AD-P2B.4 follows dependencies, and OkHttp is one here).
 */
class AiroTsSplicePointFinder(
    private val client: OkHttpClient,
    private val url: String,
    private val probeBudgetBytes: Long = PROBE_BUDGET_BYTES,
) : AiroSplicePointFinder {
    override fun findNextSplicePoint(): Boolean {
        return runCatching {
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use false
                val parser = AiroTsSpliceParser()
                val source = response.body.source()
                val buffer = ByteArray(READ_CHUNK_BYTES)
                var read = 0L
                while (read < probeBudgetBytes) {
                    val n = source.read(buffer)
                    if (n == -1) break
                    read += n
                    val chunk = if (n == buffer.size) buffer else buffer.copyOf(n)
                    if (parser.feed(chunk) != null) return@use true
                }
                false
            }
        }.getOrDefault(false)
    }

    private companion object {
        const val PROBE_BUDGET_BYTES = 512_000L
        const val READ_CHUNK_BYTES = 8192
    }
}
