package io.airo.app

import java.net.InetAddress
import java.net.Socket
import javax.net.SocketFactory
import okhttp3.ConnectionPool
import okhttp3.Dns
import okhttp3.OkHttpClient

/** F4.2's connection pool / timeout values, as plain constants so tests
 * can assert on them directly without poking OkHttp internals that don't
 * expose a configured-max getter. */
object AiroConnectionPoolConfig {
    const val MAX_IDLE_CONNECTIONS = 6
    const val IDLE_TIMEOUT_SECONDS = 45L
    const val CONNECT_TIMEOUT_SECONDS = 3L
    const val READ_TIMEOUT_SECONDS = 8L

    /** Raised above the platform default per F4.2.4 -- small receive
     * windows throttle high-bitrate TS on high-latency links. */
    const val TARGET_RECEIVE_BUFFER_BYTES = 256 * 1024
}

/** [Dns] backed by [AiroResolverCache] -- never calls
 * `InetAddress.getAllByName` directly; that's the resolver cache's job
 * (Task 2), not duplicated here. */
class AiroOkHttpDns(private val resolverCache: AiroResolverCache) : Dns {
    override fun lookup(hostname: String): List<InetAddress> {
        return resolverCache.resolve(hostname).map { InetAddress.getByName(it) }
    }
}

/**
 * `TCP_NODELAY` + raised `SO_RCVBUF` (F4.2.4) on every socket OkHttp
 * opens through this factory. Applies to plain (non-TLS) sockets;
 * OkHttp's TLS path negotiates its own `SSLSocket` on top of one of
 * these via the configured `SSLSocketFactory`; wrapping that too is a
 * follow-up once real HTTPS provider traffic is measured through the
 * custom `DataSource` in Task 4 -- not silently assumed complete here.
 */
class AiroTunedSocketFactory : SocketFactory() {
    private val delegate: SocketFactory = getDefault()

    override fun createSocket(): Socket = tune(delegate.createSocket())

    override fun createSocket(host: String, port: Int): Socket =
        tune(delegate.createSocket(host, port))

    override fun createSocket(
        host: String,
        port: Int,
        localHost: InetAddress,
        localPort: Int,
    ): Socket = tune(delegate.createSocket(host, port, localHost, localPort))

    override fun createSocket(host: InetAddress, port: Int): Socket =
        tune(delegate.createSocket(host, port))

    override fun createSocket(
        address: InetAddress,
        port: Int,
        localAddress: InetAddress,
        localPort: Int,
    ): Socket = tune(delegate.createSocket(address, port, localAddress, localPort))

    private fun tune(socket: Socket): Socket {
        socket.tcpNoDelay = true
        if (socket.receiveBufferSize < AiroConnectionPoolConfig.TARGET_RECEIVE_BUFFER_BYTES) {
            socket.receiveBufferSize = AiroConnectionPoolConfig.TARGET_RECEIVE_BUFFER_BYTES
        }
        return socket
    }
}

/** Builds the [OkHttpClient] the custom `DataSource` (Task 4) will use:
 * pooled/tuned connections resolved through [resolverCache], per F4.2. */
fun buildAiroOkHttpClient(resolverCache: AiroResolverCache): OkHttpClient {
    return OkHttpClient.Builder()
        .dns(AiroOkHttpDns(resolverCache))
        .socketFactory(AiroTunedSocketFactory())
        .connectionPool(
            ConnectionPool(
                AiroConnectionPoolConfig.MAX_IDLE_CONNECTIONS,
                AiroConnectionPoolConfig.IDLE_TIMEOUT_SECONDS,
                java.util.concurrent.TimeUnit.SECONDS,
            ),
        )
        .connectTimeout(
            AiroConnectionPoolConfig.CONNECT_TIMEOUT_SECONDS,
            java.util.concurrent.TimeUnit.SECONDS,
        )
        .readTimeout(
            AiroConnectionPoolConfig.READ_TIMEOUT_SECONDS,
            java.util.concurrent.TimeUnit.SECONDS,
        )
        .build()
}
