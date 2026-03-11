import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/widgets/autumn_widgets.dart';
import '../../../core/services/widget_service.dart';
import '../../habits/presentation/providers/habits_provider.dart';
import '../../profile/presentation/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String userId;
  final ValueChanged<int>? onNavigate;
  const HomeScreen({super.key, required this.userId, this.onNavigate});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _db = SupabaseConfig.client;

  int _goalsCount = 0, _todosCount = 0;
  int _level = 1, _currentXp = 0, _xpForNext = 500, _totalXp = 0;
  List<Map<String, dynamic>> _deadlines = [];

  // ── Calendario ────────────────────────────────────────────────────────────
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // mapa de fecha (yyyy-MM-dd) → lista de colores de eventos
  Map<String, List<Color>> _calendarEvents = {};

  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  String _treeAsset = 'assets/images/tree_small.png';
  double _treeSize = 96;
  String _levelTitle = 'ÁRBOL JOVEN';

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -3.0, end: 3.0)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _loadAll();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _checkOverdueGoals(),
      _loadAllStats(),
      _loadDeadlines(),
      _loadCalendarEvents(),
    ]);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _checkFreezeNotification();
    });
  }

  Future<void> _checkOverdueGoals() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final overdueGoals = await _db
          .from('goals')
          .select('id')
          .eq('user_id', widget.userId)
          .eq('status', 'active')
          .lt('deadline', today);
      for (final g in overdueGoals) {
        await _db.from('goals').update({'status': 'failed'}).eq('id', g['id']);
        await _applyXp(-50, 'Meta vencida', 'goal_failed', g['id'] as int, today);
      }
    } catch (e) {
      debugPrint('checkOverdue error: $e');
    }
  }

  Future<void> _applyXp(int amount, String reason, String source,
      int sourceId, String eventDate) async {
    try {
      final existing = await _db
          .from('xp_log')
          .select('id')
          .eq('source', source)
          .eq('source_id', sourceId)
          .eq('event_date', eventDate)
          .maybeSingle();
      if (existing != null) return;
      final profile = await _db
          .from('profiles')
          .select('total_xp')
          .eq('id', widget.userId)
          .single();
      final current = profile['total_xp'] as int? ?? 0;
      final newXp = (current + amount).clamp(0, 999999);
      await _db.from('profiles').update({'total_xp': newXp}).eq('id', widget.userId);
      await _db.from('xp_log').insert({
        'user_id': widget.userId,
        'amount': amount,
        'reason': reason,
        'source': source,
        'source_id': sourceId,
        'event_date': eventDate,
      });
    } catch (e) {
      debugPrint('XP error: $e');
    }
  }

  Future<void> _loadAllStats() async {
    try {
      final results = await Future.wait([_fetchStats(), _fetchXp()]);
      final stats = results[0] as Map<String, dynamic>;
      final xp = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      final newLevel = xp['level'] as int;
      await _maybeNotifyLevelUp(newLevel);
      setState(() {
        _goalsCount = stats['goalsCount'] as int;
        _todosCount = stats['todosCount'] as int;
        _level = newLevel;
        _currentXp = xp['currentXp'] as int;
        _xpForNext = xp['xpForNext'] as int;
        _totalXp = xp['totalXp'] as int;
        _updateLevelDerived(newLevel);
      });
      _syncWidget();
    } catch (e) {
      debugPrint('loadAllStats error: $e');
    }
  }

  Future<void> _maybeNotifyLevelUp(int newLevel) async {
    if (newLevel <= 1) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNotified = prefs.getInt('last_level_notified_${widget.userId}') ?? 1;
      if (newLevel > lastNotified) {
        await prefs.setInt('last_level_notified_${widget.userId}', newLevel);
        if (mounted) _showLevelUpBanner(newLevel);
      }
    } catch (e) {
      debugPrint('levelUp notify error: $e');
    }
  }

  void _showLevelUpBanner(int level) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: AutumnColors.accentOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Text('🌳', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¡SUBISTE AL NIVEL $level!',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('¡Sigue así, tu árbol crece!',
                    style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white70)),
              ])),
        ]),
      ),
    );
  }

  void _syncWidget() {
    try {
      final habitsState = ref.read(habitsProvider);
      final sorted = [...habitsState.streakData]
        ..sort((a, b) => b.streak.compareTo(a.streak));
      final h1 = sorted.isNotEmpty ? sorted[0] : null;
      final h2 = sorted.length > 1 ? sorted[1] : null;
      final h3 = sorted.length > 2 ? sorted[2] : null;
      WidgetService.updateWidget(
        level: _level,
        totalXp: _currentXp,
        xpToNext: _xpForNext,
        goalsCount: _goalsCount,
        tasksToday: _todosCount,
        habit1Name: h1?.name ?? '',
        habit1Streak: h1?.streak ?? 0,
        habit2Name: h2?.name ?? '',
        habit2Streak: h2?.streak ?? 0,
        habit3Name: h3?.name ?? '',
        habit3Streak: h3?.streak ?? 0,
      );
    } catch (e) {
      debugPrint('syncWidget error: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final goals = await _db
        .from('goals')
        .select('id')
        .eq('user_id', widget.userId)
        .eq('status', 'active') as List;
    final todos = await _db
        .from('todos')
        .select('id')
        .eq('user_id', widget.userId)
        .neq('status', 'done') as List;
    return {'goalsCount': goals.length, 'todosCount': todos.length};
  }

  Future<Map<String, dynamic>> _fetchXp() async {
    try {
      final profile = await _db
          .from('profiles')
          .select('total_xp')
          .eq('id', widget.userId)
          .single();
      final totalXp = profile['total_xp'] as int? ?? 0;
      final level = _calcLevel(totalXp);
      final xpForCurrent = _xpForLevel(level);
      final xpForNext = _xpForLevel(level + 1);
      final currentXp = totalXp - xpForCurrent;
      final xpNeeded = xpForNext - xpForCurrent;
      return {
        'level': level,
        'currentXp': currentXp.clamp(0, xpNeeded),
        'xpForNext': xpNeeded,
        'totalXp': totalXp,
      };
    } catch (e) {
      return {'level': 1, 'currentXp': 0, 'xpForNext': 500, 'totalXp': 0};
    }
  }

  int _calcLevel(int totalXp) {
    int level = 1;
    while (totalXp >= _xpForLevel(level + 1)) {
      level++;
      if (level >= 20) break;
    }
    return level;
  }

  int _xpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) total += 300 + i * 200;
    return total;
  }

  void _updateLevelDerived(int level) {
    if (level >= 7) {
      _treeAsset = 'assets/images/tree_large.png';
      _treeSize = 140;
      _levelTitle = level >= 11 ? 'ÁRBOL LEGENDARIO' : 'ÁRBOL MADURO';
    } else if (level >= 3) {
      _treeAsset = 'assets/images/tree_medium.png';
      _treeSize = 118;
      _levelTitle = 'ÁRBOL EN CRECIMIENTO';
    } else {
      _treeAsset = 'assets/images/tree_small.png';
      _treeSize = 96;
      _levelTitle = 'ÁRBOL JOVEN';
    }
  }

  Future<void> _loadDeadlines() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final limit = DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10);
      final results = await Future.wait([
        _db.from('goals').select('title, deadline')
            .eq('user_id', widget.userId).eq('status', 'active')
            .gte('deadline', today).lte('deadline', limit).order('deadline'),
        _db.from('todos').select('title, deadline')
            .eq('user_id', widget.userId).neq('status', 'done')
            .not('deadline', 'is', null)
            .gte('deadline', today).lte('deadline', limit).order('deadline'),
      ]);
      final all = [
        ...(results[0] as List).map((g) => {'title': g['title'], 'deadline': g['deadline']}),
        ...(results[1] as List).map((t) => {'title': t['title'], 'deadline': t['deadline']}),
      ];
      all.sort((a, b) => (a['deadline'] as String).compareTo(b['deadline'] as String));
      if (mounted) setState(() => _deadlines = all.take(5).toList());
    } catch (e) {
      debugPrint('loadDeadlines error: $e');
    }
  }

  // ── Cargar eventos del calendario ─────────────────────────────────────────

  Future<void> _loadCalendarEvents() async {
    try {
      // Rango: primer día del mes anterior al último día del mes siguiente
      final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
      final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
      final from = firstDay.toIso8601String().substring(0, 10);
      final to = lastDay.toIso8601String().substring(0, 10);

      final results = await Future.wait([
        // Metas activas
        _db.from('goals').select('deadline')
            .eq('user_id', widget.userId).eq('status', 'active')
            .not('deadline', 'is', null)
            .gte('deadline', from).lte('deadline', to),
        // Tareas pendientes
        _db.from('todos').select('deadline')
            .eq('user_id', widget.userId).neq('status', 'done')
            .not('deadline', 'is', null)
            .gte('deadline', from).lte('deadline', to),
        // Objetivos pendientes
        _db.from('objectives').select('deadline')
            .eq('status', 'pending')
            .not('deadline', 'is', null)
            .gte('deadline', from).lte('deadline', to),
      ]);

      final Map<String, List<Color>> events = {};

      void addEvent(String? date, Color color) {
        if (date == null || date.isEmpty) return;
        final key = date.substring(0, 10);
        events[key] = [...(events[key] ?? []), color];
      }

      for (final g in results[0] as List) addEvent(g['deadline'] as String?, AutumnColors.accentOrange);
      for (final t in results[1] as List) addEvent(t['deadline'] as String?, AutumnColors.accentGold);
      for (final o in results[2] as List) addEvent(o['deadline'] as String?, AutumnColors.mossGreen);

      if (mounted) setState(() => _calendarEvents = events);
    } catch (e) {
      debugPrint('loadCalendarEvents error: $e');
    }
  }

  Future<void> _checkFreezeNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastShown = prefs.getString('freeze_popup_shown_${widget.userId}') ?? '';
      if (lastShown == today) return;
      final habitsNotifier = ref.read(habitsProvider.notifier);
      final habitsState = ref.read(habitsProvider);
      final missing = await habitsNotifier.getMissingYesterday();
      if (missing.isNotEmpty && habitsState.freezes > 0 && mounted) {
        await prefs.setString('freeze_popup_shown_${widget.userId}', today);
        _showFreezePopup(habitsState.freezes, missing);
      }
    } catch (e) {
      debugPrint('checkFreezeNotification error: $e');
    }
  }

  void _showFreezePopup(int freezes, List<({int id, String name})> missingHabits) {
    final c = context.ac;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('EEEE dd').format(yesterday).toUpperCase();
    final freezesLeft = [freezes];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: c.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('❄ USAR FREEZE',
              style: GoogleFonts.pressStart2p(color: AutumnColors.freeze, fontSize: 10)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Ayer ($yesterdayStr) fallaste estos hábitos.',
                  style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Tienes $freezes freeze${freezes != 1 ? "s" : ""} disponible${freezes != 1 ? "s" : ""}.',
                  style: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.freeze),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ...missingHabits.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(h.name.toUpperCase(),
                      style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textPrimary))),
                  StatefulBuilder(builder: (_, _s) => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AutumnColors.freeze,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    onPressed: freezesLeft[0] > 0
                        ? () async {
                      final ok = await ref.read(habitsProvider.notifier).applyManualFreeze(h.id);
                      if (ok) { freezesLeft[0]--; setDlg(() {}); }
                    }
                        : null,
                    child: Text(freezesLeft[0] > 0 ? '❄ FREEZE' : 'SIN FREEZES',
                        style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
                  )),
                ]),
              )),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () { Navigator.pop(ctx); _goTo(2); },
                child: Text('→ IR A HÁBITOS',
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.mossGreen))),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('DECIDIR DESPUÉS',
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))),
          ],
        ),
      ),
    );
  }

  void _goTo(int tab) => widget.onNavigate?.call(tab);

  String _nextMilestoneHint() {
    final pct = _xpForNext > 0 ? (_currentXp / _xpForNext * 100).round() : 0;
    if (pct >= 80) return '¡Casi en el siguiente nivel!';
    if (pct >= 50) return 'Vas a la mitad del nivel';
    if (pct >= 25) return 'Buen comienzo, sigue así';
    return 'Completa hábitos para crecer';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final habitsState = ref.watch(habitsProvider);
    final freezes = habitsState.freezes;
    final maxStreak = habitsState.streakData.isEmpty
        ? 0
        : habitsState.streakData.map((s) => s.streak).reduce((a, b) => a > b ? a : b);
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(DateTime.now()).toUpperCase();
    final xpProgress = _xpForNext > 0 ? (_currentXp / _xpForNext).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AutumnColors.accentOrange,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            backgroundColor: c.bgCard,
            expandedHeight: 56,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
                title: Row(children: [
                  Image.asset('assets/images/acorn.png', width: 18, height: 18),
                  const SizedBox(width: 8),
                  Text('LifeXP',
                      style: GoogleFonts.pressStart2p(fontSize: 14, color: AutumnColors.accentOrange)),
                ])),
            actions: [
              IconButton(
                  icon: Icon(Icons.settings_rounded, color: c.textDisabled, size: 22),
                  tooltip: 'Perfil y ajustes',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId)),
                  ).then((_) => _loadAll())),
            ],
            bottom: PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: Container(height: 2, color: AutumnColors.accentOrange)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dateStr,
                    style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                const SizedBox(height: 14),
                _buildTreeHero(context, xpProgress),
                const SizedBox(height: 16),
                _buildSectionLabel(context, 'ESTADO DEL JUGADOR'),
                const SizedBox(height: 10),
                _buildStatsGrid(context, freezes, maxStreak),
                const SizedBox(height: 16),
                _buildSectionLabel(context, 'PRÓXIMOS VENCIMIENTOS'),
                const SizedBox(height: 10),
                _buildDeadlineCard(context),
                const SizedBox(height: 16),
                // ── Calendario mensual (reemplaza acciones rápidas) ────────
                _buildSectionLabel(context, 'CALENDARIO'),
                const SizedBox(height: 10),
                _buildCalendar(context),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Calendario mensual ────────────────────────────────────────────────────

  Widget _buildCalendar(BuildContext context) {
    final c = context.ac;
    final today = DateTime.now();
    final firstOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    // Lunes = 0, domingo = 6
    final startWeekday = (firstOfMonth.weekday - 1) % 7;
    final monthName = DateFormat('MMMM yyyy', 'es').format(_calendarMonth).toUpperCase();
    const weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Column(children: [
        // ── Header mes ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            GestureDetector(
              onTap: () {
                setState(() => _calendarMonth =
                    DateTime(_calendarMonth.year, _calendarMonth.month - 1));
                _loadCalendarEvents();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: c.bgSurface, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.chevron_left, size: 18, color: c.textSecondary),
              ),
            ),
            Expanded(
              child: Text(monthName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pressStart2p(
                      fontSize: 9, color: AutumnColors.accentOrange)),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _calendarMonth =
                    DateTime(_calendarMonth.year, _calendarMonth.month + 1));
                _loadCalendarEvents();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: c.bgSurface, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.chevron_right, size: 18, color: c.textSecondary),
              ),
            ),
          ]),
        ),
        // ── Días de la semana ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: weekdays.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7,
                        color: d == 'S' || d == 'D'
                            ? AutumnColors.accentRed.withOpacity(0.6)
                            : c.textDisabled)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 4),
        // ── Grid de días ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
              final dateKey = date.toIso8601String().substring(0, 10);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final events = _calendarEvents[dateKey] ?? [];
              final isWeekend = date.weekday == 6 || date.weekday == 7;

              return _calendarDay(context, day, isToday, isWeekend, events, date);
            },
          ),
        ),
        // ── Leyenda ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendDot(AutumnColors.accentOrange, 'Meta'),
            const SizedBox(width: 12),
            _legendDot(AutumnColors.accentGold, 'Tarea'),
            const SizedBox(width: 12),
            _legendDot(AutumnColors.mossGreen, 'Objetivo'),
          ]),
        ),
      ]),
    );
  }

  Widget _calendarDay(BuildContext context, int day, bool isToday,
      bool isWeekend, List<Color> events, DateTime date) {
    final c = context.ac;
    // Limitar a 3 puntos distintos (uno por tipo)
    final uniqueColors = events.toSet().take(3).toList();

    return GestureDetector(
      onTap: events.isEmpty ? null : () => _showDayDetail(context, date),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isToday
              ? AutumnColors.accentOrange.withOpacity(0.15)
              : events.isNotEmpty
              ? c.bgSurface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: AutumnColors.accentOrange, width: 1.5)
              : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$day',
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                color: isToday
                    ? AutumnColors.accentOrange
                    : isWeekend
                    ? AutumnColors.accentRed.withOpacity(0.6)
                    : c.textPrimary,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              )),
          if (uniqueColors.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: uniqueColors.map((color) => Container(
                width: 4, height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )).toList(),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    final c = context.ac;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled)),
    ]);
  }

  // ── Detalle del día al tocar ──────────────────────────────────────────────

  Future<void> _showDayDetail(BuildContext context, DateTime date) async {
    final c = context.ac;
    final dateKey = date.toIso8601String().substring(0, 10);
    final dateLabel = DateFormat('d MMMM yyyy', 'es').format(date).toUpperCase();

    // Cargar items del día
    final results = await Future.wait([
      _db.from('goals').select('title').eq('user_id', widget.userId)
          .eq('status', 'active').eq('deadline', dateKey),
      _db.from('todos').select('title').eq('user_id', widget.userId)
          .neq('status', 'done').eq('deadline', dateKey),
      _db.from('objectives').select('title').eq('status', 'pending')
          .eq('deadline', dateKey),
    ]);

    final goals = (results[0] as List).map((g) => g['title'] as String).toList();
    final todos = (results[1] as List).map((t) => t['title'] as String).toList();
    final objs  = (results[2] as List).map((o) => o['title'] as String).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: AutumnColors.accentOrange.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text(dateLabel,
              style: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.accentOrange)),
          const SizedBox(height: 14),
          if (goals.isEmpty && todos.isEmpty && objs.isEmpty)
            Text('Sin eventos este día',
                style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled)),
          if (goals.isNotEmpty) ...[
            _dayDetailSection(ctx, '🎯 METAS', goals, AutumnColors.accentOrange),
            const SizedBox(height: 10),
          ],
          if (todos.isNotEmpty) ...[
            _dayDetailSection(ctx, '📋 TAREAS', todos, AutumnColors.accentGold),
            const SizedBox(height: 10),
          ],
          if (objs.isNotEmpty)
            _dayDetailSection(ctx, '✅ OBJETIVOS', objs, AutumnColors.mossGreen),
        ]),
      ),
    );
  }

  Widget _dayDetailSection(BuildContext ctx, String title, List<String> items, Color color) {
    final c = ctx.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.pressStart2p(fontSize: 7, color: color)),
      const SizedBox(height: 6),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(width: 4, height: 4,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(item,
              style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textPrimary),
              overflow: TextOverflow.ellipsis)),
        ]),
      )),
    ]);
  }

  // ── Widgets existentes (sin cambios) ──────────────────────────────────────

  Widget _buildTreeHero(BuildContext context, double xpProgress) {
    final c = context.ac;
    return Container(
      decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AutumnColors.mossGreen.withOpacity(0.45), width: 1.5),
          boxShadow: [BoxShadow(color: AutumnColors.mossGreen.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: AutumnColors.mossGreen.withOpacity(0.08),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15))),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AutumnColors.accentOrange, borderRadius: BorderRadius.circular(8)),
                child: Text('LVL $_level',
                    style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(child: Text(_levelTitle,
                style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.mossGreen))),
            Text('$_totalXp XP total',
                style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
          ]),
        ),
        SizedBox(
          height: 200,
          child: Stack(alignment: Alignment.center, children: [
            Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 32, decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [AutumnColors.mossGreen.withOpacity(0), AutumnColors.mossGreen.withOpacity(0.08)])))),
            Positioned(left: 18, top: 30,
                child: Transform.rotate(angle: -0.4,
                    child: Opacity(opacity: 0.55, child: Image.asset('assets/images/leaf_orange.png', width: 22, height: 22, filterQuality: FilterQuality.none)))),
            Positioned(left: 38, bottom: 50,
                child: Transform.rotate(angle: 0.6,
                    child: Opacity(opacity: 0.45, child: Image.asset('assets/images/leaf_brown.png', width: 18, height: 18, filterQuality: FilterQuality.none)))),
            Positioned(right: 22, top: 24,
                child: Transform.rotate(angle: 0.5,
                    child: Opacity(opacity: 0.6, child: Image.asset('assets/images/leaf_yellow.png', width: 24, height: 24, filterQuality: FilterQuality.none)))),
            Positioned(right: 44, bottom: 44,
                child: Transform.rotate(angle: -0.3,
                    child: Opacity(opacity: 0.4, child: Image.asset('assets/images/leaf_orange.png', width: 16, height: 16, filterQuality: FilterQuality.none)))),
            Positioned(right: 16, top: 12,
                child: Opacity(opacity: 0.7, child: Image.asset('assets/images/acorn.png', width: 18, height: 18, filterQuality: FilterQuality.none))),
            Positioned(left: 16, bottom: 16,
                child: Opacity(opacity: 0.5, child: Image.asset('assets/images/acorn.png', width: 14, height: 14, filterQuality: FilterQuality.none))),
            AnimatedBuilder(
                animation: _floatAnim,
                child: Image.asset(_treeAsset, width: _treeSize, height: _treeSize, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                builder: (_, child) => Transform.translate(offset: Offset(0, _floatAnim.value), child: child)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_nextMilestoneHint(),
                  style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
              Text('$_currentXp / $_xpForNext XP',
                  style: GoogleFonts.pressStart2p(fontSize: 7, color: AutumnColors.accentOrange)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(children: [
                  Container(height: 14, color: c.bgSurface),
                  AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      widthFactor: xpProgress,
                      child: Container(height: 14,
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [AutumnColors.accentOrange, AutumnColors.accentGold])))),
                  SizedBox(height: 14,
                      child: Center(child: Text('${(xpProgress * 100).round()}%',
                          style: GoogleFonts.pressStart2p(fontSize: 7,
                              color: xpProgress > 0.3 ? Colors.white : c.textDisabled)))),
                ])),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStatsGrid(BuildContext context, int freezes, int maxStreak) {
    final stats = [
      (freezes, '❄', 'FREEZES', AutumnColors.freeze),
      (_goalsCount, '🎯', 'METAS', AutumnColors.accentOrange),
      (maxStreak, '🔥', 'RACHA', AutumnColors.accentGold),
      (_todosCount, '📋', 'TAREAS', AutumnColors.mossGreen),
    ];
    return GridView.count(
        crossAxisCount: 4, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.82,
        children: stats.map((s) => _statCard(context, s.$1.toString(), s.$2, s.$3, s.$4)).toList());
  }

  Widget _statCard(BuildContext context, String value, String emoji, String label, Color color) {
    final c = context.ac;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
          color: c.bgCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 5),
        Text(value, style: GoogleFonts.pressStart2p(fontSize: 15, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildDeadlineCard(BuildContext context) {
    final c = context.ac;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.bgCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.divider)),
        child: _deadlines.isEmpty
            ? Row(children: [
          const Text('🌿', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text('Sin vencimientos próximos',
              style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.mossGreen))),
        ])
            : Column(children: _deadlines.take(5).map((d) => _deadlineRow(context, d)).toList()));
  }

  Widget _deadlineRow(BuildContext context, Map<String, dynamic> item) {
    final c = context.ac;
    DateTime? dl;
    try { dl = DateTime.parse(item['deadline'] as String); } catch (_) {}
    final diff = dl != null ? dl.difference(DateTime.now()).inDays : null;
    String label; Color color;
    if (diff == null) { label = '?'; color = c.textDisabled; }
    else if (diff < 0) { label = 'VENCIDA'; color = AutumnColors.accentRed; }
    else if (diff == 0) { label = 'HOY'; color = AutumnColors.accentRed; }
    else if (diff == 1) { label = 'MAÑANA'; color = AutumnColors.accentOrange; }
    else if (diff <= 3) { label = 'En ${diff}d'; color = AutumnColors.accentOrange; }
    else { label = 'En ${diff}d'; color = AutumnColors.accentGold; }

    final title = item['title'] as String? ?? '';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(title.length > 30 ? '${title.substring(0, 30)}…' : title,
              style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textPrimary))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.4))),
              child: Text(label, style: GoogleFonts.pressStart2p(fontSize: 7, color: color))),
        ]));
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    final c = context.ac;
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: AutumnColors.accentOrange, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled, fontWeight: FontWeight.bold)),
    ]);
  }
}