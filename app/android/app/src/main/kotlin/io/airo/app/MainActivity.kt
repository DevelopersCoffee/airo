package io.airo.app

import android.Manifest
import android.content.ContentUris
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

class MainActivity : FlutterActivity() {
    private val GEMINI_NANO_CHANNEL = "com.airo.gemini_nano"
    private val GEMINI_NANO_EVENT_CHANNEL = "com.airo.gemini_nano/stream"
    private val LITERT_LM_CHANNEL = "com.airo.litert_lm"
    private val AGENT_CONNECTORS_CHANNEL = "com.airo.agent_connectors"
    private val CALENDAR_PERMISSION_REQUEST = 9001

    private var pendingCalendarResult: MethodChannel.Result? = null
    private var pendingCalendarDate: String? = null

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
                        if (date.isNullOrBlank()) {
                            result.success(mapOf(
                                "error" to "missing_date",
                                "message" to "Calendar lookup requires a date."
                            ))
                        } else {
                            readCalendarEvents(date, result)
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

        if (requestCode != CALENDAR_PERMISSION_REQUEST) return

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

    private fun readCalendarEvents(date: String, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            pendingCalendarResult = result
            pendingCalendarDate = date
            requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), CALENDAR_PERMISSION_REQUEST)
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
}
