package io.airo.app

import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AiroResolverCacheTest {
    private val pool = Executors.newCachedThreadPool()

    @After
    fun shutdownPool() {
        pool.shutdownNow()
    }

    private class FakeResolver(
        private val addresses: List<String>?,
        private val releaseLatch: CountDownLatch? = null,
        private val throwError: Boolean = false,
    ) {
        var callCount = 0
            private set

        fun resolve(): List<String>? {
            callCount++
            releaseLatch?.await(2, TimeUnit.SECONDS)
            if (throwError) throw IOException("resolver unavailable")
            return addresses
        }
    }

    private fun cacheWith(
        system: FakeResolver,
        doh: FakeResolver,
        ttlMillis: Long = TimeUnit.MINUTES.toMillis(10),
        dohTimeoutMillis: Long = 300,
        clock: () -> Long = System::currentTimeMillis,
    ): AiroResolverCache {
        return AiroResolverCache(
            systemResolver = { system.resolve() },
            dohTransport = { doh.resolve() },
            executor = pool,
            clock = clock,
            ttlMillis = ttlMillis,
            dohTimeoutMillis = dohTimeoutMillis,
        )
    }

    @Test
    fun `whichever resolver answers first wins the race`() {
        val fast = FakeResolver(addresses = listOf("1.1.1.1"))
        val slowRelease = CountDownLatch(1)
        val slow = FakeResolver(addresses = listOf("2.2.2.2"), releaseLatch = slowRelease)

        val cache = cacheWith(system = fast, doh = slow)
        try {
            val result = cache.resolve("example.com")
            assertEquals(listOf("1.1.1.1"), result)
        } finally {
            slowRelease.countDown()
        }
    }

    @Test
    fun `a failing doh transport does not fail the resolution when system succeeds`() {
        val system = FakeResolver(addresses = listOf("1.1.1.1"))
        val doh = FakeResolver(addresses = null, throwError = true)

        val cache = cacheWith(system = system, doh = doh)

        assertEquals(listOf("1.1.1.1"), cache.resolve("example.com"))
    }

    @Test
    fun `doh timing out falls back to the system resolver instead of failing closed`() {
        val system = FakeResolver(addresses = listOf("1.1.1.1"))
        val dohNeverReleases = CountDownLatch(1)
        val doh = FakeResolver(addresses = listOf("2.2.2.2"), releaseLatch = dohNeverReleases)

        // System is also given a latch so its first (racing) attempt hangs
        // past the doh timeout, forcing the cache down the "one last
        // synchronous attempt" fallback path rather than the race itself
        // resolving in time.
        val systemRelease = CountDownLatch(1)
        val hangingSystem = FakeResolver(addresses = listOf("1.1.1.1"), releaseLatch = systemRelease)

        val cache = cacheWith(system = hangingSystem, doh = doh, dohTimeoutMillis = 100)
        try {
            systemRelease.countDown()
            val result = cache.resolve("example.com")
            assertEquals(listOf("1.1.1.1"), result)
        } finally {
            dohNeverReleases.countDown()
        }
    }

    @Test
    fun `both resolvers failing throws rather than returning a silently empty result`() {
        val system = FakeResolver(addresses = null)
        val doh = FakeResolver(addresses = null, throwError = true)

        val cache = cacheWith(system = system, doh = doh)

        assertThrows(AiroResolverException::class.java) { cache.resolve("example.com") }
    }

    @Test
    fun `a cache hit within TTL skips the race entirely`() {
        val system = FakeResolver(addresses = listOf("1.1.1.1"))
        val doh = FakeResolver(addresses = listOf("2.2.2.2"))
        val cache = cacheWith(system = system, doh = doh)

        cache.resolve("example.com")
        val callsAfterFirst = system.callCount
        cache.resolve("example.com")

        assertEquals(callsAfterFirst, system.callCount)
    }

    @Test
    fun `TTL expiry triggers a fresh race instead of returning a stale answer`() {
        var now = 0L
        val system = FakeResolver(addresses = listOf("1.1.1.1"))
        val doh = FakeResolver(addresses = listOf("2.2.2.2"))
        val cache = cacheWith(system = system, doh = doh, ttlMillis = 1000, clock = { now })

        cache.resolve("example.com")
        assertEquals(1, system.callCount)

        now += 2000 // past the 1000ms TTL
        cache.resolve("example.com")

        assertTrue("expected a second resolution after TTL expiry", system.callCount >= 2)
    }

    @Test
    fun `different hosts are cached independently`() {
        val system = FakeResolver(addresses = listOf("1.1.1.1"))
        val doh = FakeResolver(addresses = listOf("2.2.2.2"))
        val cache = cacheWith(system = system, doh = doh)

        cache.resolve("a.example.com")
        cache.resolve("b.example.com")

        assertEquals(2, system.callCount)
    }
}
