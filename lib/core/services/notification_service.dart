import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// ===========================
// 🔔 NOTIFICATION SERVICE
// ===========================

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

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    _setLocalTimezone();

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

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

  // ── Timezone ───────────────────────────────────────────────────────────────
  void _setLocalTimezone() {
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
      return;
    } catch (_) {}

    const shortNameMap = {
      'ECT': 'America/Guayaquil', 'COT': 'America/Bogota',
      'PET': 'America/Lima',      'VET': 'America/Caracas',
      'BOT': 'America/La_Paz',    'BRT': 'America/Sao_Paulo',
      'ART': 'America/Argentina/Buenos_Aires',
      'CLT': 'America/Santiago',  'UYT': 'America/Montevideo',
      'PYT': 'America/Asuncion',  'EST': 'America/New_York',
      'CST': 'America/Chicago',   'MST': 'America/Denver',
      'PST': 'America/Los_Angeles', 'AST': 'America/Halifax',
      'GMT': 'Europe/London',     'CET': 'Europe/Paris',
      'EET': 'Europe/Athens',     'IST': 'Asia/Kolkata',
      'JST': 'Asia/Tokyo',        'AEST': 'Australia/Sydney',
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
      tz.setLocalLocation(
          tz.getLocation('Etc/GMT${h <= 0 ? '+' : '-'}${h.abs()}'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  // ── Notification details ───────────────────────────────────────────────────
  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'lifexp_reminders', 'LifeXP Recordatorios',
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
      'lifexp_habits_v2', 'LifeXP Hábitos',
      channelDescription: 'Recordatorios diarios de hábitos',
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

  // ── Schedule deadline notifications ───────────────────────────────────────
  /// daysBefore = 0 → notifica el mismo día del deadline a la hora indicada
  /// daysBefore = 1 → notifica 1 día antes, etc.
  Future<void> scheduleDeadlineNotifications({
    required int itemId,
    required String itemType,
    required String title,
    required DateTime deadline,
    required Map<String, int> config,
  }) async {
    if (!_initialized) await init();
    await cancelItemNotifications(itemId: itemId, itemType: itemType);

    final daysBefore        = config['daysBefore'] ?? 0;
    final hour              = config['hour'] ?? 9;
    final minute            = config['minute'] ?? 0;
    final repeatTimes       = config['repeatTimes'] ?? 1;
    final repeatIntervalHrs = config['repeatIntervalHours'] ?? 3;
    final payload           = _payloadForType(itemType);

    // ── Calcular fecha base de la primera notificación ─────────────────────
    // daysBefore=0 → mismo día del deadline
    // daysBefore=1 → un día antes, etc.
    final notifDate = DateTime(
      deadline.year,
      deadline.month,
      deadline.day - daysBefore,
      hour,
      minute,
    );

    final firstNotif = tz.TZDateTime.from(notifDate, tz.local);

    // Si la hora ya pasó hoy (mismo día) simplemente no programamos
    if (firstNotif.isBefore(tz.TZDateTime.now(tz.local))) return;

    final bodies = {
      'goal':      daysBefore == 0
          ? '🎯 Tu meta vence HOY'
          : '🎯 Tu meta vence en $daysBefore día${daysBefore != 1 ? "s" : ""}',
      'objective': daysBefore == 0
          ? '📋 Un objetivo vence HOY'
          : '📋 Un objetivo vence pronto',
      'todo':      daysBefore == 0
          ? '✅ Una tarea vence HOY'
          : '✅ Una tarea vence en $daysBefore día${daysBefore != 1 ? "s" : ""}',
    };

    for (int i = 0; i < repeatTimes; i++) {
      final notifTime = firstNotif.add(Duration(hours: i * repeatIntervalHrs));
      if (notifTime.isBefore(tz.TZDateTime.now(tz.local))) continue;
      // No programar más allá del día del deadline
      final deadlineTZ = tz.TZDateTime.from(
          DateTime(deadline.year, deadline.month, deadline.day, 23, 59),
          tz.local);
      if (notifTime.isAfter(deadlineTZ)) continue;

      await _plugin.zonedSchedule(
        _buildNotifId(itemId, itemType, i),
        title,
        bodies[itemType] ?? 'Recordatorio LifeXP',
        notifTime,
        _details(),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ── Schedule daily habit reminder ──────────────────────────────────────────
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

    await _plugin.zonedSchedule(
      _habitReminderId,
      'LifeXP — Hábitos del día 🔥',
      '¿Ya completaste tus hábitos de hoy?',
      scheduled,
      _habitDetails(),
      payload: 'habits',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────
  Future<void> cancelItemNotifications(
      {required int itemId, required String itemType}) async {
    if (!_initialized) await init();
    for (int i = 0; i < 5; i++) {
      await _plugin.cancel(_buildNotifId(itemId, itemType, i));
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

  // ── IDs & helpers ──────────────────────────────────────────────────────────
  static const _prefixes        = {'goal': 1, 'objective': 2, 'todo': 3};
  static const _habitReminderId = 9999;

  int _buildNotifId(int itemId, String itemType, int repetitionIndex) {
    final prefix = _prefixes[itemType] ?? 9;
    return prefix * 100000 + itemId * 10 + repetitionIndex;
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

// Top-level — requerido por flutter_local_notifications para background
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {}