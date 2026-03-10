// ===========================
// ⚡ HABITS PROVIDER
// ===========================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/habit.dart';
import '../../domain/habits_state.dart';
import '../../data/habits_repository.dart';
import '../../../../core/services/widget_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/supabase/supabase_client.dart';
import 'package:flutter/foundation.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final habitsRepositoryProvider = Provider<HabitsRepository>(
      (_) => HabitsRepository(),
);

final userIdProvider = StateProvider<String>((ref) => '');

final habitsProvider =
StateNotifierProvider<HabitsNotifier, HabitsState>((ref) {
  final repo   = ref.watch(habitsRepositoryProvider);
  final userId = ref.watch(userIdProvider);
  return HabitsNotifier(repo, userId);
});

// ── StateNotifier ─────────────────────────────────────────────────────────────

class HabitsNotifier extends StateNotifier<HabitsState> {
  final HabitsRepository _repo;
  final String _userId;
  final _db = SupabaseConfig.client;

  HabitsNotifier(this._repo, this._userId) : super(HabitsState()) {
    if (_userId.isNotEmpty) loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.wait([
      _repo.checkMissedHabits(_userId),
      _loadScreenData(state.selectedDate),
    ]);
    state = state.copyWith(isLoading: false);
    _syncWidget();
  }

  Future<void> _loadScreenData(DateTime date) async {
    try {
      final data = await _repo.loadScreenData(_userId, date);
      state = state.copyWith(
        habits:         data.habits,
        streakData:     data.streakData,
        completedCache: data.completedMap,
        freezes:        data.freezes,
        selectedDate:   date,
        isLoading:      false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectDate(DateTime date) => _loadScreenData(date);

  Future<void> refresh() async {
    await loadAll();
  }

  // ── Widget sync ───────────────────────────────────────────────────────────

  void _syncWidget() {
    if (_userId.isEmpty) return;
    try {
      final maxStreak = state.streakData.isEmpty
          ? 0
          : state.streakData
          .map((s) => s.streak as int)
          .reduce((a, b) => a > b ? a : b);

      final sorted = [...state.streakData]
        ..sort((a, b) => b.streak.compareTo(a.streak));

      final h1 = sorted.isNotEmpty ? sorted[0] : null;
      final h2 = sorted.length > 1 ? sorted[1] : null;
      final h3 = sorted.length > 2 ? sorted[2] : null;

      WidgetService.updateWidget(
        streak:       maxStreak,
        habit1Name:   h1?.name ?? '',
        habit1Streak: h1?.streak ?? 0,
        habit2Name:   h2?.name ?? '',
        habit2Streak: h2?.streak ?? 0,
        habit3Name:   h3?.name ?? '',
        habit3Streak: h3?.streak ?? 0,
      );
    } catch (_) {}
  }

  // ── Toggle completado (optimistic) ────────────────────────────────────────

  Future<void> toggleCompleted(int habitId) async {
    if (!state.isToday) return;

    final wasCompleted = state.completedCache[habitId] ?? false;
    final newCompleted = !wasCompleted;

    final newCache = Map<int, bool>.from(state.completedCache);
    newCache[habitId] = newCompleted;

    final newStreakData = state.streakData.map((s) {
      if (s.habitId != habitId) return s;
      final newStreak       = newCompleted ? s.streak + 1 : (s.streak - 1).clamp(0, 999);
      final newDaysToFreeze = (s.daysToFreeze - (newCompleted ? 1 : -1)).clamp(0, 999);
      return s.copyWith(
        statusKey:    newCompleted ? HabitStatusKey.done : HabitStatusKey.pending,
        streak:       newStreak,
        daysToFreeze: newDaysToFreeze,
      );
    }).toList();

    state = state.copyWith(completedCache: newCache, streakData: newStreakData);
    _syncWidget();

    // ── Analytics: habit completado ───────────────────────────────────────
    if (newCompleted) {
      final habitData = state.habits.firstWhere(
            (h) => h.id == habitId,
        orElse: () => state.habits.first,
      );
      final streakData = newStreakData.firstWhere(
            (s) => s.habitId == habitId,
        orElse: () => newStreakData.first,
      );
      final currentStreak = streakData.streak as int;

      AnalyticsService.habitCompleted(
        habitId:       habitId,
        habitName:     habitData.name,
        category:      habitData.category ?? 'General',
        currentStreak: currentStreak,
      );

      const milestones = [3, 7, 14, 30, 60, 100];
      if (milestones.contains(currentStreak)) {
        AnalyticsService.streakMilestone(
          habitId:    habitId,
          habitName:  habitData.name,
          streakDays: currentStreak,
        );
      }
    }

    try {
      final dateStr = state.selectedDate.toIso8601String().substring(0, 10);
      await _repo.toggleCompleted(habitId, _userId, dateStr);

      // ── Evaluar objetivos vinculados a este hábito ────────────────────
      await _checkLinkedObjectives(habitId);
    } catch (e) {
      final revertCache = Map<int, bool>.from(state.completedCache);
      revertCache[habitId] = wasCompleted;
      final revertStreaks = state.streakData.map((s) {
        if (s.habitId != habitId) return s;
        return s.copyWith(
          statusKey:    wasCompleted ? HabitStatusKey.done : HabitStatusKey.pending,
          streak:       wasCompleted ? s.streak : (s.streak - 1).clamp(0, 999),
          daysToFreeze: wasCompleted ? s.daysToFreeze : (s.daysToFreeze + 1),
        );
      }).toList();
      state = state.copyWith(
        completedCache: revertCache,
        streakData:     revertStreaks,
        error:          e.toString(),
      );
      _syncWidget();
    }
  }

  // ── Evaluar objetivos vinculados ──────────────────────────────────────────
  // Se llama después de cada toggle. Busca objetivos ligados a este hábito
  // con deadline definido y evalúa si se alcanzó el 80% de completados.

  Future<void> _checkLinkedObjectives(int habitId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Buscar objetivos ligados a este hábito que estén pendientes y tengan deadline
      final objectives = await _db
          .from('objectives')
          .select('id, goal_id, created_at, deadline, status')
          .eq('habit_id', habitId)
          .eq('type', 'habit')
          .eq('status', 'pending')
          .not('deadline', 'is', null)
          .neq('deadline', '');

      for (final obj in objectives as List) {
        final objId      = obj['id'] as int;
        final deadline   = obj['deadline'] as String;
        final createdAt  = obj['created_at'] as String;

        // Solo evaluar si el deadline ya llegó o pasó
        if (deadline.compareTo(today) > 0) continue;

        // Calcular período: desde created_at hasta deadline (inclusive)
        final start = DateTime.parse(createdAt.substring(0, 10));
        final end   = DateTime.parse(deadline);
        final totalDays = end.difference(start).inDays + 1;
        if (totalDays <= 0) continue;

        // Contar días completados en habit_logs dentro del período
        final logs = await _db
            .from('habit_logs')
            .select('date')
            .eq('habit_id', habitId)
            .eq('completed', true)
            .gte('date', createdAt.substring(0, 10))
            .lte('date', deadline);

        final completedDays = (logs as List).length;
        final ratio = completedDays / totalDays;

        if (ratio >= 0.80) {
          // ✅ Objetivo cumplido
          await _db
              .from('objectives')
              .update({'status': 'completed'})
              .eq('id', objId);

          // XP positivo
          await _repo.applyXp(
            _userId,
            50,
            'Objetivo de hábito completado',
            'objective_habit_completed',
            objId,
            today,
          );
        } else {
          // ❌ Objetivo fallido — deadline pasó y no alcanzó el 80%
          await _db
              .from('objectives')
              .update({'status': 'failed'})
              .eq('id', objId);

          // Penalización XP
          await _repo.applyXp(
            _userId,
            -80,
            'Objetivo de hábito fallido (${(ratio * 100).round()}% completado)',
            'objective_habit_failed',
            objId,
            today,
          );
        }
      }
    } catch (e) {
      // Silencioso — no interrumpir el flujo principal
      debugPrint('_checkLinkedObjectives error: $e');
    }
  }

  // ── Crear hábito ──────────────────────────────────────────────────────────

  Future<void> createHabit(String name, String category) async {
    try {
      final newHabit = await _repo.createHabit(_userId, name, category);
      final newStreak = HabitStreak(
        habitId:      newHabit.id,
        name:         newHabit.name,
        streak:       0,
        statusKey:    HabitStatusKey.pending,
        daysToFreeze: 7,
      );
      final newCache = Map<int, bool>.from(state.completedCache);
      newCache[newHabit.id] = false;

      state = state.copyWith(
        habits:         [...state.habits, newHabit],
        streakData:     [...state.streakData, newStreak],
        completedCache: newCache,
        selectedDate:   DateTime.now(),
      );
      _syncWidget();

      AnalyticsService.habitCreated(
        habitName: name,
        category:  category.isEmpty ? 'General' : category,
      );
    } catch (e) {
      state = state.copyWith(error: 'Error creando hábito: $e');
    }
  }

  // ── Retirar hábito ────────────────────────────────────────────────────────

  Future<void> retireHabit(int habitId) async {
    final newCache = Map<int, bool>.from(state.completedCache)..remove(habitId);
    state = state.copyWith(
      habits:         state.habits.where((h) => h.id != habitId).toList(),
      streakData:     state.streakData.where((s) => s.habitId != habitId).toList(),
      completedCache: newCache,
    );
    _syncWidget();
    try {
      await _repo.retireHabit(habitId);
    } catch (e) {
      await _loadScreenData(state.selectedDate);
      state = state.copyWith(error: 'Error retirando hábito: $e');
    }
  }

  // ── Freezes ───────────────────────────────────────────────────────────────

  Future<bool> applyManualFreeze(int habitId) async {
    final ok = await _repo.applyManualFreeze(habitId, _userId);
    if (ok) {
      final habitData = state.habits.firstWhere(
            (h) => h.id == habitId,
        orElse: () => state.habits.first,
      );
      AnalyticsService.freezeUsed(
        habitId:   habitId,
        habitName: habitData.name,
      );
      state = state.copyWith(freezes: state.freezes - 1);
      await _loadScreenData(state.selectedDate);
    }
    return ok;
  }

  Future<List<({int id, String name})>> getMissingYesterday() =>
      _repo.getMissingYesterday(_userId);

  Future<void> applyXp(int amount, String reason, String source,
      int sourceId, String eventDate) =>
      _repo.applyXp(_userId, amount, reason, source, sourceId, eventDate);

  void clearError() => state = state.copyWith(clearError: true);
}