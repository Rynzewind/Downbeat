package app.downbeat.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

object DownloadNotification {
    const val CHANNEL_ID = "downbeat_downloads"
    const val NOTIFICATION_ID = 4102

    fun createChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Downbeat downloads", NotificationManager.IMPORTANCE_LOW))
    }

    fun build(context: Context, text: String, progress: Int? = null): Notification {
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val cancelIntent = Intent(context, DownbeatDownloadService::class.java).setAction(DownbeatDownloadService.ACTION_CANCEL)
        val cancel = PendingIntent.getService(context, 1, cancelIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_downbeat_notification)
            .setContentTitle("Downbeat")
            .setContentText(text)
            .setContentIntent(open)
            .setOnlyAlertOnce(true)
            .setOngoing(progress != null)
            .setProgress(100, progress ?: 0, progress == null)
            .addAction(0, "Cancel", cancel)
            .build()
    }
}
