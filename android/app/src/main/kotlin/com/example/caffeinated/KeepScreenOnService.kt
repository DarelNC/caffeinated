package com.example.caffeinated

import android.app.*
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class KeepScreenOnService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        val channelId = "keep_screen_on_channel"
        val channelName = "Keep Screen On"

        val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Mantener pantalla activa")
            .setContentText("La pantalla no se apagará")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .build()

        startForeground(1, notification)

        val pm = getSystemService(POWER_SERVICE) as PowerManager
        // wakeLock = pm.newWakeLock(
        //     PowerManager.SCREEN_DIM_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
        //     "KeepScreenOn::Wakelock"
        // )
        wakeLock = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "KeepScreenOn::WakeLock"
        )

        wakeLock?.acquire()
    }

    override fun onDestroy() {
        super.onDestroy()
        wakeLock?.release()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
