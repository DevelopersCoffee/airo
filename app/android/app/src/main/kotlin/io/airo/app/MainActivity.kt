package io.airo.app

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.CalendarContract
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val GEMINI_NANO_CHANNEL = "com.airo.gemini_nano"
    private val GEMINI_NANO_EVENT_CHANNEL = "com.airo.gemini_nano/stream"
    private val LITERT_LM_CHANNEL = "com.airo.litert_lm"
    private val AGENT_CONNECTORS_CHANNEL = "com.airo.agent_connectors"
    private val MEETING_TRANSCRIPTION_CHANNEL = "com.airo.meeting/transcription"
    private val MEETING_TRANSCRIPTION_EVENTS_CHANNEL = "com.airo.meeting/transcription_events"
    private val CALENDAR_READ_PERMISSION_REQUEST = 9001
    private val CALENDAR_WRITE_PERMISSION_REQUEST = 9002
    private val MEETING_AUDIO_PERMISSION_REQUEST = 9003

    private var pendingCalendarResult: MethodChannel.Result? = null
    private var pendingCalendarDate: String? = null
    private var pendingCalendarCreateResult: MethodChannel.Result? = null
    private var pendingCalendarCreateArguments: Map<String, Any?>? = null
    private var pendingMeetingStartResult: MethodChannel.Result? = null
    private var pendingMeetingStartArguments: Map<String, Any?>? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechEventSink: EventChannel.EventSink? = null
    private var speechMeetingId: String? = null
    private var speechLanguageCode: String = Locale.getDefault().toLanguageTag()
    private var speechChunkIndex = 0
    private var speechPaused = false
    private var speechActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Gemini Nano plugin
        val plugin = GeminiNanoPlugin(this)

        // Register MethodChannel for method calls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEMINI_NANO_CHANNEL)
            .setMethodCallHandler(plugin)

        // Register EventChannel for streaming
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GEMINI_NANO_EVENT_CHANNEL)
            .setStreamHandler(plugin.getStreamHandler())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LITERT_LM_CHANNEL)
            .setMethodCallHandler(LiteRtLmPlugin(this))

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MEETING_TRANSCRIPTION_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    speechEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    speechEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEETING_TRANSCRIPTION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRealtimeTranscription" -> {
                        val arguments = call.arguments as? Map<String, Any?>
                        if (arguments == null) {
                            result.error(
                                "missing_arguments",
                                "Live Notes requires a meeting id and language.",
                                null
                            )
                        } else {
                            startMeetingTranscription(arguments, result)
                        }
                    }
                    "pauseRealtimeTranscription" -> {
                        speechPaused = true
                        speechRecognizer?.stopListening()
                        result.success(null)
                    }
                    "resumeRealtimeTranscription" -> {
                        speechPaused = false
                        startSpeechListening()
                        result.success(null)
                    }
                    "stopRealtimeTranscription" -> {
                        stopMeetingTranscription()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AGENT_CONNECTORS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readCalendarEvents" -> {
                        val date = call.argument<String>("date")
                        if (date.isNullOrBlank()) {
                            result.success(mapOf(
                                "error" to "missing_date",
                                "message" to "Calendar lookup requires a date."
                            ))
                        } else {
                            readCalendarEvents(date, result)
                        }
                    }
                    "createCalendarEvent" -> {
                        val arguments = call.arguments as? Map<String, Any?>
                        if (arguments == null) {
                            result.success(mapOf(
                                "error" to "missing_arguments",
                                "message" to "Calendar event creation requires event details."
                            ))
                        } else {
                            createCalendarEvent(arguments, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            CALENDAR_READ_PERMISSION_REQUEST -> {
                val result = pendingCalendarResult
                val date = pendingCalendarDate
                pendingCalendarResult = null
                pendingCalendarDate = null

                if (result == null || date == null) return

                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    readCalendarEvents(date, result)
                } else {
                    result.success(mapOf(
                        "error" to "calendar_permission_denied",
                        "message" to "Calendar permission is required to check your schedule."
                    ))
                }
            }
            CALENDAR_WRITE_PERMISSION_REQUEST -> {
                val result = pendingCalendarCreateResult
                val arguments = pendingCalendarCreateArguments
                pendingCalendarCreateResult = null
                pendingCalendarCreateArguments = null

                if (result == null || arguments == null) return

                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    createCalendarEvent(arguments, result)
                } else {
                    result.success(mapOf(
                        "error" to "calendar_permission_denied",
                        "message" to "Calendar permission is required to add this event."
                    ))
                }
            }
            MEETING_AUDIO_PERMISSION_REQUEST -> {
                val result = pendingMeetingStartResult
                val arguments = pendingMeetingStartArguments
                pendingMeetingStartResult = null
                pendingMeetingStartArguments = null

                if (result == null || arguments == null) return

                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    startMeetingTranscription(arguments, result)
                } else {
                    result.error(
                        "microphone_permission_denied",
                        "Microphone permission is required to start Live Notes.",
                        null
                    )
                }
            }
        }
    }

    private fun startMeetingTranscription(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val meetingId = arguments["meetingId"] as? String
        val languageCode = arguments["languageCode"] as? String ?: Locale.getDefault().toLanguageTag()
        if (meetingId.isNullOrBlank()) {
            result.error("missing_meeting_id", "Live Notes requires a meeting id.", null)
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingMeetingStartResult = result
            pendingMeetingStartArguments = arguments
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MEETING_AUDIO_PERMISSION_REQUEST)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error(
                "speech_recognizer_unavailable",
                "This device does not expose Android speech recognition.",
                null
            )
            return
        }

        stopMeetingTranscription()
        speechMeetingId = meetingId
        speechLanguageCode = languageCode
        speechChunkIndex = 0
        speechPaused = false
        speechActive = true
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).also { recognizer ->
            recognizer.setRecognitionListener(meetingRecognitionListener())
        }
        startSpeechListening()
        result.success(null)
    }

    private fun stopMeetingTranscription() {
        speechActive = false
        speechPaused = false
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        speechMeetingId = null
    }

    private fun startSpeechListening() {
        if (!speechActive || speechPaused || speechRecognizer == null) return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, speechLanguageCode)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        speechRecognizer?.startListening(intent)
    }

    private fun meetingRecognitionListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onEvent(eventType: Int, params: Bundle?) = Unit

            override fun onPartialResults(partialResults: Bundle?) {
                val text = bestSpeechText(partialResults) ?: return
                emitSpeechChunk(text, isFinal = false)
            }

            override fun onResults(results: Bundle?) {
                val text = bestSpeechText(results)
                if (text != null) {
                    emitSpeechChunk(text, isFinal = true)
                    speechChunkIndex += 1
                }
                if (speechActive && !speechPaused) {
                    startSpeechListening()
                }
            }

            override fun onError(error: Int) {
                if (speechActive && !speechPaused) {
                    startSpeechListening()
                }
            }
        }
    }

    private fun bestSpeechText(bundle: Bundle?): String? {
        val matches = bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
        return matches?.firstOrNull()
    }

    private fun emitSpeechChunk(text: String, isFinal: Boolean) {
        val meetingId = speechMeetingId ?: return
        val startMs = speechChunkIndex * 8000
        val endMs = startMs + 8000
        speechEventSink?.success(
            mapOf(
                "id" to "android_speech_${speechChunkIndex}_${if (isFinal) "final" else "partial"}",
                "meetingId" to meetingId,
                "text" to text,
                "startMs" to startMs,
                "endMs" to endMs,
                "isFinal" to isFinal,
                "confidence" to 0.8
            )
        )
    }

    private fun readCalendarEvents(date: String, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            pendingCalendarResult = result
            pendingCalendarDate = date
            requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), CALENDAR_READ_PERMISSION_REQUEST)
            return
        }

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        dateFormat.isLenient = false
        val parsedDate = try {
            dateFormat.parse(date)
        } catch (_: Exception) {
            null
        }
        if (parsedDate == null) {
            result.success(mapOf(
                "error" to "invalid_date",
                "message" to "Calendar date must use YYYY-MM-DD."
            ))
            return
        }

        val start = Calendar.getInstance()
        start.time = parsedDate
        start.set(Calendar.HOUR_OF_DAY, 0)
        start.set(Calendar.MINUTE, 0)
        start.set(Calendar.SECOND, 0)
        start.set(Calendar.MILLISECOND, 0)

        val end = start.clone() as Calendar
        end.add(Calendar.DAY_OF_MONTH, 1)

        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, start.timeInMillis)
        ContentUris.appendId(builder, end.timeInMillis)

        val projection = arrayOf(
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME
        )

        val events = mutableListOf<Map<String, Any?>>()
        val outputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)

        try {
            contentResolver.query(
                builder.build(),
                projection,
                null,
                null,
                "${CalendarContract.Instances.BEGIN} ASC"
            )?.use { cursor ->
                val titleIndex = cursor.getColumnIndex(CalendarContract.Instances.TITLE)
                val beginIndex = cursor.getColumnIndex(CalendarContract.Instances.BEGIN)
                val endIndex = cursor.getColumnIndex(CalendarContract.Instances.END)
                val calendarIndex = cursor.getColumnIndex(CalendarContract.Instances.CALENDAR_DISPLAY_NAME)

                while (cursor.moveToNext()) {
                    val title = cursor.getString(titleIndex) ?: "Untitled event"
                    val beginMillis = cursor.getLong(beginIndex)
                    val endMillis = cursor.getLong(endIndex)
                    val calendarName = cursor.getString(calendarIndex)
                    events.add(mapOf(
                        "title" to title,
                        "start" to outputFormat.format(beginMillis),
                        "end" to outputFormat.format(endMillis),
                        "calendar" to calendarName
                    ))
                }
            }
            result.success(mapOf("date" to date, "events" to events))
        } catch (error: Exception) {
            result.success(mapOf(
                "error" to "calendar_read_failed",
                "message" to (error.message ?: "Calendar events could not be read.")
            ))
        }
    }

    private fun createCalendarEvent(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val hasReadPermission = checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
        val hasWritePermission = checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED
        if (!hasReadPermission || !hasWritePermission) {
            pendingCalendarCreateResult = result
            pendingCalendarCreateArguments = arguments
            requestPermissions(
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
                CALENDAR_WRITE_PERMISSION_REQUEST
            )
            return
        }

        val title = arguments["title"] as? String
        val date = arguments["date"] as? String
        val hour = (arguments["hour"] as? Number)?.toInt()
        val minute = (arguments["minute"] as? Number)?.toInt() ?: 0
        val durationMinutes = (arguments["duration_minutes"] as? Number)?.toInt() ?: 30
        val message = arguments["message"] as? String
        val repeatDaily = arguments["repeat_daily"] as? Boolean ?: false

        if (title.isNullOrBlank() || date.isNullOrBlank() || hour == null) {
            result.success(mapOf(
                "error" to "missing_event_details",
                "message" to "Calendar event creation requires title, date, and time."
            ))
            return
        }

        val start = calendarFor(date, hour, minute)
        if (start == null) {
            result.success(mapOf(
                "error" to "invalid_date",
                "message" to "Calendar date must use YYYY-MM-DD."
            ))
            return
        }
        val end = start.clone() as Calendar
        end.add(Calendar.MINUTE, durationMinutes.coerceAtLeast(1))

        val calendarId = writableCalendarId()
        if (calendarId == null) {
            result.success(mapOf(
                "error" to "calendar_unavailable",
                "message" to "No writable calendar is available on this device."
            ))
            return
        }

        try {
            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calendarId)
                put(CalendarContract.Events.TITLE, title)
                put(CalendarContract.Events.DESCRIPTION, message)
                put(CalendarContract.Events.DTSTART, start.timeInMillis)
                put(CalendarContract.Events.DTEND, end.timeInMillis)
                put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                if (repeatDaily) {
                    put(CalendarContract.Events.RRULE, "FREQ=DAILY")
                }
            }
            val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            val eventId = uri?.lastPathSegment
            if (eventId == null) {
                result.success(mapOf(
                    "error" to "calendar_insert_failed",
                    "message" to "Calendar event could not be created."
                ))
                return
            }
            result.success(mapOf(
                "created" to true,
                "event_id" to eventId,
                "title" to title,
                "date" to date,
                "hour" to hour,
                "minute" to minute,
                "repeat_daily" to repeatDaily
            ))
        } catch (error: Exception) {
            result.success(mapOf(
                "error" to "calendar_insert_failed",
                "message" to (error.message ?: "Calendar event could not be created.")
            ))
        }
    }

    private fun calendarFor(date: String, hour: Int, minute: Int): Calendar? {
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        dateFormat.isLenient = false
        val parsedDate = try {
            dateFormat.parse(date)
        } catch (_: Exception) {
            null
        } ?: return null

        return Calendar.getInstance().apply {
            time = parsedDate
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }

    private fun writableCalendarId(): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.VISIBLE
        )
        val selection = "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
        val selectionArgs = arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString())

        return contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${CalendarContract.Calendars.IS_PRIMARY} DESC, ${CalendarContract.Calendars.VISIBLE} DESC"
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndex(CalendarContract.Calendars._ID)
            if (cursor.moveToFirst()) cursor.getLong(idIndex) else null
        }
    }
}
