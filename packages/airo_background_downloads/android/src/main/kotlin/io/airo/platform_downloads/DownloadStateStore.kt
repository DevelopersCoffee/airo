package io.airo.platform_downloads

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

internal data class StoredDownloadRequest(
    val artifactId: String,
    val source: String,
    val destinationPath: String,
    val expectedBytes: Long?,
    val expectedSha256: String?,
    val displayName: String?,
    val generation: Int,
    val retryCount: Int,
) {
    fun toWorkDataMap(): Map<String, Any> = buildMap {
        put("artifactId", artifactId)
        put("source", source)
        put("destinationPath", destinationPath)
        put("generation", generation)
        put("retryCount", retryCount)
        expectedBytes?.let { put("expectedBytes", it) }
        expectedSha256?.let { put("expectedSha256", it) }
        displayName?.let { put("displayName", it) }
    }

    fun toJson(): JSONObject = JSONObject()
        .put("artifactId", artifactId)
        .put("source", source)
        .put("destinationPath", destinationPath)
        .put("expectedBytes", expectedBytes)
        .put("expectedSha256", expectedSha256)
        .put("displayName", displayName)
        .put("generation", generation)
        .put("retryCount", retryCount)

    companion object {
        fun fromJson(json: JSONObject): StoredDownloadRequest =
            StoredDownloadRequest(
                artifactId = json.getString("artifactId"),
                source = json.getString("source"),
                destinationPath = json.getString("destinationPath"),
                expectedBytes = json.optionalLong("expectedBytes"),
                expectedSha256 = json.optionalString("expectedSha256"),
                displayName = json.optionalString("displayName"),
                generation = json.optInt("generation", 1),
                retryCount = json.optInt("retryCount", 0),
            )
    }
}

internal class DownloadStateStore(context: Context) {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun saveNewRequest(
        artifactId: String,
        source: String,
        destinationPath: String,
        expectedBytes: Long?,
        expectedSha256: String?,
        displayName: String?,
    ): StoredDownloadRequest {
        val current = request(artifactId)
        val request = StoredDownloadRequest(
            artifactId = artifactId,
            source = source,
            destinationPath = destinationPath,
            expectedBytes = expectedBytes,
            expectedSha256 = expectedSha256,
            displayName = displayName,
            generation = (current?.generation ?: 0) + 1,
            retryCount = current?.retryCount ?: 0,
        )
        saveRequest(request)
        addToOrder(artifactId)
        return request
    }

    @Synchronized
    fun nextAttempt(
        artifactId: String,
        incrementRetry: Boolean,
        moveToEnd: Boolean = false,
    ): StoredDownloadRequest? {
        val current = request(artifactId) ?: return null
        val request = current.copy(
            generation = current.generation + 1,
            retryCount = current.retryCount + if (incrementRetry) 1 else 0,
        )
        saveRequest(request)
        if (moveToEnd) addToOrder(artifactId)
        return request
    }

    @Synchronized
    fun invalidateGeneration(artifactId: String): StoredDownloadRequest? {
        val current = request(artifactId) ?: return null
        val updated = current.copy(generation = current.generation + 1)
        saveRequest(updated)
        return updated
    }

    fun request(artifactId: String): StoredDownloadRequest? {
        val encoded = preferences.getString(requestKey(artifactId), null) ?: return null
        return runCatching {
            StoredDownloadRequest.fromJson(JSONObject(encoded))
        }.getOrNull()
    }

    fun isCurrentGeneration(artifactId: String, generation: Int): Boolean =
        request(artifactId)?.generation == generation

    @Synchronized
    fun updateState(
        artifactId: String,
        status: String,
        downloadedBytes: Long = 0,
        totalBytes: Long = 0,
        speedBytesPerSecond: Double = 0.0,
        retryCount: Int = request(artifactId)?.retryCount ?: 0,
        failureCode: String? = null,
        failureMessage: String? = null,
        canResume: Boolean = false,
    ) {
        val state = JSONObject()
            .put("artifactId", artifactId)
            .put("status", status)
            .put("downloadedBytes", downloadedBytes.coerceAtLeast(0))
            .put("totalBytes", totalBytes.coerceAtLeast(0))
            .put("speedBytesPerSecond", speedBytesPerSecond.coerceAtLeast(0.0))
            .put("retryCount", retryCount.coerceAtLeast(0))
            .put("canResume", canResume)
        failureCode?.let { state.put("failureCode", it) }
        failureMessage?.let { state.put("failureMessage", it) }
        preferences.edit().putString(stateKey(artifactId), state.toString()).apply()
    }

    fun state(artifactId: String): Map<String, Any?>? {
        val encoded = preferences.getString(stateKey(artifactId), null) ?: return null
        return runCatching { JSONObject(encoded).toPlatformMap() }.getOrNull()
    }

    fun statesInOrder(): List<Map<String, Any?>> {
        val order = order()
        var queuePosition = 0
        return order.mapNotNull { artifactId ->
            state(artifactId)?.toMutableMap()?.apply {
                val status = this["status"]
                this["queuePosition"] = if (status == "queued") queuePosition++ else null
            }
        }
    }

    fun status(artifactId: String): String? = state(artifactId)?.get("status") as? String

    fun clearArtifact(artifactId: String) {
        preferences.edit()
            .remove(requestKey(artifactId))
            .remove(stateKey(artifactId))
            .apply()
        val remaining = order().filterNot { it == artifactId }
        saveOrder(remaining)
    }

    @Synchronized
    private fun saveRequest(request: StoredDownloadRequest) {
        preferences.edit()
            .putString(requestKey(request.artifactId), request.toJson().toString())
            .apply()
    }

    @Synchronized
    private fun addToOrder(artifactId: String) {
        val updated = order().filterNot { it == artifactId } + artifactId
        saveOrder(updated)
    }

    private fun order(): List<String> {
        val encoded = preferences.getString(ORDER_KEY, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(encoded)
            List(array.length()) { index -> array.getString(index) }
        }.getOrDefault(emptyList())
    }

    private fun saveOrder(order: List<String>) {
        preferences.edit().putString(ORDER_KEY, JSONArray(order).toString()).apply()
    }

    private fun requestKey(artifactId: String): String = "request:$artifactId"

    private fun stateKey(artifactId: String): String = "state:$artifactId"

    companion object {
        private const val PREFERENCES_NAME = "airo_platform_downloads_v1"
        private const val ORDER_KEY = "queue_order"
    }
}

private fun JSONObject.optionalLong(key: String): Long? =
    if (has(key) && !isNull(key)) getLong(key) else null

private fun JSONObject.optionalString(key: String): String? =
    if (has(key) && !isNull(key)) getString(key) else null

private fun JSONObject.toPlatformMap(): Map<String, Any?> =
    keys().asSequence().associateWith { key ->
        when (val value = get(key)) {
            JSONObject.NULL -> null
            is Number, is String, is Boolean -> value
            else -> value.toString()
        }
    }
