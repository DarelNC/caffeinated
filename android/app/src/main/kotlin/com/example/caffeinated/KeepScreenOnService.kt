package com.example.caffeinated

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class KeepScreenOnService : Service() {
    companion object {
        const val EXTRA_DURATION_MINUTES = "durationMinutes"
        private const val NOTIFICATION_CHANNEL_ID = "keep_screen_on_channel"
        private const val NOTIFICATION_ID = 1

        // Read by MainActivity so the Dart side can ask "is this actually
        // running" instead of trusting an optimistic local toggle.
        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private val stopHandler = Handler(Looper.getMainLooper())
    private var stopRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val durationMinutes = intent?.getIntExtra(EXTRA_DURATION_MINUTES, 0) ?: 0
        val endTimeMillis = if (durationMinutes > 0) {
            System.currentTimeMillis() + durationMinutes * 60_000L
        } else {
            null
        }

        startForeground(NOTIFICATION_ID, buildNotification(endTimeMillis))
        acquireWakeLock()
        scheduleAutoStop(durationMinutes)

        isRunning = true
        return START_NOT_STICKY
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return

        val pm = getSystemService(POWER_SERVICE) as PowerManager
        // No ACQUIRE_CAUSES_WAKEUP: this keeps the screen on, it doesn't
        // force it on/unlock it the instant the service starts.
        wakeLock = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK,
            "Caffeinated::KeepScreenOnWakeLock"
        )
        wakeLock?.acquire()
    }

    private fun scheduleAutoStop(durationMinutes: Int) {
        stopRunnable?.let { stopHandler.removeCallbacks(it) }
        stopRunnable = null

        if (durationMinutes <= 0) return // 0 = infinite, no auto-stop

        val runnable = Runnable { stopSelf() }
        stopRunnable = runnable
        stopHandler.postDelayed(runnable, durationMinutes * 60_000L)
    }

    private fun buildNotification(endTimeMillis: Long?): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Caffeinated is active")
            .setSmallIcon(R.drawable.ic_caffeinated_on_large)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)

        if (endTimeMillis != null) {
            // A native chronometer ticks this down every second on its own —
            // no repeated notify() calls needed to keep it "live".
            builder
                .setContentText("Screen stays on until the countdown ends.")
                .setWhen(endTimeMillis)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
        } else {
            builder.setContentText("Screen will stay on until you stop it.")
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Keep Screen On",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows while Caffeinated is keeping the screen on"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRunnable?.let { stopHandler.removeCallbacks(it) }
        stopRunnable = null
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        wakeLock = null
        isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
