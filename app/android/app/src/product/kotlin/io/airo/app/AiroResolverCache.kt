package io.airo.app

import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** Thrown when neither the system resolver nor DoH can answer for a host. */
class AiroResolverException(message: String) : Exception(message)

/**
 * In-memory DNS resolver cache (F4.1). Races the system resolver against
 * DoH -- whichever answers first with a real result wins; a hard timeout
 * on the DoH side falls back to a direct synchronous system-resolver
 * attempt instead of failing closed (F4.1.6). Results are cached for
 * [ttlMillis] (F4.1.1), keyed per host (F4.1.3 pre-resolves the whole
 * playlist's unique hosts up front, one cache entry per host).
 *
 * [systemResolver] and [dohTransport] are injected function types so the
 * race/cache/fallback logic is fully unit-testable against fakes -- no
 * real network or device needed (see AiroResolverCacheTest). A real DoH
 * transport implementation is wired in once Wave B Task 1's OkHttp
 * dependency is confirmed; this class has no dependency on that decision.
 *
 * IP pinning (F4.1.4 -- never re-resolve mid-session) is enforced by the
 * *caller*: a session reads [resolve] once at open time and must not call
 * it again for the life of that session. This class only guarantees the
 * cache itself won't silently serve a different answer within one TTL
 * window; it does not track "sessions."
 */
class AiroResolverCache(
    private val systemResolver: (String) -> List<String>?,
    private val dohTransport: (String) -> List<String>?,
    private val executor: ExecutorService = Executors.newCachedThreadPool(),
    private val clock: () -> Long = System::currentTimeMillis,
    private val ttlMillis: Long = TimeUnit.MINUTES.toMillis(10),
    private val dohTimeoutMillis: Long = TimeUnit.SECONDS.toMillis(3),
) {
    private data class CacheEntry(val addresses: List<String>, val resolvedAtMillis: Long)

    private val cache = ConcurrentHashMap<String, CacheEntry>()

    fun resolve(host: String): List<String> {
        cache[host]?.let { entry ->
            if (clock() - entry.resolvedAtMillis < ttlMillis) return entry.addresses
        }
        val addresses = raceResolvers(host)
        cache[host] = CacheEntry(addresses, clock())
        return addresses
    }

    private fun raceResolvers(host: String): List<String> {
        val winner = CompletableFuture<List<String>>()

        executor.execute {
            val addresses = runCatching { systemResolver(host) }.getOrNull()
            if (addresses != null) winner.complete(addresses)
        }
        executor.execute {
            val addresses = runCatching { dohTransport(host) }.getOrNull()
            if (addresses != null) winner.complete(addresses)
        }

        return try {
            winner.get(dohTimeoutMillis, TimeUnit.MILLISECONDS)
        } catch (_: TimeoutException) {
            // Neither resolver answered within the window -- one last
            // synchronous system-resolver attempt rather than failing
            // closed (F4.1.6).
            runCatching { systemResolver(host) }.getOrNull()
                ?: throw AiroResolverException("No resolver answered for $host")
        }
    }
}
