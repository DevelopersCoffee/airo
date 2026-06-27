package io.airo.app

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
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
    private val CALENDAR_READ_PERMISSION_REQUEST = 9001
    private val CALENDAR_WRITE_PERMISSION_REQUEST = 9002

    private var pendingCalendarResult: MethodChannel.Result? = null
    private var pendingCalendarDate: String? = null
    private var pendingCalendarEndDate: String? = null
    private var pendingCalendarCreateResult: MethodChannel.Result? = null
    private var pendingCalendarCreateArguments: Map<String, Any?>? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AGENT_CONNECTORS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readCalendarEvents" -> {
                        val date = call.argument<String>("date")
                        val endDate = call.argument<String>("end_date")
                        if (date.isNullOrBlank()) {
                            result.success(mapOf(
                                "error" to "missing_date",
                                "message" to "Calendar lookup requires a date."
                            ))
                        } else {
                            readCalendarEvents(date, endDate, result)
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
                val endDate = pendingCalendarEndDate
                pendingCalendarResult = null
                pendingCalendarDate = null
                pendingCalendarEndDate = null

                if (result == null || date == null) return

                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    readCalendarEvents(date, endDate, result)
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
        }
    }

    private fun readCalendarEvents(date: String, endDate: String?, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            pendingCalendarResult = result
            pendingCalendarDate = date
            pendingCalendarEndDate = endDate
            requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), CALENDAR_READ_PERMISSION_REQUEST)
            return
        }

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        dateFormat.isLenient = false
        val parsedStartDate = try {
            dateFormat.parse(date)
        } catch (_: Exception) {
            null
        }
        if (parsedStartDate == null) {
            result.success(mapOf(
                "error" to "invalid_date",
                "message" to "Calendar date must use YYYY-MM-DD."
            ))
            return
        }
        val parsedEndDate = if (endDate.isNullOrBlank()) {
            parsedStartDate
        } else {
            try {
                dateFormat.parse(endDate)
            } catch (_: Exception) {
                null
            }
        }
        if (parsedEndDate == null) {
            result.success(mapOf(
                "error" to "invalid_end_date",
                "message" to "Calendar end_date must use YYYY-MM-DD."
            ))
            return
        }
        if (parsedEndDate.before(parsedStartDate)) {
            result.success(mapOf(
                "error" to "invalid_date_range",
                "message" to "Calendar end_date must be on or after date."
            ))
            return
        }

        val start = Calendar.getInstance()
        start.time = parsedStartDate
        start.set(Calendar.HOUR_OF_DAY, 0)
        start.set(Calendar.MINUTE, 0)
        start.set(Calendar.SECOND, 0)
        start.set(Calendar.MILLISECOND, 0)

        val end = Calendar.getInstance()
        end.time = parsedEndDate
        end.set(Calendar.HOUR_OF_DAY, 0)
        end.set(Calendar.MINUTE, 0)
        end.set(Calendar.SECOND, 0)
        end.set(Calendar.MILLISECOND, 0)
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
            result.success(
                buildMap<String, Any?> {
                    put("date", date)
                    if (!endDate.isNullOrBlank()) {
                        put("end_date", endDate)
                    }
                    put("events", events)
                }
            )
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
