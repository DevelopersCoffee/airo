package io.airo.platform_calendar

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class PlatformCalendarPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingCreateResult: MethodChannel.Result? = null
    private var pendingCreateArguments: Map<String, Any?>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> result.success(permissionPayload())
            "requestPermission" -> requestReadPermission(result)
            "openSettings" -> openSettings(result)
            "openCalendarApp" -> openCalendarApp(result)
            "listCalendars" -> listCalendars(result)
            "getEvents" -> getEvents(call, result)
            "getEvent" -> getEvent(call, result)
            "createCalendarEvent" -> createCalendarEvent(call.arguments as? Map<String, Any?>, result)
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        when (requestCode) {
            READ_PERMISSION_REQUEST -> {
                val pending = pendingPermissionResult ?: return true
                pendingPermissionResult = null
                markPermissionRequested()
                pending.success(permissionPayload())
                return true
            }
            WRITE_PERMISSION_REQUEST -> {
                val pending = pendingCreateResult
                val arguments = pendingCreateArguments
                pendingCreateResult = null
                pendingCreateArguments = null
                if (pending == null || arguments == null) return true
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    insertCalendarEvent(arguments, pending)
                } else {
                    pending.success(
                        mapOf(
                            "error" to "PERMISSION_DENIED",
                            "message" to "Calendar permission is required to add this event.",
                        ),
                    )
                }
                return true
            }
        }
        return false
    }

    private fun permissionPayload(): Map<String, Any?> {
        val granted = hasReadPermission()
        val requested = permissionRequested()
        val status = when {
            granted -> "granted"
            !requested -> "notDetermined"
            else -> "denied"
        }
        return mapOf(
            "status" to status,
            "granted" to granted,
            "can_request" to !granted,
            "adapter" to "android",
        )
    }

    private fun requestReadPermission(result: MethodChannel.Result) {
        val host = activity
        if (host == null) {
            result.success(
                mapOf(
                    "error" to "EXECUTION_FAILED",
                    "message" to "Calendar permission cannot be requested without an activity.",
                ),
            )
            return
        }
        if (hasReadPermission()) {
            result.success(permissionPayload())
            return
        }
        pendingPermissionResult = result
        markPermissionRequested()
        host.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), READ_PERMISSION_REQUEST)
    }

    private fun openSettings(result: MethodChannel.Result) {
        val host = activity ?: context
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        host.startActivity(intent)
        result.success(mapOf("opened" to true))
    }

    private fun openCalendarApp(result: MethodChannel.Result) {
        try {
            val host = activity ?: context
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = CalendarContract.CONTENT_URI
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            host.startActivity(intent)
            result.success(mapOf("opened" to true))
        } catch (_: Exception) {
            result.success(mapOf("opened" to false))
        }
    }

    private fun listCalendars(result: MethodChannel.Result) {
        if (!hasReadPermission()) {
            result.success(permissionRequired())
            return
        }
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.IS_PRIMARY,
        )
        val calendars = mutableListOf<Map<String, Any?>>()
        try {
            context.contentResolver.query(
                CalendarContract.Calendars.CONTENT_URI,
                projection,
                "${CalendarContract.Calendars.VISIBLE}=1",
                null,
                "${CalendarContract.Calendars.IS_PRIMARY} DESC",
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndex(CalendarContract.Calendars._ID)
                val titleIndex = cursor.getColumnIndex(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
                val accountIndex = cursor.getColumnIndex(CalendarContract.Calendars.ACCOUNT_NAME)
                val primaryIndex = cursor.getColumnIndex(CalendarContract.Calendars.IS_PRIMARY)
                while (cursor.moveToNext()) {
                    calendars.add(
                        mapOf(
                            "id" to cursor.getLong(idIndex).toString(),
                            "title" to (cursor.getString(titleIndex) ?: "Calendar"),
                            "account" to cursor.getString(accountIndex),
                            "isPrimary" to (cursor.getInt(primaryIndex) == 1),
                        ),
                    )
                }
            }
            result.success(mapOf("calendars" to calendars, "adapter" to "android"))
        } catch (error: Exception) {
            result.success(
                mapOf(
                    "error" to "EXECUTION_FAILED",
                    "message" to (error.message ?: "Calendars could not be listed."),
                ),
            )
        }
    }

    private fun getEvents(call: MethodCall, result: MethodChannel.Result) {
        if (!hasReadPermission()) {
            result.success(permissionRequired())
            return
        }
        val startMillis = parseInstant(call.argument<String>("start"))
        val endMillis = parseInstant(call.argument<String>("end"))
        if (startMillis == null || endMillis == null) {
            result.success(
                mapOf(
                    "error" to "INVALID_ARGUMENT",
                    "message" to "Calendar lookup requires start and end timestamps.",
                ),
            )
            return
        }
        if (endMillis < startMillis) {
            result.success(
                mapOf(
                    "error" to "INVALID_ARGUMENT",
                    "message" to "Calendar end must be on or after start.",
                ),
            )
            return
        }
        val maxResults = (call.argument<Number>("maxResults")?.toInt() ?: 50).coerceIn(1, 200)
        val calendarIds = call.argument<List<String>>("calendarIds")
        val search = call.argument<String>("search")?.trim().orEmpty()
        val startedAt = System.currentTimeMillis()

        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, startMillis)
        ContentUris.appendId(builder, endMillis)
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.DESCRIPTION,
            CalendarContract.Instances.EVENT_TIMEZONE,
            CalendarContract.Instances.ALL_DAY,
        )
        val selection = StringBuilder()
        val selectionArgs = mutableListOf<String>()
        if (!calendarIds.isNullOrEmpty()) {
            selection.append(
                calendarIds.joinToString(prefix = "${CalendarContract.Instances.CALENDAR_ID} IN (", postfix = ")") { "?" },
            )
            selectionArgs.addAll(calendarIds)
        }
        val events = mutableListOf<Map<String, Any?>>()
        val outputFormat = isoFormatter()
        try {
            context.contentResolver.query(
                builder.build(),
                projection,
                selection.toString().ifBlank { null },
                if (selectionArgs.isEmpty()) null else selectionArgs.toTypedArray(),
                "${CalendarContract.Instances.BEGIN} ASC",
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndex(CalendarContract.Instances.EVENT_ID)
                val titleIndex = cursor.getColumnIndex(CalendarContract.Instances.TITLE)
                val beginIndex = cursor.getColumnIndex(CalendarContract.Instances.BEGIN)
                val endIndex = cursor.getColumnIndex(CalendarContract.Instances.END)
                val calendarIndex = cursor.getColumnIndex(CalendarContract.Instances.CALENDAR_DISPLAY_NAME)
                val calendarIdIndex = cursor.getColumnIndex(CalendarContract.Instances.CALENDAR_ID)
                val locationIndex = cursor.getColumnIndex(CalendarContract.Instances.EVENT_LOCATION)
                val descriptionIndex = cursor.getColumnIndex(CalendarContract.Instances.DESCRIPTION)
                val timezoneIndex = cursor.getColumnIndex(CalendarContract.Instances.EVENT_TIMEZONE)
                val allDayIndex = cursor.getColumnIndex(CalendarContract.Instances.ALL_DAY)
                while (cursor.moveToNext() && events.size < maxResults) {
                    val title = cursor.getString(titleIndex) ?: "Untitled event"
                    if (search.isNotEmpty()) {
                        val haystack = listOf(
                            title,
                            cursor.getString(locationIndex).orEmpty(),
                            cursor.getString(descriptionIndex).orEmpty(),
                        ).joinToString(" ").lowercase(Locale.US)
                        if (!haystack.contains(search.lowercase(Locale.US))) continue
                    }
                    events.add(
                        mapOf(
                            "id" to cursor.getLong(idIndex).toString(),
                            "title" to title,
                            "start" to outputFormat.format(Date(cursor.getLong(beginIndex))),
                            "end" to outputFormat.format(Date(cursor.getLong(endIndex))),
                            "calendar" to cursor.getString(calendarIndex),
                            "calendarId" to cursor.getLong(calendarIdIndex).toString(),
                            "location" to cursor.getString(locationIndex),
                            "description" to cursor.getString(descriptionIndex),
                            "timezone" to (cursor.getString(timezoneIndex) ?: TimeZone.getDefault().id),
                            "attendees" to emptyList<String>(),
                            "isAllDay" to (cursor.getInt(allDayIndex) == 1),
                        ),
                    )
                }
            }
            result.success(
                mapOf(
                    "events" to events,
                    "adapter" to "android",
                    "duration_ms" to (System.currentTimeMillis() - startedAt),
                ),
            )
        } catch (error: Exception) {
            result.success(
                mapOf(
                    "error" to "EXECUTION_FAILED",
                    "message" to (error.message ?: "Calendar events could not be read."),
                ),
            )
        }
    }

    private fun getEvent(call: MethodCall, result: MethodChannel.Result) {
        if (!hasReadPermission()) {
            result.success(permissionRequired())
            return
        }
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.success(
                mapOf(
                    "error" to "INVALID_ARGUMENT",
                    "message" to "Calendar event id is required.",
                ),
            )
            return
        }
        val now = System.currentTimeMillis()
        val start = now - DAY_MILLIS
        val end = now + 30 * DAY_MILLIS
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, start)
        ContentUris.appendId(builder, end)
        try {
            context.contentResolver.query(
                builder.build(),
                arrayOf(
                    CalendarContract.Instances.EVENT_ID,
                    CalendarContract.Instances.TITLE,
                    CalendarContract.Instances.BEGIN,
                    CalendarContract.Instances.END,
                    CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
                    CalendarContract.Instances.CALENDAR_ID,
                    CalendarContract.Instances.EVENT_LOCATION,
                    CalendarContract.Instances.DESCRIPTION,
                    CalendarContract.Instances.EVENT_TIMEZONE,
                    CalendarContract.Instances.ALL_DAY,
                ),
                "${CalendarContract.Instances.EVENT_ID}=?",
                arrayOf(id),
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    result.success(mapOf("event" to null))
                    return
                }
                val outputFormat = isoFormatter()
                result.success(
                    mapOf(
                        "event" to mapOf(
                            "id" to cursor.getLong(0).toString(),
                            "title" to (cursor.getString(1) ?: "Untitled event"),
                            "start" to outputFormat.format(Date(cursor.getLong(2))),
                            "end" to outputFormat.format(Date(cursor.getLong(3))),
                            "calendar" to cursor.getString(4),
                            "calendarId" to cursor.getLong(5).toString(),
                            "location" to cursor.getString(6),
                            "description" to cursor.getString(7),
                            "timezone" to (cursor.getString(8) ?: TimeZone.getDefault().id),
                            "attendees" to emptyList<String>(),
                            "isAllDay" to (cursor.getInt(9) == 1),
                        ),
                    ),
                )
            } ?: result.success(mapOf("event" to null))
        } catch (error: Exception) {
            result.success(
                mapOf(
                    "error" to "EXECUTION_FAILED",
                    "message" to (error.message ?: "Calendar event could not be read."),
                ),
            )
        }
    }

    private fun createCalendarEvent(arguments: Map<String, Any?>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.success(
                mapOf(
                    "error" to "INVALID_ARGUMENT",
                    "message" to "Calendar event creation requires event details.",
                ),
            )
            return
        }
        val title = arguments["title"] as? String
        val start = arguments["start"] as? String
        val end = arguments["end"] as? String
        if (start != null && end != null) {
            if (title.isNullOrBlank()) {
                result.success(
                    mapOf(
                        "error" to "invalid_calendar_event",
                        "message" to "Calendar event requires title, start, and end.",
                    ),
                )
                return
            }
            val startMillis = parseInstant(start)
            val endMillis = parseInstant(end)
            if (startMillis == null || endMillis == null || endMillis <= startMillis) {
                result.success(
                    mapOf(
                        "error" to "invalid_calendar_event_time",
                        "message" to "Calendar event times must use ISO-8601 and end after start.",
                    ),
                )
                return
            }
            val host = activity
            if (host == null) {
                result.success(
                    mapOf(
                        "error" to "calendar_app_unavailable",
                        "message" to "No calendar app is available to create this event.",
                    ),
                )
                return
            }
            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, title)
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
                (arguments["description"] as? String)?.takeIf { it.isNotBlank() }?.let {
                    putExtra(CalendarContract.Events.DESCRIPTION, it)
                }
                (arguments["location"] as? String)?.takeIf { it.isNotBlank() }?.let {
                    putExtra(CalendarContract.Events.EVENT_LOCATION, it)
                }
            }
            if (intent.resolveActivity(host.packageManager) == null) {
                result.success(
                    mapOf(
                        "error" to "calendar_app_unavailable",
                        "message" to "No calendar app is available to create this event.",
                    ),
                )
                return
            }
            host.startActivity(intent)
            result.success(mapOf("created" to true, "confirmation" to "native_calendar_app"))
            return
        }

        if (!hasReadPermission() || !hasWritePermission()) {
            val host = activity
            if (host == null) {
                result.success(permissionRequired())
                return
            }
            pendingCreateResult = result
            pendingCreateArguments = arguments
            host.requestPermissions(
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
                WRITE_PERMISSION_REQUEST,
            )
            return
        }
        insertCalendarEvent(arguments, result)
    }

    private fun insertCalendarEvent(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val title = arguments["title"] as? String
        val date = arguments["date"] as? String
        val hour = (arguments["hour"] as? Number)?.toInt()
        val minute = (arguments["minute"] as? Number)?.toInt() ?: 0
        val durationMinutes = (arguments["duration_minutes"] as? Number)?.toInt() ?: 30
        val message = arguments["message"] as? String
        val repeatDaily = arguments["repeat_daily"] as? Boolean ?: false
        if (title.isNullOrBlank() || date.isNullOrBlank() || hour == null) {
            result.success(
                mapOf(
                    "error" to "missing_event_details",
                    "message" to "Calendar event creation requires title, date, and time.",
                ),
            )
            return
        }
        val startCal = calendarFor(date, hour, minute)
        if (startCal == null) {
            result.success(
                mapOf(
                    "error" to "invalid_date",
                    "message" to "Calendar date must use YYYY-MM-DD.",
                ),
            )
            return
        }
        val endCal = startCal.clone() as Calendar
        endCal.add(Calendar.MINUTE, durationMinutes.coerceAtLeast(1))
        val calendarId = writableCalendarId()
        if (calendarId == null) {
            result.success(
                mapOf(
                    "error" to "calendar_unavailable",
                    "message" to "No writable calendar is available on this device.",
                ),
            )
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
            val uri = context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            val eventId = uri?.lastPathSegment
            if (eventId == null) {
                result.success(
                    mapOf(
                        "error" to "calendar_insert_failed",
                        "message" to "Calendar event could not be created.",
                    ),
                )
                return
            }
            result.success(
                mapOf(
                    "created" to true,
                    "event_id" to eventId,
                    "title" to title,
                    "date" to date,
                    "hour" to hour,
                    "minute" to minute,
                    "repeat_daily" to repeatDaily,
                ),
            )
        } catch (error: Exception) {
            result.success(
                mapOf(
                    "error" to "calendar_insert_failed",
                    "message" to (error.message ?: "Calendar event could not be created."),
                ),
            )
        }
    }

    private fun calendarFor(date: String, hour: Int, minute: Int): Calendar? {
        if (hour !in 0..23 || minute !in 0..59) return null
        val parsed = try {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }.parse(date)
        } catch (_: Exception) {
            null
        } ?: return null
        return Calendar.getInstance().apply {
            time = parsed
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }

    private fun writableCalendarId(): Long? {
        return context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars._ID),
            "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?",
            arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
            "${CalendarContract.Calendars.IS_PRIMARY} DESC, ${CalendarContract.Calendars.VISIBLE} DESC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getLong(0) else null
        }
    }

    private fun hasReadPermission(): Boolean {
        return context.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasWritePermission(): Boolean {
        return context.checkSelfPermission(Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun permissionRequested(): Boolean {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(REQUESTED_KEY, false)
    }

    private fun markPermissionRequested() {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(REQUESTED_KEY, true)
            .apply()
    }

    private fun permissionRequired(): Map<String, Any?> {
        val code = if (permissionRequested()) "PERMISSION_DENIED" else "PERMISSION_REQUIRED"
        val message = if (permissionRequested()) {
            "Calendar access is disabled. Enable it in system settings to let Airo read your calendar."
        } else {
            "Airo needs calendar access to read your events."
        }
        return mapOf("error" to code, "message" to message)
    }

    private fun parseInstant(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        return try {
            java.time.Instant.parse(value).toEpochMilli()
        } catch (_: Exception) {
            try {
                java.time.OffsetDateTime.parse(value).toInstant().toEpochMilli()
            } catch (_: Exception) {
                try {
                    java.time.LocalDateTime.parse(value)
                        .atZone(java.time.ZoneId.systemDefault())
                        .toInstant()
                        .toEpochMilli()
                } catch (_: Exception) {
                    isoFormatter().parse(value)?.time
                }
            }
        }
    }

    private fun isoFormatter(): SimpleDateFormat {
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply { isLenient = false }
    }

    companion object {
        private const val CHANNEL = "dev.airo.platform_calendar/methods"
        private const val READ_PERMISSION_REQUEST = 9101
        private const val WRITE_PERMISSION_REQUEST = 9102
        private const val PREFS = "platform_calendar"
        private const val REQUESTED_KEY = "permission_requested"
        private const val DAY_MILLIS = 24L * 60L * 60L * 1000L
    }
}
