package com.example.print_service

import android.content.Intent
import android.net.Uri

object BrowserLauncher {
    fun intent(url: String): Intent {
        val uri = Uri.parse(url)
        require(uri.scheme in listOf("http", "https") && !uri.host.isNullOrBlank() && uri.userInfo == null) {
            "Alamat website HTTP atau HTTPS tidak valid."
        }
        return Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
    }
}
