package io.max.paperplay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app's process in the foreground while the person has this turned on, so
 * syncing and filing carry on after they leave. Playback has its own service. Its
 * notification says what the app is doing, and is updated as that changes.
 */
class KeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = build(this, "Paper Play is running", "Starting up", null, null, true)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION, notification)
        }
        // Not restarted by Android: with the app gone there'd be nothing for it to keep alive.
        return START_NOT_STICKY
    }

    companion object {
        private const val CHANNEL = "io.max.paperplay.background"
        private const val NOTIFICATION = 4712

        @Volatile
        private var running = false

        private fun build(
            context: Context,
            title: String,
            text: String,
            progress: Int?,
            max: Int?,
            indeterminate: Boolean,
        ): Notification {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Running in the background", NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                },
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra(MainActivity.OPEN_EXTRA, "tasks"),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val builder = Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_teleplayer)
                .setContentTitle(title)
                // The first line, with the rest when it's pulled down.
                .setContentText(text.lineSequence().firstOrNull().orEmpty())
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(open)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
            if (max != null && progress != null) {
                builder.setProgress(max, progress, false)
            } else if (indeterminate) {
                builder.setProgress(0, 0, true)
            }
            return builder.build()
        }

        private const val COPY_NOTIFICATION = 4713

        /**
         * Its own notification for copying songs from a chat. Tapping it opens the app on that
         * chat's review page ([open] is handed back to Flutter). Null [max] means it's finished.
         */
        fun copyProgress(context: Context, title: String, text: String, progress: Int?, max: Int?, open: String) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Running in the background", NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                },
            )
            val tap = PendingIntent.getActivity(
                context,
                1,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra(MainActivity.OPEN_EXTRA, open),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val builder = Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_teleplayer)
                .setContentTitle(title)
                .setContentText(text)
                .setContentIntent(tap)
                .setOnlyAlertOnce(true)
                .setOngoing(max != null)
                .setAutoCancel(max == null)
            if (max != null && progress != null) builder.setProgress(max, progress, false)
            manager.notify(COPY_NOTIFICATION, builder.build())
        }

        /** Redraws the notification. Nothing happens unless the service is running. */
        fun update(
            context: Context,
            title: String,
            text: String,
            progress: Int?,
            max: Int?,
            indeterminate: Boolean,
        ) {
            if (!running) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION, build(context, title, text, progress, max, indeterminate))
        }
    }
}
