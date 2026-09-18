package com.example.supply_sync

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.app.PendingIntent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home screen widget showing the app counter.
 *
 * Tapping the widget opens the app; tapping "+" increments the counter natively
 * in the storage shared with Flutter (see lib/home_widget_sync.dart).
 */
class CounterWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.counter_widget).apply {
            setTextViewText(R.id.widget_counter, readCounter(widgetData).toString())
            setTextViewText(
                R.id.widget_updated_at,
                widgetData.getString(KEY_UPDATED_AT, null)?.let {
                  context.getString(R.string.widget_updated_at, it)
                } ?: context.getString(R.string.widget_no_data),
            )
            setOnClickPendingIntent(
                R.id.widget_container,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            setOnClickPendingIntent(R.id.widget_increment, incrementIntent(context))
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action != ACTION_INCREMENT) return

    val prefs = HomeWidgetPlugin.getData(context)
    val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
    prefs.edit().putInt(KEY_COUNTER, readCounter(prefs) + 1).putString(KEY_UPDATED_AT, time).apply()

    val manager = AppWidgetManager.getInstance(context)
    val ids = manager.getAppWidgetIds(ComponentName(context, CounterWidgetProvider::class.java))
    onUpdate(context, manager, ids, prefs)
  }

  private fun incrementIntent(context: Context): PendingIntent {
    val intent = Intent(context, CounterWidgetProvider::class.java).setAction(ACTION_INCREMENT)
    return PendingIntent.getBroadcast(
        context,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  companion object {
    private const val ACTION_INCREMENT = "com.example.supply_sync.action.INCREMENT_COUNTER"
    private const val KEY_COUNTER = "counter"
    private const val KEY_UPDATED_AT = "updated_at"

    // Flutter stores small ints as Int and large ones as Long.
    private fun readCounter(prefs: SharedPreferences): Int =
        (prefs.all[KEY_COUNTER] as? Number)?.toInt() ?: 0
  }
}
