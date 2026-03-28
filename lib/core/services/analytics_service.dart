import 'package:posthog_flutter/posthog_flutter.dart';

class AnalyticsService {
  static const _apiKey = 'phc_XzHMZphHmpnlZcuHY9Njdgq7Ep6a6BHJyy1FQNNzmNs';
  static const _host   = 'https://us.i.posthog.com';

  static Future<void> init() async {
    final config = PostHogConfig(_apiKey)
      ..host = _host
      ..flushAt = 1                              // ← envía cada evento inmediatamente
      ..flushInterval = const Duration(seconds: 20) // ← flush cada 5 segundos
      ..captureApplicationLifecycleEvents = true
      ..debug = false;
    await Posthog().setup(config);
  }

  static Future<void> identify(String userId, {String? email}) async {
    await Posthog().identify(
      userId: userId,
      userProperties: email != null ? {'email': email} : null,
    );
  }

  static Future<void> reset() async {
    await Posthog().reset();
  }

  static Future<void> habitCompleted({
    required int habitId,
    required String habitName,
    required String category,
    required int currentStreak,
  }) async {
    await Posthog().capture(
      eventName: 'habit_completed',
      properties: {
        'habit_id':       habitId,
        'habit_name':     habitName,
        'category':       category,
        'current_streak': currentStreak,
      },
    );
  }

  static Future<void> habitCreated({
    required String habitName,
    required String category,
  }) async {
    await Posthog().capture(
      eventName: 'habit_created',
      properties: {'habit_name': habitName, 'category': category},
    );
  }

  static Future<void> levelUp({
    required int newLevel,
    required int totalXp,
  }) async {
    await Posthog().capture(
      eventName: 'level_up',
      properties: {'new_level': newLevel, 'total_xp': totalXp},
    );
  }

  static Future<void> streakMilestone({
    required int habitId,
    required String habitName,
    required int streakDays,
  }) async {
    await Posthog().capture(
      eventName: 'streak_milestone',
      properties: {
        'habit_id':    habitId,
        'habit_name':  habitName,
        'streak_days': streakDays,
      },
    );
  }

  static Future<void> goalCreated({
    required String title,
    required String priority,
  }) async {
    await Posthog().capture(
      eventName: 'goal_created',
      properties: {'title': title, 'priority': priority},
    );
  }

  static Future<void> goalCompleted({required String title}) async {
    await Posthog().capture(
      eventName: 'goal_completed',
      properties: {'title': title},
    );
  }

  static Future<void> freezeUsed({
    required int habitId,
    required String habitName,
  }) async {
    await Posthog().capture(
      eventName: 'freeze_used',
      properties: {'habit_id': habitId, 'habit_name': habitName},
    );
  }

  static Future<void> screenViewed(String screenName) async {
    await Posthog().screen(screenName: screenName);
  }
}