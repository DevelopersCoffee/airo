package io.airo.app

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink

/**
 * TV Media3 PCM tap wiring for Spatial Mode (#2081). [renderersFactory] installs
 * [AiroIdentitySpatialAudioProcessor] on [DefaultAudioSink]. IPTV playback on
 * Aika Stream still uses `video_player` today; this proves the tap on the
 * in-repo Media3 engine path used by the zero-copy cast / streaming surface.
 */
@UnstableApi
object AiroSpatialPcmTap {
    @Volatile
    private var mode: SpatialMode = SpatialMode.ORIGINAL

    private val processor = AiroIdentitySpatialAudioProcessor {
        mode == SpatialMode.SPATIAL
    }

    enum class SpatialMode { ORIGINAL, SPATIAL }

    fun renderersFactory(context: Context): DefaultRenderersFactory {
        return object : DefaultRenderersFactory(context) {
            override fun buildAudioSink(
                context: Context,
                enableFloatOutput: Boolean,
                enableAudioOutputPlaybackParams: Boolean,
            ): AudioSink {
                return DefaultAudioSink.Builder(context)
                    .setEnableFloatOutput(enableFloatOutput)
                    .setEnableAudioOutputPlaybackParameters(enableAudioOutputPlaybackParams)
                    .setAudioProcessors(arrayOf(processor))
                    .build()
            }
        }
    }

    fun setSpatialAudioMode(stableId: String) {
        mode = when (stableId) {
            "spatial" -> SpatialMode.SPATIAL
            else -> SpatialMode.ORIGINAL
        }
    }

    fun tapStatusMap(): Map<String, Any?> {
        return mapOf(
            "backend" to "video_player",
            "tapKind" to "pcm_after_decode",
            "processorInstalled" to true,
            "framesProcessed" to processor.framesProcessed,
            "detailCodes" to listOf(
                "default_audio_sink",
                "identity_audio_processor",
                "pcm_after_decode",
                "mode_${mode.name.lowercase()}",
            ),
        )
    }
}
