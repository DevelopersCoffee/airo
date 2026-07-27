package io.airo.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class PhoneMediaPickerPlugin(private val activity: Activity) {
    companion object {
        private const val CHANNEL = "com.airo/phone_media_picker"
        private const val REQUEST_PICK_VIDEO = 9410
    }

    private val leases = mutableMapOf<String, ParcelFileDescriptor>()
    private var pendingResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickVideo" -> pickVideo(result)
                "release" -> {
                    release(call.argument<String>("token"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun pickVideo(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("picker_active", "A video picker is already open.", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = "video/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (intent.resolveActivity(activity.packageManager) == null) {
            result.error("picker_unavailable", "No video picker is available.", null)
            return
        }

        pendingResult = result
        activity.startActivityForResult(intent, REQUEST_PICK_VIDEO)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_VIDEO) return false

        val result = pendingResult
        pendingResult = null
        if (result == null) return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }

        try {
            val descriptor = activity.contentResolver.openFileDescriptor(uri, "r")
                ?: error("The selected video could not be opened.")
            val title = queryDisplayName(uri) ?: "Selected video"
            val token = UUID.randomUUID().toString()
            leases[token] = descriptor
            result.success(
                mapOf(
                    "token" to token,
                    "descriptor" to descriptor.fd,
                    "filePath" to "/proc/self/fd/${descriptor.fd}",
                    "title" to title,
                    "size" to descriptor.statSize
                )
            )
        } catch (error: Exception) {
            result.error(
                "open_failed",
                error.message ?: "The selected video could not be opened.",
                null
            )
        }
        return true
    }

    private fun queryDisplayName(uri: Uri): String? {
        return activity.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) null else cursor.getString(index)
        }
    }

    private fun release(token: String?) {
        token?.let(leases::remove)?.close()
    }
}
