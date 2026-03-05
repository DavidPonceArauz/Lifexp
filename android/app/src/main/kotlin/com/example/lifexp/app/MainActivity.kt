package com.example.lifexp

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.lifexp/widget"
    private val PREFS   = "lifexp_widget_prefs"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val editor = prefs.edit()

                    val streak        = call.argument<Int>("streak")        ?: -1
                    val level         = call.argument<Int>("level")         ?: -1
                    val totalXp       = call.argument<Int>("total_xp")      ?: -1
                    val xpToNext      = call.argument<Int>("xp_to_next")    ?: -1
                    val goalsCount    = call.argument<Int>("goals_count")   ?: -1
                    val tasksToday    = call.argument<Int>("tasks_today")   ?: -1
                    val habit1Name    = call.argument<String>("habit_1_name")   ?: ""
                    val habit1Streak  = call.argument<Int>("habit_1_streak")    ?: -1
                    val habit2Name    = call.argument<String>("habit_2_name")   ?: ""
                    val habit2Streak  = call.argument<Int>("habit_2_streak")    ?: -1
                    val habit3Name    = call.argument<String>("habit_3_name")   ?: ""
                    val habit3Streak  = call.argument<Int>("habit_3_streak")    ?: -1

                    if (streak      >= 0) editor.putInt("streak",       streak)
                    if (level       >= 0) editor.putInt("level",        level)
                    if (totalXp     >= 0) editor.putInt("total_xp",     totalXp)
                    if (xpToNext    >= 0) editor.putInt("xp_to_next",   xpToNext)
                    if (goalsCount  >= 0) editor.putInt("goals_count",  goalsCount)
                    if (tasksToday  >= 0) editor.putInt("tasks_today",  tasksToday)
                    if (habit1Name.isNotEmpty())  editor.putString("habit_1_name",   habit1Name)
                    if (habit1Streak >= 0)        editor.putInt("habit_1_streak",    habit1Streak)
                    if (habit2Name.isNotEmpty())  editor.putString("habit_2_name",   habit2Name)
                    if (habit2Streak >= 0)        editor.putInt("habit_2_streak",    habit2Streak)
                    if (habit3Name.isNotEmpty())  editor.putString("habit_3_name",   habit3Name)
                    if (habit3Streak >= 0)        editor.putInt("habit_3_streak",    habit3Streak)
                    editor.apply()

                    val manager   = AppWidgetManager.getInstance(applicationContext)
                    val component = ComponentName(applicationContext, LifeXPWidget::class.java)
                    val widgetIds = manager.getAppWidgetIds(component)
                    if (widgetIds.isNotEmpty()) {
                        LifeXPWidget().onUpdate(applicationContext, manager, widgetIds)
                    }

                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
