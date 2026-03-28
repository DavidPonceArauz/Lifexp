import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/autumn_theme.dart';

// ===========================
// 🔔 NOTIFICATION CONFIG WIDGET
// ===========================

class NotificationConfig {
  final bool enabled;
  final int daysBefore;   // 0 = mismo día
  final int hour;
  final int minute;
  final int repeatTimes;
  final int repeatIntervalHours;

  const NotificationConfig({
    this.enabled = false,
    this.daysBefore = 0,  // ← default: mismo día
    this.hour = 9,
    this.minute = 0,
    this.repeatTimes = 1,
    this.repeatIntervalHours = 3,
  });

  NotificationConfig copyWith({
    bool? enabled,
    int? daysBefore,
    int? hour,
    int? minute,
    int? repeatTimes,
    int? repeatIntervalHours,
  }) =>
      NotificationConfig(
        enabled: enabled ?? this.enabled,
        daysBefore: daysBefore ?? this.daysBefore,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        repeatTimes: repeatTimes ?? this.repeatTimes,
        repeatIntervalHours: repeatIntervalHours ?? this.repeatIntervalHours,
      );

  Map<String, int> toConfigMap() => {
    'daysBefore': daysBefore,
    'hour': hour,
    'minute': minute,
    'repeatTimes': repeatTimes,
    'repeatIntervalHours': repeatIntervalHours,
  };

  String get summary {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final daysStr = daysBefore == 0
        ? 'El mismo día'
        : daysBefore == 1 ? '1 día antes' : '$daysBefore días antes';
    final repeatStr = repeatTimes == 1
        ? '1 vez'
        : '$repeatTimes veces cada ${repeatIntervalHours}h';
    return '$daysStr a las $timeStr · $repeatStr';
  }
}

// ── Widget compartido de selector de hora ─────────────────────────────────────
Widget buildTimePicker({
  required BuildContext context,
  required int hour,
  required int minute,
  required Color accentColor,
  required Future<void> Function(int hour, int minute) onPicked,
}) {
  final timeStr =
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  return GestureDetector(
    onTap: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: hour, minute: minute),
        builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                    primary: accentColor,
                    onPrimary: Colors.white,
                    surface: AutumnColors.bgCard,
                    onSurface: AutumnColors.textPrimary)),
            child: child!),
      );
      if (picked != null) await onPicked(picked.hour, picked.minute);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AutumnColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha:0.5))),
      child: Row(children: [
        Icon(Icons.access_time_rounded, size: 16, color: accentColor),
        const SizedBox(width: 10),
        Text(timeStr,
            style: GoogleFonts.pressStart2p(
                fontSize: 12,
                color: AutumnColors.textPrimary,
                fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('Toca para cambiar',
            style: GoogleFonts.pressStart2p(
                fontSize: 7, color: AutumnColors.textDisabled)),
      ]),
    ),
  );
}

// ── NotificationConfigWidget (Goals / Todos) ──────────────────────────────────
class NotificationConfigWidget extends StatefulWidget {
  final NotificationConfig config;
  final ValueChanged<NotificationConfig> onChanged;

  const NotificationConfigWidget({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<NotificationConfigWidget> createState() =>
      _NotificationConfigWidgetState();
}

class _NotificationConfigWidgetState extends State<NotificationConfigWidget> {
  late NotificationConfig _cfg;

  @override
  void initState() {
    super.initState();
    _cfg = widget.config;
  }

  void _update(NotificationConfig newCfg) {
    setState(() => _cfg = newCfg);
    widget.onChanged(newCfg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cfg.enabled
            ? AutumnColors.accentOrange.withValues(alpha:0.06)
            : AutumnColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _cfg.enabled
              ? AutumnColors.accentOrange.withValues(alpha:0.5)
              : AutumnColors.divider,
          width: _cfg.enabled ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => _update(_cfg.copyWith(enabled: !_cfg.enabled)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _cfg.enabled
                      ? AutumnColors.accentOrange
                      : AutumnColors.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _cfg.enabled
                          ? AutumnColors.accentOrange
                          : AutumnColors.divider),
                ),
                child: _cfg.enabled
                    ? const Icon(Icons.notifications_active,
                    color: Colors.white, size: 16)
                    : const Icon(Icons.notifications_none,
                    color: AutumnColors.textDisabled, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECORDATORIO',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 8,
                              color: _cfg.enabled
                                  ? AutumnColors.accentOrange
                                  : AutumnColors.textDisabled)),
                      if (_cfg.enabled) ...[
                        const SizedBox(height: 2),
                        Text(_cfg.summary,
                            style: GoogleFonts.pressStart2p(
                                fontSize: 6, color: AutumnColors.textSecondary)),
                      ],
                    ],
                  )),
              Icon(
                  _cfg.enabled
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AutumnColors.textDisabled,
                  size: 18),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _cfg.enabled
              ? Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AutumnColors.divider, height: 14),
                  _cfgLabel('CUÁNDO NOTIFICAR'),
                  const SizedBox(height: 6),
                  _daySelector(),
                  const SizedBox(height: 12),
                  _cfgLabel('HORA DE LA NOTIFICACIÓN'),
                  const SizedBox(height: 6),
                  buildTimePicker(
                    context: context,
                    hour: _cfg.hour,
                    minute: _cfg.minute,
                    accentColor: AutumnColors.accentOrange,
                    onPicked: (h, m) async =>
                        _update(_cfg.copyWith(hour: h, minute: m)),
                  ),
                  const SizedBox(height: 12),
                  _cfgLabel('REPETIR'),
                  const SizedBox(height: 6),
                  _repeatSelector(),
                ]),
          )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _daySelector() {
    // 0 = mismo día, 1 = 1 día antes, etc.
    const options = [
      {'value': 0, 'label': 'DIA',  'sub': 'mismo día'},
      {'value': 1, 'label': '1D',   'sub': '1 día antes'},
      {'value': 2, 'label': '2D',   'sub': '2 días antes'},
      {'value': 3, 'label': '3D',   'sub': '3 días antes'},
      {'value': 7, 'label': '7D',   'sub': '1 semana antes'},
    ];
    return Row(
        children: options.map((opt) {
          final val = opt['value'] as int;
          final sel = _cfg.daysBefore == val;
          return Expanded(
              child: GestureDetector(
                onTap: () => _update(_cfg.copyWith(daysBefore: val)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  margin: const EdgeInsets.only(right: 5),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                      color: sel ? AutumnColors.accentOrange : AutumnColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sel
                              ? AutumnColors.accentOrange
                              : AutumnColors.divider)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(opt['label'] as String,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 9,
                            color: sel ? Colors.white : AutumnColors.textPrimary,
                            fontWeight: FontWeight.bold)),
                    Text(opt['sub'] as String,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 5,
                            color: sel ? Colors.white70 : AutumnColors.textDisabled),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ));
        }).toList());
  }

  Widget _repeatSelector() {
    return Column(children: [
      Row(children: [
        _cfgLabel('Veces:'),
        const SizedBox(width: 10),
        ...[1, 2, 3].map((n) {
          final sel = _cfg.repeatTimes == n;
          return GestureDetector(
            onTap: () => _update(_cfg.copyWith(repeatTimes: n)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                  color: sel ? AutumnColors.accentOrange : AutumnColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel
                          ? AutumnColors.accentOrange
                          : AutumnColors.divider)),
              child: Center(
                  child: Text('$n',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: sel ? Colors.white : AutumnColors.textPrimary,
                          fontWeight: FontWeight.bold))),
            ),
          );
        }),
      ]),
      if (_cfg.repeatTimes > 1) ...[
        const SizedBox(height: 10),
        Row(children: [
          _cfgLabel('Cada:'),
          const SizedBox(width: 10),
          ...[1, 2, 3, 6].map((h) {
            final sel = _cfg.repeatIntervalHours == h;
            return GestureDetector(
              onTap: () => _update(_cfg.copyWith(repeatIntervalHours: h)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    color: sel ? AutumnColors.accentGold : AutumnColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel
                            ? AutumnColors.accentGold
                            : AutumnColors.divider)),
                child: Text('${h}h',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: sel ? Colors.white : AutumnColors.textPrimary)),
              ),
            );
          }),
        ]),
      ],
    ]);
  }

  Widget _cfgLabel(String text) => Text(text,
      style: GoogleFonts.pressStart2p(
          fontSize: 7, color: AutumnColors.textDisabled));
}

// ── HabitReminderWidget ───────────────────────────────────────────────────────
class HabitReminderWidget extends StatefulWidget {
  final bool enabled;
  final int hour;
  final int minute;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const HabitReminderWidget({
    super.key,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  @override
  State<HabitReminderWidget> createState() => _HabitReminderWidgetState();
}

class _HabitReminderWidgetState extends State<HabitReminderWidget> {
  late bool _enabled;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _hour = widget.hour;
    _minute = widget.minute;
  }

  @override
  void didUpdateWidget(HabitReminderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.hour != widget.hour ||
        oldWidget.minute != widget.minute) {
      setState(() {
        _enabled = widget.enabled;
        _hour = widget.hour;
        _minute = widget.minute;
      });
    }
  }

  void _notify() => widget.onChanged({
    'enabled': _enabled,
    'hour': _hour,
    'minute': _minute,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: _enabled
            ? AutumnColors.mossGreen.withValues(alpha:0.07)
            : AutumnColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _enabled
                ? AutumnColors.mossGreen.withValues(alpha:0.5)
                : AutumnColors.divider,
            width: _enabled ? 1.5 : 1),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () {
            setState(() => _enabled = !_enabled);
            _notify();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: _enabled
                        ? AutumnColors.mossGreen
                        : AutumnColors.bgCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _enabled
                            ? AutumnColors.mossGreen
                            : AutumnColors.divider)),
                child: Icon(_enabled ? Icons.alarm_on : Icons.alarm_off,
                    color:
                    _enabled ? Colors.white : AutumnColors.textDisabled,
                    size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECORDATORIO DIARIO',
                            style: GoogleFonts.pressStart2p(
                                fontSize: 8,
                                color: _enabled
                                    ? AutumnColors.mossGreen
                                    : AutumnColors.textDisabled)),
                        if (_enabled)
                          Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Todos los días a las $timeStr',
                                  style: GoogleFonts.pressStart2p(
                                      fontSize: 6,
                                      color: AutumnColors.textSecondary))),
                      ])),
              Icon(
                  _enabled
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AutumnColors.textDisabled,
                  size: 18),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _enabled
              ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
              const Divider(color: AutumnColors.divider, height: 14),
              buildTimePicker(
                context: context,
                hour: _hour,
                minute: _minute,
                accentColor: AutumnColors.mossGreen,
                onPicked: (h, m) async {
                  setState(() {
                    _hour = h;
                    _minute = m;
                  });
                  _notify();
                },
              ),
            ]),
          )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}