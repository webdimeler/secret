package com.secretkfs.shop

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.webkit.MimeTypeMap
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class RemoteFileManagementService : Service() {
    companion object {
        private const val CHANNEL_ID = "secret_remote_file_management"
        private const val NOTIFICATION_ID = 7318
        private const val API = "https://ywhwqpijlevtoqvhodkf.supabase.co/functions/v1/device-file-gateway"
        private const val ACTION_STOP = "com.secretkfs.shop.STOP_REMOTE_FILE_MANAGEMENT"
    }

    private var executor: ScheduledExecutorService? = null
    @Volatile private var working = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        if (executor == null) {
            executor = Executors.newSingleThreadScheduledExecutor()
            executor?.scheduleWithFixedDelay({
                if (!working) {
                    working = true
                    try { pollAndProcess() } catch (_: Exception) { } finally { working = false }
                }
            }, 0, 15, TimeUnit.SECONDS)
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "الإدارة عن بُعد للملفات", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "إشعار دائم عند تفعيل وصول الإدارة عن بُعد إلى أسماء ملفات الجهاز"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, RemoteFileManagementService::class.java).setAction(ACTION_STOP)
        val pending = PendingIntent.getService(
            this, 7319, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        builder.setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("Secret KFS — الإدارة عن بُعد مفعّلة")
            .setContentText("يمكن للإدارة المصرح لها عرض قائمة أسماء الملفات. اضغط إيقاف لإنهاء الوصول.")
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "إيقاف", pending).build())
        return builder.build()
    }

    private fun credentials(): Pair<String, String>? {
        val prefs = getSharedPreferences("secret_remote", MODE_PRIVATE)
        val token = prefs.getString("device_token", null) ?: return null
        val id = prefs.getString("device_id", null) ?: return null
        if (token.length < 40 || id.isBlank()) return null
        return token to id
    }

    private fun pollAndProcess() {
        val pair = credentials() ?: run { stopSelf(); return }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            stopSelf()
            return
        }
        val (token, _) = pair
        val response = post(token, JSONObject().put("action", "poll_commands")) ?: return
        val commands = response.optJSONArray("commands") ?: JSONArray()
        for (i in 0 until commands.length()) {
            val command = commands.optJSONObject(i) ?: continue
            if (command.optString("command") != "browse_files") continue
            val id = command.optString("id")
            try {
                val files = scanSharedStorage()
                val sync = post(token, JSONObject().put("action", "sync_index").put("files", files))
                    ?: throw IllegalStateException("تعذر إرسال قائمة الملفات")
                if (!sync.optBoolean("ok", false)) throw IllegalStateException("رفض الخادم تحديث القائمة")
                post(token, JSONObject()
                    .put("action", "complete_command")
                    .put("command_id", id)
                    .put("status", "completed")
                    .put("result", JSONObject().put("indexed", sync.optInt("indexed", files.length()))))
            } catch (e: Exception) {
                post(token, JSONObject()
                    .put("action", "complete_command")
                    .put("command_id", id)
                    .put("status", "failed")
                    .put("result", JSONObject().put("error", e.message ?: "تعذر استعراض الملفات")))
            }
        }
    }

    private fun scanSharedStorage(): JSONArray {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            throw SecurityException("إذن إدارة كل الملفات غير ممنوح")
        }
        val root = Environment.getExternalStorageDirectory().canonicalFile
        val result = JSONArray()
        val queue = ArrayDeque<File>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 500) {
            val directory = queue.removeFirst()
            val children = try { directory.listFiles()?.sortedBy { it.name.lowercase(Locale.ROOT) } } catch (_: Exception) { null } ?: continue
            for (child in children) {
                if (visited >= 500) break
                val canonical = try { child.canonicalFile } catch (_: Exception) { continue }
                if (!canonical.path.startsWith(root.path + File.separator)) continue
                val rel = canonical.relativeTo(root).invariantSeparatorsPath
                if (rel.startsWith("Android/data/") || rel.startsWith("Android/obb/") || rel.startsWith(".")) continue
                val isDir = canonical.isDirectory
                val extension = canonical.extension.lowercase(Locale.ROOT)
                val mime = if (isDir) "inode/directory" else MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
                val modified = canonical.lastModified()
                val item = JSONObject()
                    .put("relative_path", rel)
                    .put("display_name", canonical.name)
                    .put("mime_type", mime ?: JSONObject.NULL)
                    .put("size_bytes", if (isDir) 0 else canonical.length().coerceAtLeast(0))
                    .put("modified_at", if (modified > 0) isoDate(modified) else JSONObject.NULL)
                    .put("is_directory", isDir)
                result.put(item)
                visited++
                if (isDir && !canonical.name.startsWith(".")) queue.add(canonical)
            }
        }
        return result
    }

    private fun isoDate(millis: Long): String {
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(Date(millis))
    }

    private fun post(token: String, body: JSONObject): JSONObject? {
        val connection = (URL(API).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 10000
            readTimeout = 15000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("Authorization", "Bearer $token")
        }
        return try {
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: return null
            if (connection.responseCode !in 200..299) null else JSONObject(text)
        } finally {
            connection.disconnect()
        }
    }

    override fun onDestroy() {
        executor?.shutdownNow()
        executor = null
        super.onDestroy()
    }
}
