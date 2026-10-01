package io.airo.app

import android.util.Log
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.ArrayDeque

/**
 * Identity PCM passthrough in Media3's post-decode [AudioProcessor] chain
 * (#2081 spike). When Spatial Mode is off, [isActive] is false and ExoPlayer
 * skips the processor entirely. When on, buffers are copied unchanged so #2082
 * can swap in binaural DSP without re-plumbing the player.
 */
@UnstableApi
class AiroIdentitySpatialAudioProcessor(
    private val spatialModeEnabled: () -> Boolean,
) : AudioProcessor {
    private var inputAudioFormat: AudioProcessor.AudioFormat =
        AudioProcessor.AudioFormat.NOT_SET
    private val pendingOutput = ArrayDeque<ByteBuffer>()
    private var inputEnded = false

    @Volatile
    var framesProcessed: Long = 0
        private set

    override fun configure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        this.inputAudioFormat = inputAudioFormat
        pendingOutput.clear()
        inputEnded = false
        return inputAudioFormat
    }

    override fun isActive(): Boolean {
        return spatialModeEnabled() && inputAudioFormat != AudioProcessor.AudioFormat.NOT_SET
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        if (!inputBuffer.hasRemaining()) {
            if (inputBuffer === EMPTY_BUFFER) {
                queueEndOfStream()
            }
            return
        }
        val copy = ByteBuffer.allocateDirect(inputBuffer.remaining())
            .order(inputBuffer.order())
        copy.put(inputBuffer)
        copy.flip()
        pendingOutput.add(copy)
        framesProcessed += 1
        if (framesProcessed <= 3L || framesProcessed % 120L == 0L) {
            Log.d(
                TAG,
                "pcm_after_decode passthrough bufferBytes=${copy.remaining()} totalFrames=$framesProcessed",
            )
        }
    }

    override fun queueEndOfStream() {
        inputEnded = true
    }

    override fun getOutput(): ByteBuffer {
        val next = pendingOutput.poll()
        if (next != null) return next
        return if (inputEnded) EMPTY_BUFFER else AudioProcessor.EMPTY_BUFFER
    }

    override fun isEnded(): Boolean {
        return inputEnded && pendingOutput.isEmpty()
    }

    override fun flush() {
        pendingOutput.clear()
        inputEnded = false
    }

    override fun reset() {
        inputAudioFormat = AudioProcessor.AudioFormat.NOT_SET
        flush()
        framesProcessed = 0
    }

    companion object {
        private const val TAG = "AiroSpatial"
        private val EMPTY_BUFFER: ByteBuffer =
            ByteBuffer.allocateDirect(0).order(ByteOrder.nativeOrder())
    }
}
