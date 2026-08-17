package com.jamboplus

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Drops Supasoka expired-subscription reminders that share the Firebase project
 * with JamboPlus. JamboPlus only listens on jamboplus_* topics, but this guards
 * legacy subscriptions and stale server mirrors.
 */
class JamboPlusMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        if (isSupasokaExpiredReminder(message)) {
            return
        }
        super.onMessageReceived(message)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    private fun isSupasokaExpiredReminder(message: RemoteMessage): Boolean {
        val data = message.data
        val kind = data["kind"]?.lowercase().orEmpty()
        val scope = data["scope"]?.lowercase().orEmpty()
        val source = data["source"]?.lowercase().orEmpty()
        val target = data["target"]?.lowercase().orEmpty()

        if (scope == "user" || target.startsWith("user:")) return true
        if (source == "supaadmin" && kind.isNotEmpty() && kind != "broadcast") return true
        if (kind in setOf("reminder", "payment_reminder", "expired_reminder")) return true

        val title = (message.notification?.title ?: data["title"] ?: "").lowercase()
        val body = (message.notification?.body ?: data["body"] ?: data["message"] ?: "").lowercase()
        val haystack = "$title $body"
        return haystack.contains("kifurushi chako kimeisha")
    }
}
