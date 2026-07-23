package com.example.nihongo_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NihongoSmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nihongo_small_widget_layout).apply {
                val kanji = widgetData.getString("widget_kanji", "愛") ?: "愛"
                val meaning = widgetData.getString("widget_meaning", "love") ?: "love"

                setTextViewText(R.id.tv_small_widget_kanji, kanji)
                setTextViewText(R.id.tv_small_widget_meaning, meaning)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.small_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}