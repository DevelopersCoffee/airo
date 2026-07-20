package io.airo.app

import android.Manifest
import android.app.UiModeManager
import android.content.ContentUris
import android.content.Context
import android.content.ContentValues
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class MainActivity : AudioServiceActivity() {
    private val GEMINI_NANO_CHANNEL = "com.airo.gemini_nano"
    private val GEMINI_NANO_EVENT_CHANNEL = "com.airo.gemini_nano/stream"
    private val LITERT_LM_CHANNEL = "com.airo.litert_lm"
    private val AGENT_CONNECTORS_CHANNEL = "com.airo.agent_connectors"
    private val DEVICE_INFO_CHANNEL = "com.airo/device_info"
    private val CALENDAR_READ_PERMISSION_REQUEST = 9001
    private val CALENDAR_WRITE_PERMISSION_REQUEST = 9002

    private var pendingCalendarResult: MethodChannel.Result? = null
    private var pendingCalendarDate: String? = null
    private var pendingCalendarEndDate: String? = null
    private var pendingCalendarCreateResult: MethodChannel.Result? = null
    private var pendingCalendarCreateArguments: Map<String, Any?>? = null

    private lateinit var pictureInPicturePlugin: AiroPictureInPicturePlugin
    private lateinit var backgroundAudioPlugin: AiroBackgroundAudioPlugin

    override fun shouldDestroyEngineWithHost(): Boolean {
        return false
    }
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

        val downloadPlugin = ModelDownloadPlugin(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airo.model_download")
            .setMethodCallHandler(downloadPlugin)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airo.model_download/progress")
            .setStreamHandler(downloadPlugin.progressStreamHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTV" -> result.success(isTvDevice())
                    "getTvPlatform" -> result.success(getTvPlatform())
                    else -> result.notImplemented()
                }
            }

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
                    "getCalendarPermissionStatus" -> getCalendarPermissionStatus(result)
                    "openCalendarPermissionSettings" -> openCalendarPermissionSettings(result)
                    else -> result.notImplemented()
                }
            }

        pictureInPicturePlugin = AiroPictureInPicturePlugin(this)
        pictureInPicturePlugin.register(flutterEngine.dartExecutor.binaryMessenger)

        backgroundAudioPlugin = AiroBackgroundAudioPlugin(this)
        backgroundAudioPlugin.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pictureInPicturePlugin.notifyModeChanged(isInPictureInPictureMode)
    }

    private fun isTvDevice(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY) ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv") ||
            uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }

    private fun getTvPlatform(): String {
        if (packageManager.hasSystemFeature("amazon.hardware.fire_tv")) {
            return "fire_tv"
        }
        if (isTvDevice()) {
            return "android_tv"
        }
        return "none"
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

    private fun getCalendarPermissionStatus(result: MethodChannel.Result) {
        val granted = checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
        result.success(mapOf(
            "status" to if (granted) "granted" else "denied",
            "granted" to granted,
            "can_request" to !granted,
            "permission" to Manifest.permission.READ_CALENDAR
        ))
    }

    private fun openCalendarPermissionSettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        startActivity(intent)
        result.success(mapOf("opened" to true))
    }

    private fun createCalendarEvent(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val title = arguments["title"] as? String
        val start = arguments["start"] as? String
        val end = arguments["end"] as? String

        if (start != null && end != null) {
            val description = arguments["description"] as? String
            val location = arguments["location"] as? String

            if (title.isNullOrBlank()) {
                result.success(mapOf(
                    "error" to "invalid_calendar_event",
                    "message" to "Calendar event requires title, start, and end."
                ))
                return
            }

            val dateTimeFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)
            dateTimeFormat.isLenient = false
            val startMillis = try {
                dateTimeFormat.parse(start)?.time
            } catch (_: Exception) {
                null
            }
            val endMillis = try {
                dateTimeFormat.parse(end)?.time
            } catch (_: Exception) {
                null
            }
            if (startMillis == null || endMillis == null || endMillis <= startMillis) {
                result.success(mapOf(
                    "error" to "invalid_calendar_event_time",
                    "message" to "Calendar event times must use ISO-8601 and end after start."
                ))
                return
            }

            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, title)
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
                if (!description.isNullOrBlank()) {
                    putExtra(CalendarContract.Events.DESCRIPTION, description)
                }
                if (!location.isNullOrBlank()) {
                    putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                }
            }

            if (intent.resolveActivity(packageManager) == null) {
                result.success(mapOf(
                    "error" to "calendar_app_unavailable",
                    "message" to "No calendar app is available to create this event."
                ))
                return
            }

            startActivity(intent)
            result.success(mapOf(
                "created" to true,
                "confirmation" to "native_calendar_app"
            ))
            return
        }

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

        val startCal = calendarFor(date, hour, minute)
        if (startCal == null) {
            result.success(mapOf(
                "error" to "invalid_date",
                "message" to "Calendar date must use YYYY-MM-DD."
            ))
            return
        }
        val endCal = startCal.clone() as Calendar
        endCal.add(Calendar.MINUTE, durationMinutes.coerceAtLeast(1))

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
                put(CalendarContract.Events.DTSTART, startCal.timeInMillis)
                put(CalendarContract.Events.DTEND, endCal.timeInMillis)
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
