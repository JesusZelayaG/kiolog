package com.kiolog.kiolog

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Picks files through the system chooser and reads text from them on the device. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                saveToDownloads(call.argument<String>("path")!!, call.argument<String>("name")!!, result)
                return@setMethodCallHandler
            }
            if (call.method == "pruneDownloads") {
                pruneDownloads(call.argument<String>("prefix")!!, call.argument<Int>("keep")!!, result)
                return@setMethodCallHandler
            }
            if (call.method == "readText") {
                readText(call.argument<String>("path")!!, result)
                return@setMethodCallHandler
            }
            if (call.method != "pick") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            pending = result
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("*/*")
            call.argument<List<String>>("mimeTypes")?.let {
                intent.putExtra(Intent.EXTRA_MIME_TYPES, it.toTypedArray())
            }
            startActivityForResult(intent, PICK_REQUEST)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_REQUEST) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            cacheDir.listFiles { file -> file.name.startsWith("picked") }?.forEach { it.delete() }
            val copy = File.createTempFile("picked", null, cacheDir)
            contentResolver.openInputStream(uri)!!.use { input ->
                copy.outputStream().use { output -> input.copyTo(output) }
            }
            result.success(copy.path)
        } catch (e: Exception) {
            result.error("pick_failed", e.message, null)
        }
    }

    /** Copies [path] to Download/Kiolog so it survives uninstalling the app. */
    private fun saveToDownloads(path: String, name: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("unsupported", "Android 10 or newer is required", null)
            return
        }
        try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "application/octet-stream")
                put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$FOLDER")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = contentResolver.insert(collection, values)!!
            contentResolver.openOutputStream(uri)!!.use { output ->
                File(path).inputStream().use { input -> input.copyTo(output) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            result.success("${Environment.DIRECTORY_DOWNLOADS}/$FOLDER/$name")
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    /** Deletes this app's oldest Download/Kiolog files named [prefix]*, keeping [keep]. */
    private fun pruneDownloads(prefix: String, keep: Int, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(0)
            return
        }
        try {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val ids = mutableListOf<Long>()
            contentResolver.query(
                collection,
                arrayOf(MediaStore.Downloads._ID),
                "${MediaStore.Downloads.RELATIVE_PATH} LIKE ? AND ${MediaStore.Downloads.DISPLAY_NAME} LIKE ?",
                arrayOf("${Environment.DIRECTORY_DOWNLOADS}/$FOLDER%", "$prefix%"),
                "${MediaStore.Downloads.DISPLAY_NAME} DESC",
            )?.use { cursor ->
                while (cursor.moveToNext()) ids.add(cursor.getLong(0))
            }
            val stale = ids.drop(keep)
            stale.forEach { id ->
                contentResolver.delete(android.content.ContentUris.withAppendedId(collection, id), null, null)
            }
            result.success(stale.size)
        } catch (e: Exception) {
            result.error("prune_failed", e.message, null)
        }
    }

    private fun readText(path: String, result: MethodChannel.Result) {
        val bitmap = try {
            load(File(path))
        } catch (e: Exception) {
            null
        }
        if (bitmap == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            .process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { text ->
                result.success(
                    text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                        line.boundingBox?.let { box ->
                            mapOf(
                                "text" to line.text,
                                "left" to box.left,
                                "top" to box.top,
                                "bottom" to box.bottom,
                            )
                        }
                    },
                )
            }
            .addOnFailureListener { e -> result.error("ocr_failed", e.message, null) }
    }

    private fun load(file: File): Bitmap? {
        val isPdf = file.inputStream().use { input ->
            ByteArray(4).also { input.read(it) }.contentEquals("%PDF".toByteArray())
        }
        if (!isPdf) return BitmapFactory.decodeFile(file.path)
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                renderer.openPage(0).use { page ->
                    val height = PDF_WIDTH * page.height / page.width
                    val bitmap = Bitmap.createBitmap(PDF_WIDTH, height, Bitmap.Config.ARGB_8888)
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    return bitmap
                }
            }
        }
    }

    private companion object {
        const val PDF_WIDTH = 2000
        const val CHANNEL = "kiolog/files"
        const val FOLDER = "Kiolog"
        const val PICK_REQUEST = 4210
    }
}
