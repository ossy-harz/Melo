package app.melo.melo_player

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

object FlacConverter {
    fun encodeAudioFileToFlac(
        sourceFile: File,
        destFile: File,
        tags: Map<String, String>,
        artworkBytes: ByteArray?,
    ): Map<String, Any?> {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        val pcmTempFile = File(destFile.parentFile, "${destFile.nameWithoutExtension}_pcm.tmp")
        try {
            extractor.setDataSource(sourceFile.absolutePath)
            val audioTrackIndex = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: throw IllegalStateException("No audio track found in source file.")

            extractor.selectTrack(audioTrackIndex)
            val inputFormat = extractor.getTrackFormat(audioTrackIndex)
            val mime = inputFormat.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalStateException("Missing audio MIME type.")

            var sampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                48000
            }
            var channelCount = if (inputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceIn(1, 2)
            } else {
                2
            }

            decoder = MediaCodec.createDecoderByType(mime)
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()

            val pcmOut = FileOutputStream(pcmTempFile)
            val bufferInfo = MediaCodec.BufferInfo()
            var isInputEos = false
            var isOutputEos = false
            var totalPcmBytes = 0L

            while (!isOutputEos) {
                if (!isInputEos) {
                    val inIndex = decoder.dequeueInputBuffer(10000L)
                    if (inIndex >= 0) {
                        val inputBuf = decoder.getInputBuffer(inIndex)
                        if (inputBuf != null) {
                            val sampleSize = extractor.readSampleData(inputBuf, 0)
                            if (sampleSize < 0) {
                                decoder.queueInputBuffer(inIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                isInputEos = true
                            } else {
                                decoder.queueInputBuffer(inIndex, 0, sampleSize, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                val outIndex = decoder.dequeueOutputBuffer(bufferInfo, 10000L)
                if (outIndex >= 0) {
                    val outBuf = decoder.getOutputBuffer(outIndex)
                    if (outBuf != null && bufferInfo.size > 0) {
                        outBuf.position(bufferInfo.offset)
                        outBuf.limit(bufferInfo.offset + bufferInfo.size)
                        val chunk = ByteArray(bufferInfo.size)
                        outBuf.get(chunk)
                        pcmOut.write(chunk)
                        totalPcmBytes += chunk.size
                    }
                    decoder.releaseOutputBuffer(outIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        isOutputEos = true
                    }
                } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = decoder.outputFormat
                    if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channelCount = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceIn(1, 2)
                    }
                }
            }
            pcmOut.flush()
            pcmOut.close()

            val bytesPerSample = 2
            val bytesPerInterleavedFrame = channelCount * bytesPerSample
            val totalSamples = totalPcmBytes / bytesPerInterleavedFrame

            val blockSize = 4096
            val flacOut = FileOutputStream(destFile)

            writeFlacHeader(
                out = flacOut,
                sampleRate = sampleRate,
                channels = channelCount,
                bitsPerSample = 16,
                totalSamples = totalSamples,
                minBlockSize = blockSize,
                maxBlockSize = blockSize,
                tags = tags,
                artworkBytes = artworkBytes,
            )

            val pcmIn = FileInputStream(pcmTempFile)
            val readBuf = ByteArray(blockSize * bytesPerInterleavedFrame)
            var frameNumber = 0L

            while (true) {
                var bytesReadTotal = 0
                while (bytesReadTotal < readBuf.size) {
                    val r = pcmIn.read(readBuf, bytesReadTotal, readBuf.size - bytesReadTotal)
                    if (r < 0) break
                    bytesReadTotal += r
                }
                if (bytesReadTotal == 0) break

                val samplesInThisBlock = bytesReadTotal / bytesPerInterleavedFrame
                val flacFrame = encodeFlacFrame(
                    pcmLeBytes = readBuf,
                    nSamples = samplesInThisBlock,
                    channels = channelCount,
                    sampleRate = sampleRate,
                    frameNumber = frameNumber,
                    standardBlockSize = blockSize,
                )
                flacOut.write(flacFrame)
                frameNumber++
                if (bytesReadTotal < readBuf.size) break
            }

            pcmIn.close()
            flacOut.flush()
            flacOut.close()

            pcmTempFile.delete()

            return mapOf(
                "destPath" to destFile.absolutePath,
                "fileSize" to destFile.length(),
                "durationMs" to ((totalSamples * 1000L) / sampleRate).toInt(),
                "sampleRate" to sampleRate,
                "channels" to channelCount,
                "bitDepth" to 16,
                "format" to "flac",
            )
        } finally {
            try {
                decoder?.stop()
                decoder?.release()
            } catch (_: Exception) {}
            try {
                extractor.release()
            } catch (_: Exception) {}
            if (pcmTempFile.exists()) {
                pcmTempFile.delete()
            }
        }
    }

    private fun writeFlacHeader(
        out: FileOutputStream,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int,
        totalSamples: Long,
        minBlockSize: Int,
        maxBlockSize: Int,
        tags: Map<String, String>,
        artworkBytes: ByteArray?,
    ) {
        out.write("fLaC".toByteArray(Charsets.US_ASCII))

        val hasVorbis = true
        val hasPicture = artworkBytes != null && artworkBytes.isNotEmpty()

        // 1. STREAMINFO metadata block (type 0, 34 bytes)
        val isLastBlock = !hasVorbis && !hasPicture
        val streamInfoTypeByte = (if (isLastBlock) 0x80 else 0x00) or 0x00
        out.write(streamInfoTypeByte)
        out.write(0)
        out.write(0)
        out.write(34)

        val si = ByteArray(34)
        si[0] = ((minBlockSize shr 8) and 0xFF).toByte()
        si[1] = (minBlockSize and 0xFF).toByte()
        si[2] = ((maxBlockSize shr 8) and 0xFF).toByte()
        si[3] = (maxBlockSize and 0xFF).toByte()

        // min and max frame sizes: 0 (unknown) -> 3 bytes each
        // sample_rate (20 bits) | channels-1 (3 bits) | (bits_per_sample-1) (5 bits) | total_samples (36 bits)
        val chBits = (channels - 1) and 0x07
        val bpsBits = (bitsPerSample - 1) and 0x1F

        si[10] = ((sampleRate shr 12) and 0xFF).toByte()
        si[11] = ((sampleRate shr 4) and 0xFF).toByte()
        si[12] = (((sampleRate and 0x0F) shl 4) or (chBits shl 1) or ((bpsBits shr 4) and 0x01)).toByte()
        si[13] = (((bpsBits and 0x0F) shl 4) or (((totalSamples shr 32) and 0x0F).toInt())).toByte()
        si[14] = ((totalSamples shr 24) and 0xFF).toByte()
        si[15] = ((totalSamples shr 16) and 0xFF).toByte()
        si[16] = ((totalSamples shr 8) and 0xFF).toByte()
        si[17] = (totalSamples and 0xFF).toByte()

        out.write(si)

        // 2. VORBIS_COMMENT metadata block (type 4)
        val vorbisStream = ByteArrayOutputStream()
        val vendorStr = "Tone Lossless FLAC Engine"
        val vendorBytes = vendorStr.toByteArray(Charsets.UTF_8)
        vorbisStream.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(vendorBytes.size).array())
        vorbisStream.write(vendorBytes)

        val commentList = tags.map { "${it.key}=${it.value}" }
        vorbisStream.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(commentList.size).array())
        for (c in commentList) {
            val cBytes = c.toByteArray(Charsets.UTF_8)
            vorbisStream.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(cBytes.size).array())
            vorbisStream.write(cBytes)
        }

        val vorbisBlockBytes = vorbisStream.toByteArray()
        val isVorbisLast = !hasPicture
        val vorbisHeaderByte = (if (isVorbisLast) 0x80 else 0x00) or 0x04
        out.write(vorbisHeaderByte)
        out.write((vorbisBlockBytes.size shr 16) and 0xFF)
        out.write((vorbisBlockBytes.size shr 8) and 0xFF)
        out.write(vorbisBlockBytes.size and 0xFF)
        out.write(vorbisBlockBytes)

        // 3. PICTURE metadata block (type 6) if artwork provided
        if (hasPicture) {
            val picStream = ByteArrayOutputStream()
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(3).array()) // front cover
            val mimeBytes = "image/jpeg".toByteArray(Charsets.US_ASCII)
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(mimeBytes.size).array())
            picStream.write(mimeBytes)
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(0).array()) // description length = 0
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(0).array()) // width
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(0).array()) // height
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(24).array()) // depth
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(0).array()) // indexed colors
            picStream.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(artworkBytes!!.size).array())
            picStream.write(artworkBytes)

            val picBlockBytes = picStream.toByteArray()
            out.write(0x80 or 0x06) // last metadata block
            out.write((picBlockBytes.size shr 16) and 0xFF)
            out.write((picBlockBytes.size shr 8) and 0xFF)
            out.write(picBlockBytes.size and 0xFF)
            out.write(picBlockBytes)
        }
    }

    private fun encodeFlacFrame(
        pcmLeBytes: ByteArray,
        nSamples: Int,
        channels: Int,
        sampleRate: Int,
        frameNumber: Long,
        standardBlockSize: Int,
    ): ByteArray {
        val header = ByteArrayOutputStream()

        // Sync code 14 bits (0xFFF8), blocking strategy: 0 = fixed block size, 1 = variable
        val isFixedBlock = (nSamples == standardBlockSize)
        val syncAndBlockStrategy = if (isFixedBlock) 0xFFF8 else 0xFFF9
        header.write((syncAndBlockStrategy shr 8) and 0xFF)
        header.write(syncAndBlockStrategy and 0xFF)

        // Block size code (4 bits) and Sample rate code (4 bits)
        val bsCode = when (nSamples) {
            192 -> 0x01
            576 -> 0x02
            1152 -> 0x03
            2304 -> 0x04
            4608 -> 0x05
            256 -> 0x08
            512 -> 0x09
            1024 -> 0x0A
            2048 -> 0x0B
            4096 -> 0x0C
            8192 -> 0x0D
            16384 -> 0x0E
            32768 -> 0x0F
            else -> 0x07 // 16-bit block size from end of header
        }
        val srCode = when (sampleRate) {
            88200 -> 0x01
            176400 -> 0x02
            192000 -> 0x03
            8000 -> 0x04
            16000 -> 0x05
            22050 -> 0x06
            24000 -> 0x07
            32000 -> 0x08
            44100 -> 0x09
            48000 -> 0x0A
            else -> 0x00
        }
        header.write((bsCode shl 4) or srCode)

        // Channel assignment: 0 = 1ch, 1 = 2ch (left, right), Sample size: 4 = 16-bit, Reserved: 0
        val chCode = (channels - 1).coerceIn(0, 1)
        header.write((chCode shl 4) or (0x04 shl 1))

        // UTF-8 coded frame or sample number
        val codedNumber = if (isFixedBlock) frameNumber else (frameNumber * standardBlockSize)
        writeFlacUtf8Number(header, codedNumber)

        if (bsCode == 0x07) {
            val bsMinus1 = nSamples - 1
            header.write((bsMinus1 shr 8) and 0xFF)
            header.write(bsMinus1 and 0xFF)
        }

        val headerBytes = header.toByteArray()
        val crc8 = computeFlacCrc8(headerBytes, headerBytes.size)

        val frameSize = headerBytes.size + 1 + channels * (1 + nSamples * 2) + 2
        val frame = ByteArray(frameSize)
        System.arraycopy(headerBytes, 0, frame, 0, headerBytes.size)
        var pos = headerBytes.size
        frame[pos++] = crc8.toByte()

        for (ch in 0 until channels) {
            frame[pos++] = 0x02
            var sampleIdx = 0
            while (sampleIdx < nSamples) {
                val pcmOffset = (sampleIdx * channels + ch) * 2
                val lo = pcmLeBytes[pcmOffset].toInt() and 0xFF
                val hi = pcmLeBytes[pcmOffset + 1].toInt() and 0xFF
                frame[pos++] = hi.toByte()
                frame[pos++] = lo.toByte()
                sampleIdx++
            }
        }

        val crc16 = computeFlacCrc16(frame, pos)
        frame[pos++] = ((crc16 shr 8) and 0xFF).toByte()
        frame[pos] = (crc16 and 0xFF).toByte()
        return frame
    }

    private fun writeFlacUtf8Number(out: ByteArrayOutputStream, value: Long) {
        when {
            value < 0x80L -> out.write(value.toInt())
            value < 0x800L -> {
                out.write((0xC0 or ((value shr 6).toInt() and 0x1F)))
                out.write((0x80 or (value.toInt() and 0x3F)))
            }
            value < 0x10000L -> {
                out.write((0xE0 or ((value shr 12).toInt() and 0x0F)))
                out.write((0x80 or ((value shr 6).toInt() and 0x3F)))
                out.write((0x80 or (value.toInt() and 0x3F)))
            }
            value < 0x200000L -> {
                out.write((0xF0 or ((value shr 18).toInt() and 0x07)))
                out.write((0x80 or ((value shr 12).toInt() and 0x3F)))
                out.write((0x80 or ((value shr 6).toInt() and 0x3F)))
                out.write((0x80 or (value.toInt() and 0x3F)))
            }
            value < 0x4000000L -> {
                out.write((0xF8 or ((value shr 24).toInt() and 0x03)))
                out.write((0x80 or ((value shr 18).toInt() and 0x3F)))
                out.write((0x80 or ((value shr 12).toInt() and 0x3F)))
                out.write((0x80 or ((value shr 6).toInt() and 0x3F)))
                out.write((0x80 or (value.toInt() and 0x3F)))
            }
            else -> {
                out.write((0xFC or ((value shr 30).toInt() and 0x01)))
                out.write((0x80 or ((value shr 24).toInt() and 0x3F)))
                out.write((0x80 or ((value shr 18).toInt() and 0x3F)))
                out.write((0x80 or ((value shr 12).toInt() and 0x3F)))
                out.write((0x80 or ((value shr 6).toInt() and 0x3F)))
                out.write((0x80 or (value.toInt() and 0x3F)))
            }
        }
    }

    private fun computeFlacCrc8(data: ByteArray, length: Int): Int {
        var crc = 0
        for (i in 0 until length) {
            crc = crc xor (data[i].toInt() and 0xFF)
            for (bit in 0 until 8) {
                crc = if ((crc and 0x80) != 0) {
                    ((crc shl 1) xor 0x07) and 0xFF
                } else {
                    (crc shl 1) and 0xFF
                }
            }
        }
        return crc
    }

    private fun computeFlacCrc16(data: ByteArray, length: Int): Int {
        var crc = 0
        for (i in 0 until length) {
            crc = crc xor ((data[i].toInt() and 0xFF) shl 8)
            for (bit in 0 until 8) {
                crc = if ((crc and 0x8000) != 0) {
                    ((crc shl 1) xor 0x8005) and 0xFFFF
                } else {
                    (crc shl 1) and 0xFFFF
                }
            }
        }
        return crc
    }
}
