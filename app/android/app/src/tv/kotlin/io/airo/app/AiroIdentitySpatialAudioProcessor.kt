package io.airo.app

import android.util.Log
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer

/**
 * Identity PCM passthrough using Media3's [BaseAudioProcessor] (#2081).
 *
 * When Spatial Mode is off, [onConfigure] returns [AudioProcessor.AudioFormat.NOT_SET]
 * so the processor is inactive and ExoPlayer matches stock [DefaultAudioSink]
 * behavior. When Spatial is on, PCM is copied unchanged (logging for smoke tests).
 */
@UnstableApi
class AiroIdentitySpatialAudioProcessor(
    private val spatialModeEnabled: () -> Boolean,
) : BaseAudioProcessor() {

    @Volatile
    var framesProcessed: Long = 0
        private set

    override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        return if (spatialModeEnabled()) {
            inputAudioFormat
        } else {
            AudioProcessor.AudioFormat.NOT_SET
        }
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val remaining = inputBuffer.remaining()
        if (remaining == 0) {
            return
        }
        framesProcessed += 1
        if (framesProcessed <= 3L || framesProcessed % 120L == 0L) {
            Log.d(
                TAG,
                "pcm_after_decode passthrough bufferBytes=$remaining totalFrames=$framesProcessed",
            )
        }
        replaceOutputBuffer(remaining).put(inputBuffer).flip()
    }

    companion object {
        private const val TAG = "AiroSpatial"
    }
}
