package com.boitexinfo.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent // ✅ ADDED THIS IMPORT

class ServiceDashboardWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.service_dashboard_widget).apply {
                // 1. Set the text counts
                val interventions = widgetData.getString("interventions_count", "0")
                val installations = widgetData.getString("installations_count", "0")
                val sav = widgetData.getString("sav_count", "0")
                val missions = widgetData.getString("missions_count", "0")

                setTextViewText(R.id.tv_interventions_count, interventions)
                setTextViewText(R.id.tv_installations_count, installations)
                setTextViewText(R.id.tv_sav_count, sav)
                setTextViewText(R.id.tv_missions_count, missions)

                // 2. ✅ ATTACH CLICK LISTENERS (SMART NAVIGATION)

                // Interventions Click
                val intentInterventions = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, android.net.Uri.parse("boitexwidget://interventions")
                )
                setOnClickPendingIntent(R.id.card_interventions, intentInterventions)

                // Installations Click
                val intentInstallations = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, android.net.Uri.parse("boitexwidget://installations")
                )
                setOnClickPendingIntent(R.id.card_installations, intentInstallations)

                // SAV Click
                val intentSav = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, android.net.Uri.parse("boitexwidget://sav")
                )
                setOnClickPendingIntent(R.id.card_sav, intentSav)

                // Missions Click
                val intentMissions = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, android.net.Uri.parse("boitexwidget://missions")
                )
                setOnClickPendingIntent(R.id.card_missions, intentMissions)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}