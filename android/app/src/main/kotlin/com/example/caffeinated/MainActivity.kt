package com.example.caffeinated

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "foreground_service"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startService" -> {
                    try {
                        val durationMinutes = call.argument<Int>("durationMinutes") ?: 0
                        val intent = Intent(this, KeepScreenOnService::class.java)
                        intent.putExtra(KeepScreenOnService.EXTRA_DURATION_MINUTES, durationMinutes)
                        startForegroundService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopService" -> {
                    try {
                        stopService(Intent(this, KeepScreenOnService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "isServiceRunning" -> {
                    result.success(KeepScreenOnService.isRunning)
                }
                "getStatus" -> {
                    result.success(
                        mapOf(
                            "isRunning" to KeepScreenOnService.isRunning,
                            "endTimeMillis" to KeepScreenOnService.currentEndTimeMillis,
                        )
                    )
                }
                "refreshNotification" -> {
                    try {
                        if (KeepScreenOnService.isRunning) {
                            val intent = Intent(this, KeepScreenOnService::class.java)
                            intent.putExtra(KeepScreenOnService.EXTRA_REFRESH_ONLY, true)
                            startForegroundService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("REFRESH_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
