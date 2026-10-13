package io.airo.app

import android.content.Context
import com.google.android.gms.cast.tv.CastReceiverOptions
import com.google.android.gms.cast.tv.ReceiverOptionsProvider

/**
 * Cast Connect receiver options for Aika Stream — dev/test only (receiver
 * app F353F9C7 is unpublished, see
 * docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md).
 * Registers only the MultiView custom namespace; no media-load handling is
 * wired here, so single-channel casting (the shipped Default-Media-Receiver
 * flow) is untouched by this — it never targets this receiver app.
 */
class AiroCastReceiverOptionsProvider : ReceiverOptionsProvider {
    override fun getOptions(context: Context): CastReceiverOptions {
        return CastReceiverOptions.Builder(context)
            .setStatusText("Aika Stream")
            .setCustomNamespaces(listOf(AiroCastReceiverMultiviewPlugin.NAMESPACE))
            .build()
    }
}
