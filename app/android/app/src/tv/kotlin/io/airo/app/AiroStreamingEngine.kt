package io.airo.app

import androidx.media3.datasource.okhttp.OkHttpDataSource
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
