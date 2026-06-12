import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/widget_service.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../data/habits_repository.dart';
import '../../domain/habit.dart';
import '../../domain/habit_objective_eval.dart';
import '../../domain/habits_state.dart';
import '../../../goals/presentation/providers/goals_provider.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>(
  (_) => HabitsRepository(),
);

final userIdProvider = StateProvider<String>((ref) => '');

final habitsProvider =
    StateNotifierProvider<HabitsNotifier, HabitsState>((ref) {
  final repo = ref.watch(habitsRepositoryProvider);
  final userId = ref.watch(userIdProvider);
  return HabitsNotifier(repo, userId, ref);
}, dependencies: [userIdProvider]);

class HabitsNotifier extends StateNotifier<HabitsState> {
  final HabitsRepository _repo;
  final String _userId;
  final Ref _ref;
  final _db = SupabaseConfig.client;

  HabitsNotifier(this._repo, this._userId, this._ref) : super(HabitsState()) {
    if (_userId.isNotEmpty) loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.wait([
      _repo.checkMissedHabits(_userId),
      _repo.checkOverdueHabitObjectives(_userId),
      _loadScreenData(state.selectedDate),
    ]);
    state = state.copyWith(isLoading: false);
    _syncWidget();
  }

  Future<void> _loadScreenData(DateTime date) async {
    try {
      final data = await _repo.loadScreenData(_userId, date);
      state = state.copyWith(
        habits: data.habits,
        streakData: data.streakData,
        completedCache: data.completedMap,
        freezes: data.freezes,
        selectedDate: date,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectDate(DateTime date) => _loadScreenData(date);

  Future<void> refresh() async {
    await loadAll();
  }

  void _syncWidget() {
    if (_userId.isEmpty) return;

    try {
      final maxStreak = state.streakData.isEmpty
          ? 0
          : state.streakData
              .map((s) => s.streak)
              .reduce((a, b) => a > b ? a : b);

      final sorted = [...state.streakData]
        ..sort((a, b) => b.streak.compareTo(a.streak));

      final h1 = sorted.isNotEmpty ? sorted[0] : null;
      final h2 = sorted.length > 1 ? sorted[1] : null;
      final h3 = sorted.length > 2 ? sorted[2] : null;

      WidgetService.updateWidget(
        streak: maxStreak,
        habit1Name: h1?.name ?? '',
        habit1Streak: h1?.streak ?? 0,
        habit2Name: h2?.name ?? '',
        habit2Streak: h2?.streak ?? 0,
        habit3Name: h3?.name ?? '',
        habit3Streak: h3?.streak ?? 0,
      );
    } catch (_) {}
  }

  Future<void> toggleCompleted(int habitId) async {
    if (!state.isToday || state.isTogglePending(habitId)) return;

    final selectedDate = state.selectedDate;
    final dateStr = selectedDate.toIso8601String().substring(0, 10);
    final wasCompleted = state.completedCache[habitId] ?? false;
    final newCompleted = !wasCompleted;
    final previousStreakData = state.streakData;

    final newCache = Map<int, bool>.from(state.completedCache);
    newCache[habitId] = newCompleted;

    state = state.copyWith(
      completedCache: newCache,
      streakData: _optimisticStreakData(
        habitId: habitId,
        wasCompleted: wasCompleted,
        isCompleted: newCompleted,
      ),
      pendingToggleIds: {...state.pendingToggleIds, habitId},
      clearError: true,
    );

    try {
      await _repo.toggleCompleted(habitId, _userId, dateStr);
      if (!mounted) return;
      state = state.copyWith(
        pendingToggleIds: {...state.pendingToggleIds}..remove(habitId),
      );
      _syncWidget();
      unawaited(
        _finishToggleSync(
          habitId: habitId,
          isCompleted: newCompleted,
          selectedDate: selectedDate,
          dateStr: dateStr,
        ),
      );
    } catch (e) {
      final revertCache = Map<int, bool>.from(state.completedCache);
      revertCache[habitId] = wasCompleted;

      state = state.copyWith(
        completedCache: revertCache,
        streakData: previousStreakData,
        pendingToggleIds: {...state.pendingToggleIds}..remove(habitId),
        error: e.toString(),
      );
    }
  }

  List<HabitStreak> _optimisticStreakData({
    required int habitId,
    required bool wasCompleted,
    required bool isCompleted,
  }) {
    final delta = isCompleted
        ? (wasCompleted ? 0 : 1)
        : (wasCompleted ? -1 : 0);

    return state.streakData.map((entry) {
      if (entry.habitId != habitId || delta == 0) {
        return entry;
      }

      if (entry.frequencyMode == HabitFrequencyMode.weekly) {
        var progress = entry.currentPeriodProgress + delta;
        if (progress < 0) progress = 0;
        if (progress > entry.currentPeriodTarget) {
          progress = entry.currentPeriodTarget;
        }

        final wasPeriodComplete =
            entry.currentPeriodProgress >= entry.currentPeriodTarget;
        final isPeriodComplete = progress >= entry.currentPeriodTarget;
        var streak = entry.streak;
        if (!wasPeriodComplete && isPeriodComplete) {
          streak++;
        } else if (wasPeriodComplete && !isPeriodComplete && streak > 0) {
          streak--;
        }

        return entry.copyWith(
          streak: streak,
          statusKey:
              isPeriodComplete ? HabitStatusKey.done : HabitStatusKey.pending,
          currentPeriodProgress: progress,
        );
      }

      var streak = entry.streak + delta;
      if (streak < 0) streak = 0;
      final remainder = streak % 7;
      final daysToFreeze = streak == 0
          ? 7
          : remainder == 0
              ? 0
              : 7 - remainder;

      return entry.copyWith(
        streak: streak,
        statusKey: isCompleted ? HabitStatusKey.done : HabitStatusKey.pending,
        daysToFreeze: daysToFreeze,
        currentPeriodProgress: isCompleted ? 1 : 0,
      );
    }).toList();
  }

  Future<void> _finishToggleSync({
    required int habitId,
    required bool isCompleted,
    required DateTime selectedDate,
    required String dateStr,
  }) async {
    try {
      final tasks = <Future<void>>[_checkLinkedObjectives(habitId)];
      if (isCompleted) {
        tasks.add(
          _repo.applyXp(
            _userId,
            10,
            'Habito completado',
            'habit_completed',
            habitId,
            dateStr,
          ),
        );
        tasks.add(
          _repo
              .awardEarnedFreezes(habitId, _userId, dateStr)
              .then((_) {}),
        );
        tasks.add(_trackHabitCompletion(habitId));
      }
      await Future.wait(tasks);
    } catch (e) {
      debugPrint('_finishToggleSync error: $e');
    }

    if (!mounted || !_sameDay(state.selectedDate, selectedDate)) {
      return;
    }
    await _loadScreenData(selectedDate);
    _syncWidget();
  }

  Future<void> _trackHabitCompletion(int habitId) async {
    final habitIndex = state.habits.indexWhere((h) => h.id == habitId);
    final streakIndex =
        state.streakData.indexWhere((entry) => entry.habitId == habitId);
    if (habitIndex == -1 || streakIndex == -1) {
      return;
    }

    final habit = state.habits[habitIndex];
    final currentStreak = state.streakData[streakIndex].streak;
    await AnalyticsService.habitCompleted(
      habitId: habitId,
      habitName: habit.name,
      category: habit.category,
      currentStreak: currentStreak,
    );

    const milestones = [3, 7, 14, 30, 60, 100];
    if (milestones.contains(currentStreak)) {
      await AnalyticsService.streakMilestone(
        habitId: habitId,
        habitName: habit.name,
        streakDays: currentStreak,
      );
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _checkLinkedObjectives(int habitId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      var goalsChanged = false;

      final ownedHabit = await _db
          .from('habits')
          .select('id')
          .eq('id', habitId)
          .eq('user_id', _userId)
          .maybeSingle();

      if (ownedHabit == null) {
        debugPrint(
          '_checkLinkedObjectives skipped: habit=$habitId does not belong to user=$_userId',
        );
        return;
      }

      final objectives = await _db
          .from('objectives')
          .select(
            'id, goal_id, created_at, deadline, status, goals!inner(user_id)',
          )
          .eq('habit_id', habitId)
          .eq('type', 'habit')
          .eq('status', 'pending')
          .eq('goals.user_id', _userId)
          .not('deadline', 'is', null);

      for (final obj in objectives as List) {
        final objId = obj['id'] as int;
        final goalId = obj['goal_id'] as int;
        final deadlineRaw = obj['deadline'];
        final createdAtRaw = obj['created_at'] as String;

        if (deadlineRaw == null || deadlineRaw.toString().isEmpty) continue;
        final endDate = deadlineRaw.toString();

        final warmupEvaluation = evaluateHabitObjectiveProgress(
          createdAtRaw: createdAtRaw,
          endDate: endDate,
          today: today,
          completedDays: 0,
        );
        if (warmupEvaluation == null) continue;

        debugPrint(
          'QUERY: habit_id=$habitId user_id=$_userId '
          'startDate=${warmupEvaluation.startDate} '
          'evalEnd=${warmupEvaluation.evalEndDate}',
        );

        final logs = await _db
            .from('habit_logs')
            .select('date')
            .eq('habit_id', habitId)
            .eq('user_id', _userId)
            .eq('completed', true)
            .gte('date', warmupEvaluation.startDate)
            .lte('date', warmupEvaluation.evalEndDate);

        debugPrint('LOGS RAW: $logs');
        final completedDays = (logs as List).length;

        final evaluation = evaluateHabitObjectiveProgress(
          createdAtRaw: createdAtRaw,
          endDate: endDate,
          today: today,
          completedDays: completedDays,
        );
        if (evaluation == null) continue;

        debugPrint(
          '_checkLinkedObjectives: obj=$objId habit=$habitId '
          'start=${evaluation.startDate} end=$endDate '
          'evalEnd=${evaluation.evalEndDate} completed=$completedDays '
          'elapsed=${evaluation.elapsedDays} total=${evaluation.totalDays} '
          'ratio=${(evaluation.ratio * 100).round()}% '
          'deadlineReached=${evaluation.deadlineReached}',
        );

        if (evaluation.ratio >= 0.80) {
          await _db
              .from('objectives')
              .update({'status': 'completed'})
              .eq('id', objId);
          _ref
              .read(goalsProvider.notifier)
              .applyLinkedObjectiveResult(goalId, completed: true);
          await _repo.applyXp(
            _userId,
            50,
            'Objetivo de habito completado',
            'objective_habit_completed',
            objId,
            today,
          );
          goalsChanged = true;
        } else if (evaluation.deadlineReached) {
          await _db.from('objectives').update({'status': 'failed'}).eq(
            'id',
            objId,
          );
          await _repo.applyXp(
            _userId,
            -80,
            'Objetivo de habito fallido (${(evaluation.ratio * 100).round()}% completado)',
            'objective_habit_failed',
            objId,
            today,
          );
          goalsChanged = true;
        }
      }

      if (goalsChanged) {
        await _ref.read(goalsProvider.notifier).load();
      }
    } catch (e) {
      debugPrint('_checkLinkedObjectives error: $e');
    }
  }

  Future<void> createHabit(
    String name,
    String category, {
    HabitFrequencyMode frequencyMode = HabitFrequencyMode.daily,
    int weeklyTarget = 7,
  }) async {
    try {
      final newHabit = await _repo.createHabit(
        _userId,
        name,
        category,
        frequencyMode: frequencyMode,
        weeklyTarget: weeklyTarget,
      );
      final newStreak = HabitStreak(
        habitId: newHabit.id,
        name: newHabit.name,
        streak: 0,
        statusKey: HabitStatusKey.pending,
        daysToFreeze: frequencyMode == HabitFrequencyMode.daily ? 7 : 0,
        frequencyMode: frequencyMode,
        weeklyTarget: frequencyMode == HabitFrequencyMode.daily ? 7 : weeklyTarget,
        currentPeriodProgress: 0,
        currentPeriodTarget: frequencyMode == HabitFrequencyMode.daily ? 1 : weeklyTarget,
      );
      final newCache = Map<int, bool>.from(state.completedCache);
      newCache[newHabit.id] = false;

      state = state.copyWith(
        habits: [...state.habits, newHabit],
        streakData: [...state.streakData, newStreak],
        completedCache: newCache,
        selectedDate: DateTime.now(),
      );
      _syncWidget();

      AnalyticsService.habitCreated(
        habitName: name,
        category: category.isEmpty ? 'General' : category,
      );
    } catch (e) {
      state = state.copyWith(error: 'Error creando habito: $e');
    }
  }

  Future<void> retireHabit(int habitId) async {
    final newCache = Map<int, bool>.from(state.completedCache)..remove(habitId);
    state = state.copyWith(
      habits: state.habits.where((h) => h.id != habitId).toList(),
      streakData: state.streakData.where((s) => s.habitId != habitId).toList(),
      completedCache: newCache,
    );
    _syncWidget();

    try {
      await _repo.retireHabit(habitId);
    } catch (e) {
      await _loadScreenData(state.selectedDate);
      state = state.copyWith(error: 'Error retirando habito: $e');
    }
  }

  Future<bool> applyManualFreeze(int habitId) async {
    final ok = await _repo.applyManualFreeze(habitId, _userId);
    if (ok) {
      final habitIndex = state.habits.indexWhere((h) => h.id == habitId);
      if (habitIndex != -1) {
        AnalyticsService.freezeUsed(
          habitId: habitId,
          habitName: state.habits[habitIndex].name,
        );
      }

      state = state.copyWith(freezes: state.freezes - 1);
      await _loadScreenData(state.selectedDate);
    }
    return ok;
  }

  Future<bool> applyManualFreezeForDate(
    int habitId,
    DateTime freezeDate, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _userId;
    final ok = await _repo.applyManualFreeze(
      habitId,
      effectiveUserId,
      freezeDate: freezeDate,
    );
    if (ok) {
      state = state.copyWith(freezes: state.freezes - 1);
      await _loadScreenData(state.selectedDate);
    }
    return ok;
  }

  Future<List<PendingHabitFreeze>> getPendingFreezes() =>
      _repo.getPendingFreezes(_userId);

  Future<({
    int freezes,
    List<PendingHabitFreeze> pending,
  })> getFreezePromptData({String? userId}) async {
    final effectiveUserId = userId ?? _userId;
    if (effectiveUserId.isEmpty) {
      return (
        freezes: 0,
        pending: const <PendingHabitFreeze>[],
      );
    }

    final results = await Future.wait<Object>([
      _repo.getUserFreezes(effectiveUserId),
      _repo.getPendingFreezes(effectiveUserId),
    ]);
    final freezes = results[0] as int;
    final pending = results[1] as List<PendingHabitFreeze>;
    state = state.copyWith(freezes: freezes);
    return (freezes: freezes, pending: pending);
  }

  Future<void> applyXp(
    int amount,
    String reason,
    String source,
    int sourceId,
    String eventDate,
  ) =>
      _repo.applyXp(_userId, amount, reason, source, sourceId, eventDate);

  void clearError() => state = state.copyWith(clearError: true);
}
