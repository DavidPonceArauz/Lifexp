import 'package:flutter/foundation.dart';

import '../../../core/services/xp_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/habit.dart';
import '../domain/habit_objective_eval.dart';

class HabitsRepository {
  final _db = SupabaseConfig.client;
  final _xpService = XpService();

  Future<({
    List<Habit> habits,
    List<HabitStreak> streakData,
    Map<int, bool> completedMap,
    int freezes,
  })> loadScreenData(String userId, DateTime date) async {
    final dateStr = _dateKey(date);
    final habits = await _loadHabits(userId, dateStr);
    final freezes = await getUserFreezes(userId);

    if (habits.isEmpty) {
      return (
        habits: const <Habit>[],
        streakData: const <HabitStreak>[],
        completedMap: const <int, bool>{},
        freezes: freezes,
      );
    }

    final habitIds = habits.map((h) => h.id).toList();
    final completionRows = await _db
        .from('habit_logs')
        .select('habit_id')
        .eq('user_id', userId)
        .inFilter('habit_id', habitIds)
        .eq('date', dateStr)
        .eq('completed', true);

    final completedMap = <int, bool>{
      for (final h in habits) h.id: false,
    };
    for (final row in completionRows as List) {
      completedMap[row['habit_id'] as int] = true;
    }

    final completedDatesByHabit = await _loadCompletedDatesByHabit(
      userId,
      habitIds,
      dateStr,
    );
    final freezeDatesByHabit = await _loadFreezeDatesByHabit(
      userId,
      habitIds,
      dateStr,
    );

    final streakData = habits
        .map(
          (habit) => _buildHabitStreak(
            habit: habit,
            selectedDate: date,
            completedDates: completedDatesByHabit[habit.id] ?? const <String>{},
            freezeDates: freezeDatesByHabit[habit.id] ?? const <String>{},
            isCompletedOnSelectedDate: completedMap[habit.id] ?? false,
          ),
        )
        .toList();

    return (
      habits: habits,
      streakData: streakData,
      completedMap: completedMap,
      freezes: freezes,
    );
  }

  Future<void> toggleCompleted(int habitId, String userId, String dateStr) async {
    await _db.rpc('toggle_habit', params: {
      'p_habit_id': habitId,
      'p_user_id': userId,
      'p_date': dateStr,
    });
  }

  Future<Habit> createHabit(
    String userId,
    String name,
    String category, {
    HabitFrequencyMode frequencyMode = HabitFrequencyMode.daily,
    int weeklyTarget = 7,
  }) async {
    final dateStr = _dateKey(DateTime.now());
    try {
      final result = await _db
          .from('habits')
          .insert({
            'user_id': userId,
            'name': name.trim(),
            'category': category.trim(),
            'active': true,
            'created_at': dateStr,
            'frequency_mode': frequencyMode.name,
            'weekly_target':
                frequencyMode == HabitFrequencyMode.daily ? 7 : weeklyTarget,
          })
          .select(
            'id, user_id, name, category, active, created_at, frequency_mode, weekly_target',
          )
          .single();
      return Habit.fromMap(Map<String, dynamic>.from(result));
    } catch (_) {
      final result = await _db
          .from('habits')
          .insert({
            'user_id': userId,
            'name': name.trim(),
            'category': category.trim(),
            'active': true,
            'created_at': dateStr,
          })
          .select('id, user_id, name, category, active, created_at')
          .single();
      return Habit.fromMap(Map<String, dynamic>.from(result)).copyWith(
        frequencyMode: frequencyMode,
        weeklyTarget: frequencyMode == HabitFrequencyMode.daily ? 7 : weeklyTarget,
      );
    }
  }

  Future<void> retireHabit(int habitId) async {
    await _db.from('habits').update({
      'active': false,
      'deleted_at': _dateKey(DateTime.now()),
    }).eq('id', habitId);
  }

  Future<int> getUserFreezes(String userId) async {
    try {
      final result = await _db
          .from('habit_freezes')
          .select('freezes')
          .eq('user_id', userId)
          .maybeSingle();
      if (result == null) {
        await _db.from('habit_freezes').insert({'user_id': userId, 'freezes': 0});
        return 0;
      }
      return result['freezes'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> applyManualFreeze(
    int habitId,
    String userId, {
    DateTime? freezeDate,
  }) async {
    try {
      final effectiveDate = _dateKey(
        freezeDate ?? DateTime.now().subtract(const Duration(days: 1)),
      );

      final existingFreeze = await _db
          .from('habit_freeze_days')
          .select('habit_id')
          .eq('habit_id', habitId)
          .eq('user_id', userId)
          .eq('date', effectiveDate)
          .maybeSingle();
      if (existingFreeze != null) {
        return false;
      }

      final freezes = await getUserFreezes(userId);
      if (freezes <= 0) {
        return false;
      }

      await _db.from('habit_freeze_days').insert({
        'habit_id': habitId,
        'user_id': userId,
        'date': effectiveDate,
      });
      await _db
          .from('habit_freezes')
          .update({'freezes': freezes - 1}).eq('user_id', userId);
      await _clearMissedXpPenalty(userId, habitId, effectiveDate);
      return true;
    } catch (e) {
      debugPrint('applyManualFreeze error: $e');
      return false;
    }
  }

  Future<int> awardEarnedFreezes(
    int habitId,
    String userId,
    String dateStr,
  ) async {
    try {
      final habits = await _loadHabits(userId, dateStr);
      Habit? habit;
      for (final candidate in habits) {
        if (candidate.id == habitId) {
          habit = candidate;
          break;
        }
      }
      if (habit == null || habit.frequencyMode != HabitFrequencyMode.daily) {
        return 0;
      }

      final completedDatesByHabit = await _loadCompletedDatesByHabit(
        userId,
        [habitId],
        dateStr,
      );
      final freezeDatesByHabit = await _loadFreezeDatesByHabit(
        userId,
        [habitId],
        dateStr,
      );
      final streak = _countDailyStreakFrom(
        habit: habit,
        selectedDate: DateTime.parse(dateStr),
        completedDates: completedDatesByHabit[habitId] ?? const <String>{},
        freezeDates: freezeDatesByHabit[habitId] ?? const <String>{},
      );
      final milestone = (streak ~/ 7) * 7;
      if (milestone < 7) {
        return 0;
      }

      final progress = await _db
          .from('habit_freeze_progress')
          .select('streak_at_reward')
          .eq('user_id', userId)
          .eq('habit_id', habitId)
          .maybeSingle();
      final lastRewarded =
          (progress?['streak_at_reward'] as num?)?.toInt() ?? 0;
      if (lastRewarded >= milestone) {
        return 0;
      }

      var rewardsDue = (milestone - lastRewarded) ~/ 7;
      if (rewardsDue <= 0) {
        return 0;
      }
      if (rewardsDue > 20) {
        rewardsDue = 20;
      }

      final freezes = await getUserFreezes(userId);
      await _db
          .from('habit_freezes')
          .update({'freezes': freezes + rewardsDue}).eq('user_id', userId);
      await _saveFreezeProgress(userId, habitId, milestone, milestone + 7);
      return rewardsDue;
    } catch (e) {
      debugPrint('awardEarnedFreezes error: $e');
      return 0;
    }
  }

  Future<List<PendingHabitFreeze>> getPendingFreezes(String userId) async {
    try {
      final today = _dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final previousWeekStart = _weekStart(today).subtract(const Duration(days: 7));
      final previousWeekEnd = previousWeekStart.add(const Duration(days: 6));
      final habits = await _loadHabits(userId, _dateKey(today));

      if (habits.isEmpty) {
        return const <PendingHabitFreeze>[];
      }

      final habitIds = habits.map((h) => h.id).toList();
      final completedDatesByHabit = await _loadCompletedDatesByHabit(
        userId,
        habitIds,
        _dateKey(today),
      );
      final freezeDatesByHabit = await _loadFreezeDatesByHabit(
        userId,
        habitIds,
        _dateKey(today),
      );

      final pending = <PendingHabitFreeze>[];
      for (final habit in habits) {
        final completedDates = completedDatesByHabit[habit.id] ?? const <String>{};
        final freezeDates = freezeDatesByHabit[habit.id] ?? const <String>{};

        if (habit.frequencyMode == HabitFrequencyMode.daily) {
          if (_dateOnly(DateTime.parse(habit.createdAt)).isAfter(yesterday)) {
            continue;
          }
          final yesterdayKey = _dateKey(yesterday);
          if (!completedDates.contains(yesterdayKey) &&
              !freezeDates.contains(yesterdayKey)) {
            pending.add(
              PendingHabitFreeze(
                habitId: habit.id,
                name: habit.name,
                freezeDate: yesterday,
                isWeekly: false,
                periodLabel: yesterdayKey,
              ),
            );
          }
          continue;
        }

        if (_dateOnly(DateTime.parse(habit.createdAt)).isAfter(previousWeekEnd)) {
          continue;
        }

        final previousWeekCount = _countCompletionsInRange(
          completedDates,
          previousWeekStart,
          previousWeekEnd,
        );
        final weekFreezeKey = _dateKey(previousWeekEnd);
        if (previousWeekCount < habit.weeklyTarget &&
            !freezeDates.contains(weekFreezeKey)) {
          pending.add(
            PendingHabitFreeze(
              habitId: habit.id,
              name: habit.name,
              freezeDate: previousWeekEnd,
              isWeekly: true,
              periodLabel:
                  '${_dateKey(previousWeekStart)} - ${_dateKey(previousWeekEnd)}',
            ),
          );
        }
      }

      return pending;
    } catch (e) {
      debugPrint('getPendingFreezes error: $e');
      return const <PendingHabitFreeze>[];
    }
  }

  Future<void> applyXp(
    String userId,
    int amount,
    String reason,
    String source,
    int sourceId,
    String eventDate,
  ) async {
    await _xpService.applyXp(
      userId: userId,
      amount: amount,
      reason: reason,
      source: source,
      sourceId: sourceId,
      eventDate: eventDate,
    );
  }

  Future<void> checkMissedHabits(String userId) async {
    try {
      final today = _dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final previousWeekStart = _weekStart(today).subtract(const Duration(days: 7));
      final previousWeekEnd = previousWeekStart.add(const Duration(days: 6));
      final habits = await _loadHabits(userId, _dateKey(today));

      if (habits.isEmpty) {
        return;
      }

      final habitIds = habits.map((h) => h.id).toList();
      final completedDatesByHabit = await _loadCompletedDatesByHabit(
        userId,
        habitIds,
        _dateKey(today),
      );
      final freezeDatesByHabit = await _loadFreezeDatesByHabit(
        userId,
        habitIds,
        _dateKey(today),
      );

      for (final habit in habits) {
        final completedDates = completedDatesByHabit[habit.id] ?? const <String>{};
        final freezeDates = freezeDatesByHabit[habit.id] ?? const <String>{};
        if (habit.frequencyMode == HabitFrequencyMode.daily) {
          if (_dateOnly(DateTime.parse(habit.createdAt)).isAfter(yesterday)) {
            continue;
          }
          final yesterdayKey = _dateKey(yesterday);
          if (!completedDates.contains(yesterdayKey) &&
              !freezeDates.contains(yesterdayKey)) {
            await applyXp(
              userId,
              -15,
              'Habito no registrado: ${habit.name}',
              'habit_missed',
              habit.id,
              yesterdayKey,
            );
          }
          continue;
        }

        if (_dateOnly(DateTime.parse(habit.createdAt)).isAfter(previousWeekEnd)) {
          continue;
        }
        final previousWeekCount = _countCompletionsInRange(
          completedDates,
          previousWeekStart,
          previousWeekEnd,
        );
        final weekFreezeKey = _dateKey(previousWeekEnd);
        if (previousWeekCount < habit.weeklyTarget &&
            !freezeDates.contains(weekFreezeKey)) {
          await applyXp(
            userId,
            -15,
            'Habito semanal no completado: ${habit.name}',
            'habit_weekly_missed',
            habit.id,
            weekFreezeKey,
          );
        }
      }
    } catch (e) {
      debugPrint('checkMissed error: $e');
    }
  }

  Future<void> checkOverdueHabitObjectives(String userId) async {
    try {
      final today = _dateKey(DateTime.now());

      final objectives = await _db
          .from('objectives')
          .select('id, habit_id, created_at, deadline, goals!inner(user_id)')
          .eq('type', 'habit')
          .eq('status', 'pending')
          .eq('goals.user_id', userId)
          .not('deadline', 'is', null)
          .lt('deadline', today);

      if ((objectives as List).isEmpty) {
        return;
      }

      final habitIds = objectives.map((o) => o['habit_id'] as int).toSet().toList();

      final userHabits = await _db
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .inFilter('id', habitIds);

      final userHabitIds =
          (userHabits as List).map((h) => h['id'] as int).toSet();

      for (final obj in objectives) {
        final habitId = obj['habit_id'] as int;
        if (!userHabitIds.contains(habitId)) {
          continue;
        }

        final objId = obj['id'] as int;
        final deadlineRaw = obj['deadline'];
        final createdAtRaw = obj['created_at'] as String;

        if (deadlineRaw == null || deadlineRaw.toString().isEmpty) {
          continue;
        }
        final deadline = deadlineRaw.toString();

        final baseEvaluation = evaluateHabitObjectiveProgress(
          createdAtRaw: createdAtRaw,
          endDate: deadline,
          today: today,
          completedDays: 0,
        );
        if (baseEvaluation == null) {
          continue;
        }

        final logs = await _db
            .from('habit_logs')
            .select('date')
            .eq('habit_id', habitId)
            .eq('user_id', userId)
            .eq('completed', true)
            .gte('date', baseEvaluation.startDate)
            .lte('date', deadline);

        final completedDays = (logs as List).length;
        final evaluation = evaluateHabitObjectiveProgress(
          createdAtRaw: createdAtRaw,
          endDate: deadline,
          today: today,
          completedDays: completedDays,
        );
        if (evaluation == null) {
          continue;
        }

        debugPrint(
          'checkOverdueHabitObjectives: obj=$objId habit=$habitId '
          'start=${evaluation.startDate} end=$deadline '
          'completed=$completedDays total=${evaluation.totalDays} '
          'ratio=${(evaluation.ratio * 100).round()}%',
        );

        if (evaluation.ratio >= 0.80) {
          await _db
              .from('objectives')
              .update({'status': 'completed'}).eq('id', objId);

          await applyXp(
            userId,
            50,
            'Objetivo de habito completado',
            'objective_habit_completed',
            objId,
            today,
          );
        } else {
          await _db
              .from('objectives')
              .update({'status': 'failed'}).eq('id', objId);

          await applyXp(
            userId,
            -80,
            'Objetivo de habito fallido (${(evaluation.ratio * 100).round()}% completado)',
            'objective_habit_failed',
            objId,
            today,
          );
        }
      }
    } catch (e) {
      debugPrint('checkOverdueHabitObjectives error: $e');
    }
  }

  Future<List<Habit>> _loadHabits(String userId, String maxDate) async {
    try {
      final rows = await _db
          .from('habits')
          .select(
            'id, user_id, name, category, active, created_at, frequency_mode, weekly_target',
          )
          .eq('user_id', userId)
          .eq('active', true)
          .lte('created_at', maxDate)
          .order('created_at');
      return (rows as List)
          .map((row) => Habit.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      final rows = await _db
          .from('habits')
          .select('id, user_id, name, category, active, created_at')
          .eq('user_id', userId)
          .eq('active', true)
          .lte('created_at', maxDate)
          .order('created_at');
      return (rows as List)
          .map((row) => Habit.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    }
  }

  Future<Map<int, Set<String>>> _loadCompletedDatesByHabit(
    String userId,
    List<int> habitIds,
    String maxDate,
  ) async {
    final rows = await _db
        .from('habit_logs')
        .select('habit_id, date')
        .eq('user_id', userId)
        .inFilter('habit_id', habitIds)
        .eq('completed', true)
        .lte('date', maxDate);

    final byHabit = <int, Set<String>>{
      for (final habitId in habitIds) habitId: <String>{},
    };
    for (final row in rows as List) {
      byHabit[row['habit_id'] as int]?.add(row['date'] as String);
    }
    return byHabit;
  }

  Future<Map<int, Set<String>>> _loadFreezeDatesByHabit(
    String userId,
    List<int> habitIds,
    String maxDate,
  ) async {
    final rows = await _db
        .from('habit_freeze_days')
        .select('habit_id, date')
        .eq('user_id', userId)
        .inFilter('habit_id', habitIds)
        .lte('date', maxDate);

    final byHabit = <int, Set<String>>{
      for (final habitId in habitIds) habitId: <String>{},
    };
    for (final row in rows as List) {
      byHabit[row['habit_id'] as int]?.add(row['date'] as String);
    }
    return byHabit;
  }

  HabitStreak _buildHabitStreak({
    required Habit habit,
    required DateTime selectedDate,
    required Set<String> completedDates,
    required Set<String> freezeDates,
    required bool isCompletedOnSelectedDate,
  }) {
    if (habit.frequencyMode == HabitFrequencyMode.weekly) {
      return _buildWeeklyStreak(
        habit: habit,
        selectedDate: selectedDate,
        completedDates: completedDates,
        freezeDates: freezeDates,
      );
    }

    return _buildDailyStreak(
      habit: habit,
      selectedDate: selectedDate,
      completedDates: completedDates,
      freezeDates: freezeDates,
      isCompletedOnSelectedDate: isCompletedOnSelectedDate,
    );
  }

  HabitStreak _buildDailyStreak({
    required Habit habit,
    required DateTime selectedDate,
    required Set<String> completedDates,
    required Set<String> freezeDates,
    required bool isCompletedOnSelectedDate,
  }) {
    final selected = _dateOnly(selectedDate);
    final today = _dateOnly(DateTime.now());
    final createdAt = _dateOnly(DateTime.parse(habit.createdAt));
    final selectedKey = _dateKey(selected);
    final isFrozen = freezeDates.contains(selectedKey);

    final statusKey = isCompletedOnSelectedDate
        ? HabitStatusKey.done
        : isFrozen
            ? HabitStatusKey.frozen
            : selected.isBefore(today)
                ? HabitStatusKey.missed
                : HabitStatusKey.pending;

    var streak = 0;
    var cursor = selected;
    if (selected == today && !isCompletedOnSelectedDate && !isFrozen) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (!cursor.isBefore(createdAt)) {
      final key = _dateKey(cursor);
      if (completedDates.contains(key) || freezeDates.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }

    final remainingToFreeze = streak == 0
        ? 7
        : streak % 7 == 0
            ? 0
            : 7 - (streak % 7);

    return HabitStreak(
      habitId: habit.id,
      name: habit.name,
      streak: streak,
      statusKey: statusKey,
      daysToFreeze: remainingToFreeze,
      frequencyMode: habit.frequencyMode,
      weeklyTarget: habit.weeklyTarget,
      currentPeriodProgress: isCompletedOnSelectedDate ? 1 : 0,
      currentPeriodTarget: 1,
    );
  }

  HabitStreak _buildWeeklyStreak({
    required Habit habit,
    required DateTime selectedDate,
    required Set<String> completedDates,
    required Set<String> freezeDates,
  }) {
    final selected = _dateOnly(selectedDate);
    final today = _dateOnly(DateTime.now());
    final selectedWeekStart = _weekStart(selected);
    final selectedWeekEnd = selectedWeekStart.add(const Duration(days: 6));
    final selectedWeekCount =
        _countCompletionsInRange(completedDates, selectedWeekStart, selectedWeekEnd);
    final isFrozen = freezeDates.contains(_dateKey(selectedWeekEnd));
    final isComplete = selectedWeekCount >= habit.weeklyTarget;

    final statusKey = isComplete
        ? HabitStatusKey.done
        : isFrozen
            ? HabitStatusKey.frozen
            : selectedWeekEnd.isBefore(today)
                ? HabitStatusKey.missed
                : HabitStatusKey.pending;

    var streak = 0;
    var weekStart = selectedWeekStart;
    var skippedCurrentOpenWeek = false;

    while (true) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      if (weekEnd.isBefore(_dateOnly(DateTime.parse(habit.createdAt)))) {
        break;
      }

      final weekCount =
          _countCompletionsInRange(completedDates, weekStart, weekEnd);
      final weekFrozen = freezeDates.contains(_dateKey(weekEnd));
      final weekComplete = weekCount >= habit.weeklyTarget || weekFrozen;
      final isCurrentWeek = weekStart == selectedWeekStart;

      if (isCurrentWeek &&
          !weekComplete &&
          !weekEnd.isBefore(today) &&
          !skippedCurrentOpenWeek) {
        skippedCurrentOpenWeek = true;
        weekStart = weekStart.subtract(const Duration(days: 7));
        continue;
      }

      if (weekComplete) {
        streak++;
        weekStart = weekStart.subtract(const Duration(days: 7));
        continue;
      }
      break;
    }

    return HabitStreak(
      habitId: habit.id,
      name: habit.name,
      streak: streak,
      statusKey: statusKey,
      daysToFreeze: 0,
      frequencyMode: habit.frequencyMode,
      weeklyTarget: habit.weeklyTarget,
      currentPeriodProgress: selectedWeekCount,
      currentPeriodTarget: habit.weeklyTarget,
    );
  }

  int _countCompletionsInRange(
    Set<String> completedDates,
    DateTime start,
    DateTime end,
  ) {
    var count = 0;
    var cursor = _dateOnly(start);
    final normalizedEnd = _dateOnly(end);
    while (!cursor.isAfter(normalizedEnd)) {
      if (completedDates.contains(_dateKey(cursor))) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  int _countDailyStreakFrom({
    required Habit habit,
    required DateTime selectedDate,
    required Set<String> completedDates,
    required Set<String> freezeDates,
  }) {
    final createdAt = _dateOnly(DateTime.parse(habit.createdAt));
    var streak = 0;
    var cursor = _dateOnly(selectedDate);
    while (!cursor.isBefore(createdAt)) {
      final key = _dateKey(cursor);
      if (completedDates.contains(key) || freezeDates.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return streak;
  }

  Future<void> _clearMissedXpPenalty(
    String userId,
    int habitId,
    String eventDate,
  ) async {
    var removedPenalty = false;
    for (final source in const ['habit_missed', 'habit_weekly_missed']) {
      final rows = await _db
          .from('xp_log')
          .select('id')
          .eq('user_id', userId)
          .eq('source', source)
          .eq('source_id', habitId)
          .eq('event_date', eventDate);
      if ((rows as List).isEmpty) {
        continue;
      }

      await _db
          .from('xp_log')
          .delete()
          .eq('user_id', userId)
          .eq('source', source)
          .eq('source_id', habitId)
          .eq('event_date', eventDate);
      removedPenalty = true;
    }

    if (removedPenalty) {
      await _recalculateProfileXp(userId);
    }
  }

  Future<void> _recalculateProfileXp(String userId) async {
    final rows = await _db.from('xp_log').select('amount').eq('user_id', userId);
    var totalXp = 0;
    for (final row in rows as List) {
      final amount = row['amount'];
      if (amount is int) {
        totalXp += amount;
      } else if (amount is num) {
        totalXp += amount.round();
      }
    }
    if (totalXp < 0) {
      totalXp = 0;
    } else if (totalXp > 999999) {
      totalXp = 999999;
    }
    await _db.from('profiles').update({'total_xp': totalXp}).eq('id', userId);
  }

  Future<void> _saveFreezeProgress(
    String userId,
    int habitId,
    int streakAtReward,
    int nextMilestone,
  ) async {
    final existing = await _db
        .from('habit_freeze_progress')
        .select('habit_id')
        .eq('user_id', userId)
        .eq('habit_id', habitId)
        .maybeSingle();

    final values = {
      'streak_at_reward': streakAtReward,
      'next_milestone': nextMilestone,
    };

    if (existing == null) {
      await _db.from('habit_freeze_progress').insert({
        'user_id': userId,
        'habit_id': habitId,
        ...values,
      });
      return;
    }

    await _db
        .from('habit_freeze_progress')
        .update(values)
        .eq('user_id', userId)
        .eq('habit_id', habitId);
  }

  DateTime _weekStart(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) =>
      _dateOnly(date).toIso8601String().substring(0, 10);
}
