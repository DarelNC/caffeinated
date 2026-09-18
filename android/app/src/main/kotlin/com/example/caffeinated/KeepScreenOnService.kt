package com.example.caffeinated

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.CountDownTimer
import android.os.IBinder
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
    private var countDownTimer: CountDownTimer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val durationMinutes = intent?.getIntExtra(EXTRA_DURATION_MINUTES, 0) ?: 0

        startForeground(NOTIFICATION_ID, buildNotification(durationMinutes))
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
        countDownTimer?.cancel()
        countDownTimer = null

        if (durationMinutes <= 0) return // 0 = infinite, no auto-stop

        val totalMillis = durationMinutes * 60_000L
        countDownTimer = object : CountDownTimer(totalMillis, 30_000L) {
            override fun onTick(millisUntilFinished: Long) {
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, buildNotification(durationMinutes, millisUntilFinished))
            }

            override fun onFinish() {
                stopSelf()
            }
        }.also { it.start() }
    }

    private fun buildNotification(durationMinutes: Int, millisRemaining: Long? = null): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val contentText = when {
            durationMinutes <= 0 -> "Screen will stay on until you stop it."
            millisRemaining != null -> "Screen stays on for ${formatRemaining(millisRemaining)} more."
            else -> "Screen stays on for $durationMinutes min."
        }

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Caffeinated is active")
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_caffeinated_on_large)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun formatRemaining(millis: Long): String {
        val totalSeconds = millis / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return if (minutes > 0) "${minutes}m ${seconds}s" else "${seconds}s"
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
        countDownTimer?.cancel()
        countDownTimer = null
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        wakeLock = null
        isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
