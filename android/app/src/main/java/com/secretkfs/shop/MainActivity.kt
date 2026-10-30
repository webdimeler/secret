package com.secretkfs.shop

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
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
    private val homeUrl = "https://webdimeler.github.io/secret/"
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
                    progress.visibility = View.VISIBLE
                    errorPanel.visibility = View.GONE
                }

                override fun onPageFinished(view: WebView, url: String) {
                    progress.visibility = View.GONE
                }

                override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                    if (request.isForMainFrame) {
                        progress.visibility = View.GONE
                        errorPanel.visibility = View.VISIBLE
                    }
                }
            }
            webChromeClient = WebChromeClient()
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

        if (savedInstanceState != null) webView.restoreState(savedInstanceState) else webView.loadUrl(homeUrl)
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
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.destroy()
        }
        super.onDestroy()
    }
}
