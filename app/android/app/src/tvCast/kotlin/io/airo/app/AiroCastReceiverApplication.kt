package io.airo.app

import android.app.Application
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.google.android.gms.cast.tv.CastReceiverContext

/**
 * Cast Connect requires [CastReceiverContext] initialized once at process
 * start and started/stopped with the app's foreground lifecycle — mirrors
 * Google's official sample (CastDemoApplication.kt / AppLifecycleObserver.kt
 * at github.com/googlecast/CastAndroidTvReceiver). Dev/test only: see
 * AiroCastReceiverOptionsProvider's doc comment.
 *
 * Gated on [BuildConfig.ENABLE_CAST_RECEIVER] (see build.gradle.kts):
 * initInstance/start crash every launch on Android 13+ when the receiver
 * app is never actually reachable, which is true for every real user.
 */
class AiroCastReceiverApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (!BuildConfig.ENABLE_CAST_RECEIVER) return
        CastReceiverContext.initInstance(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(CastReceiverLifecycleObserver())
    }
}

private class CastReceiverLifecycleObserver : DefaultLifecycleObserver {
    override fun onStart(owner: LifecycleOwner) {
        CastReceiverContext.getInstance().start()
    }

    override fun onStop(owner: LifecycleOwner) {
        CastReceiverContext.getInstance().stop()
    }
}
