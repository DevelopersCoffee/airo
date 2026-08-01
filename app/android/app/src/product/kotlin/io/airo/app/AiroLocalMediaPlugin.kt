package io.airo.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.provider.DocumentsContract
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URI
import java.net.URL
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element

/**
 * Storage Access Framework bridge for user-authorized USB/removable media.
 * It never requests broad storage permission and never logs a path or URI.
 */
class AiroLocalMediaPlugin(private val activity: Activity) {
    private val requestCode = 9403
    private val maxDlnaResponseBytes = 2 * 1024 * 1024
    private var pendingResult: MethodChannel.Result? = null
    private val dlnaServers = ConcurrentHashMap<String, DlnaServer>()

    private data class DlnaServer(
        val controlUrl: String,
        val serviceType: String
    )

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "io.airo.local_media").setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(
                    mapOf(
                        "removableStorage" to true,
                        "dlnaUpnp" to true
                    )
                )
                "requestRemovableStorage" -> requestRoot(result)
                "browseRemovableStorage" -> {
                    val rootUri = call.argument<String>("rootUri")
                    if (rootUri.isNullOrBlank()) {
                        result.error("invalid_root", "Choose a media folder first.", null)
                    } else {
                        browse(rootUri, result)
                    }
                }
                "discoverDlna" -> discoverDlna(result)
                "browseDlna" -> {
                    val containerUri = call.argument<String>("containerUri")
                    if (containerUri.isNullOrBlank()) {
                        result.error(
                            "invalid_container",
                            "Choose a network media folder first.",
                            null
                        )
                    } else {
                        browseDlna(containerUri, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestRoot(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("request_in_progress", "A folder request is already open.", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        activity.startActivityForResult(intent, requestCode)
    }

    fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != requestCode) return false
        val result = pendingResult
        pendingResult = null
        if (result == null) return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        val flags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            result.success(uri.toString())
        } catch (_: SecurityException) {
            result.error("permission_denied", "The selected folder could not be opened.", null)
        }
        return true
    }

    private fun browse(root: String, result: MethodChannel.Result) {
        Thread {
            try {
                val treeUri = Uri.parse(root)
                val documentId = if (treeUri.path?.contains("/document/") == true) {
                    DocumentsContract.getDocumentId(treeUri)
                } else {
                    DocumentsContract.getTreeDocumentId(treeUri)
                }
                val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                    treeUri,
                    documentId
                )
                val projection = arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE
                )
                val entries = mutableListOf<Map<String, String>>()
                activity.contentResolver.query(
                    childrenUri,
                    projection,
                    null,
                    null,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME + " ASC"
                )?.use { cursor ->
                    val idIndex = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID
                    )
                    val nameIndex = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME
                    )
                    val mimeIndex = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_MIME_TYPE
                    )
                    while (cursor.moveToNext()) {
                        val id = cursor.getString(idIndex)
                        val name = cursor.getString(nameIndex) ?: "Media"
                        val mime = cursor.getString(mimeIndex) ?: ""
                        val kind = kindFor(name, mime) ?: continue
                        val documentUri = DocumentsContract
                            .buildDocumentUriUsingTree(treeUri, id)
                            .toString()
                        entries.add(
                            buildMap {
                                put("id", id)
                                put("name", name)
                                put("kind", kind)
                                put("accessUri", documentUri)
                                if (kind == "folder") put("childrenUri", documentUri)
                            }
                        )
                    }
                }
                activity.runOnUiThread { result.success(entries) }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "browse_failed",
                        "The selected media folder could not be read.",
                        null
                    )
                }
            }
        }.start()
    }

    private fun kindFor(name: String, mime: String): String? {
        if (mime == DocumentsContract.Document.MIME_TYPE_DIR) return "folder"
        if (mime.startsWith("video/")) return "video"
        if (mime.startsWith("audio/")) return "audio"
        val extension = name.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "mp4", "mkv", "webm", "mov", "m4v", "avi", "ts", "m2ts" -> "video"
            "mp3", "m4a", "aac", "flac", "ogg", "wav" -> "audio"
            "srt", "vtt", "ass", "ssa" -> "subtitle"
            else -> null
        }
    }

    private fun discoverDlna(result: MethodChannel.Result) {
        Thread {
            try {
                val entries = discoverSsdpLocations()
                    .mapNotNull(::loadDlnaServer)
                    .distinctBy { it["id"] }
                    .sortedBy { it["name"]?.lowercase() }
                activity.runOnUiThread { result.success(entries) }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "dlna_discovery_failed",
                        "Network media servers could not be discovered.",
                        null
                    )
                }
            }
        }.start()
    }

    private fun discoverSsdpLocations(): Set<String> {
        val wifiManager = activity.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val multicastLock = wifiManager
            ?.createMulticastLock("airo-dlna-discovery")
            ?.apply {
                setReferenceCounted(false)
                acquire()
            }
        try {
            val request = (
                "M-SEARCH * HTTP/1.1\r\n" +
                    "HOST: 239.255.255.250:1900\r\n" +
                    "MAN: \"ssdp:discover\"\r\n" +
                    "MX: 2\r\n" +
                    "ST: urn:schemas-upnp-org:device:MediaServer:1\r\n\r\n"
                ).toByteArray(StandardCharsets.US_ASCII)
            val target = InetAddress.getByName("239.255.255.250")
            val locations = linkedSetOf<String>()
            DatagramSocket().use { socket ->
                socket.soTimeout = 350
                repeat(2) {
                    socket.send(DatagramPacket(request, request.size, target, 1900))
                }
                val deadline = System.currentTimeMillis() + 2600
                while (System.currentTimeMillis() < deadline) {
                    try {
                        val buffer = ByteArray(8192)
                        val packet = DatagramPacket(buffer, buffer.size)
                        socket.receive(packet)
                        val response = String(
                            packet.data,
                            packet.offset,
                            packet.length,
                            StandardCharsets.US_ASCII
                        )
                        val location = response
                            .lineSequence()
                            .map(String::trim)
                            .firstOrNull {
                                it.startsWith("location:", ignoreCase = true)
                            }
                            ?.substringAfter(':')
                            ?.trim()
                        if (location != null && isApprovedLocalUrl(location)) {
                            locations.add(location)
                        }
                    } catch (_: java.net.SocketTimeoutException) {
                        // Continue until the bounded discovery deadline.
                    }
                }
            }
            return locations
        } finally {
            if (multicastLock?.isHeld == true) multicastLock.release()
        }
    }

    private fun loadDlnaServer(location: String): Map<String, String>? {
        val descriptor = httpRequest(location, method = "GET") ?: return null
        val document = parseXml(descriptor) ?: return null
        val deviceType = firstText(document.documentElement, "deviceType")
        if (!deviceType.contains("MediaServer", ignoreCase = true)) return null
        val friendlyName = firstText(document.documentElement, "friendlyName")
            .ifBlank { "Network media server" }
        val udn = firstText(document.documentElement, "UDN").ifBlank { location }
        val services = document.getElementsByTagNameNS("*", "service")
        var serviceType = ""
        var controlPath = ""
        for (index in 0 until services.length) {
            val service = services.item(index) as? Element ?: continue
            val candidateType = firstText(service, "serviceType")
            if (!candidateType.contains("ContentDirectory", ignoreCase = true)) {
                continue
            }
            serviceType = candidateType
            controlPath = firstText(service, "controlURL")
            break
        }
        if (serviceType.isBlank() || controlPath.isBlank()) return null
        val controlUrl = try {
            URI(location).resolve(controlPath).toString()
        } catch (_: Exception) {
            return null
        }
        if (!isApprovedLocalUrl(controlUrl)) return null
        val serverId = opaqueId(udn)
        dlnaServers[serverId] = DlnaServer(
            controlUrl = controlUrl,
            serviceType = serviceType
        )
        val rootHandle = dlnaHandle(serverId, "0")
        return mapOf(
            "id" to opaqueId("$serverId:root"),
            "name" to friendlyName,
            "kind" to "folder",
            "accessUri" to rootHandle,
            "childrenUri" to rootHandle
        )
    }

    private fun browseDlna(containerUri: String, result: MethodChannel.Result) {
        Thread {
            try {
                val token = parseDlnaHandle(containerUri)
                    ?: throw IllegalArgumentException("invalid handle")
                val server = dlnaServers[token.first]
                    ?: throw IllegalStateException("server expired")
                val response = browseContentDirectory(server, token.second)
                    ?: throw IllegalStateException("browse failed")
                val entries = decodeDidl(token.first, response)
                activity.runOnUiThread { result.success(entries) }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "dlna_browse_failed",
                        "The network media folder could not be read.",
                        null
                    )
                }
            }
        }.start()
    }

    private fun browseContentDirectory(
        server: DlnaServer,
        objectId: String
    ): String? {
        val body = """<?xml version="1.0" encoding="utf-8"?>
            |<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            | s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            |<s:Body>
            |<u:Browse xmlns:u="${xmlEscape(server.serviceType)}">
            |<ObjectID>${xmlEscape(objectId)}</ObjectID>
            |<BrowseFlag>BrowseDirectChildren</BrowseFlag>
            |<Filter>*</Filter>
            |<StartingIndex>0</StartingIndex>
            |<RequestedCount>500</RequestedCount>
            |<SortCriteria>+dc:title</SortCriteria>
            |</u:Browse>
            |</s:Body>
            |</s:Envelope>""".trimMargin()
        val response = httpRequest(
            server.controlUrl,
            method = "POST",
            body = body,
            headers = mapOf(
                "Content-Type" to "text/xml; charset=\"utf-8\"",
                "SOAPACTION" to "\"${server.serviceType}#Browse\""
            )
        ) ?: return null
        val soap = parseXml(response) ?: return null
        val results = soap.getElementsByTagNameNS("*", "Result")
        return if (results.length == 0) null else results.item(0).textContent
    }

    private fun decodeDidl(
        serverId: String,
        didlXml: String
    ): List<Map<String, String>> {
        val didl = parseXml(didlXml) ?: return emptyList()
        val entries = mutableListOf<Map<String, String>>()
        val containers = didl.getElementsByTagNameNS("*", "container")
        for (index in 0 until containers.length) {
            val container = containers.item(index) as? Element ?: continue
            val objectId = container.getAttribute("id")
            if (objectId.isBlank()) continue
            val name = firstText(container, "title").ifBlank { "Folder" }
            val handle = dlnaHandle(serverId, objectId)
            entries.add(
                mapOf(
                    "id" to opaqueId("$serverId:$objectId"),
                    "name" to name,
                    "kind" to "folder",
                    "accessUri" to handle,
                    "childrenUri" to handle
                )
            )
        }
        val items = didl.getElementsByTagNameNS("*", "item")
        for (index in 0 until items.length) {
            val item = items.item(index) as? Element ?: continue
            val objectId = item.getAttribute("id")
            if (objectId.isBlank()) continue
            val name = firstText(item, "title").ifBlank { "Media" }
            val upnpClass = firstText(item, "class")
            val resources = item.getElementsByTagNameNS("*", "res")
            var resourceUrl = ""
            var protocolInfo = ""
            for (resourceIndex in 0 until resources.length) {
                val resource = resources.item(resourceIndex) as? Element ?: continue
                val candidate = resource.textContent?.trim().orEmpty()
                if (isApprovedLocalUrl(candidate)) {
                    resourceUrl = candidate
                    protocolInfo = resource.getAttribute("protocolInfo")
                    break
                }
            }
            if (resourceUrl.isBlank()) continue
            val kind = dlnaKind(name, upnpClass, protocolInfo) ?: continue
            entries.add(
                mapOf(
                    "id" to opaqueId("$serverId:$objectId"),
                    "name" to name,
                    "kind" to kind,
                    "accessUri" to resourceUrl
                )
            )
        }
        return entries.sortedBy { it["name"]?.lowercase() }
    }

    private fun dlnaKind(
        name: String,
        upnpClass: String,
        protocolInfo: String
    ): String? {
        val lowerClass = upnpClass.lowercase()
        val lowerProtocol = protocolInfo.lowercase()
        if (lowerClass.contains("videoitem") || lowerProtocol.contains("video/")) {
            return "video"
        }
        if (lowerClass.contains("audioitem") || lowerProtocol.contains("audio/")) {
            return "audio"
        }
        val extension = name.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "mp4", "mkv", "webm", "mov", "m4v", "avi", "ts", "m2ts" -> "video"
            "mp3", "m4a", "aac", "flac", "ogg", "wav" -> "audio"
            "srt", "vtt", "ass", "ssa" -> "subtitle"
            else -> null
        }
    }

    private fun httpRequest(
        rawUrl: String,
        method: String,
        body: String? = null,
        headers: Map<String, String> = emptyMap()
    ): String? {
        if (!isApprovedLocalUrl(rawUrl)) return null
        val connection = URL(rawUrl).openConnection() as? HttpURLConnection
            ?: return null
        return try {
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 3500
            connection.readTimeout = 5000
            connection.requestMethod = method
            headers.forEach(connection::setRequestProperty)
            if (body != null) {
                connection.doOutput = true
                connection.outputStream.use {
                    it.write(body.toByteArray(StandardCharsets.UTF_8))
                }
            }
            if (connection.responseCode !in 200..299) return null
            val declaredLength = connection.contentLengthLong
            if (declaredLength > maxDlnaResponseBytes) return null
            connection.inputStream.use { stream ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    total += count
                    if (total > maxDlnaResponseBytes) return null
                    output.write(buffer, 0, count)
                }
                output.toString(StandardCharsets.UTF_8.name())
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun isApprovedLocalUrl(rawUrl: String): Boolean {
        val uri = try {
            URI(rawUrl)
        } catch (_: Exception) {
            return false
        }
        if (uri.scheme != "http" && uri.scheme != "https") return false
        val host = uri.host ?: return false
        return try {
            InetAddress.getAllByName(host).all(::isLocalAddress)
        } catch (_: Exception) {
            false
        }
    }

    private fun isLocalAddress(address: InetAddress): Boolean {
        if (address.isAnyLocalAddress ||
            address.isLoopbackAddress ||
            address.isLinkLocalAddress ||
            address.isSiteLocalAddress
        ) {
            return true
        }
        val bytes = address.address
        return bytes.size == 16 && (bytes[0].toInt() and 0xfe) == 0xfc
    }

    private fun parseXml(xml: String): org.w3c.dom.Document? {
        return try {
            val factory = DocumentBuilderFactory.newInstance().apply {
                isNamespaceAware = true
                isXIncludeAware = false
                setExpandEntityReferences(false)
                setFeature(
                    "http://apache.org/xml/features/disallow-doctype-decl",
                    true
                )
                setFeature(
                    "http://xml.org/sax/features/external-general-entities",
                    false
                )
                setFeature(
                    "http://xml.org/sax/features/external-parameter-entities",
                    false
                )
            }
            factory.newDocumentBuilder().parse(
                ByteArrayInputStream(xml.toByteArray(StandardCharsets.UTF_8))
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun firstText(element: Element, localName: String): String {
        val nodes = element.getElementsByTagNameNS("*", localName)
        return if (nodes.length == 0) "" else nodes.item(0).textContent?.trim().orEmpty()
    }

    private fun dlnaHandle(serverId: String, objectId: String): String {
        val encoded = Base64.encodeToString(
            objectId.toByteArray(StandardCharsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
        )
        return "dlna://server/$serverId/$encoded"
    }

    private fun parseDlnaHandle(handle: String): Pair<String, String>? {
        if (handle.length > 4096) return null
        val uri = try {
            Uri.parse(handle)
        } catch (_: Exception) {
            return null
        }
        if (uri.scheme != "dlna" || uri.host != "server") return null
        if (uri.pathSegments.size != 2) return null
        val serverId = uri.pathSegments[0]
        val objectId = try {
            String(
                Base64.decode(
                    uri.pathSegments[1],
                    Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
                ),
                StandardCharsets.UTF_8
            )
        } catch (_: Exception) {
            return null
        }
        return serverId to objectId
    }

    private fun opaqueId(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(StandardCharsets.UTF_8))
        return digest.take(12).joinToString("") { "%02x".format(it) }
    }

    private fun xmlEscape(value: String): String {
        return value
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")
    }
}
