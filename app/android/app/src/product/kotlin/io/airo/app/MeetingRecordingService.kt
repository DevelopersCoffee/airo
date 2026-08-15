package io.airo.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service backing #1656 AC2 -- "Android: foreground service with
 * mic-use notification; respect OS mic privacy indicators".
 *
 * This service does not touch the microphone itself: `record`'s
 * `AudioRecorder` (invoked from Dart, `AudioRecorderPort`) does the actual
 * capture. This class exists purely so Android does not kill the recording
 * process the moment the app backgrounds -- a `RECORD_AUDIO`-holding process
 * with no foreground service of type `microphone` is exactly what Android
 * 14+'s background-mic restrictions kill first. Because
 * `MeetingCaptureController.start` calls
 * `MeetingRecordingServiceGateway.start` immediately before
 * `AudioRecorderPort.start`, this service's persistent notification is up
 * *before* the encoder opens the mic, and Android's own mic-privacy
 * indicator (the green dot / status-bar icon) is driven entirely by the OS
 * from the `RECORD_AUDIO` permission grant -- nothing in this class can
 * suppress or route around it, by design (AC2's "respect OS mic privacy
 * indicators" is therefore automatic, not something this service implements).
 *
 * Started/stopped from Dart via `MeetingRecordingServiceGateway`
 * (`com.airo.meeting_recording` MethodChannel, wired in
 * `MainActivity.configureFlutterEngine`) rather than bound -- there is
 * nothing for Dart to call back into once the notification is showing, so a
 * fire-and-forget start/stop `Intent` pair is the whole contract.
 */
class MeetingRecordingService : Service() {
    companion object {
        const val ACTION_START = "io.airo.app.MEETING_RECORDING_START"
        const val ACTION_STOP = "io.airo.app.MEETING_RECORDING_STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"

        private const val CHANNEL_ID = "meeting_recording"
        private const val NOTIFICATION_ID = 4201

        fun startIntent(context: Context, title: String, text: String?): Intent {
            return Intent(context, MeetingRecordingService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
            }
        }

        fun stopIntent(context: Context): Intent {
            return Intent(context, MeetingRecordingService::class.java).apply {
                action = ACTION_STOP
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Recording meeting audio"
                val text = intent?.getStringExtra(EXTRA_TEXT)
                startForegroundWithNotification(title, text)
            }
        }
        // Not sticky: if the OS kills this service, the recording it was
        // covering has already stopped (the process died), so there is
        // nothing meaningful to restart into.
        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification(title: String, text: String?) {
        ensureChannel()
        val openApp = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = openApp?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text ?: "")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .apply { if (contentIntent != null) setContentIntent(contentIntent) }
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Meeting recording",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while Airo Mind is recording a meeting."
        }
        manager.createNotificationChannel(channel)
    }
}
