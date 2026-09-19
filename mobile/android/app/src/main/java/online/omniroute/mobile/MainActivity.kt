package online.omniroute.mobile

import android.annotation.SuppressLint
import android.content.Context
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var setupView: LinearLayout
    private val prefs by lazy { getSharedPreferences("omniroute_mobile", Context.MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showApp()
    }

    private fun showApp() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        setupView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(48, 72, 48, 48)
        }

        val title = TextView(this).apply {
            text = "OmniRoute Mobile"
            textSize = 28f
            gravity = Gravity.CENTER
        }

        val help = TextView(this).apply {
            text = "Enter your OmniRoute server address. Example: https://your-server.example or http://192.168.1.50:20128"
            textSize = 16f
            setPadding(0, 24, 0, 24)
        }

        val serverInput = EditText(this).apply {
            hint = "OmniRoute server URL"
            setSingleLine(true)
            setText(prefs.getString("server_url", ""))
        }

        val connect = Button(this).apply {
            text = "Connect"
            setOnClickListener {
                val normalized = normalizeUrl(serverInput.text.toString())
                if (normalized != null) {
                    prefs.edit().putString("server_url", normalized).apply()
                    openServer(normalized)
                } else {
                    serverInput.error = "Enter a valid http:// or https:// address"
                }
            }
        }

        setupView.addView(title)
        setupView.addView(help)
        setupView.addView(serverInput, LinearLayout.LayoutParams(-1, -2))
        setupView.addView(connect, LinearLayout.LayoutParams(-1, -2))

        webView = WebView(this).apply {
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(-1, 0, 1f)
        }

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            visibility = View.GONE
            gravity = Gravity.CENTER
        }

        val back = Button(this).apply {
            text = "Back"
            setOnClickListener { if (webView.canGoBack()) webView.goBack() }
        }
        val home = Button(this).apply {
            text = "Home"
            setOnClickListener { prefs.getString("server_url", null)?.let(::openServer) }
        }
        val change = Button(this).apply {
            text = "Server"
            setOnClickListener {
                webView.visibility = View.GONE
                controls.visibility = View.GONE
                setupView.visibility = View.VISIBLE
            }
        }

        controls.addView(back, LinearLayout.LayoutParams(0, -2, 1f))
        controls.addView(home, LinearLayout.LayoutParams(0, -2, 1f))
        controls.addView(change, LinearLayout.LayoutParams(0, -2, 1f))

        root.addView(setupView, LinearLayout.LayoutParams(-1, 0, 1f))
        root.addView(webView)
        root.addView(controls)
        setContentView(root)

        configureWebView()
        prefs.getString("server_url", null)?.let { saved ->
            setupView.visibility = View.GONE
            webView.visibility = View.VISIBLE
            controls.visibility = View.VISIBLE
            webView.loadUrl(saved)
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            setSupportZoom(true)
            builtInZoomControls = false
        }
        webView.webChromeClient = WebChromeClient()
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean = false
        }
    }

    private fun openServer(url: String) {
        setupView.visibility = View.GONE
        webView.visibility = View.VISIBLE
        (webView.parent as? LinearLayout)?.getChildAt(2)?.visibility = View.VISIBLE
        webView.loadUrl(url)
    }

    private fun normalizeUrl(raw: String): String? {
        val trimmed = raw.trim().trimEnd('/')
        if (trimmed.isBlank()) return null
        return when {
            trimmed.startsWith("https://") -> trimmed
            trimmed.startsWith("http://") -> trimmed
            else -> "https://$trimmed"
        }
    }

    override fun onBackPressed() {
        if (::webView.isInitialized && webView.visibility == View.VISIBLE && webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
