package app.trainlog.trainlog

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Use Android's document picker; no broad storage permission. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var bytes: ByteArray? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.trainlog/documents")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveBackup") { result.notImplemented(); return@setMethodCallHandler }
                if (pending != null) { result.error("busy", "已有文件选择器打开", null); return@setMethodCallHandler }
                val data = call.argument<ByteArray>("bytes")
                if (data == null || data.size > 32 * 1024 * 1024) {
                    result.error("invalid", "备份大小无效", null); return@setMethodCallHandler
                }
                pending = result; bytes = data
                try {
                    startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "TrainLog.json")
                    }, 4701)
                } catch (error: Exception) {
                    pending = null; bytes = null
                    result.error("picker", error.localizedMessage, null)
                }
            }
    }

    @Deprecated("Used for the document picker on FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4701) return
        val result = pending ?: return
        val payload = bytes
        pending = null; bytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || payload == null) {
            result.success(false); return
        }
        try {
            val stream = contentResolver.openOutputStream(uri, "wt") ?: error("无法打开目标文件")
            stream.use { it.write(payload); it.flush() }
            result.success(true)
        } catch (error: Exception) { result.error("write", error.localizedMessage, null) }
    }
}
