package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val exportRequest = 0x5036
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "acessoja/personal_data")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveJson") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.size > 8 * 1024 * 1024) {
                    result.error("invalid_export", "Arquivo inválido.", null)
                } else if (pendingResult != null) {
                    result.error("export_busy", "Há um salvamento em andamento.", null)
                } else {
                    pendingResult = result
                    pendingBytes = bytes
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, "acessoja-meus-dados.json")
                    }
                    try {
                        startActivityForResult(intent, exportRequest)
                    } catch (_: Exception) {
                        pendingResult = null
                        pendingBytes = null
                        result.error("export_unavailable", "Não foi possível abrir o salvamento.", null)
                    }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest) return
        val result = pendingResult ?: return
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            result.success(false)
            return
        }
        val executor = Executors.newSingleThreadExecutor()
        executor.execute {
            try {
                val stream = contentResolver.openOutputStream(uri, "w")
                    ?: throw java.io.IOException("No output stream")
                stream.use { it.write(bytes) }
                runOnUiThread { result.success(true) }
            } catch (_: Exception) {
                runOnUiThread { result.error("export_failed", "Não foi possível salvar.", null) }
            } finally {
                bytes.fill(0)
                executor.shutdown()
            }
        }
    }

    override fun onDestroy() {
        pendingBytes?.fill(0)
        pendingBytes = null
        pendingResult?.success(false)
        pendingResult = null
        super.onDestroy()
    }
}
