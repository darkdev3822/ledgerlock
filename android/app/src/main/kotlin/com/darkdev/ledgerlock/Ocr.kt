package com.darkdev.ledgerlock

import android.content.Context
import android.graphics.BitmapFactory
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.File

/**
 * On-device receipt OCR (SPEC §3). Image bytes arrive from Dart already decrypted and are decoded IN MEMORY:
 * no plaintext image file is ever written. Only the (non-sensitive) language model is copied to app storage,
 * because Tesseract needs a filesystem path for it. No networking anywhere in this path.
 */
object Ocr {
    private const val LANG = "eng"
    private const val MAX_SIDE = 2400 // receipts stay legible; bounds memory for huge photos

    @Synchronized
    fun recognize(ctx: Context, bytes: ByteArray): String {
        val dataDir = ensureModel(ctx)
        // Decode bounds first, then downsample by a power of two if the photo is huge.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IllegalArgumentException("not an image")
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_SIDE) sample *= 2
        val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IllegalArgumentException("not an image")
        val api = TessBaseAPI()
        try {
            if (!api.init(dataDir.absolutePath, LANG)) throw IllegalStateException("OCR model failed to load")
            api.pageSegMode = TessBaseAPI.PageSegMode.PSM_AUTO
            api.setImage(bmp)
            api.getUTF8Text() // runs recognition
            return rowsFromWords(api)
        } finally {
            api.recycle()
            bmp.recycle()
        }
    }

    private class Word(val text: String, val left: Int, val top: Int, val bottom: Int) {
        val mid get() = (top + bottom) / 2
        val height get() = bottom - top
    }

    /**
     * Rebuilds text rows from word positions. Tesseract's layout analysis can read a receipt's price column as
     * separate columns (even splitting "12.49" at the point), which detaches amounts from their labels. Grouping
     * words by vertical position keeps "TOTAL ... 38.76" on one line whatever the segmentation did.
     */
    private fun rowsFromWords(api: TessBaseAPI): String {
        val words = mutableListOf<Word>()
        val it = api.resultIterator ?: return ""
        try {
            it.begin()
            do {
                val t = it.getUTF8Text(TessBaseAPI.PageIteratorLevel.RIL_WORD)?.trim().orEmpty()
                if (t.isEmpty()) continue
                val r = it.getBoundingRect(TessBaseAPI.PageIteratorLevel.RIL_WORD)
                words.add(Word(t, r.left, r.top, r.bottom))
            } while (it.next(TessBaseAPI.PageIteratorLevel.RIL_WORD))
        } finally {
            it.delete()
        }
        if (words.isEmpty()) return ""
        val h = words.map { it.height }.sorted()[words.size / 2].coerceAtLeast(1)
        val rows = mutableListOf<MutableList<Word>>()
        for (w in words.sortedBy { it.mid }) {
            val row = rows.lastOrNull()
            if (row != null && kotlin.math.abs(row.map { it.mid }.average() - w.mid) < h * 0.6) row.add(w) else rows.add(mutableListOf(w))
        }
        val sb = StringBuilder()
        for (row in rows) {
            val sorted = row.sortedBy { it.left }
            for ((i, w) in sorted.withIndex()) {
                // Re-join pieces split inside a number ("12." + "49"): no space when a digit/point meets a digit.
                if (i > 0) {
                    val prev = sorted[i - 1].text
                    val glue = (prev.endsWith(".") || prev.endsWith(",")) && w.text.first().isDigit()
                    if (!glue) sb.append(' ')
                }
                sb.append(w.text)
            }
            sb.append('\n')
        }
        return sb.toString()
    }

    /** Copies assets/tessdata/eng.traineddata to files/ocr/tessdata once. Returns files/ocr. */
    private fun ensureModel(ctx: Context): File {
        val root = File(ctx.filesDir, "ocr")
        val out = File(root, "tessdata/$LANG.traineddata")
        if (!out.exists()) {
            out.parentFile?.mkdirs()
            val tmp = File(out.parentFile, "$LANG.tmp")
            ctx.assets.open("tessdata/$LANG.traineddata").use { input -> tmp.outputStream().use { input.copyTo(it) } }
            tmp.renameTo(out)
        }
        return root
    }
}
