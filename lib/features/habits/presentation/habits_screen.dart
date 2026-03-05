import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/widgets/autumn_widgets.dart';
import '../../../core/widgets/notification_config_widget.dart';
import '../../../core/services/notification_service.dart';
import '../domain/habit.dart';
import 'providers/habits_provider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/celebration_overlay.dart';
import '../../../core/widgets/xp_toast.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  final String userId;
  const HabitsScreen({super.key, required this.userId});
  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const List<Map<String, String>> _categories = [
    {'label': 'Personal', 'emoji': '🧘'},
    {'label': 'Salud / Fitness', 'emoji': '💪'},
    {'label': 'Meditación', 'emoji': '🕯️'},
    {'label': 'Sueño / Descanso', 'emoji': '😴'},
    {'label': 'Alimentación', 'emoji': '🥗'},
    {'label': 'Hidratación', 'emoji': '💧'},
    {'label': 'Estudio / Educación', 'emoji': '📚'},
    {'label': 'Lectura / Libros', 'emoji': '📖'},
    {'label': 'Idiomas', 'emoji': '🌐'},
    {'label': 'Cursos Online', 'emoji': '🖥️'},
    {'label': 'Investigación', 'emoji': '🔬'},
    {'label': 'Trabajo / Laboral', 'emoji': '💼'},
    {'label': 'Finanzas / Ahorro', 'emoji': '💰'},
    {'label': 'Emprendimiento', 'emoji': '🚀'},
    {'label': 'Networking', 'emoji': '🤝'},
    {'label': 'Reuniones', 'emoji': '📅'},
    {'label': 'Proyectos / Hobbies', 'emoji': '🎨'},
    {'label': 'Creatividad / Arte', 'emoji': '🖌️'},
    {'label': 'Música', 'emoji': '🎵'},
    {'label': 'Fotografía', 'emoji': '📷'},
    {'label': 'Escritura', 'emoji': '✍️'},
    {'label': 'Cocina', 'emoji': '🍳'},
    {'label': 'Jardinería', 'emoji': '🌿'},
    {'label': 'Juegos / Gaming', 'emoji': '🎮'},
    {'label': 'Social / Amigos', 'emoji': '👥'},
    {'label': 'Familia', 'emoji': '🏠'},
    {'label': 'Pareja / Relaciones', 'emoji': '❤️'},
    {'label': 'Mascotas', 'emoji': '🐾'},
    {'label': 'Viajes', 'emoji': '✈️'},
    {'label': 'Naturaleza / Outdoor', 'emoji': '🏕️'},
    {'label': 'Deporte', 'emoji': '⚽'},
    {'label': 'Voluntariado', 'emoji': '🤲'},
    {'label': 'Rutina / Hábitos', 'emoji': '🔄'},
    {'label': 'Desarrollo personal', 'emoji': '🌱'},
    {'label': 'Tecnología', 'emoji': '💻'},
    {'label': 'Casa / Hogar', 'emoji': '🧹'},
    {'label': 'Trámites / Gestiones', 'emoji': '📋'},
    {'label': 'Espiritual / Fe', 'emoji': '🙏'},
  ];

  bool _reminderEnabled = false;
  int  _reminderHour    = 20;
  int  _reminderMinute  = 0;

  String  _fStatus   = 'TODOS';
  String? _fCategory;
  String  _fFreq     = 'TODAS';
  String  _fSort     = 'RACHA';
  bool    _filtersOpen = false;

  String _message      = 'KEEP YOUR STREAK ALIVE!';
  Color  _messageColor = AutumnColors.mossGreen;

  final Map<int, GlobalKey<HabitCompleteAnimationState>> _animKeys = {};

  GlobalKey<HabitCompleteAnimationState> _keyFor(int habitId) =>
      _animKeys.putIfAbsent(habitId, () => GlobalKey<HabitCompleteAnimationState>());

  @override
  void initState() {
    super.initState();
    _loadReminderPrefs();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _maybeShowFreezePopup();
    });
  }

  Future<void> _loadReminderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _reminderEnabled = prefs.getBool('habit_reminder_enabled') ?? false;
      _reminderHour    = prefs.getInt('habit_reminder_hour')    ?? 20;
      _reminderMinute  = prefs.getInt('habit_reminder_minute')  ?? 0;
    });
  }

  Future<void> _saveReminderPrefs(bool enabled, int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('habit_reminder_enabled', enabled);
    await prefs.setInt('habit_reminder_hour', hour);
    await prefs.setInt('habit_reminder_minute', minute);
    final ns = NotificationService();
    if (enabled) {
      await ns.scheduleHabitReminder(hour: hour, minute: minute);
    } else {
      await ns.cancelHabitReminder();
    }
  }

  Future<void> _maybeShowFreezePopup() async {
    final notifier = ref.read(habitsProvider.notifier);
    final state    = ref.read(habitsProvider);
    final missing  = await notifier.getMissingYesterday();
    if (missing.isNotEmpty && state.freezes > 0 && mounted) {
      _showFreezePopup(state.freezes, missing);
    }
  }

  String _statusKeyToString(dynamic statusKey) {
    final map = {
      HabitStatusKey.done:    'done',
      HabitStatusKey.frozen:  'frozen',
      HabitStatusKey.missed:  'missed',
      HabitStatusKey.pending: 'pending',
    };
    return map[statusKey] ?? 'pending';
  }

  List<dynamic> _applyFilters(List habits, List streakData) {
    var filtered = List<dynamic>.from(streakData);
    if (_fStatus != 'TODOS') {
      filtered = filtered.where((s) => _statusKeyToString(s.statusKey) == _fStatus).toList();
    }
    if (_fCategory != null) {
      final catMap = {for (var h in habits) h.id: h.category};
      filtered = filtered.where((s) => catMap[s.habitId] == _fCategory).toList();
    }
    if (_fFreq != 'TODAS') {
      filtered = filtered.where((s) {
        final streak = s.streak as int;
        if (_fFreq == 'ALTA')  return streak >= 30;
        if (_fFreq == 'MEDIA') return streak >= 10 && streak < 30;
        if (_fFreq == 'BAJA')  return streak < 10;
        return true;
      }).toList();
    }
    if (_fSort == 'RACHA') {
      filtered.sort((a, b) => (b.streak as int).compareTo(a.streak as int));
    } else if (_fSort == 'NOMBRE') {
      filtered.sort((a, b) => (a.name as String).compareTo(b.name as String));
    } else if (_fSort == 'CATEGORÍA') {
      final catMap = {for (var h in habits) h.id: h.category as String? ?? ''};
      filtered.sort((a, b) => (catMap[a.habitId] ?? '').compareTo(catMap[b.habitId] ?? ''));
    }
    return filtered;
  }

  void _setMsg(String msg, Color color) {
    if (mounted) setState(() { _message = msg; _messageColor = color; });
  }

  int _calcLevel(int totalXp) {
    int level = 1;
    while (totalXp >= _xpForLevel(level + 1)) { level++; if (level >= 20) break; }
    return level;
  }
  int _xpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) total += 300 + i * 200;
    return total;
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showFreezePopup(int freezes, List<({int id, String name})> missingHabits) {
    final c = context.ac;
    final yesterday    = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('EEEE dd').format(yesterday).toUpperCase();
    final freezesLeft  = [freezes];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: c.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('❄ USAR FREEZE',
              style: GoogleFonts.pressStart2p(color: AutumnColors.freeze, fontSize: 12)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Ayer ($yesterdayStr) no completaste estos hábitos.\n'
                'Tienes $freezes freeze${freezes != 1 ? "s" : ""} disponible${freezes != 1 ? "s" : ""}.',
                style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ...missingHabits.map((h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(h.name.toUpperCase(),
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textPrimary))),
                const SizedBox(width: 8),
                StatefulBuilder(builder: (ctx2, setBtnState) {
                  final noFreezes = freezesLeft[0] <= 0;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AutumnColors.freeze,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    onPressed: noFreezes ? null : () async {
                      final ok = await ref.read(habitsProvider.notifier).applyManualFreeze(h.id);
                      if (ok) {
                        freezesLeft[0]--;
                        setDlg(() {});
                        _setMsg('❄ FREEZE aplicado a "${h.name}"', AutumnColors.freeze);
                      }
                    },
                    child: Text(noFreezes ? 'SIN FREEZES' : '❄ FREEZE',
                        style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
                  );
                }),
              ]),
            )),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('CERRAR SIN USAR',
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))),
          ],
        ),
      ),
    );
  }

  void _openCreateHabitPopup() {
    final c = context.ac;
    final nameCtrl = TextEditingController();
    String? selectedCategory;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: c.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('NUEVO HÁBITO',
              style: GoogleFonts.pressStart2p(color: AutumnColors.mossGreen, fontSize: 12)),
          content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogInput(ctx, nameCtrl, 'Nombre del hábito...'),
            const SizedBox(height: 10),
            Autocomplete<String>(
              optionsBuilder: (tv) {
                final q = tv.text.toLowerCase();
                if (q.isEmpty) return _categories.map((cat) => '${cat['emoji']} ${cat['label']}');
                return _categories.where((cat) => cat['label']!.toLowerCase().contains(q))
                    .map((cat) => '${cat['emoji']} ${cat['label']}');
              },
              onSelected: (val) {
                final label = val.substring(val.indexOf(' ') + 1);
                setDlg(() => selectedCategory = label);
              },
              fieldViewBuilder: (ctx2, ctrl2, fn, _) => TextField(
                controller: ctrl2, focusNode: fn,
                onChanged: (v) { if (v.isEmpty) setDlg(() => selectedCategory = null); },
                style: GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 9),
                decoration: InputDecoration(
                    hintText: 'Categoría (escribe para buscar)...',
                    hintStyle: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled),
                    prefixIcon: selectedCategory != null
                        ? Padding(padding: const EdgeInsets.all(10), child: Text(
                        _categories.firstWhere((cat) => cat['label'] == selectedCategory,
                            orElse: () => {'emoji': '📁', 'label': ''})['emoji']!,
                        style: const TextStyle(fontSize: 16)))
                        : const Icon(Icons.folder_outlined, size: 16, color: AutumnColors.mossGreen),
                    suffixIcon: selectedCategory != null
                        ? const Icon(Icons.check_circle, size: 16, color: AutumnColors.mossGreen)
                        : null,
                    filled: true, fillColor: c.bgSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.divider)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AutumnColors.mossGreen, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              ),
              optionsViewBuilder: (ctx2, onSel, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(elevation: 6, borderRadius: BorderRadius.circular(10), color: c.bgCard,
                    child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
                        child: ListView.builder(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: options.length, itemBuilder: (_, i) {
                              final opt = options.elementAt(i);
                              return InkWell(onTap: () => onSel(opt),
                                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Text(opt, style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textPrimary))));
                            }))),
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('CANCELAR', style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AutumnColors.mossGreen),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(habitsProvider.notifier).createHabit(nameCtrl.text, selectedCategory ?? '');
                  _setMsg('NEW HABIT SYNCED!', AutumnColors.mossGreen);
                },
                child: Text('ADD', style: GoogleFonts.pressStart2p(fontSize: 9, color: c.bgCard))),
          ],
        ),
      ),
    );
  }

  Widget _dialogInput(BuildContext ctx, TextEditingController ctrl, String hint) {
    final c = ctx.ac;
    return TextField(
      controller: ctrl,
      style: GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 11),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled),
        filled: true, fillColor: c.bgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AutumnColors.mossGreen.withOpacity(0.4))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  void _openCalendarPopup(DateTime selectedDate) {
    final c = context.ac;
    DateTime calDate = DateTime(selectedDate.year, selectedDate.month, 1);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: c.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('SELECCIONAR FECHA',
              style: GoogleFonts.pressStart2p(color: AutumnColors.mossGreen, fontSize: 11)),
          content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: AutumnColors.accentOrange),
                  onPressed: () => setDlg(() => calDate = DateTime(calDate.year, calDate.month - 1, 1))),
              Expanded(child: Text(DateFormat('MMMM yyyy').format(calDate).toUpperCase(),
                  style: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.mossGreen),
                  textAlign: TextAlign.center)),
              IconButton(icon: const Icon(Icons.chevron_right, color: AutumnColors.accentOrange),
                  onPressed: () => setDlg(() => calDate = DateTime(calDate.year, calDate.month + 1, 1))),
            ]),
            Row(children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                .map((d) => Expanded(child: Text(d, textAlign: TextAlign.center,
                style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled)))).toList()),
            const SizedBox(height: 4),
            _buildCalendarGrid(calDate, selectedDate, ctx),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('CERRAR', style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime calDate, DateTime selectedDate, BuildContext ctx) {
    final c = ctx.ac;
    final today       = DateTime.now();
    final daysInMonth = DateTime(calDate.year, calDate.month + 1, 0).day;
    final startOffset = (DateTime(calDate.year, calDate.month, 1).weekday - 1) % 7;
    final cells       = <Widget>[];
    for (int i = 0; i < startOffset; i++) cells.add(const SizedBox());
    for (int d = 1; d <= daysInMonth; d++) {
      final day      = DateTime(calDate.year, calDate.month, d);
      final isFuture = day.isAfter(today);
      final isSelected = day.year == selectedDate.year &&
          day.month == selectedDate.month && day.day == selectedDate.day;
      cells.add(GestureDetector(
        onTap: isFuture ? null : () {
          Navigator.pop(ctx);
          ref.read(habitsProvider.notifier).selectDate(day);
        },
        child: Container(
          margin: const EdgeInsets.all(1.5), height: 30,
          decoration: BoxDecoration(
              color: isSelected ? AutumnColors.mossGreen : isFuture ? c.bgSurface : c.bgCard,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: isSelected ? AutumnColors.mossGreen : c.divider)),
          child: Center(child: Text('$d', style: GoogleFonts.pressStart2p(fontSize: 8,
              color: isFuture ? c.textDisabled : isSelected ? c.bgCard : c.textPrimary))),
        ),
      ));
    }
    return GridView.count(crossAxisCount: 7, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(), children: cells);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c              = context.ac;
    final state          = ref.watch(habitsProvider);
    final habits         = state.habits;
    final allStreaks      = state.streakData;
    final freezes        = state.freezes;
    final selectedDate   = state.selectedDate;
    final isLoading      = state.isLoading;
    final filteredStreaks = _applyFilters(habits, allStreaks);
    final isPast = selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: c.bgPrimary,
      appBar: AppBar(
        backgroundColor: c.bgCard, elevation: 0, automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HABITS 🔥', style: GoogleFonts.pressStart2p(fontSize: 14, color: AutumnColors.mossGreen)),
          Text(DateFormat('EEEE, MMMM dd').format(selectedDate).toUpperCase(),
              style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AutumnColors.mossGreen, size: 26),
              tooltip: 'Nuevo hábito', onPressed: _openCreateHabitPopup),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2),
            child: Container(height: 2, color: AutumnColors.mossGreen)),
      ),
      body: isLoading && habits.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AutumnColors.mossGreen))
          : RefreshIndicator(
        onRefresh: () => ref.read(habitsProvider.notifier).refresh(),
        color: AutumnColors.mossGreen,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _buildStreakPanel(context, allStreaks, freezes),
          const SizedBox(height: 10),
          _buildHabitFilterPanel(context, habits, allStreaks, filteredStreaks),
          const SizedBox(height: 10),
          if (allStreaks.isNotEmpty && filteredStreaks.length != allStreaks.length)
            Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Text('Mostrando ${filteredStreaks.length} de ${allStreaks.length} hábitos',
                    style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled))),
          AutumnButton(text: '📅 CALENDARIO', onPressed: () => _openCalendarPopup(selectedDate),
              bgColor: c.bgSurface, textColor: c.textPrimary),
          const SizedBox(height: 10),
          HabitReminderWidget(
            enabled: _reminderEnabled, hour: _reminderHour, minute: _reminderMinute,
            onChanged: (cfg) {
              final en = cfg['enabled'] as bool;
              final h  = cfg['hour'] as int;
              final m  = cfg['minute'] as int;
              setState(() { _reminderEnabled = en; _reminderHour = h; _reminderMinute = m; });
              _saveReminderPrefs(en, h, m);
            },
          ),
          const SizedBox(height: 10),
          if (_message.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Text(_message,
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: _messageColor),
                    textAlign: TextAlign.center)),
          if (isPast)
            Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AutumnColors.accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AutumnColors.accentGold.withOpacity(0.4))),
                child: Text('📋 REGISTRO DE ESTE DÍA (solo lectura)',
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.accentGold),
                    textAlign: TextAlign.center)),
          Text("TODAY'S HABITS",
              style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final filteredIds  = filteredStreaks.map((s) => s.habitId as int).toSet();
            final visibleHabits = (_fStatus == 'TODOS' && _fCategory == null && _fFreq == 'TODAS')
                ? habits
                : habits.where((h) => filteredIds.contains(h.id)).toList();

            if (visibleHabits.isEmpty) {
              return PixelEmptyState(
                type: EmptyStateType.habits,
                customTitle: habits.isEmpty ? 'SIN HÁBITOS\nAÚN' : 'SIN\nRESULTADOS',
                customSubtitle: habits.isEmpty
                    ? 'Construye tu racha.\nUn hábito a la vez.'
                    : 'Intenta cambiar\nlos filtros.',
                customActionLabel: habits.isEmpty ? '+ NUEVO HÁBITO' : null,
                onAction: habits.isEmpty ? _openCreateHabitPopup : null,
              );
            }
            return Column(children: visibleHabits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildHabitCard(h, state))).toList());
          }),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  // ── Habit Card ────────────────────────────────────────────────────────────

  Widget _buildHabitCard(dynamic habit, dynamic state) {
    final c           = context.ac;
    final habitId     = habit.id as int;
    final name        = habit.name as String;
    final category    = habit.category as String? ?? 'General';
    final isCompleted = state.isCompleted(habitId);
    final accentColor = isCompleted ? AutumnColors.mossGreen : AutumnColors.accentOrange;
    final isToday     = state.isToday as bool;
    final animKey     = _keyFor(habitId);

    return Dismissible(
      key: ValueKey('habit_$habitId'),
      direction: DismissDirection.startToEnd,
      background: Container(
          alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
              color: AutumnColors.accentRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.delete_outline, color: AutumnColors.accentRed)),
      confirmDismiss: (_) async => await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
              backgroundColor: c.bgCard,
              title: Text('RETIRAR HÁBITO',
                  style: GoogleFonts.pressStart2p(fontSize: 11, color: AutumnColors.accentRed)),
              content: Text('¿Retirar "$name" de días futuros?',
                  style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textPrimary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx, false),
                    child: Text('NO', style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))),
                TextButton(onPressed: () => Navigator.pop(dialogCtx, true),
                    child: Text('SÍ', style: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.accentRed))),
              ])),
      onDismissed: (_) {
        ref.read(habitsProvider.notifier).retireHabit(habitId);
        _setMsg('HABIT RETIRED FROM FUTURE DAYS', AutumnColors.accentOrange);
      },
      child: HabitCompleteAnimation(
        key: animKey,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
              color: c.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.divider),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(2, -2))]),
          child: Row(children: [
            Container(width: 4, decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name.toUpperCase(),
                      style: GoogleFonts.pressStart2p(fontSize: 11, color: c.textPrimary, fontWeight: FontWeight.bold))),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: isCompleted ? AutumnColors.mossGreen : c.bgSurface,
                          borderRadius: BorderRadius.circular(11)),
                      child: Text(isCompleted ? 'DONE' : 'PENDING',
                          style: GoogleFonts.pressStart2p(fontSize: 8,
                              color: isCompleted ? c.bgCard : c.textDisabled))),
                ]),
                const SizedBox(height: 4),
                Text(category, style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled)),
                const SizedBox(height: 8),
                SizedBox(height: 34, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted ? AutumnColors.mossGreen : c.bgSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: isToday ? () async {
                      if (!isCompleted) {
                        animKey.currentState?.pulse();
                        XpToast.show(context, amount: 10);
                      }
                      await ref.read(habitsProvider.notifier).toggleCompleted(habitId);
                    } : null,
                    child: Text(isCompleted ? 'COMPLETADO' : '○  MARCAR',
                        style: GoogleFonts.pressStart2p(fontSize: 9,
                            color: isCompleted ? c.bgCard : AutumnColors.accentOrange)))),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Streak Panel ──────────────────────────────────────────────────────────

  Widget _buildStreakPanel(BuildContext context, List streakData, int freezes) {
    final c = context.ac;
    const statusColors = {
      'done':    AutumnColors.mossGreen, 'frozen':  AutumnColors.freeze,
      'missed':  AutumnColors.accentRed, 'pending': AutumnColors.accentGold,
    };
    const statusIcons = {
      'done': Icons.check_circle, 'frozen': Icons.ac_unit,
      'missed': Icons.cancel, 'pending': Icons.schedule,
    };
    const statusLabels = {
      'done': 'DONE', 'frozen': 'FROZEN', 'missed': 'MISSED', 'pending': 'PENDING'
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.bgCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AutumnColors.accentGold, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_fire_department, color: AutumnColors.accentGold, size: 16),
          const SizedBox(width: 6),
          Text('DAILY STREAKS', style: GoogleFonts.pressStart2p(fontSize: 10, color: AutumnColors.accentGold, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.ac_unit, color: AutumnColors.freeze, size: 14),
          const SizedBox(width: 4),
          Text(freezes > 0
              ? '$freezes FREEZE${freezes != 1 ? "S" : ""} DISPONIBLE${freezes != 1 ? "S" : ""}'
              : 'NO FREEZES',
              style: GoogleFonts.pressStart2p(fontSize: 8,
                  color: freezes > 0 ? AutumnColors.freeze : AutumnColors.accentRed,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        if (streakData.isEmpty)
          Text('NO ACTIVE HABITS', style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))
        else
          ...streakData.map((s) {
            final statusKey    = _statusKeyToString(s.statusKey);
            final streak       = s.streak as int;
            final daysToFreeze = s.daysToFreeze as int;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(flex: 3,
                    child: Text((s.name as String).toUpperCase(),
                        style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textPrimary, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
                SizedBox(width: 50, child: Row(children: [
                  if (streak > 0) ...[
                    const Icon(Icons.local_fire_department, color: AutumnColors.accentGold, size: 10),
                    const SizedBox(width: 2),
                    Text('${streak}d', style: GoogleFonts.pressStart2p(fontSize: 7, color: AutumnColors.accentGold)),
                  ] else
                    Text('—', style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                ])),
                SizedBox(width: 64, child: Row(children: [
                  Icon(statusIcons[statusKey] ?? Icons.schedule, color: statusColors[statusKey], size: 10),
                  const SizedBox(width: 2),
                  Text(statusLabels[statusKey] ?? '',
                      style: GoogleFonts.pressStart2p(fontSize: 7, color: statusColors[statusKey])),
                ])),
                SizedBox(width: 52, child: Row(children: [
                  const Icon(Icons.ac_unit, color: AutumnColors.freeze, size: 10),
                  const SizedBox(width: 2),
                  Text(daysToFreeze > 0 ? 'en ${daysToFreeze}d' : '¡HOY!',
                      style: GoogleFonts.pressStart2p(fontSize: 7, color: AutumnColors.freeze)),
                ])),
              ]),
            );
          }),
      ]),
    );
  }

  // ── Filter Panel ──────────────────────────────────────────────────────────

  Widget _buildHabitFilterPanel(BuildContext context, List habits, List allStreaks, List filteredStreaks) {
    final c = context.ac;
    final activeFilters = (_fStatus != 'TODOS' ? 1 : 0) + (_fCategory != null ? 1 : 0) +
        (_fFreq != 'TODAS' ? 1 : 0) + (_fSort != 'RACHA' ? 1 : 0);
    final cats = habits.map((h) => h.category as String?)
        .where((cat) => cat != null && cat.isNotEmpty).cast<String>().toSet().toList();

    return Container(
      decoration: BoxDecoration(
          color: c.bgCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activeFilters > 0 ? AutumnColors.mossGreen.withOpacity(0.5) : c.divider)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _filtersOpen = !_filtersOpen),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const Icon(Icons.filter_list_rounded, size: 16, color: AutumnColors.mossGreen),
                const SizedBox(width: 8),
                Text('FILTROS', style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.mossGreen)),
                if (activeFilters > 0) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AutumnColors.mossGreen, borderRadius: BorderRadius.circular(10)),
                      child: Text('$activeFilters', style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white))),
                ],
                const Spacer(),
                if (activeFilters > 0)
                  GestureDetector(
                      onTap: () => setState(() { _fStatus = 'TODOS'; _fCategory = null; _fFreq = 'TODAS'; _fSort = 'RACHA'; }),
                      child: Text('LIMPIAR', style: GoogleFonts.pressStart2p(fontSize: 7, color: AutumnColors.accentRed))),
                const SizedBox(width: 8),
                Icon(_filtersOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: c.textDisabled),
              ])),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220), curve: Curves.easeInOut,
          child: _filtersOpen
              ? Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Divider(color: c.divider, height: 14),
                _hfLabel(c, 'ESTADO DE HOY'), const SizedBox(height: 6),
                Row(children: [
                  {'v': 'TODOS',   'l': 'TODOS',   'c': AutumnColors.mossGreen},
                  {'v': 'done',    'l': '✅ HECHO', 'c': AutumnColors.mossGreen},
                  {'v': 'pending', 'l': '⏳ PEND',  'c': AutumnColors.accentGold},
                  {'v': 'missed',  'l': '❌ FALL',  'c': AutumnColors.accentRed},
                ].map((item) {
                  final sel = _fStatus == item['v'] as String;
                  final col = item['c'] as Color;
                  return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _fStatus = item['v'] as String),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(color: sel ? col : c.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? col : c.divider)),
                          child: Text(item['l'] as String, textAlign: TextAlign.center,
                              style: GoogleFonts.pressStart2p(fontSize: 6,
                                  color: sel ? Colors.white : c.textSecondary)))));
                }).toList()),
                const SizedBox(height: 10),
                _hfLabel(c, 'RACHA'), const SizedBox(height: 6),
                Row(children: [
                  {'v': 'TODAS', 'l': 'TODAS',    'c': AutumnColors.mossGreen},
                  {'v': 'ALTA',  'l': '🔥 +30d',  'c': AutumnColors.accentOrange},
                  {'v': 'MEDIA', 'l': '🌿 10-30', 'c': AutumnColors.accentGold},
                  {'v': 'BAJA',  'l': '🌱 <10d',  'c': c.textSecondary},
                ].map((item) {
                  final sel = _fFreq == item['v'] as String;
                  final col = item['c'] as Color;
                  return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _fFreq = item['v'] as String),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(color: sel ? col : c.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? col : c.divider)),
                          child: Text(item['l'] as String, textAlign: TextAlign.center,
                              style: GoogleFonts.pressStart2p(fontSize: 6,
                                  color: sel ? Colors.white : c.textSecondary)))));
                }).toList()),
                if (cats.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _hfLabel(c, 'CATEGORÍA'), const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    GestureDetector(onTap: () => setState(() => _fCategory = null),
                        child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: _fCategory == null ? AutumnColors.mossGreen : c.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _fCategory == null ? AutumnColors.mossGreen : c.divider)),
                            child: Text('TODAS', style: GoogleFonts.pressStart2p(fontSize: 7,
                                color: _fCategory == null ? Colors.white : c.textSecondary)))),
                    ...cats.map((cat) {
                      final sel = _fCategory == cat;
                      return GestureDetector(onTap: () => setState(() => _fCategory = sel ? null : cat),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                  color: sel ? AutumnColors.mossGreen : c.bgSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: sel ? AutumnColors.mossGreen : c.divider)),
                              child: Text(cat, style: GoogleFonts.pressStart2p(fontSize: 7,
                                  color: sel ? Colors.white : c.textSecondary))));
                    }),
                  ]),
                ],
                Divider(color: c.divider, height: 14),
                _hfLabel(c, 'ORDENAR POR'), const SizedBox(height: 6),
                Row(children: [
                  {'v': 'RACHA',     'i': Icons.local_fire_department_rounded},
                  {'v': 'NOMBRE',    'i': Icons.sort_by_alpha_rounded},
                  {'v': 'CATEGORÍA', 'i': Icons.folder_outlined},
                ].map((item) {
                  final v   = item['v'] as String;
                  final ico = item['i'] as IconData;
                  final sel = _fSort == v;
                  return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _fSort = v),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                              color: sel ? AutumnColors.mossGreen : c.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? AutumnColors.mossGreen : c.divider)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(ico, size: 11, color: sel ? Colors.white : c.textSecondary),
                            const SizedBox(width: 4),
                            Text(v, style: GoogleFonts.pressStart2p(fontSize: 6,
                                color: sel ? Colors.white : c.textSecondary)),
                          ]))));
                }).toList()),
              ]))
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _hfLabel(dynamic c, String t) =>
      Text(t, style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled));
}