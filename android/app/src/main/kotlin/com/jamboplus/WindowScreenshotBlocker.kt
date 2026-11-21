package com.jamboplus

import android.app.Activity
import android.view.WindowManager

/** Blocks screenshots and most screen recording (Android FLAG_SECURE). */
internal fun Activity.enableScreenshotBlocking() {
    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
}
