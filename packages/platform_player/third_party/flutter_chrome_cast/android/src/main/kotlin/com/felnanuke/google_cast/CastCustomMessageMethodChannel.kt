package com.felnanuke.google_cast

import android.util.Log
import com.google.android.gms.cast.Cast
import com.google.android.gms.cast.CastDevice
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.Session
import com.google.android.gms.cast.framework.SessionManagerListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val TAG = "CastCustomMessage"

/**
 * Flutter method channel for an app-defined Cast message namespace.
 *
 * The stock plugin only wraps the Cast SDK's built-in media namespace
 * (load/play/pause/etc via [RemoteMediaClientMethodChannel]). This adds the
 * separate `CastSession.sendMessage` / `setMessageReceivedCallbacks` pair
 * the SDK exposes for a receiver's own custom logic — used by feature_iptv's
 * Cast MultiView remote control (see
 * docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md).
 *
 * Sending to the stock default media receiver (the `CC1AD845` app id
 * [CastContextMethodChannel] falls back to) goes nowhere: it doesn't
 * register a callback for an app-defined namespace. This channel only does
 * anything once a receiver — a Cast Connect app or custom web receiver —
 * registers the same namespace on its side.
 */
class CastCustomMessageMethodChannel : FlutterPlugin, MethodChannel.MethodCallHandler,
    SessionManagerListener<Session>, Cast.MessageReceivedCallback {

    private lateinit var channel: MethodChannel
    private var registeredNamespace: String? = null
    private var listenerAttached = false

    private val sessionManager
        get() = CastContext.getSharedInstance()?.sessionManager

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger,
            "com.felnanuke.google_cast.custom_message",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        unregisterNamespace()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setNamespace" -> {
                registerNamespace(call.arguments as String)
                result.success(true)
            }
            "sendMessage" -> sendMessage(call, result)
            else -> result.notImplemented()
        }
    }

    private fun sendMessage(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as Map<String, Any?>
        val namespace = args["namespace"] as String
        val message = args["message"] as String
        val session = sessionManager?.currentCastSession
        if (session == null || !session.isConnected) {
            result.error("NO_SESSION", "No connected Cast session.", null)
            return
        }
        try {
            // CastSession.sendMessage is synchronous — it either returns
            // having handed the message to the SDK's outgoing queue, or
            // throws. It does not report whether the receiver acted on it.
            session.sendMessage(namespace, message)
            result.success(true)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send custom Cast message", e)
            result.error("SEND_FAILED", e.message, null)
        }
    }

    private fun registerNamespace(namespace: String) {
        unregisterNamespace()
        registeredNamespace = namespace
        sessionManager?.addSessionManagerListener(this, Session::class.java)
        listenerAttached = true
        (sessionManager?.currentCastSession)?.let { attachCallback(it, namespace) }
    }

    private fun unregisterNamespace() {
        val namespace = registeredNamespace
        if (namespace != null) {
            try {
                sessionManager?.currentCastSession?.removeMessageReceivedCallbacks(namespace)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to remove message callback", e)
            }
        }
        if (listenerAttached) {
            sessionManager?.removeSessionManagerListener(this, Session::class.java)
            listenerAttached = false
        }
        registeredNamespace = null
    }

    private fun attachCallback(session: CastSession, namespace: String) {
        try {
            session.setMessageReceivedCallbacks(namespace, this)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to attach message callback", e)
        }
    }

    override fun onMessageReceived(castDevice: CastDevice, namespace: String, message: String) {
        channel.invokeMethod(
            "onMessageReceived",
            mapOf("namespace" to namespace, "message" to message),
        )
    }

    // SessionManagerListener<Session> — a CastSession object is recreated on
    // every start/resume, so the message callback (attached per-instance)
    // has to be reattached each time rather than once at registration.
    override fun onSessionStarted(session: Session, sessionId: String) {
        reattach(session)
    }

    override fun onSessionResumed(session: Session, wasSuspended: Boolean) {
        reattach(session)
    }

    private fun reattach(session: Session) {
        val namespace = registeredNamespace ?: return
        (session as? CastSession)?.let { attachCallback(it, namespace) }
    }

    override fun onSessionEnded(session: Session, error: Int) {}
    override fun onSessionEnding(session: Session) {}
    override fun onSessionResumeFailed(session: Session, error: Int) {}
    override fun onSessionResuming(session: Session, sessionId: String) {}
    override fun onSessionStartFailed(session: Session, error: Int) {}
    override fun onSessionStarting(session: Session) {}
    override fun onSessionSuspended(session: Session, reason: Int) {}
}
