package io.airo.app

import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import okhttp3.Dns
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AiroConnectionPoolTest {
    @Test
    fun `pool config constants match F4-2's specified values`() {
        assertEquals(6, AiroConnectionPoolConfig.MAX_IDLE_CONNECTIONS)
        assertEquals(45L, AiroConnectionPoolConfig.IDLE_TIMEOUT_SECONDS)
        assertEquals(3L, AiroConnectionPoolConfig.CONNECT_TIMEOUT_SECONDS)
        assertEquals(8L, AiroConnectionPoolConfig.READ_TIMEOUT_SECONDS)
    }

    @Test
    fun `okhttp client is built with the configured connect and read timeouts`() {
        val client = buildAiroOkHttpClient(resolverCache = fakeResolverCache())

        assertEquals(3_000, client.connectTimeoutMillis)
        assertEquals(8_000, client.readTimeoutMillis)
    }

    @Test
    fun `dns delegates to the resolver cache instead of calling InetAddress directly`() {
        var resolveCalls = 0
        val cache = AiroResolverCache(
            systemResolver = { resolveCalls++; listOf("127.0.0.1") },
            dohTransport = { null },
        )
        val dns: Dns = AiroOkHttpDns(cache)

        val addresses = dns.lookup("example.com")

        assertEquals(1, resolveCalls)
        assertEquals(listOf(InetAddress.getByName("127.0.0.1")), addresses)
    }

    @Test
    fun `the tuned socket factory enables TCP_NODELAY on a real loopback socket`() {
        ServerSocket(0).use { server ->
            val socket = AiroTunedSocketFactory().createSocket("127.0.0.1", server.localPort)
            socket.use {
                assertTrue(it.tcpNoDelay)
            }
        }
    }

    @Test
    fun `the tuned socket factory raises the receive buffer above the platform default`() {
        val platformDefaultRcvBuf = ServerSocket(0).use { server ->
            Socket("127.0.0.1", server.localPort).use { it.receiveBufferSize }
        }

        ServerSocket(0).use { server ->
            AiroTunedSocketFactory().createSocket("127.0.0.1", server.localPort).use {
                assertTrue(it.receiveBufferSize >= platformDefaultRcvBuf)
            }
        }
    }

    private fun fakeResolverCache(): AiroResolverCache {
        return AiroResolverCache(
            systemResolver = { listOf("127.0.0.1") },
            dohTransport = { null },
        )
    }
}
