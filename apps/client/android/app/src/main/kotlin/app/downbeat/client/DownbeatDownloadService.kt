package app.downbeat.client

import android.app.Service
import android.content.Intent
import android.os.IBinder

class DownbeatDownloadService : Service() {
    override fun onCreate() {
        super.onCreate()
        DownloadNotification.createChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            DownloadBridge.cancelActive()
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(DownloadNotification.NOTIFICATION_ID, DownloadNotification.build(this, "Preparing download"))
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object { const val ACTION_CANCEL = "app.downbeat.client.CANCEL_DOWNLOAD" }
}
