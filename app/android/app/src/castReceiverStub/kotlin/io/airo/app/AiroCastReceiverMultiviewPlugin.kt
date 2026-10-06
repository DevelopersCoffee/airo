package io.airo.app

import io.flutter.plugin.common.BinaryMessenger

/** No-op Cast Connect bridge for Fire TV builds without play-services-cast-tv. */
class AiroCastReceiverMultiviewPlugin {
    fun register(@Suppress("UNUSED_PARAMETER") messenger: BinaryMessenger) {}
}
