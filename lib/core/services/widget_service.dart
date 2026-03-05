import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Escribe datos en SharedPreferences nativo de Android
/// y dispara la actualizacion del widget via MethodChannel.
class WidgetService {
  static const _channel = MethodChannel('com.example.lifexp/widget');

  static Future<void> init() async {}

  static Future<void> updateWidget({
    int streak      = -1,
    int level       = -1,
    int totalXp     = -1,
    int xpToNext    = -1,
    int goalsCount  = -1,
    int tasksToday  = -1,
    // Hábitos (nombre + racha, hasta 3)
    String habit1Name   = '',
    int    habit1Streak = -1,
    String habit2Name   = '',
    int    habit2Streak = -1,
    String habit3Name   = '',
    int    habit3Streak = -1,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'streak':        streak,
        'level':         level,
        'total_xp':      totalXp,
        'xp_to_next':    xpToNext,
        'goals_count':   goalsCount,
        'tasks_today':   tasksToday,
        'habit_1_name':   habit1Name,
        'habit_1_streak': habit1Streak,
        'habit_2_name':   habit2Name,
        'habit_2_streak': habit2Streak,
        'habit_3_name':   habit3Name,
        'habit_3_streak': habit3Streak,
      });
    } catch (e) {
      debugPrint('WidgetService updateWidget error: $e');
    }
  }
}