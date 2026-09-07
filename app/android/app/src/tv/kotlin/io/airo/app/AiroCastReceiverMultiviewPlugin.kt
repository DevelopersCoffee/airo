package io.airo.app

import android.util.Log
import com.google.android.gms.cast.tv.CastReceiverContext
import com.google.android.gms.cast.tv.SenderDisconnectedEventInfo
import com.google.android.gms.cast.tv.SenderInfo
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val TAG = "AiroCastReceiverMultiview"

/**
 * Bridges the Cast Connect custom-namespace channel to Dart's
 * `MultiviewCastReceiverTransport` (see
 * docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md).
 * Dev/test only — [AiroCastReceiverOptionsProvider] registers [NAMESPACE]
 * on the F353F9C7 receiver app, which is unpublished and only reachable
 * from a registered test device.
 *
 * Assumes at most one connected sender at a time, matching the Dart-side
 * interface's own documented scope: the last sender to send a command is
 * who [publishState] replies to.
 */
class AiroCastReceiverMultiviewPlugin {
    companion object {
        const val CHANNEL_NAME = "com.developerscoffee.airo/cast_multiview_receiver"
        const val NAMESPACE = "urn:x-cast:com.developerscoffee.airo.multiview"
    }

    private var channel: MethodChannel? = null
    private var currentSenderId: String? = null

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result -> onMethodCall(call, result) }
        this.channel = channel

        val receiverContext = CastReceiverContext.getInstance()
        receiverContext.setMessageReceivedListener(NAMESPACE) { _, senderId, message ->
            currentSenderId = senderId
            channel.invokeMethod("onCommand", mapOf("message" to message))
        }
        receiverContext.registerEventCallback(object : CastReceiverContext.EventCallback() {
            override fun onSenderDisconnected(eventInfo: SenderDisconnectedEventInfo) {
                if (eventInfo.senderInfo.senderId == currentSenderId) {
                    currentSenderId = null
                }
            }
        })
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "publishState" -> publishState(call, result)
            else -> result.notImplemented()
        }
    }

    private fun publishState(call: MethodCall, result: MethodChannel.Result) {
        val senderId = currentSenderId
        if (senderId == null) {
            // No connected sender to reply to -- not an error, just nothing
            // to do (mirrors the Dart Fake/Unavailable transports' silent
            // no-op when nothing is connected).
            result.success(null)
            return
        }
        val message = call.argument<String>("message")
        if (message == null) {
            result.error("INVALID_ARGUMENT", "Missing 'message'.", null)
            return
        }
        try {
            CastReceiverContext.getInstance().sendMessage(NAMESPACE, senderId, message)
            result.success(null)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to publish MultiView state", e)
            result.error("SEND_FAILED", e.message, null)
        }
    }
}
