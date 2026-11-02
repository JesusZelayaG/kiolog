package com.kiolog.kiolog

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Opens the system file chooser and hands Dart a private copy of the chosen file. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
            val copy = File.createTempFile("picked", null, cacheDir)
            contentResolver.openInputStream(uri)!!.use { input ->
                copy.outputStream().use { output -> input.copyTo(output) }
            }
            result.success(copy.path)
        } catch (e: Exception) {
            result.error("pick_failed", e.message, null)
        }
    }

    private companion object {
        const val CHANNEL = "kiolog/files"
        const val PICK_REQUEST = 4210
    }
}
