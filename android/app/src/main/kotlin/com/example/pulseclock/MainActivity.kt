package com.example.pulseclock

import android.app.Activity
import android.content.ClipData
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val fileSaverChannelName = "workpulse/file_saver"
    private val createCsvRequestCode = 7301
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingCsvBytes: ByteArray? = null
    private var pendingFileName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            fileSaverChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveCsv" -> saveCsv(
                    call.argument<String>("fileName"),
                    call.argument<String>("csv"),
                    result
                )
                "openSavedCsv" -> openSavedCsv(
                    call.argument<String>("uri"),
                    result
                )
                "shareSavedCsv" -> shareSavedCsv(
                    call.argument<String>("uri"),
                    call.argument<String>("fileName"),
                    result
                )
                "shareCsv" -> shareCsv(
                    call.argument<String>("fileName"),
                    call.argument<String>("csv"),
                    result
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun saveCsv(fileName: String?, csv: String?, result: MethodChannel.Result) {
        if (pendingSaveResult != null) {
            result.error("save_in_progress", "A CSV save is already in progress.", null)
            return
        }

        val safeFileName = fileName
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "workpulse_attendance_report.csv"

        pendingSaveResult = result
        pendingCsvBytes = (csv ?: "").toByteArray(Charsets.UTF_8)
        pendingFileName = safeFileName

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/csv"
            putExtra(Intent.EXTRA_TITLE, safeFileName)
        }
        startActivityForResult(intent, createCsvRequestCode)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != createCsvRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingSaveResult
        val csvBytes = pendingCsvBytes
        val fileName = pendingFileName ?: "workpulse_attendance_report.csv"
        pendingSaveResult = null
        pendingCsvBytes = null
        pendingFileName = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }

        try {
            val documentUri = data.data!!
            val persistableFlags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            try {
                contentResolver.takePersistableUriPermission(documentUri, persistableFlags)
            } catch (_: SecurityException) {
                // Some document providers grant access without persistable permissions.
            }

            val outputStream = contentResolver.openOutputStream(documentUri)
            if (outputStream == null) {
                result?.error("save_failed", "Unable to open the selected file.", null)
                return
            }
            outputStream.use { stream ->
                stream.write(csvBytes ?: ByteArray(0))
                stream.flush()
            }
            result?.success(
                mapOf(
                    "uri" to documentUri.toString(),
                    "fileName" to fileName
                )
            )
        } catch (error: Exception) {
            result?.error("save_failed", error.localizedMessage, null)
        }
    }

    private fun openSavedCsv(uriValue: String?, result: MethodChannel.Result) {
        val uri = parseUri(uriValue, result) ?: return
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "text/csv")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData = ClipData.newRawUri("WorkPulse attendance report", uri)
        }

        try {
            startActivity(intent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error(
                "no_csv_app",
                "No application is installed that can open CSV files.",
                null
            )
        } catch (error: Exception) {
            result.error("open_failed", error.localizedMessage, null)
        }
    }

    private fun shareSavedCsv(
        uriValue: String?,
        fileName: String?,
        result: MethodChannel.Result
    ) {
        val uri = parseUri(uriValue, result) ?: return
        launchShareChooser(uri, fileName, result)
    }

    private fun shareCsv(fileName: String?, csv: String?, result: MethodChannel.Result) {
        try {
            val safeFileName = sanitizeFileName(fileName)
            val exportDirectory = File(cacheDir, "workpulse_exports").apply { mkdirs() }
            val csvFile = File(exportDirectory, safeFileName)
            csvFile.writeText(csv ?: "", Charsets.UTF_8)

            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.workpulse.fileprovider",
                csvFile
            )
            launchShareChooser(uri, safeFileName, result)
        } catch (error: Exception) {
            result.error("share_failed", error.localizedMessage, null)
        }
    }

    private fun launchShareChooser(
        uri: Uri,
        fileName: String?,
        result: MethodChannel.Result
    ) {
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/csv"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "WorkPulse Attendance Report")
            putExtra(Intent.EXTRA_TITLE, fileName ?: "WorkPulse Attendance Report")
            clipData = ClipData.newRawUri("WorkPulse attendance report", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(Intent.createChooser(sendIntent, "Share attendance report"))
            result.success(null)
        } catch (error: Exception) {
            result.error("share_failed", error.localizedMessage, null)
        }
    }

    private fun parseUri(uriValue: String?, result: MethodChannel.Result): Uri? {
        if (uriValue.isNullOrBlank()) {
            result.error("invalid_uri", "The saved file location is unavailable.", null)
            return null
        }
        return Uri.parse(uriValue)
    }

    private fun sanitizeFileName(fileName: String?): String {
        val requestedName = fileName
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "workpulse_attendance_report.csv"
        val safeName = requestedName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return if (safeName.endsWith(".csv", ignoreCase = true)) {
            safeName
        } else {
            "$safeName.csv"
        }
    }
}
