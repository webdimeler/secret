package com.secretkfs.shop

import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.database.Cursor
import android.provider.DocumentsContract
import android.webkit.JavascriptInterface
import org.json.JSONArray
import org.json.JSONObject
import android.graphics.Color
import android.net.Uri
import android.webkit.ValueCallback
import android.os.Bundle
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

class MainActivity : Activity() {
    private lateinit var webView: WebView
    private lateinit var progress: ProgressBar
    private lateinit var errorPanel: LinearLayout
    private var pendingFileCallback: ValueCallback<Array<Uri>>? = null
    private val filePickerRequestCode = 4107
    private val storageTreeRequestCode = 4110
    private var selectedTreeUri: Uri? = null
    private val homeUrl = "https://webdimeler.github.io/secret/device-share.html"
    private val brand = Color.rgb(184, 79, 125)
    private val pageBg = Color.rgb(255, 248, 250)

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = pageBg
        window.navigationBarColor = pageBg
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR

        val root = FrameLayout(this).apply { setBackgroundColor(pageBg) }
        webView = WebView(this).apply {
            setBackgroundColor(pageBg)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.databaseEnabled = true
            settings.loadsImagesAutomatically = true
            settings.javaScriptCanOpenWindowsAutomatically = false
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.setSupportMultipleWindows(false)
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val uri = request.url
                    val scheme = uri.scheme ?: return true
                    if (scheme == "https" && (uri.host == "webdimeler.github.io" || uri.host == "ywhwqpijlevtoqvhodkf.supabase.co" || uri.host == "images.unsplash.com" || uri.host == "cdn.jsdelivr.net")) return false
                    if (scheme == "http" && uri.host == "webdimeler.github.io") return false
                    if (scheme == "about" || scheme == "data" || scheme == "blob") return false
                    openExternal(uri)
                    return true
                }

                override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                    this@MainActivity.progress.visibility = View.VISIBLE
                    this@MainActivity.errorPanel.visibility = View.GONE
                }

                override fun onPageFinished(view: WebView, url: String) {
                    this@MainActivity.progress.visibility = View.GONE
                }

                override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                    if (request.isForMainFrame) {
                        this@MainActivity.progress.visibility = View.GONE
                        this@MainActivity.errorPanel.visibility = View.VISIBLE
                    }
                }
            }
            addJavascriptInterface(this@MainActivity.StorageBridge(), "AndroidStorage")
            webChromeClient = object : WebChromeClient() {
                override fun onShowFileChooser(
                    webView: WebView,
                    filePathCallback: ValueCallback<Array<Uri>>,
                    fileChooserParams: WebChromeClient.FileChooserParams
                ): Boolean {
                    pendingFileCallback?.onReceiveValue(null)
                    pendingFileCallback = filePathCallback

                    // Explain access and ask the user before opening Android's system file picker.
                    AlertDialog.Builder(this@MainActivity)
                        .setTitle("السماح باختيار الملفات")
                        .setMessage(
                            "سيُفتح منتقي الملفات الرسمي في Android. يمكنك السماح باختيار ملفات محددة أو الضغط على رفض. " +
                            "لن يحصل التطبيق على إذن شامل لمساحة التخزين، ولن يتم إرسال أي ملف إلا إذا اخترته ووافقت على مشاركته."
                        )
                        .setPositiveButton("اختيار ملفات") { _, _ ->
                            try {
                                val intent = fileChooserParams.createIntent().apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                }
                                startActivityForResult(intent, filePickerRequestCode)
                            } catch (_: ActivityNotFoundException) {
                                pendingFileCallback = null
                                filePathCallback.onReceiveValue(null)
                            } catch (_: SecurityException) {
                                pendingFileCallback = null
                                filePathCallback.onReceiveValue(null)
                            }
                        }
                        .setNegativeButton("رفض") { _, _ ->
                            pendingFileCallback = null
                            filePathCallback.onReceiveValue(null)
                        }
                        .setOnCancelListener {
                            pendingFileCallback = null
                            filePathCallback.onReceiveValue(null)
                        }
                        .show()
                    return true
                }
            }
        }
        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = true
            indeterminateTintList = android.content.res.ColorStateList.valueOf(brand)
        }
        errorPanel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(36, 32, 36, 32)
            visibility = View.GONE
            addView(TextView(this@MainActivity).apply {
                text = "تعذر الاتصال بالمتجر"
                textSize = 22f
                setTextColor(Color.rgb(75, 48, 61))
                gravity = Gravity.CENTER
            })
            addView(TextView(this@MainActivity).apply {
                text = "تحققي من اتصال الإنترنت ثم حاولي مرة أخرى."
                textSize = 15f
                setTextColor(Color.DKGRAY)
                gravity = Gravity.CENTER
                setPadding(0, 14, 0, 22)
            })
            addView(Button(this@MainActivity).apply {
                text = "إعادة المحاولة"
                setTextColor(Color.WHITE)
                setBackgroundColor(brand)
                setOnClickListener { webView.reload() }
            })
        }

        root.addView(webView, FrameLayout.LayoutParams(-1, -1))
        root.addView(progress, FrameLayout.LayoutParams(-1, 8, Gravity.TOP))
        root.addView(errorPanel, FrameLayout.LayoutParams(-1, -1))
        setContentView(root)
        selectedTreeUri = getSharedPreferences("secret_storage", MODE_PRIVATE)
            .getString("selected_tree_uri", null)?.let { Uri.parse(it) }

        if (savedInstanceState != null) webView.restoreState(savedInstanceState) else webView.loadUrl(homeUrl)
    }

    private inner class StorageBridge {
        @JavascriptInterface
        fun getDeviceName(): String = (Build.MANUFACTURER + " " + Build.MODEL).trim().take(100)

        @JavascriptInterface
        fun hasAllFilesAccess(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()

        @JavascriptInterface
        fun setRemoteCredentials(token: String, deviceId: String) {
            if (token.length >= 40 && deviceId.matches(Regex("^[0-9a-fA-F-]{36}$"))) {
                getSharedPreferences("secret_remote", MODE_PRIVATE).edit()
                    .putString("device_token", token).putString("device_id", deviceId).apply()
            }
        }

        @JavascriptInterface
        fun requestAllFilesAccess() {
            runOnUiThread {
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("السماح باستعراض مساحة التخزين")
                    .setMessage("هذا الإذن يسمح للتطبيق بفهرسة أسماء الملفات ومجلداتها المشتركة عند طلبك من لوحة الإدارة. لن تُرفع محتويات الملفات تلقائيًا. يمكنك إيقاف الخدمة من الإشعار الدائم.")
                    .setPositiveButton("فتح إعدادات الإذن") { _, _ ->
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                                Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName"))
                            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            startActivity(intent)
                        } catch (_: Exception) {
                            try { startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)) } catch (_: Exception) {
                                webView.evaluateJavascript("window.onRemoteAccessMessage && window.onRemoteAccessMessage('تعذر فتح إعدادات الإذن.')", null)
                            }
                        }
                    }
                    .setNegativeButton("إلغاء", null)
                    .show()
            }
        }

        @JavascriptInterface
        fun startRemoteManagement(): Boolean {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) return false
            val prefs = getSharedPreferences("secret_remote", MODE_PRIVATE)
            if (prefs.getString("device_token", null).isNullOrBlank() || prefs.getString("device_id", null).isNullOrBlank()) return false
            val intent = Intent(this@MainActivity, RemoteFileManagementService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                return true
            } catch (_: Exception) { return false }
        }

        @JavascriptInterface
        fun stopRemoteManagement() {
            stopService(Intent(this@MainActivity, RemoteFileManagementService::class.java))
        }

        @JavascriptInterface
        fun hasFolderAccess(): Boolean = selectedTreeUri != null

        @JavascriptInterface
        fun pickFolder() {
            runOnUiThread {
                if (!webView.url.orEmpty().contains("webdimeler.github.io/secret/device-share.html")) {
                    webView.evaluateJavascript("window.onStorageBridgeError && window.onStorageBridgeError('افتح صفحة مشاركة ملفات الجهاز أولًا.')", null)
                    return@runOnUiThread
                }
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("اختيار مجلد لاستعراضه")
                    .setMessage("ستشارك لوحة الإدارة أسماء الملفات الموجودة مباشرة داخل المجلد الذي تختاره فقط، مع أحجامها وأنواعها. لن يتم فحص المجلدات الفرعية أو رفع محتوى الملفات. يمكنك إيقاف المشاركة من الصفحة.")
                    .setPositiveButton("اختيار مجلد") { _, _ ->
                        try {
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), storageTreeRequestCode)
                        } catch (_: Exception) {
                            webView.evaluateJavascript("window.onStorageBridgeError && window.onStorageBridgeError('تعذر فتح منتقي المجلدات.')", null)
                        }
                    }
                    .setNegativeButton("إلغاء", null)
                    .show()
            }
        }

        @JavascriptInterface
        fun refreshFolderList() {
            runOnUiThread {
                if (!webView.url.orEmpty().contains("webdimeler.github.io/secret/device-share.html")) {
                    webView.evaluateJavascript("window.onStorageBridgeError && window.onStorageBridgeError('افتح صفحة مشاركة ملفات الجهاز أولًا.')", null)
                    return@runOnUiThread
                }
                val uri = selectedTreeUri ?: getSharedPreferences("secret_storage", MODE_PRIVATE)
                    .getString("selected_tree_uri", null)?.let { Uri.parse(it) }
                if (uri == null) {
                    webView.evaluateJavascript("window.onStorageBridgeError && window.onStorageBridgeError('اختر مجلدًا أولًا من الهاتف.')", null)
                    return@runOnUiThread
                }
                selectedTreeUri = uri
                sendSelectedFolderIndex(uri)
            }
        }

        @JavascriptInterface
        fun stopFolderSharing() {
            runOnUiThread {
                selectedTreeUri?.let { uri ->
                    try { contentResolver.releasePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) {}
                }
                selectedTreeUri = null
                getSharedPreferences("secret_storage", MODE_PRIVATE).edit().remove("selected_tree_uri").apply()
                webView.evaluateJavascript("window.onStorageSharingStopped && window.onStorageSharingStopped()", null)
            }
        }
    }

    private fun sendSelectedFolderIndex(treeUri: Uri) {
        val rows = JSONArray()
        try {
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri, DocumentsContract.getTreeDocumentId(treeUri)
            )
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED
            )
            contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                val sizeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                val modifiedCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                var count = 0
                while (cursor.moveToNext() && count < 500) {
                    val name = if (nameCol >= 0) cursor.getString(nameCol).orEmpty() else ""
                    if (name.isBlank()) continue
                    val isDirectory = mimeCol >= 0 && cursor.getString(mimeCol) == DocumentsContract.Document.MIME_TYPE_DIR
                    val item = JSONObject()
                    item.put("path", name)
                    item.put("name", name)
                    item.put("mime_type", if (isDirectory) "inode/directory" else if (mimeCol >= 0) cursor.getString(mimeCol) else JSONObject.NULL)
                    item.put("size_bytes", if (isDirectory || sizeCol < 0 || cursor.isNull(sizeCol)) 0 else cursor.getLong(sizeCol))
                    item.put("modified_at", if (modifiedCol >= 0 && !cursor.isNull(modifiedCol)) cursor.getLong(modifiedCol) else 0)
                    item.put("is_directory", isDirectory)
                    rows.put(item)
                    count++
                }
            }
            webView.post {
                val json = JSONObject.quote(rows.toString())
                webView.evaluateJavascript("window.onStorageFolderSelected && window.onStorageFolderSelected($json)", null)
            }
        } catch (_: Exception) {
            webView.post {
                webView.evaluateJavascript("window.onStorageBridgeError && window.onStorageBridgeError('تعذر قراءة محتويات المجلد المحدد. اختر مجلدًا آخر وحاول مجددًا.')", null)
            }
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == storageTreeRequestCode) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                selectedTreeUri = uri
                try {
                    contentResolver.takePersistableUriPermission(uri, data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
                } catch (_: Exception) {}
                getSharedPreferences("secret_storage", MODE_PRIVATE).edit().putString("selected_tree_uri", uri.toString()).apply()
                sendSelectedFolderIndex(uri)
            } else {
                webView.evaluateJavascript("window.onStorageBridgeError && window.onStorageBridgeError('لم يتم اختيار مجلد.')", null)
            }
            return
        }
        if (requestCode == filePickerRequestCode) {
            val callback = pendingFileCallback
            pendingFileCallback = null
            callback?.onReceiveValue(
                if (resultCode == Activity.RESULT_OK) WebChromeClient.FileChooserParams.parseResult(resultCode, data) else null
            )
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun openExternal(uri: Uri) {
        try {
            val intent = when (uri.scheme) {
                "mailto" -> Intent(Intent.ACTION_SENDTO, uri)
                "tel" -> Intent(Intent.ACTION_DIAL, uri)
                else -> Intent(Intent.ACTION_VIEW, uri)
            }
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            // No compatible app installed; keep the store open.
        } catch (_: SecurityException) {
            // Ignore unsafe or unsupported external links.
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) webView.goBack() else super.onBackPressed()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (::webView.isInitialized) webView.saveState(outState)
    }

    override fun onDestroy() {
        pendingFileCallback?.onReceiveValue(null)
        pendingFileCallback = null
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.destroy()
        }
        super.onDestroy()
    }
}
