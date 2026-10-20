// android/app/src/main/kotlin/com/example/scamshield_flutter_app/LinkConfirmationService.kt
package com.elephas.ai

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.cardview.widget.CardView

/**
 * Apple-style Link Confirmation Service
 * 
 * Shows a minimal, elegant confirmation dialog when user clicks a suspicious link.
 * Instead of blocking with scary alerts, we gently ask "Open this link?"
 * 
 * Design philosophy:
 * - Minimal and clean (Apple-style)
 * - Non-intrusive
 * - User has full control (Cancel / Continue)
 * - Shows the actual domain
 * - Brief explanation of why we're asking
 */
class LinkConfirmationService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var dimBackground: View? = null
    private var isShowing = false
    private val handler = Handler(Looper.getMainLooper())
    
    private var pendingUrl: String? = null

    companion object {
        private const val TAG = "LinkConfirmation"
        
        // Suspicious URL patterns that trigger confirmation
        val SUSPICIOUS_PATTERNS = listOf(
            "bit.ly", "tinyurl", "goo.gl", "t.co", "ow.ly", 
            "is.gd", "buff.ly", "adf.ly", "cutt.ly", "short.gy",
            "rb.gy", "clck.ru", "shorte.st", "bc.vc"
        )
        
        // Typosquatting patterns for banks
        val TYPOSQUAT_PATTERNS = listOf(
            "hdfc-", "icici-", "sbi-", "axis-", "kotak-",
            "hdfcbank\\d", "icic1bank", "sb1\\.in", 
            "-verify", "-update", "-kyc", "-secure"
        )
        
        fun isSuspiciousUrl(url: String): Boolean {
            val lowerUrl = url.lowercase()
            
            // Check for URL shorteners
            if (SUSPICIOUS_PATTERNS.any { lowerUrl.contains(it) }) {
                return true
            }
            
            // Check for typosquatting
            if (TYPOSQUAT_PATTERNS.any { lowerUrl.contains(it) }) {
                return true
            }
            
            // Check for suspicious TLDs
            val suspiciousTlds = listOf(".xyz", ".top", ".club", ".work", ".click", ".link")
            if (suspiciousTlds.any { lowerUrl.endsWith(it) }) {
                return true
            }
            
            return false
        }
        
        fun extractDomain(url: String): String {
            return try {
                val uri = Uri.parse(url)
                uri.host ?: url.take(50)
            } catch (e: Exception) {
                url.take(50)
            }
        }
        
        fun getWarningMessage(url: String): String {
            val lowerUrl = url.lowercase()
            
            return when {
                SUSPICIOUS_PATTERNS.any { lowerUrl.contains(it) } -> 
                    "This link uses a URL shortener. The actual destination is hidden."
                TYPOSQUAT_PATTERNS.any { lowerUrl.contains(it) } -> 
                    "This link may be impersonating a bank website."
                else -> 
                    "This link could not be verified as safe."
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "LinkConfirmationService created")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "showConfirmation" -> {
                val url = intent.getStringExtra("url") ?: ""
                if (url.isNotEmpty()) {
                    showConfirmation(url)
                }
            }
            "hideConfirmation" -> {
                hideConfirmation()
            }
        }
        return START_NOT_STICKY
    }

    private fun showConfirmation(url: String) {
        if (isShowing) {
            hideConfirmation()
        }
        
        pendingUrl = url
        
        handler.post {
            try {
                // Create dim background
                dimBackground = View(this).apply {
                    setBackgroundColor(Color.parseColor("#80000000"))
                    setOnClickListener {
                        // Clicking outside = cancel
                        hideConfirmation()
                    }
                }
                
                val dimParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                )
                
                windowManager.addView(dimBackground, dimParams)
                
                // Inflate the confirmation dialog
                val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
                overlayView = inflater.inflate(R.layout.link_confirmation_overlay, null)
                
                // Set up the dialog content
                overlayView?.let { view ->
                    val domainText = view.findViewById<TextView>(R.id.domainText)
                    val warningText = view.findViewById<TextView>(R.id.warningText)
                    val cancelButton = view.findViewById<TextView>(R.id.cancelButton)
                    val continueButton = view.findViewById<TextView>(R.id.continueButton)
                    
                    // Set domain
                    domainText.text = extractDomain(url)
                    
                    // Set warning
                    warningText.text = getWarningMessage(url)
                    
                    // Cancel button - just hide
                    cancelButton.setOnClickListener {
                        Log.d(TAG, "User cancelled link: $url")
                        hideConfirmation()
                    }
                    
                    // Continue button - open the link
                    continueButton.setOnClickListener {
                        Log.d(TAG, "User continued to link: $url")
                        hideConfirmation()
                        openUrl(url)
                    }
                }
                
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                }
                
                windowManager.addView(overlayView, params)
                isShowing = true
                
                Log.d(TAG, "Showing link confirmation for: $url")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error showing confirmation: ${e.message}")
            }
        }
    }

    private fun hideConfirmation() {
        handler.post {
            try {
                dimBackground?.let {
                    windowManager.removeView(it)
                    dimBackground = null
                }
                overlayView?.let {
                    windowManager.removeView(it)
                    overlayView = null
                }
                isShowing = false
                pendingUrl = null
            } catch (e: Exception) {
                Log.e(TAG, "Error hiding confirmation: ${e.message}")
            }
        }
    }
    
    private fun openUrl(url: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening URL: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        hideConfirmation()
    }
}
