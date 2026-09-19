package com.example.caffeinated

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Status-only home screen widget: shows AWAKE/ASLEEP, tapping it opens the
 * app. No toggle here on purpose — starting/stopping stays in the app,
 * where the duration picker and countdown already live.
 *
 * KeepScreenOnService calls [refreshAll] directly whenever it starts or
 * stops, so the widget stays accurate without polling. updatePeriodMillis
 * in caffeinated_widget_info.xml (30 min, Android's practical minimum) is
 * just a defensive fallback, not the primary update path.
 */
class CaffeinatedWidgetProvider : AppWidgetProvider() {
    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CaffeinatedWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                onUpdateWidgets(context, manager, ids)
            }
        }

        private fun onUpdateWidgets(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val isRunning = KeepScreenOnService.isRunning
            val views = RemoteViews(context.packageName, R.layout.widget_caffeinated)

            views.setTextViewText(R.id.widget_status, if (isRunning) "AWAKE" else "ASLEEP")
            views.setTextColor(
                R.id.widget_status,
                if (isRunning) 0xFFE9FF4F.toInt() else 0xFFF6EFE6.toInt()
            )

            val openApp = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                openApp,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.widget_status, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_hint, pendingIntent)

            for (id in ids) {
                manager.updateAppWidget(id, views)
            }
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        onUpdateWidgets(context, manager, ids)
    }
}
