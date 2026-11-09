package app.melo.melo_player

import android.app.RecoverableSecurityException
import android.content.Intent
import android.content.ContentUris
import android.content.IntentSender
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val PICK_MUSIC_FOLDER_REQUEST = 7021
        private const val DELETE_DEVICE_AUDIO_REQUEST = 7022
        private val audioExtensions = setOf("mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "webm")
    }

    private val ioExecutor = Executors.newFixedThreadPool(4)
    private val artworkExecutor = Executors.newFixedThreadPool(4)
    private val waveformExecutor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val waveformCache = LinkedHashMap<String, List<Double>>(32, 0.75f, true)
    private var pendingFolderResult: MethodChannel.Result? = null
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingDeleteUri: Uri? = null
    private var retryDeleteAfterConfirmation = false
    @Volatile
    private var audioGenreCache: Map<Long, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val libraryHandler = MethodChannel.MethodCallHandler { call, result ->
            handleLibraryMethod(call, result)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.melo.melo_player/library",
        ).setMethodCallHandler(libraryHandler)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.melomeloplayer/library",
        ).setMethodCallHandler(libraryHandler)
    }

    private fun handleLibraryMethod(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "androidSdkVersion" -> result.success(android.os.Build.VERSION.SDK_INT)
            "scanAudio" -> scanAudio(call, result)
            "pickMusicFolder" -> pickMusicFolder(result)
            "scanMusicFolder" -> scanMusicFolder(call, result)
            "releaseMusicFolder" -> releaseMusicFolder(call, result)
            "deleteDeviceAudio" -> deleteDeviceAudio(call, result)
            "deleteDeviceAudioBatch" -> deleteDeviceAudioBatch(call, result)
            "readLyrics" -> readLyrics(call, result)
            "readLocalAudioMetadata" -> readLocalAudioMetadata(call, result)
            "readAudioTags" -> readLocalAudioMetadata(call, result)
            "readAudioQuality" -> readAudioQuality(call, result)
            "readAudioWaveform" -> readAudioWaveform(call, result)
            "getArtwork" -> loadArtwork(call, result)
            "openYtMusicLogin" -> openYtMusicLogin(result)
            "saveToDeviceMusic" -> saveToDeviceMusic(call, result)
            "convertToLosslessFlac" -> convertToLosslessFlac(call, result)
            "getAppVersion" -> getAppVersion(result)
            "installUpdateApk" -> installUpdateApk(call, result)
            "openUrl" -> openUrl(call, result)
            "getDeviceName" -> getDeviceName(result)
            else -> result.notImplemented()
        }
    }

    private fun getAppVersion(result: MethodChannel.Result) {
        try {
            val pkgInfo = packageManager.getPackageInfo(packageName, 0)
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.versionCode
            }
            result.success(
                mapOf(
                    "versionName" to (pkgInfo.versionName ?: "1.0.0"),
                    "versionCode" to versionCode,
                    "packageName" to packageName,
                ),
            )
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "versionName" to "1.0.0",
                    "versionCode" to 1,
                    "packageName" to packageName,
                ),
            )
        }
    }

    private fun getDeviceName(result: MethodChannel.Result) {
        try {
            val model = android.os.Build.MODEL ?: "Phone"
            val manufacturer = android.os.Build.MANUFACTURER ?: ""
            val name = if (model.startsWith(manufacturer, ignoreCase = true)) {
                model
            } else {
                "$manufacturer $model".trim()
            }
            result.success(name.ifEmpty { "Phone" })
        } catch (_: Exception) {
            result.success("Osman's Phone")
        }
    }

    private fun installUpdateApk(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val apkPath = call.argument<String>("apkPath")?.trim()
        if (apkPath.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "apkPath is required.", null)
            return
        }
        try {
            val apkFile = File(apkPath)
            if (!apkFile.exists() || apkFile.length() == 0L) {
                result.error("FILE_MISSING", "Downloaded APK file was not found.", null)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !packageManager.canRequestPackageInstalls()
            ) {
                val permIntent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(permIntent)
                result.success("PERMISSION_REQUIRED")
                return
            }

            val apkUri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                apkFile,
            )
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(installIntent)
            result.success("INSTALLER_LAUNCHED")
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message ?: "Failed to launch APK installer.", null)
        }
    }

    private fun openUrl(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val url = call.argument<String>("url")?.trim()
        if (url.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "url is required.", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message ?: "Could not open URL.", null)
        }
    }

    private fun saveToDeviceMusic(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val sourcePath = call.argument<String>("sourcePath")?.trim()
        val fileName = call.argument<String>("fileName")?.trim()
        val title = call.argument<String>("title")?.trim() ?: "Unknown title"
        val artist = call.argument<String>("artist")?.trim() ?: "Unknown artist"
        val album = call.argument<String>("album")?.trim() ?: "Single"
        val durationMs = call.argument<Number>("durationMs")?.toLong()

        if (sourcePath.isNullOrEmpty() || fileName.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "sourcePath and fileName are required.", null)
            return
        }

        ioExecutor.execute {
            try {
                val sourceFile = File(sourcePath)
                if (!sourceFile.exists() || sourceFile.length() == 0L) {
                    mainHandler.post {
                        result.error("SOURCE_MISSING", "Source audio file does not exist.", null)
                    }
                    return@execute
                }

                val ext = fileName.substringAfterLast('.', "m4a").lowercase()
                val mimeType = when (ext) {
                    "m4a", "mp4", "aac" -> "audio/mp4"
                    "flac" -> "audio/flac"
                    "mp3" -> "audio/mpeg"
                    "ogg", "opus" -> "audio/ogg"
                    "wav" -> "audio/wav"
                    "webm" -> "audio/webm"
                    else -> "audio/mp4"
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val collection = MediaStore.Audio.Media.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY,
                    )
                    // Remove any existing duplicate with the same display name in Music/Tone
                    try {
                        contentResolver.delete(
                            collection,
                            "${MediaStore.Audio.Media.DISPLAY_NAME} = ? AND ${MediaStore.Audio.Media.RELATIVE_PATH} LIKE ?",
                            arrayOf(fileName, "Music/Tone%"),
                        )
                    } catch (_: Exception) {}

                    val values = android.content.ContentValues().apply {
                        put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
                        put(MediaStore.Audio.Media.TITLE, title)
                        put(MediaStore.Audio.Media.ARTIST, artist)
                        put(MediaStore.Audio.Media.ALBUM, album)
                        put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                        put(MediaStore.Audio.Media.RELATIVE_PATH, "Music/Tone")
                        put(MediaStore.Audio.Media.IS_MUSIC, 1)
                        put(MediaStore.Audio.Media.IS_PENDING, 1)
                        if (durationMs != null && durationMs > 0L) {
                            put(MediaStore.Audio.Media.DURATION, durationMs)
                        }
                    }

                    val itemUri = contentResolver.insert(collection, values)
                        ?: throw IllegalStateException("Could not create MediaStore entry in Music/Tone.")

                    contentResolver.openOutputStream(itemUri)?.use { out ->
                        sourceFile.inputStream().use { input ->
                            input.copyTo(out, bufferSize = 64 * 1024)
                        }
                    } ?: throw IllegalStateException("Could not open MediaStore output stream.")

                    val completeValues = android.content.ContentValues().apply {
                        put(MediaStore.Audio.Media.IS_PENDING, 0)
                    }
                    contentResolver.update(itemUri, completeValues, null, null)

                    var publicPath: String? = null
                    contentResolver.query(
                        itemUri,
                        arrayOf(MediaStore.Audio.Media.DATA),
                        null,
                        null,
                        null,
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            publicPath = cursor.getString(0)
                        }
                    }

                    mainHandler.post {
                        result.success(
                            mapOf(
                                "uri" to itemUri.toString(),
                                "path" to (publicPath ?: itemUri.toString()),
                            ),
                        )
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val musicDir = File(
                        android.os.Environment.getExternalStoragePublicDirectory(
                            android.os.Environment.DIRECTORY_MUSIC,
                        ),
                        "Tone",
                    )
                    if (!musicDir.exists()) musicDir.mkdirs()
                    val destFile = File(musicDir, fileName)
                    sourceFile.copyTo(destFile, overwrite = true)
                    android.media.MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(destFile.absolutePath),
                        arrayOf(mimeType),
                        null,
                    )
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "uri" to Uri.fromFile(destFile).toString(),
                                "path" to destFile.absolutePath,
                            ),
                        )
                    }
                }
            } catch (error: Exception) {
                Log.e("TonePlayer", "Failed to save track to Music/Tone", error)
                mainHandler.post {
                    result.error("SAVE_FAILED", error.message, null)
                }
            }
        }
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        artworkExecutor.shutdown()
        waveformExecutor.shutdown()
        super.onDestroy()
    }

    private fun isNonSongAudioName(name: String): Boolean {
        val lower = name.trim().lowercase()
        return lower.startsWith("ptt-") ||
            lower.startsWith("aud-") ||
            lower.startsWith("call_recording") ||
            lower.startsWith("voice_") ||
            lower.contains("whatsapp voice") ||
            lower.contains("whatsapp audio")
    }

    private fun pickMusicFolder(result: MethodChannel.Result) {
        if (pendingFolderResult != null) {
            result.error("FOLDER_PICKER_BUSY", "A folder picker is already open.", null)
            return
        }
        pendingFolderResult = result
        try {
            startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                    )
                },
                PICK_MUSIC_FOLDER_REQUEST,
            )
        } catch (error: Exception) {
            pendingFolderResult = null
            result.error("FOLDER_PICKER_FAILED", error.message, null)
        }
    }

    private fun openYtMusicLogin(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                val dialog = android.app.Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen)
                val layout = android.widget.LinearLayout(this).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    layoutParams = android.view.ViewGroup.LayoutParams(
                        android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                        android.view.ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    setBackgroundColor(0xFF121212.toInt())
                }

                // Top bar
                val topBar = android.widget.LinearLayout(this).apply {
                    orientation = android.widget.LinearLayout.HORIZONTAL
                    setPadding(36, 54, 36, 24)
                    setBackgroundColor(0xFF1E1E1E.toInt())
                }
                val titleView = android.widget.TextView(this).apply {
                    text = "Sign in to YouTube Music"
                    setTextColor(0xFFFFFFFF.toInt())
                    textSize = 17f
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    layoutParams = android.widget.LinearLayout.LayoutParams(
                        0,
                        android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                        1f
                    )
                }
                val closeButton = android.widget.Button(this).apply {
                    text = "Close"
                    setTextColor(0xFFFF3B30.toInt())
                    setBackgroundColor(0x00000000)
                    textSize = 15f
                    setOnClickListener {
                        dialog.dismiss()
                        result.success(null)
                    }
                }
                topBar.addView(titleView)
                topBar.addView(closeButton)
                layout.addView(topBar)

                val webView = android.webkit.WebView(this).apply {
                    layoutParams = android.widget.LinearLayout.LayoutParams(
                        android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                        0,
                        1f
                    )
                }
                val webSettings = webView.settings
                webSettings.javaScriptEnabled = true
                webSettings.domStorageEnabled = true
                webSettings.databaseEnabled = true
                webSettings.userAgentString =
                    "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"

                val cookieManager = android.webkit.CookieManager.getInstance()
                cookieManager.setAcceptCookie(true)
                cookieManager.setAcceptThirdPartyCookies(webView, true)

                var loginCompleted = false

                webView.webViewClient = object : android.webkit.WebViewClient() {
                    override fun onPageFinished(view: android.webkit.WebView?, url: String?) {
                        super.onPageFinished(view, url)
                        if (url != null && (url.contains("music.youtube.com") || url.contains("youtube.com")) && !loginCompleted) {
                            val cookies = cookieManager.getCookie("https://music.youtube.com")
                                ?: cookieManager.getCookie("https://youtube.com")
                            if (cookies != null && (cookies.contains("SAPISID") || cookies.contains("__Secure-3PAPISID") || cookies.contains("SID") || cookies.contains("LOGIN_INFO"))) {
                                loginCompleted = true
                                mainHandler.postDelayed({
                                    try {
                                        dialog.dismiss()
                                        result.success(cookies)
                                    } catch (_: Exception) {}
                                }, 600)
                            }
                        }
                    }
                }

                layout.addView(webView)
                dialog.setContentView(layout)
                dialog.show()

                webView.loadUrl("https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fmusic.youtube.com%2F")
            } catch (e: Exception) {
                Log.e("TonePlayer", "Error opening YouTube login webview", e)
                result.error("LOGIN_ERROR", e.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Android; used for the document-tree result.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DELETE_DEVICE_AUDIO_REQUEST) {
            finishDeviceAudioDeletion(resultCode)
            return
        }
        if (requestCode != PICK_MUSIC_FOLDER_REQUEST) return
        val result = pendingFolderResult ?: return
        pendingFolderResult = null
        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val treeUri = data.data!!
        try {
            val grantedFlags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            contentResolver.takePersistableUriPermission(treeUri, grantedFlags)
            val documentId = DocumentsContract.getTreeDocumentId(treeUri)
            val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
            val name = contentResolver.query(
                documentUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)
                } else {
                    null
                }
            } ?: "Music folder"
            result.success(mapOf("uri" to treeUri.toString(), "name" to name))
        } catch (error: Exception) {
            result.error("FOLDER_ACCESS_FAILED", error.message, null)
        }
    }

    private fun deleteDeviceAudio(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val uri = call.argument<String>("uri")?.let(Uri::parse)
        if (uri == null || uri.scheme != "content") {
            result.error("INVALID_AUDIO_DELETE_REQUEST", "A content URI is required.", null)
            return
        }
        if (pendingDeleteResult != null) {
            result.error("AUDIO_DELETE_BUSY", "A song deletion is already awaiting confirmation.", null)
            return
        }

        try {
            if (DocumentsContract.isDocumentUri(this, uri)) {
                if (!DocumentsContract.deleteDocument(contentResolver, uri)) {
                    result.error("AUDIO_DELETE_FAILED", "The document provider did not delete the song.", null)
                } else {
                    result.success(true)
                }
                return
            }
            if (uri.authority != "media") {
                result.error("UNSUPPORTED_AUDIO_DELETE", "This music source cannot be deleted by Tone.", null)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val request = MediaStore.createDeleteRequest(contentResolver, listOf(uri))
                launchDeleteConfirmation(
                    uri = uri,
                    result = result,
                    intentSender = request.intentSender,
                    retryDelete = false,
                )
            } else {
                try {
                    if (contentResolver.delete(uri, null, null) <= 0) {
                        result.error("AUDIO_DELETE_FAILED", "The song could not be found or deleted.", null)
                    } else {
                        result.success(true)
                    }
                } catch (error: RecoverableSecurityException) {
                    launchDeleteConfirmation(
                        uri = uri,
                        result = result,
                        intentSender = error.userAction.actionIntent.intentSender,
                        retryDelete = true,
                    )
                }
            }
        } catch (error: Exception) {
            result.error(
                "AUDIO_DELETE_FAILED",
                error.message ?: "Android could not delete this song.",
                null,
            )
        }
    }

    private fun deleteDeviceAudioBatch(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val uriValues = call.argument<List<String>>("uris")
        val uris = uriValues?.map(Uri::parse)
        if (uris.isNullOrEmpty() || uris.any {
                it.scheme != "content" ||
                    it.authority != "media" ||
                    DocumentsContract.isDocumentUri(this, it)
            }
        ) {
            result.error(
                "INVALID_AUDIO_DELETE_REQUEST",
                "A non-empty list of MediaStore audio URIs is required.",
                null,
            )
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error(
                "BULK_DELETE_UNSUPPORTED",
                "Batch deletion requires Android 11 or later.",
                null,
            )
            return
        }
        if (pendingDeleteResult != null) {
            result.error(
                "AUDIO_DELETE_BUSY",
                "A song deletion is already awaiting confirmation.",
                null,
            )
            return
        }

        try {
            val request = MediaStore.createDeleteRequest(contentResolver, uris)
            pendingDeleteResult = result
            pendingDeleteUri = null
            retryDeleteAfterConfirmation = false
            startIntentSenderForResult(
                request.intentSender,
                DELETE_DEVICE_AUDIO_REQUEST,
                null,
                0,
                0,
                0,
            )
        } catch (error: Exception) {
            pendingDeleteResult = null
            pendingDeleteUri = null
            retryDeleteAfterConfirmation = false
            result.error(
                "AUDIO_DELETE_CONFIRMATION_FAILED",
                error.message ?: "Android could not show its delete confirmation.",
                null,
            )
        }
    }

    private fun launchDeleteConfirmation(
        uri: Uri,
        result: MethodChannel.Result,
        intentSender: IntentSender,
        retryDelete: Boolean,
    ) {
        pendingDeleteResult = result
        pendingDeleteUri = uri
        retryDeleteAfterConfirmation = retryDelete
        try {
            startIntentSenderForResult(
                intentSender,
                DELETE_DEVICE_AUDIO_REQUEST,
                null,
                0,
                0,
                0,
            )
        } catch (error: Exception) {
            pendingDeleteResult = null
            pendingDeleteUri = null
            retryDeleteAfterConfirmation = false
            result.error(
                "AUDIO_DELETE_CONFIRMATION_FAILED",
                error.message ?: "Android could not show its delete confirmation.",
                null,
            )
        }
    }

    private fun finishDeviceAudioDeletion(resultCode: Int) {
        val result = pendingDeleteResult ?: return
        val uri = pendingDeleteUri
        val retryDelete = retryDeleteAfterConfirmation
        pendingDeleteResult = null
        pendingDeleteUri = null
        retryDeleteAfterConfirmation = false

        if (resultCode != RESULT_OK) {
            result.success(false)
            return
        }
        if (!retryDelete) {
            result.success(true)
            return
        }
        try {
            if (uri == null || contentResolver.delete(uri, null, null) <= 0) {
                result.error("AUDIO_DELETE_FAILED", "Android approved access, but the song was not deleted.", null)
            } else {
                result.success(true)
            }
        } catch (error: Exception) {
            result.error(
                "AUDIO_DELETE_FAILED",
                error.message ?: "Android could not delete this song.",
                null,
            )
        }
    }

    private fun scanMusicFolder(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val uriValue = call.argument<String>("uri")
        val treeUri = uriValue?.let(Uri::parse)
        if (treeUri == null || treeUri.scheme != "content") {
            result.error("INVALID_FOLDER_URI", "A valid folder URI is required.", null)
            return
        }
        ioExecutor.execute {
            try {
                val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
                val pendingIds = ArrayDeque<String>()
                val visited = mutableSetOf<String>()
                val audioDocuments = mutableListOf<Map<String, Any?>>()
                val lyricDocuments = mutableMapOf<String, String>()
                val coverArtDocuments = mutableMapOf<String, String>()
                pendingIds.add(rootDocumentId)
                while (pendingIds.isNotEmpty()) {
                    val parentId = pendingIds.removeLast()
                    if (!visited.add(parentId)) continue
                    val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                        treeUri,
                        parentId,
                    )
                    contentResolver.query(
                        childrenUri,
                        arrayOf(
                            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                            DocumentsContract.Document.COLUMN_MIME_TYPE,
                            DocumentsContract.Document.COLUMN_SIZE,
                            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                        ),
                        null,
                        null,
                        null,
                    )?.use { cursor ->
                        val idColumn = cursor.getColumnIndexOrThrow(
                            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        )
                        val nameColumn = cursor.getColumnIndexOrThrow(
                            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                        )
                        val mimeColumn = cursor.getColumnIndexOrThrow(
                            DocumentsContract.Document.COLUMN_MIME_TYPE,
                        )
                        val sizeColumn = cursor.getColumnIndex(
                            DocumentsContract.Document.COLUMN_SIZE,
                        )
                        val modifiedColumn = cursor.getColumnIndex(
                            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                        )
                        while (cursor.moveToNext()) {
                            val documentId = cursor.getString(idColumn)
                            val name = cursor.getString(nameColumn) ?: continue
                            val mimeType = cursor.getString(mimeColumn)
                            if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                                pendingIds.add(documentId)
                                continue
                            }
                            val extension = name.substringAfterLast('.', "").lowercase()
                            val baseName = name.substringBeforeLast('.', name).lowercase()
                            val documentKey = "$parentId/$baseName"
                            if (extension == "lrc" || extension == "txt") {
                                val previous = lyricDocuments[documentKey]
                                if (previous == null || extension == "lrc") {
                                    lyricDocuments[documentKey] = documentId
                                }
                                continue
                            }
                            if (
                                extension in setOf("jpg", "jpeg", "png", "webp") &&
                                baseName in setOf(
                                    "cover",
                                    "folder",
                                    "front",
                                    "albumart",
                                    "artwork",
                                )
                            ) {
                                if (
                                    coverArtDocuments[parentId] == null ||
                                    baseName == "cover"
                                ) {
                                    coverArtDocuments[parentId] = documentId
                                }
                                continue
                            }
                            if (extension !in audioExtensions) continue
                            if (isNonSongAudioName(name)) continue
                            audioDocuments.add(
                                mapOf(
                                    "documentId" to documentId,
                                    "name" to name,
                                    "parentId" to parentId,
                                    "baseName" to baseName,
                                    "sizeBytes" to if (
                                        sizeColumn >= 0 &&
                                        !cursor.isNull(sizeColumn)
                                    ) {
                                        cursor.getLong(sizeColumn)
                                    } else {
                                        null
                                    },
                                    "dateModifiedSeconds" to if (
                                        modifiedColumn >= 0 &&
                                        !cursor.isNull(modifiedColumn)
                                    ) {
                                        cursor.getLong(modifiedColumn) / 1000
                                    } else {
                                        null
                                    },
                                ),
                            )
                        }
                    } ?: throw IllegalStateException("Android could not read this folder.")
                }
                val audio = audioDocuments.mapNotNull { document ->
                    val documentId = document.getValue("documentId") as String
                    val name = document.getValue("name") as String
                    val parentId = document.getValue("parentId") as String
                    val baseName = document.getValue("baseName") as String
                    val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        documentId,
                    )
                    val key = "$parentId/$baseName"
                    val metadata = try {
                        readAudioMetadata(
                            documentUri,
                            name.substringBeforeLast('.', name),
                            "Unknown album",
                        )
                    } catch (error: Exception) {
                        Log.w("ToneLibrary", "Could not read tags for $name", error)
                        emptyMap()
                    }
                    val durationMs = (metadata["durationMs"] as? Number)?.toLong()
                    if (durationMs != null && durationMs > 0L && durationMs < 30_000L) {
                        return@mapNotNull null
                    }
                    val lyricDocumentId = lyricDocuments[key]
                    mapOf(
                        "uri" to documentUri.toString(),
                        "name" to name,
                        "title" to (metadata["title"] as? String
                            ?: name.substringBeforeLast('.', name)),
                        "artist" to (metadata["artist"] as? String ?: "Unknown artist"),
                        "album" to (metadata["album"] as? String ?: "Unknown album"),
                        "durationMs" to metadata["durationMs"],
                        "artworkUri" to (
                            metadata["artworkUri"] as? String
                                ?: coverArtDocuments[document.getValue("parentId")]?.let {
                                    DocumentsContract.buildDocumentUriUsingTree(treeUri, it).toString()
                                }
                            ),
                        "year" to metadata["year"],
                        "trackNumber" to metadata["trackNumber"],
                        "sizeBytes" to document["sizeBytes"],
                        "dateModifiedSeconds" to document["dateModifiedSeconds"],
                        "sourceFolderUri" to treeUri.toString(),
                        "lyricsUri" to lyricDocumentId?.let {
                            DocumentsContract.buildDocumentUriUsingTree(treeUri, it).toString()
                        },
                    )
                }
                mainHandler.post { result.success(audio) }
            } catch (error: SecurityException) {
                mainHandler.post {
                    result.error("FOLDER_ACCESS_REVOKED", error.message, null)
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("FOLDER_SCAN_FAILED", error.message, null)
                }
            }
        }
    }

    private fun readAudioMetadata(
        uri: Uri,
        fallbackTitle: String,
        fallbackAlbum: String,
    ): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            setAudioDataSource(retriever, uri)
            val artworkUri = if (retriever.embeddedPicture != null) uri.toString() else null
            return mapOf(
                "title" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                    ?.takeIf { it.isNotBlank() }?.trim().orEmpty().ifEmpty { fallbackTitle },
                "artist" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    ?.takeIf { it.isNotBlank() }?.trim().orEmpty().ifEmpty { "Unknown artist" },
                "album" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                    ?.takeIf { it.isNotBlank() }?.trim().orEmpty().ifEmpty { fallbackAlbum },
                "durationMs" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION,
                )?.toLongOrNull(),
                "year" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_YEAR,
                )?.toIntOrNull(),
                "trackNumber" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER,
                )?.substringBefore('/')?.toIntOrNull(),
                "discNumber" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DISC_NUMBER,
                )?.substringBefore('/')?.toIntOrNull(),
                "trackCount" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_NUM_TRACKS,
                )?.toIntOrNull(),
                "albumArtist" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST,
                )?.trim()?.takeIf { it.isNotEmpty() },
                "composer" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_COMPOSER,
                )?.trim()?.takeIf { it.isNotEmpty() },
                "writer" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_WRITER,
                )?.trim()?.takeIf { it.isNotEmpty() },
                "compilation" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_COMPILATION,
                )?.trim()?.takeIf { it.isNotEmpty() },
                "genre" to retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_GENRE,
                )?.trim()?.takeIf { it.isNotEmpty() },
                "bpm" to readId3Bpm(uri),
                "artworkUri" to artworkUri,
            )
        } finally {
            retriever.release()
        }
    }

    private fun readId3Bpm(uri: Uri): Double? {
        val input = if (uri.scheme == "file") {
            File(uri.path ?: return null).inputStream()
        } else {
            contentResolver.openInputStream(uri) ?: return null
        }
        return input.use { stream ->
            val header = ByteArray(10)
            if (!readFully(stream, header) || String(header, 0, 3) != "ID3") {
                return@use null
            }
            val version = header[3].toInt() and 0xff
            if (version !in 3..4) return@use null
            val declaredSize = ((header[6].toInt() and 0x7f) shl 21) or
                ((header[7].toInt() and 0x7f) shl 14) or
                ((header[8].toInt() and 0x7f) shl 7) or
                (header[9].toInt() and 0x7f)
            val tag = ByteArray(minOf(declaredSize, 64 * 1024))
            var bytesRead = 0
            while (bytesRead < tag.size) {
                val count = stream.read(tag, bytesRead, tag.size - bytesRead)
                if (count < 0) break
                bytesRead += count
            }
            var offset = 0
            while (offset + 10 <= bytesRead) {
                val frameId = String(tag, offset, 4, Charsets.ISO_8859_1)
                if (frameId.all { it == '\u0000' }) break
                val frameSize = if (version == 4) {
                    ((tag[offset + 4].toInt() and 0x7f) shl 21) or
                        ((tag[offset + 5].toInt() and 0x7f) shl 14) or
                        ((tag[offset + 6].toInt() and 0x7f) shl 7) or
                        (tag[offset + 7].toInt() and 0x7f)
                } else {
                    ((tag[offset + 4].toInt() and 0xff) shl 24) or
                        ((tag[offset + 5].toInt() and 0xff) shl 16) or
                        ((tag[offset + 6].toInt() and 0xff) shl 8) or
                        (tag[offset + 7].toInt() and 0xff)
                }
                val bodyStart = offset + 10
                if (frameSize <= 0 || frameSize > bytesRead - bodyStart) break
                if (frameId == "TBPM" && frameSize > 1) {
                    val encoding = tag[bodyStart].toInt() and 0xff
                    val charset = when (encoding) {
                        1 -> Charsets.UTF_16
                        2 -> Charsets.UTF_16BE
                        3 -> Charsets.UTF_8
                        else -> Charsets.ISO_8859_1
                    }
                    val text = String(
                        tag,
                        bodyStart + 1,
                        frameSize - 1,
                        charset,
                    )
                    val bpm = Regex("""\d{2,3}(?:[.,]\d+)?""")
                        .find(text)?.value
                        ?.replace(',', '.')
                        ?.toDoubleOrNull()
                    if (bpm != null && bpm in 30.0..300.0) return@use bpm
                }
                offset = bodyStart + frameSize
            }
            null
        }
    }

    private fun readFully(input: InputStream, buffer: ByteArray): Boolean {
        var offset = 0
        while (offset < buffer.size) {
            val count = input.read(buffer, offset, buffer.size - offset)
            if (count <= 0) return false
            offset += count
        }
        return true
    }

    private fun readLocalAudioMetadata(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val path = call.argument<String>("path")
        val fallbackTitle = call.argument<String>("fallbackTitle")
        if (path.isNullOrBlank() || fallbackTitle == null) {
            result.error(
                "INVALID_AUDIO_METADATA_REQUEST",
                "A local audio path and fallback title are required.",
                null,
            )
            return
        }
        if (path.startsWith("youtube:") || path.startsWith("spotify:")) {
            result.success(null)
            return
        }
        ioExecutor.execute {
            try {
                val parsedUri = Uri.parse(path)
                val uri = if (parsedUri.scheme == null) {
                    Uri.fromFile(File(path))
                } else {
                    parsedUri
                }
                if (uri.scheme == "file" && !File(uri.path ?: path).isFile) {
                    throw IllegalArgumentException("The imported audio file is unavailable.")
                }
                val metadata = readAudioMetadata(
                    uri,
                    fallbackTitle,
                    "Unknown album",
                )
                mainHandler.post { result.success(metadata) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("AUDIO_METADATA_READ_FAILED", error.message, null)
                }
            }
        }
    }

    private fun readAudioQuality(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val source = call.argument<String>("uri")
        if (source.isNullOrBlank()) {
            result.error("INVALID_AUDIO_QUALITY_REQUEST", "An audio URI is required.", null)
            return
        }
        if (source.startsWith("youtube:") || source.startsWith("spotify:")) {
            result.success(null)
            return
        }
        ioExecutor.execute {
            val extractor = MediaExtractor()
            try {
                setAudioDataSource(extractor, Uri.parse(source))
                val audioFormat = (0 until extractor.trackCount)
                    .asSequence()
                    .map(extractor::getTrackFormat)
                    .firstOrNull {
                        it.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
                    } ?: throw IllegalStateException("No audio stream was found.")
                val mime = audioFormat.getString(MediaFormat.KEY_MIME)
                    ?: throw IllegalStateException("The audio codec is unavailable.")
                val details = mutableMapOf<String, Any?>("mimeType" to mime)
                if (audioFormat.containsKey(MediaFormat.KEY_BIT_RATE)) {
                    details["bitRate"] = audioFormat.getInteger(MediaFormat.KEY_BIT_RATE)
                }
                if (audioFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                    details["sampleRate"] =
                        audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                }
                if (audioFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                    details["channelCount"] =
                        audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                }
                mainHandler.post { result.success(details) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("AUDIO_QUALITY_READ_FAILED", error.message, null)
                }
            } finally {
                extractor.release()
            }
        }
    }

    private fun readAudioWaveform(
            call: io.flutter.plugin.common.MethodCall,
            result: MethodChannel.Result,
        ) {
            val source = call.argument<String>("uri")
            val binCount = call.argument<Int>("binCount") ?: 256
            if (source.isNullOrBlank()) {
                result.error("INVALID_WAVEFORM_REQUEST", "An audio URI is required.", null)
                return
            }
            if (binCount !in 64..512) {
                result.error(
                    "INVALID_WAVEFORM_REQUEST",
                    "Waveform resolution must be between 64 and 512 samples.",
                    null,
                )
                return
            }
            waveformExecutor.execute {
                try {
                    val cacheKey = "$source:$binCount"
                    val cached = synchronized(waveformCache) {
                        waveformCache[cacheKey]
                    }
                    val waveform = cached ?: decodeAudioWaveform(source, binCount).also {
                        synchronized(waveformCache) {
                            waveformCache[cacheKey] = it
                            while (waveformCache.size > 24) {
                                val oldest = waveformCache.keys.firstOrNull() ?: break
                                waveformCache.remove(oldest)
                            }
                        }
                    }
                    mainHandler.post { result.success(waveform) }
                } catch (error: Exception) {
                    mainHandler.post {
                        result.error(
                            "AUDIO_WAVEFORM_READ_FAILED",
                            error.message ?: "The audio waveform could not be decoded.",
                            null,
                        )
                    }
                }
            }
        }

        private fun decodeAudioWaveform(source: String, binCount: Int): List<Double> {
            val extractor = MediaExtractor()
            var decoder: MediaCodec? = null
            try {
                setAudioDataSource(extractor, Uri.parse(source))
                val audioTrackIndex = (0 until extractor.trackCount)
                    .firstOrNull {
                        extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                            ?.startsWith("audio/") == true
                    } ?: throw IllegalStateException("No audio stream was found.")
                val inputFormat = extractor.getTrackFormat(audioTrackIndex)
                val mime = inputFormat.getString(MediaFormat.KEY_MIME)
                    ?: throw IllegalStateException("The audio codec is unavailable.")
                var durationUs = if (inputFormat.containsKey(MediaFormat.KEY_DURATION)) {
                    inputFormat.getLong(MediaFormat.KEY_DURATION)
                } else {
                    0L
                }
                if (durationUs <= 0) {
                    val retriever = MediaMetadataRetriever()
                    try {
                        setAudioDataSource(retriever, Uri.parse(source))
                        durationUs = retriever
                            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                            ?.toLongOrNull()
                            ?.times(1000)
                            ?: 0L
                    } finally {
                        retriever.release()
                    }
                }
                if (durationUs <= 0) {
                    throw IllegalStateException("The audio duration is unavailable.")
                }

                extractor.selectTrack(audioTrackIndex)
                decoder = MediaCodec.createDecoderByType(mime)
                decoder.configure(inputFormat, null, null, 0)
                decoder.start()

                val peaks = FloatArray(binCount)
                val bufferInfo = MediaCodec.BufferInfo()
                var inputEnded = false
                var outputEnded = false
                var outputFormat = inputFormat
                var stalledIterations = 0
                while (!outputEnded) {
                    var progressed = false
                    if (!inputEnded) {
                        val inputIndex = decoder.dequeueInputBuffer(10_000)
                        if (inputIndex >= 0) {
                            val inputBuffer = decoder.getInputBuffer(inputIndex)
                                ?: throw IllegalStateException("Decoder input is unavailable.")
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                decoder.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    0,
                                    0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputEnded = true
                            } else {
                                decoder.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    sampleSize,
                                    extractor.sampleTime,
                                    extractor.sampleFlags,
                                )
                                extractor.advance()
                            }
                            progressed = true
                        }
                    }

                    when (val outputIndex = decoder.dequeueOutputBuffer(bufferInfo, 10_000)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            outputFormat = decoder.outputFormat
                            progressed = true
                        }
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        else -> if (outputIndex >= 0) {
                            val outputBuffer = decoder.getOutputBuffer(outputIndex)
                            if (outputBuffer != null && bufferInfo.size > 0) {
                                collectWaveformPeaks(
                                    outputBuffer,
                                    bufferInfo,
                                    outputFormat,
                                    durationUs,
                                    peaks,
                                )
                            }
                            outputEnded =
                                bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            decoder.releaseOutputBuffer(outputIndex, false)
                            progressed = true
                        }
                    }
                    stalledIterations = if (progressed) 0 else stalledIterations + 1
                    if (stalledIterations > 300) {
                        throw IllegalStateException("Audio decoding stopped before the waveform was complete.")
                    }
                }

                val maximum = peaks.maxOrNull() ?: 0f
                return peaks.map { peak ->
                    if (maximum <= 0f) 0.0 else (peak / maximum).toDouble()
                }
            } finally {
                try {
                    decoder?.stop()
                } catch (_: IllegalStateException) {
                    // Decoder may not have reached the started state.
                }
                decoder?.release()
                extractor.release()
            }
        }

        private fun collectWaveformPeaks(
            buffer: java.nio.ByteBuffer,
            info: MediaCodec.BufferInfo,
            format: MediaFormat,
            durationUs: Long,
            peaks: FloatArray,
        ) {
            val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE).coerceAtLeast(1)
            val encoding = if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                format.containsKey(MediaFormat.KEY_PCM_ENCODING)
            ) {
                format.getInteger(MediaFormat.KEY_PCM_ENCODING)
            } else {
                AudioFormat.ENCODING_PCM_16BIT
            }
            val samplesPerFrame = when (encoding) {
                AudioFormat.ENCODING_PCM_FLOAT -> 4
                AudioFormat.ENCODING_PCM_8BIT -> 1
                else -> 2
            }
            val frameSize = channels * samplesPerFrame
            val start = info.offset
            val end = (info.offset + info.size).coerceAtMost(buffer.capacity())
            val pcm = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
            pcm.position(start)
            pcm.limit(end)
            val frameCount = (end - start) / frameSize
            for (frame in 0 until frameCount) {
                var framePeak = 0f
                repeat(channels) {
                    val magnitude = when (encoding) {
                        AudioFormat.ENCODING_PCM_FLOAT -> abs(pcm.float).coerceIn(0f, 1f)
                        AudioFormat.ENCODING_PCM_8BIT ->
                            abs((pcm.get().toInt() and 0xff) - 128) / 128f
                        else -> abs(pcm.short.toInt()) / 32768f
                    }
                    framePeak = max(framePeak, magnitude)
                }
                val timestampUs =
                    info.presentationTimeUs + frame.toLong() * 1_000_000L / sampleRate
                val bin = ((timestampUs.coerceAtLeast(0) * peaks.size) / durationUs)
                    .toInt()
                    .coerceIn(0, peaks.lastIndex)
                peaks[bin] = max(peaks[bin], framePeak)
            }
        }
    private fun readLyrics(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val uri = call.argument<String>("uri")?.let(Uri::parse)
        if (uri == null || uri.scheme != "content") {
            result.error("INVALID_LYRICS_URI", "A valid lyrics URI is required.", null)
            return
        }
        ioExecutor.execute {
            try {
                val lyrics = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)
                    ?.use { it.readText() }
                    ?: throw IllegalStateException("The selected lyrics file is unavailable.")
                mainHandler.post { result.success(lyrics) }
            } catch (error: SecurityException) {
                mainHandler.post {
                    result.error("LYRICS_ACCESS_REVOKED", error.message, null)
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("LYRICS_READ_FAILED", error.message, null)
                }
            }
        }
    }

    private fun releaseMusicFolder(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val uriValue = call.argument<String>("uri")
        val uri = uriValue?.let(Uri::parse)
        if (uri == null || uri.scheme != "content") {
            result.error("INVALID_FOLDER_URI", "A valid folder URI is required.", null)
            return
        }
        try {
            contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            result.success(null)
        } catch (error: Exception) {
            result.error("FOLDER_RELEASE_FAILED", error.message, null)
        }
    }

    private fun scanAudio(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val offset = (call.argument<Int>("offset") ?: 0).coerceAtLeast(0)
        val limit = (call.argument<Int>("limit") ?: 250).coerceIn(1, 500)
        val modifiedAfterSeconds = call.argument<Long>("modifiedAfterSeconds")
        ioExecutor.execute {
            try {
                val genresByAudioId = if (offset == 0 || audioGenreCache == null) {
                    readAudioGenres().also { audioGenreCache = it }
                } else {
                    audioGenreCache.orEmpty()
                }
                val collection =
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                    } else {
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                    }
                val projection = arrayOf(
                    MediaStore.Audio.Media._ID,
                    MediaStore.Audio.Media.TITLE,
                    MediaStore.Audio.Media.ARTIST,
                    MediaStore.Audio.Media.ALBUM,
                    MediaStore.Audio.Media.ALBUM_ID,
                    MediaStore.Audio.Media.DISPLAY_NAME,
                    MediaStore.Audio.Media.DURATION,
                    MediaStore.Audio.Media.YEAR,
                    MediaStore.Audio.Media.TRACK,
                    MediaStore.Audio.Media.DATE_MODIFIED,
                    MediaStore.Audio.Media.SIZE,
                )
                val audio = mutableListOf<Map<String, Any?>>()
                val sortOrder =
                    "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC, " +
                        "${MediaStore.Audio.Media._ID} ASC"
                val baseFilter =
                    "(${MediaStore.Audio.Media.IS_MUSIC} != 0) AND " +
                        "${MediaStore.Audio.Media.IS_RINGTONE} = 0 AND " +
                        "${MediaStore.Audio.Media.IS_ALARM} = 0 AND " +
                        "${MediaStore.Audio.Media.IS_NOTIFICATION} = 0 AND " +
                        "${MediaStore.Audio.Media.DURATION} >= 30000"
                val selection = if (modifiedAfterSeconds == null) {
                    baseFilter
                } else {
                    "$baseFilter AND ${MediaStore.Audio.Media.DATE_MODIFIED} >= ?"
                }
                val cursor = contentResolver.query(
                    collection,
                    projection,
                    selection,
                    modifiedAfterSeconds?.let { arrayOf(it.toString()) },
                    sortOrder,
                )
                cursor?.use { audioCursor ->
                    if (offset > 0) {
                        if (!audioCursor.moveToPosition(offset - 1)) {
                            mainHandler.post { result.success(emptyList<Map<String, Any?>>()) }
                            return@execute
                        }
                    }
                    val idColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                    val titleColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                    val artistColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                    val albumColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                    val albumIdColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                    val nameColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                    val durationColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                    val yearColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
                    val trackColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
                    val dateModifiedColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                    val sizeColumn =
                        audioCursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                    var pageCount = 0
                    while (pageCount < limit && audioCursor.moveToNext()) {
                        pageCount++
                        val id = audioCursor.getLong(idColumn)
                        val name = audioCursor.getString(nameColumn) ?: continue
                        if (isNonSongAudioName(name)) continue
                        val durationMs = audioCursor.getLong(durationColumn)
                        if (durationMs in 1..29999) continue
                        val title = audioCursor.getString(titleColumn)
                            ?.takeIf { it.isNotBlank() && it != "<unknown>" }
                            ?: name.substringBeforeLast('.', name)
                        val artist = audioCursor.getString(artistColumn)
                            ?.takeIf { it.isNotBlank() && it != "<unknown>" }
                            ?: "Unknown artist"
                        val album = audioCursor.getString(albumColumn)
                            ?.takeIf { it.isNotBlank() && it != "<unknown>" }
                            ?: "Unknown album"
                        val albumId = audioCursor.getLong(albumIdColumn)
                        val year = audioCursor.getInt(yearColumn).takeIf { it > 0 }
                        val trackNumber = audioCursor.getInt(trackColumn)
                            .rem(1000)
                            .takeIf { it > 0 }
                        val mediaUri = ContentUris.withAppendedId(collection, id)
                        // Only fall back to MediaMetadataRetriever if durationMs is missing, so scanning 500+ songs finishes in < 100ms
                        val fallbackMetadata = if (durationMs <= 0) {
                            try {
                                readAudioMetadata(mediaUri, title, album)
                            } catch (error: Exception) {
                                Log.w("ToneLibrary", "Could not read tags for $name", error)
                                emptyMap()
                            }
                        } else {
                            emptyMap()
                        }
                        val resolvedDurationMs = if (durationMs > 0) {
                            durationMs
                        } else {
                            (fallbackMetadata["durationMs"] as? Number)?.toLong()
                        }
                        if (resolvedDurationMs != null && resolvedDurationMs < 30_000L) continue
                        val embeddedArtworkUri =
                            fallbackMetadata["artworkUri"] as? String
                        audio.add(
                            mapOf(
                                "uri" to mediaUri.toString(),
                                "name" to name,
                                "title" to if (title == name.substringBeforeLast('.', name)) {
                                    fallbackMetadata["title"] as? String ?: title
                                } else {
                                    title
                                },
                                "artist" to if (artist == "Unknown artist") {
                                    fallbackMetadata["artist"] as? String ?: artist
                                } else {
                                    artist
                                },
                                "album" to if (album == "Unknown album") {
                                    fallbackMetadata["album"] as? String ?: album
                                } else {
                                    album
                                },
                                "durationMs" to resolvedDurationMs,
                                "artworkUri" to if (albumId > 0) {
                                    "content://media/external/audio/albumart/$albumId"
                                } else {
                                    embeddedArtworkUri ?: mediaUri.toString()
                                },
                                "year" to (year ?: fallbackMetadata["year"]),
                                "trackNumber" to (
                                    trackNumber ?: fallbackMetadata["trackNumber"]
                                ),
                                "genre" to (
                                    genresByAudioId[id]
                                        ?: fallbackMetadata["genre"] as? String
                                    ),
                                "bpm" to fallbackMetadata["bpm"],
                                "dateModifiedSeconds" to audioCursor.getLong(dateModifiedColumn),
                                "sizeBytes" to audioCursor.getLong(sizeColumn),
                            ),
                        )
                    }
                } ?: throw IllegalStateException("Android could not query device audio.")
                mainHandler.post { result.success(audio) }
            } catch (error: SecurityException) {
                mainHandler.post {
                    result.error("AUDIO_PERMISSION_DENIED", error.message, null)
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("AUDIO_SCAN_FAILED", error.message, null)
                }
            }
        }
    }

    private fun readAudioGenres(): Map<Long, String> {
        val genresByAudioId = mutableMapOf<Long, String>()
        try {
            contentResolver.query(
                MediaStore.Audio.Genres.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Audio.Genres._ID, MediaStore.Audio.Genres.NAME),
                null,
                null,
                null,
            )?.use { genres ->
                val idColumn = genres.getColumnIndexOrThrow(MediaStore.Audio.Genres._ID)
                val nameColumn = genres.getColumnIndexOrThrow(MediaStore.Audio.Genres.NAME)
                while (genres.moveToNext()) {
                    val genreId = genres.getLong(idColumn)
                    val name = genres.getString(nameColumn)?.trim().orEmpty()
                    if (name.isEmpty()) continue
                    try {
                        val membersUri = MediaStore.Audio.Genres.Members.getContentUri(
                            "external",
                            genreId,
                        )
                        contentResolver.query(
                            membersUri,
                            arrayOf(MediaStore.Audio.Media._ID),
                            null,
                            null,
                            null,
                        )?.use { members ->
                            val memberIdColumn =
                                members.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                            while (members.moveToNext()) {
                                val mediaId = members.getLong(memberIdColumn)
                                if (mediaId !in genresByAudioId) {
                                    genresByAudioId[mediaId] = name
                                }
                            }
                        }
                    } catch (error: Exception) {
                        Log.w("ToneLibrary", "Could not read members for genre $name", error)
                    }
                }
            }
        } catch (error: Exception) {
            Log.w("ToneLibrary", "Could not read indexed audio genres", error)
        }
        return genresByAudioId
    }

    private fun loadArtwork(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val uriValue = call.argument<String>("uri")
        val sourceUriValue = call.argument<String>("sourceUri")
        val uri = uriValue?.let(Uri::parse)
        val sourceUri = sourceUriValue?.let(Uri::parse)
        if (uri == null && sourceUri == null) {
            result.error(
                "INVALID_ARTWORK_URI",
                "An artwork URI or local audio source is required.",
                null,
            )
            return
        }
        artworkExecutor.execute {
            try {
                val artworkBytes = uri?.let(::readArtworkUriBytes)
                    ?: sourceUri?.let(::readArtworkUriBytes)
                val bytes = artworkBytes
                    ?: throw IllegalStateException("No embedded album artwork was found.")
                mainHandler.post { result.success(bytes) }
            } catch (error: SecurityException) {
                mainHandler.post {
                    result.error("ARTWORK_ACCESS_DENIED", error.message, null)
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("ARTWORK_LOAD_FAILED", error.message, null)
                }
            }
        }
    }

    private fun readArtworkUriBytes(artworkUri: Uri): ByteArray? {
        val pathLower = (artworkUri.path ?: artworkUri.toString()).lowercase()
        val isImageExt = pathLower.endsWith(".jpg") ||
            pathLower.endsWith(".jpeg") ||
            pathLower.endsWith(".png") ||
            pathLower.endsWith(".webp")

        if (artworkUri.scheme == "file" || (artworkUri.scheme == null && isImageExt)) {
            val file = File(artworkUri.path ?: artworkUri.toString())
            if (file.isFile && file.length() > 0L) {
                if (isImageExt) {
                    return file.readBytes()
                }
            }
        }

        val isAlbumArtContent = artworkUri.path?.contains("/albumart/") == true ||
            (artworkUri.scheme == "content" &&
                contentResolver.getType(artworkUri)?.startsWith("image/") == true)
        if (isAlbumArtContent) {
            try {
                contentResolver.openInputStream(artworkUri)?.use { return it.readBytes() }
            } catch (_: Exception) {}
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    val bitmap = contentResolver.loadThumbnail(
                        artworkUri,
                        android.util.Size(512, 512),
                        null,
                    )
                    val out = java.io.ByteArrayOutputStream()
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, out)
                    val data = out.toByteArray()
                    if (data.isNotEmpty()) return data
                } catch (_: Exception) {}
            }
        }

        return try {
            extractEmbeddedArtwork(artworkUri)
        } catch (_: Exception) {
            null
        }
    }

    private fun extractEmbeddedArtwork(uri: Uri): ByteArray? {
        val retriever = MediaMetadataRetriever()
        try {
            setAudioDataSource(retriever, uri)
            return retriever.embeddedPicture
        } finally {
            retriever.release()
        }
    }

    private fun convertToLosslessFlac(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val sourcePath = call.argument<String>("sourcePath")?.trim()
        val destPath = call.argument<String>("destPath")?.trim()
        val title = call.argument<String>("title")?.trim() ?: "Unknown title"
        val artist = call.argument<String>("artist")?.trim() ?: "Unknown artist"
        val album = call.argument<String>("album")?.trim() ?: "Single"
        val year = call.argument<Number>("year")?.toInt()
        val genre = call.argument<String>("genre")?.trim()
        val trackNumber = call.argument<Number>("trackNumber")?.toInt()
        val artworkPath = call.argument<String>("artworkPath")?.trim()

        if (sourcePath.isNullOrEmpty() || destPath.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "sourcePath and destPath are required.", null)
            return
        }

        ioExecutor.execute {
            try {
                val sourceFile = File(sourcePath)
                if (!sourceFile.exists() || sourceFile.length() == 0L) {
                    mainHandler.post {
                        result.error("SOURCE_MISSING", "Source audio file does not exist.", null)
                    }
                    return@execute
                }
                val destFile = File(destPath)
                destFile.parentFile?.mkdirs()
                val artworkBytes = artworkPath?.let { path ->
                    val f = File(path)
                    if (f.isFile && f.length() > 0L) f.readBytes() else null
                }
                val tags = mutableMapOf(
                    "TITLE" to title,
                    "ARTIST" to artist,
                    "ALBUM" to album,
                    "ENCODER" to "Tone Lossless FLAC Engine (16-bit Hi-Res)",
                )
                if (year != null && year > 0) tags["DATE"] = year.toString()
                if (!genre.isNullOrEmpty()) tags["GENRE"] = genre
                if (trackNumber != null && trackNumber > 0) tags["TRACKNUMBER"] = trackNumber.toString()

                val info = FlacConverter.encodeAudioFileToFlac(
                    sourceFile = sourceFile,
                    destFile = destFile,
                    tags = tags,
                    artworkBytes = artworkBytes,
                )
                mainHandler.post {
                    result.success(info)
                }
            } catch (error: Exception) {
                Log.e("TonePlayer", "Failed to convert audio to FLAC", error)
                mainHandler.post {
                    result.error("FLAC_CONVERT_FAILED", error.message, null)
                }
            }
        }
    }

    internal fun setAudioDataSource(retriever: MediaMetadataRetriever, uri: Uri) {
        when (uri.scheme) {
            "content" -> retriever.setDataSource(this, uri)
            "file" -> retriever.setDataSource(
                uri.path ?: throw IllegalArgumentException("Invalid audio file URI."),
            )
            "http", "https" -> retriever.setDataSource(uri.toString(), emptyMap())
            null -> retriever.setDataSource(uri.toString())
            else -> throw IllegalArgumentException("Unsupported audio source: ${uri.scheme}")
        }
    }

    internal fun setAudioDataSource(extractor: MediaExtractor, uri: Uri) {
        when (uri.scheme) {
            "content" -> contentResolver.openAssetFileDescriptor(uri, "r")?.use { descriptor ->
                if (descriptor.length >= 0) {
                    extractor.setDataSource(
                        descriptor.fileDescriptor,
                        descriptor.startOffset,
                        descriptor.length,
                    )
                } else {
                    extractor.setDataSource(descriptor.fileDescriptor)
                }
            } ?: throw IllegalArgumentException("The audio source is unavailable.")
            "file" -> extractor.setDataSource(
                uri.path ?: throw IllegalArgumentException("Invalid audio file URI."),
            )
            "http", "https" -> extractor.setDataSource(uri.toString())
            null -> extractor.setDataSource(uri.toString())
            else -> throw IllegalArgumentException("Unsupported audio source: ${uri.scheme}")
        }
    }
}
