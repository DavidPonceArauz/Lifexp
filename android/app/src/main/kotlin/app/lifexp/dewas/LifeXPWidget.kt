package app.lifexp.dewas

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class LifeXPWidget : AppWidgetProvider() {

    private val PREFS = "lifexp_widget_prefs"

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val streak = prefs.getInt("streak", 0)
            val level = prefs.getInt("level", 1)
            val totalXp = prefs.getInt("total_xp", 0)
            val xpToNext = prefs.getInt("xp_to_next", 500)
            val goals = prefs.getInt("goals_count", 0)
            val tasks = prefs.getInt("tasks_today", 0)

            val habit1Name = prefs.getString("habit_1_name", "") ?: ""
            val habit1Streak = prefs.getInt("habit_1_streak", 0)
            val habit2Name = prefs.getString("habit_2_name", "") ?: ""
            val habit2Streak = prefs.getInt("habit_2_streak", 0)
            val habit3Name = prefs.getString("habit_3_name", "") ?: ""
            val habit3Streak = prefs.getInt("habit_3_streak", 0)

            val xpProgress = if (xpToNext > 0) {
                ((totalXp.toFloat() / xpToNext.toFloat()) * 100).toInt().coerceIn(0, 100)
            } else {
                0
            }

            val views = RemoteViews(context.packageName, R.layout.home_widget_layout)

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            views.setTextViewText(R.id.widget_level_badge, "LVL $level")
            views.setTextViewText(R.id.widget_xp_text, "$totalXp / $xpToNext XP")
            views.setProgressBar(R.id.widget_xp_bar, 100, xpProgress, false)
            views.setTextViewText(R.id.widget_xp_pct, "$xpProgress% al siguiente nivel")
            views.setTextViewText(R.id.widget_streak, "$streak")

            fun habitLine(name: String, streak: Int): String {
                if (name.isEmpty()) return ""
                val fire = when {
                    streak >= 30 -> "\uD83C\uDFC6"
                    streak >= 14 -> "\u26A1"
                    streak >= 7 -> "\uD83D\uDD25"
                    streak >= 3 -> "\u2726"
                    else -> "\u00B7"
                }
                val short = if (name.length > 14) name.substring(0, 14) + "\u2026" else name
                return "$fire ${short.uppercase()} ${streak}d"
            }

            views.setTextViewText(R.id.widget_habit_1, habitLine(habit1Name, habit1Streak))
            views.setTextViewText(R.id.widget_habit_2, habitLine(habit2Name, habit2Streak))
            views.setTextViewText(R.id.widget_habit_3, habitLine(habit3Name, habit3Streak))
            views.setTextViewText(R.id.widget_goals, "$goals")
            views.setTextViewText(R.id.widget_tasks, "$tasks")

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout)
            views.setTextViewText(R.id.widget_level_badge, "LVL 1")
            views.setTextViewText(R.id.widget_xp_text, "0 / 500 XP")
            views.setProgressBar(R.id.widget_xp_bar, 100, 0, false)
            views.setTextViewText(R.id.widget_xp_pct, "0% al siguiente nivel")
            views.setTextViewText(R.id.widget_streak, "0")
            views.setTextViewText(R.id.widget_habit_1, "\u00B7 Abre la app")
            views.setTextViewText(R.id.widget_habit_2, "")
            views.setTextViewText(R.id.widget_habit_3, "")
            views.setTextViewText(R.id.widget_goals, "0")
            views.setTextViewText(R.id.widget_tasks, "0")
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
