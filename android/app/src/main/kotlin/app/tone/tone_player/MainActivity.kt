package app.tone.tone_player

import android.content.Intent
import android.content.ContentUris
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
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val PICK_MUSIC_FOLDER_REQUEST = 7021
        private val audioExtensions = setOf("mp3", "m4a", "aac", "flac", "wav", "ogg", "opus")
    }

    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val waveformExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val waveformCache = LinkedHashMap<String, List<Double>>(32, 0.75f, true)
    private var pendingFolderResult: MethodChannel.Result? = null
    @Volatile
    private var audioGenreCache: Map<Long, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.tone.tone_player/library")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "androidSdkVersion" -> result.success(android.os.Build.VERSION.SDK_INT)
                    "scanAudio" -> scanAudio(call, result)
                    "pickMusicFolder" -> pickMusicFolder(result)
                    "scanMusicFolder" -> scanMusicFolder(call, result)
                    "releaseMusicFolder" -> releaseMusicFolder(call, result)
                    "readLyrics" -> readLyrics(call, result)
                    "readLocalAudioMetadata" -> readLocalAudioMetadata(call, result)
                    "readAudioQuality" -> readAudioQuality(call, result)
                    "readAudioWaveform" -> readAudioWaveform(call, result)
                    "getArtwork" -> loadArtwork(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        waveformExecutor.shutdown()
        super.onDestroy()
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

    @Deprecated("Deprecated in Android; used for the document-tree result.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_MUSIC_FOLDER_REQUEST) return
        val result = pendingFolderResult ?: return
        pendingFolderResult = null
        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val treeUri = data.data!!
        try {
            val grantedFlags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
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
                val audioDocuments = mutableListOf<Map<String, String>>()
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
                            audioDocuments.add(
                                mapOf(
                                    "documentId" to documentId,
                                    "name" to name,
                                    "parentId" to parentId,
                                    "baseName" to baseName,
                                ),
                            )
                        }
                    } ?: throw IllegalStateException("Android could not read this folder.")
                }
                val audio = audioDocuments.map { document ->
                    val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        document.getValue("documentId"),
                    )
                    val name = document.getValue("name")
                    val key = "${document.getValue("parentId")}/${document.getValue("baseName")}"
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
                                    DocumentsContract.buildDocumentUriUsingTree(
                                        treeUri,
                                        it,
                                    ).toString()
                                }
                            ),
                        "year" to metadata["year"],
                        "trackNumber" to metadata["trackNumber"],
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
        ioExecutor.execute {
            try {
                val file = File(path)
                if (!file.isFile) {
                    throw IllegalArgumentException("The imported audio file is unavailable.")
                }
                val metadata = readAudioMetadata(
                    Uri.fromFile(file),
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
                )
                val audio = mutableListOf<Map<String, Any?>>()
                val sortOrder =
                    "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC, " +
                        "${MediaStore.Audio.Media._ID} ASC"
                val cursor = contentResolver.query(
                    collection,
                    projection,
                    null,
                    null,
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
                    var pageCount = 0
                    while (pageCount < limit && audioCursor.moveToNext()) {
                        pageCount++
                        val id = audioCursor.getLong(idColumn)
                        val name = audioCursor.getString(nameColumn) ?: continue
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
                        val durationMs = audioCursor.getLong(durationColumn)
                        val year = audioCursor.getInt(yearColumn).takeIf { it > 0 }
                        val trackNumber = audioCursor.getInt(trackColumn)
                            .rem(1000)
                            .takeIf { it > 0 }
                        val mediaUri = ContentUris.withAppendedId(collection, id)
                        val fallbackMetadata = if (
                            artist == "Unknown artist" ||
                            album == "Unknown album" ||
                            durationMs <= 0 ||
                            albumId <= 0
                        ) {
                            try {
                                readAudioMetadata(mediaUri, title, album)
                            } catch (error: Exception) {
                                Log.w("ToneLibrary", "Could not read tags for $name", error)
                                emptyMap()
                            }
                        } else {
                            emptyMap()
                        }
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
                                "durationMs" to if (durationMs > 0) {
                                    durationMs
                                } else {
                                    fallbackMetadata["durationMs"]
                                },
                                "artworkUri" to if (albumId > 0) {
                                    "content://media/external/audio/albumart/$albumId"
                                } else {
                                    embeddedArtworkUri
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
        ioExecutor.execute {
            try {
                val embeddedArtwork = sourceUri?.let(::extractEmbeddedArtwork)
                val artworkBytes = embeddedArtwork ?: uri?.let { artworkUri ->
                    val isArtwork = artworkUri.path?.contains("/albumart/") == true ||
                        contentResolver.getType(artworkUri)?.startsWith("image/") == true
                    if (isArtwork) {
                        contentResolver.openInputStream(artworkUri)?.use { it.readBytes() }
                    } else {
                        extractEmbeddedArtwork(artworkUri)
                    }
                }
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

    private fun extractEmbeddedArtwork(uri: Uri): ByteArray? {
        val retriever = MediaMetadataRetriever()
        try {
            setAudioDataSource(retriever, uri)
            return retriever.embeddedPicture
        } finally {
            retriever.release()
        }
    }

    private fun setAudioDataSource(retriever: MediaMetadataRetriever, uri: Uri) {
        when (uri.scheme) {
            "content" -> retriever.setDataSource(this, uri)
            "file" -> retriever.setDataSource(
                uri.path ?: throw IllegalArgumentException("Invalid audio file URI."),
            )
            null -> retriever.setDataSource(uri.toString())
            else -> throw IllegalArgumentException("Unsupported local audio source.")
        }
    }

    private fun setAudioDataSource(extractor: MediaExtractor, uri: Uri) {
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
            null -> extractor.setDataSource(uri.toString())
            else -> throw IllegalArgumentException("Unsupported local audio source.")
        }
    }
}
