import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  final _tapController = StreamController<String>.broadcast();
  Stream<String> get onNotificationTap => _tapController.stream;

  String? _pendingColdStartPayload;
  String? consumeColdStartPayload() {
    final p = _pendingColdStartPayload;
    _pendingColdStartPayload = null;
    return p;
  }

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    _setLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _checkLaunchNotification();
    _initialized = true;
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _tapController.add(payload);
    }
  }

  Future<void> _checkLaunchNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _pendingColdStartPayload = payload;
      }
    }
  }

  void _setLocalTimezone() {
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
      return;
    } catch (_) {}

    const shortNameMap = {
      'ECT': 'America/Guayaquil',
      'COT': 'America/Bogota',
      'PET': 'America/Lima',
      'VET': 'America/Caracas',
      'BOT': 'America/La_Paz',
      'BRT': 'America/Sao_Paulo',
      'ART': 'America/Argentina/Buenos_Aires',
      'CLT': 'America/Santiago',
      'UYT': 'America/Montevideo',
      'PYT': 'America/Asuncion',
      'EST': 'America/New_York',
      'CST': 'America/Chicago',
      'MST': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'AST': 'America/Halifax',
      'GMT': 'Europe/London',
      'CET': 'Europe/Paris',
      'EET': 'Europe/Athens',
      'IST': 'Asia/Kolkata',
      'JST': 'Asia/Tokyo',
      'AEST': 'Australia/Sydney',
    };

    try {
      final mapped = shortNameMap[DateTime.now().timeZoneName];
      if (mapped != null) {
        tz.setLocalLocation(tz.getLocation(mapped));
        return;
      }
    } catch (_) {}

    try {
      final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
      for (final entry in tz.timeZoneDatabase.locations.entries) {
        if (tz.TZDateTime.now(entry.value).timeZoneOffset.inMinutes ==
            offsetMinutes) {
          tz.setLocalLocation(entry.value);
          return;
        }
      }
    } catch (_) {}

    try {
      final h = DateTime.now().timeZoneOffset.inHours;
      tz.setLocalLocation(tz.getLocation('Etc/GMT${h <= 0 ? '+' : '-'}${h.abs()}'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'lifexp_reminders',
          'LifeXP Recordatorios',
          channelDescription: 'Recordatorios de metas, objetivos y tareas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  NotificationDetails _habitDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'lifexp_habits_v2',
          'LifeXP Habitos',
          channelDescription: 'Recordatorios diarios de habitos',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  NotificationDetails _calendarDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'lifexp_calendar',
          'LifeXP Calendario',
          channelDescription: 'Recordatorios de eventos del calendario',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  Future<void> scheduleDeadlineNotifications({
    required int itemId,
    required String itemType,
    required String title,
    required DateTime deadline,
    required Map<String, dynamic> config,
  }) async {
    if (!_initialized) await init();
    await cancelItemNotifications(itemId: itemId, itemType: itemType);

    final reminderDays = _extractReminderDays(config);
    final hour = _asInt(config['hour'], fallback: 9);
    final minute = _asInt(config['minute'], fallback: 0);
    final repeatTimes = _asInt(config['repeatTimes'], fallback: 1);
    final repeatIntervalHrs =
        _asInt(config['repeatIntervalHours'], fallback: 3);
    final payload = _payloadForType(itemType);
    final deadlineTZ = tz.TZDateTime.from(
      DateTime(deadline.year, deadline.month, deadline.day, 23, 59),
      tz.local,
    );

    for (final daysBefore in reminderDays) {
      final notifDate = DateTime(
        deadline.year,
        deadline.month,
        deadline.day - daysBefore,
        hour,
        minute,
      );
      final firstNotif = tz.TZDateTime.from(notifDate, tz.local);
      if (firstNotif.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final body = _deadlineBody(itemType, daysBefore);
      for (int i = 0; i < repeatTimes; i++) {
        final notifTime = firstNotif.add(Duration(hours: i * repeatIntervalHrs));
        if (notifTime.isBefore(tz.TZDateTime.now(tz.local))) continue;
        if (notifTime.isAfter(deadlineTZ)) continue;

        await _scheduleZoned(
          id: _buildNotifId(itemId, itemType, daysBefore, i),
          title: title,
          body: body,
          scheduledDate: notifTime,
          details: _details(),
          payload: payload,
        );
      }
    }
  }

  Future<void> scheduleCalendarEventNotification({
    required int eventId,
    required String title,
    required String date,
    String? time,
    Map<String, dynamic>? notifConfig,
    String? notes,
  }) async {
    if (!_initialized) await init();
    await cancelCalendarEventNotification(eventId);

    try {
      final eventDate = DateTime.parse(date);

      int hour;
      int minute;
      if (notifConfig != null) {
        hour = _asInt(notifConfig['hour'], fallback: 9);
        minute = _asInt(notifConfig['minute'], fallback: 0);
      } else if (time != null && time.isNotEmpty) {
        final parts = time.split(':');
        hour = int.tryParse(parts[0]) ?? 9;
        minute = int.tryParse(parts[1]) ?? 0;
      } else {
        hour = 9;
        minute = 0;
      }

      final reminderDays = _extractReminderDays(notifConfig ?? const {});
      final repeatTimes = _asInt(notifConfig?['repeatTimes'], fallback: 1);
      final repeatIntervalHrs =
          _asInt(notifConfig?['repeatIntervalHours'], fallback: 3);
      final deadlineTZ = tz.TZDateTime.from(
        DateTime(eventDate.year, eventDate.month, eventDate.day, 23, 59),
        tz.local,
      );

      for (final daysBefore in reminderDays) {
        final notifDate = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day - daysBefore,
          hour,
          minute,
        );
        final firstNotif = tz.TZDateTime.from(notifDate, tz.local);
        if (firstNotif.isBefore(tz.TZDateTime.now(tz.local))) continue;

        final body = notes != null && notes.isNotEmpty
            ? notes
            : daysBefore == 0
                ? 'Tienes un evento hoy'
                : 'Evento en $daysBefore dia${daysBefore != 1 ? "s" : ""}';

        for (int i = 0; i < repeatTimes; i++) {
          final notifTime = firstNotif.add(Duration(hours: i * repeatIntervalHrs));
          if (notifTime.isBefore(tz.TZDateTime.now(tz.local))) continue;
          if (notifTime.isAfter(deadlineTZ)) continue;

          await _scheduleZoned(
            id: _buildCalendarNotifId(eventId, daysBefore, i),
            title: title,
            body: body,
            scheduledDate: notifTime,
            details: _calendarDetails(),
            payload: 'home',
          );
        }
      }
    } catch (e) {
      debugPrint('scheduleCalendarEventNotification error: $e');
    }
  }

  Future<void> scheduleHabitReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await init();
    await cancelHabitReminder();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _scheduleZoned(
      id: _habitReminderId,
      title: 'LifeXP - Habitos del dia',
      body: 'Ya completaste tus habitos de hoy?',
      scheduledDate: scheduled,
      details: _habitDetails(),
      payload: 'habits',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelItemNotifications({
    required int itemId,
    required String itemType,
  }) async {
    if (!_initialized) await init();
    for (final daysBefore in _supportedReminderDays) {
      for (int i = 0; i < 5; i++) {
        await _plugin.cancel(_buildNotifId(itemId, itemType, daysBefore, i));
      }
    }
  }

  Future<void> cancelCalendarEventNotification(int eventId) async {
    if (!_initialized) await init();
    for (final daysBefore in _supportedReminderDays) {
      for (int i = 0; i < 5; i++) {
        await _plugin.cancel(_buildCalendarNotifId(eventId, daysBefore, i));
      }
    }
  }

  Future<void> cancelHabitReminder() async {
    if (!_initialized) await init();
    await _plugin.cancel(_habitReminderId);
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

  static const _prefixes = {'goal': 1, 'objective': 2, 'todo': 3};
  static const _habitReminderId = 9999;
  static const _calendarPrefix = 4;
  static const _supportedReminderDays = [0, 1, 3, 7];

  List<int> _extractReminderDays(Map<String, dynamic> config) {
    final raw = config['reminderDays'];
    if (raw is List) {
      final values = raw.whereType<int>().toSet().toList()..sort();
      if (values.isNotEmpty) {
        return values;
      }
    }
    final legacy = config['daysBefore'];
    if (legacy is int) {
      return [legacy];
    }
    return const [0];
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return fallback;
  }

  Future<void> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint('zonedSchedule exact failed for $id, retrying inexact: $e');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }
  }

  String _deadlineBody(String itemType, int daysBefore) {
    switch (itemType) {
      case 'goal':
        return daysBefore == 0
            ? 'Tu meta vence HOY'
            : 'Tu meta vence en $daysBefore dia${daysBefore != 1 ? "s" : ""}';
      case 'objective':
        return daysBefore == 0
            ? 'Un objetivo vence HOY'
            : 'Un objetivo vence en $daysBefore dia${daysBefore != 1 ? "s" : ""}';
      case 'todo':
        return daysBefore == 0
            ? 'Una tarea vence HOY'
            : 'Una tarea vence en $daysBefore dia${daysBefore != 1 ? "s" : ""}';
      default:
        return 'Recordatorio LifeXP';
    }
  }

  int _buildNotifId(
    int itemId,
    String itemType,
    int daysBefore,
    int repetitionIndex,
  ) {
    final prefix = _prefixes[itemType] ?? 9;
    return prefix * 1000000 + itemId * 100 + daysBefore * 10 + repetitionIndex;
  }

  int _buildCalendarNotifId(int eventId, int daysBefore, int repetitionIndex) {
    return _calendarPrefix * 1000000 +
        eventId * 100 +
        daysBefore * 10 +
        repetitionIndex;
  }

  String _payloadForType(String itemType) {
    switch (itemType) {
      case 'goal':
      case 'objective':
        return 'goals';
      case 'todo':
        return 'todo';
      default:
        return 'habits';
    }
  }
}

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {}
