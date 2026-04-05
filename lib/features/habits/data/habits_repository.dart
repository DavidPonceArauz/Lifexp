// ===========================
// 🗄️ HABITS REPOSITORY
// ===========================

import 'package:flutter/foundation.dart';
import '../domain/habit.dart';
import '../domain/habit_objective_eval.dart';
import '../../../core/supabase/supabase_client.dart';

class HabitsRepository {
  final _db = SupabaseConfig.client;

  // ── Carga principal (RPC batch) ───────────────────────────────────────────

  Future<({
  List<Habit> habits,
  List<HabitStreak> streakData,
  Map<int, bool> completedMap,
  int freezes,
  })> loadScreenData(String userId, DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);

    // Una sola llamada que trae hábitos, completados, freezes
    final result = await _db.rpc('get_habits_screen_data', params: {
      'p_user_id': userId,
      'p_date': dateStr,
    });

    final habitsRaw = List<Map<String, dynamic>>.from(result['habits'] ?? []);
    final streakDataRaw = List<Map<String, dynamic>>.from(result['streak_data'] ?? []);
    final completedMapRaw = Map<String, dynamic>.from(result['completed_map'] ?? {});
    final freezes = result['freezes'] as int? ?? 0;

    final habits = habitsRaw.map(Habit.fromMap).toList();

    final Map<int, bool> completedMap = {
      for (final h in habits)
        h.id: completedMapRaw[h.id.toString()] == true,
    };

    // ✅ Una sola llamada SQL para TODOS los streaks
    final streakRows = await _db.rpc('get_habit_streaks', params: {
      'p_user_id': userId,
    }) as List;

    final streakByHabitId = <int, Map<String, dynamic>>{
      for (final r in streakRows)
        r['out_habit_id'] as int: r as Map<String, dynamic>,
    };

    final streakData = streakDataRaw.map((s) {
      final hid = s['id'] as int;
      final isCompleted = s['is_completed_today'] as bool? ?? false;
      final isFrozen = s['is_frozen_today'] as bool? ?? false;

      final statusKey = isCompleted
          ? HabitStatusKey.done
          : isFrozen
          ? HabitStatusKey.frozen
          : HabitStatusKey.pending;

      final streakRow = streakByHabitId[hid];
      final streak = streakRow?['out_streak'] as int? ?? 0;
      final daysToFreeze = streakRow?['out_days_to_freeze'] as int? ?? 7;

      return HabitStreak(
        habitId: hid,
        name: s['name'] as String,
        streak: streak,
        statusKey: statusKey,
        daysToFreeze: daysToFreeze,
      );
    }).toList();

    return (
    habits: habits,
    streakData: streakData,
    completedMap: completedMap,
    freezes: freezes,
    );
  }

  // ── Toggle completado ─────────────────────────────────────────────────────

  Future<void> toggleCompleted(int habitId, String userId, String dateStr) async {
    await _db.rpc('toggle_habit', params: {
      'p_habit_id': habitId,
      'p_user_id': userId,
      'p_date': dateStr,
    });
  }

  // ── Crear hábito ──────────────────────────────────────────────────────────

  Future<Habit> createHabit(String userId, String name, String category) async {
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final result = await _db.from('habits').insert({
      'user_id': userId,
      'name': name.trim(),
      'category': category.trim(),
      'active': true,
      'created_at': dateStr,
    }).select('id, user_id, name, category, active, created_at').single();
    return Habit.fromMap(result);
  }

  // ── Retirar hábito ────────────────────────────────────────────────────────

  Future<void> retireHabit(int habitId) async {
    await _db.from('habits').update({
      'active': false,
      'deleted_at': DateTime.now().toIso8601String().substring(0, 10),
    }).eq('id', habitId);
  }

  // ── Freezes ───────────────────────────────────────────────────────────────

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

  Future<bool> applyManualFreeze(int habitId, String userId) async {
    final freezes = await getUserFreezes(userId);
    if (freezes <= 0) return false;
    try {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);

      await _db.from('habit_freeze_days').upsert({
        'habit_id': habitId,
        'user_id': userId,
        'date': yesterday,
      });
      await _db
          .from('habit_freezes')
          .update({'freezes': freezes - 1}).eq('user_id', userId);
      await _db.from('habit_freeze_progress').upsert({
        'user_id': userId,
        'habit_id': habitId,
        'streak_at_reward': 0,
        'next_milestone': 7,
      });
      return true;
    } catch (e) {
      debugPrint('applyManualFreeze error: $e');
      return false;
    }
  }

  // ── Hábitos faltantes ayer ────────────────────────────────────────────────

  Future<List<({int id, String name})>> getMissingYesterday(String userId) async {
    try {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);

      // 1 query — hábitos activos creados antes de ayer
      final habits = await _db
          .from('habits')
          .select('id, name')
          .eq('user_id', userId)
          .eq('active', true)
          .lte('created_at', yesterday);

      if (habits.isEmpty) return [];

      final habitIds = habits.map((h) => h['id'] as int).toList();

      // 1 query — logs completados ayer
      final logs = await _db
          .from('habit_logs')
          .select('habit_id')
          .inFilter('habit_id', habitIds)
          .eq('date', yesterday)
          .eq('completed', true);

      // 1 query — freezes de ayer
      final freezes = await _db
          .from('habit_freeze_days')
          .select('habit_id')
          .inFilter('habit_id', habitIds)
          .eq('date', yesterday);

      // Filtrar en Dart
      final completedIds = logs.map((l) => l['habit_id'] as int).toSet();
      final frozenIds    = freezes.map((f) => f['habit_id'] as int).toSet();

      return habits
          .where((h) {
        final hid = h['id'] as int;
        return !completedIds.contains(hid) && !frozenIds.contains(hid);
      })
          .map((h) => (id: h['id'] as int, name: h['name'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── XP ────────────────────────────────────────────────────────────────────

  Future<void> applyXp(
      String userId,
      int amount,
      String reason,
      String source,
      int sourceId,
      String eventDate,
      ) async {
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
          .eq('id', userId)
          .single();
      final current = profile['total_xp'] as int? ?? 0;
      final newXp = (current + amount).clamp(0, 999999);

      await _db.from('profiles').update({'total_xp': newXp}).eq('id', userId);
      await _db.from('xp_log').insert({
        'user_id': userId,
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

  Future<void> checkMissedHabits(String userId) async {
    try {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);

      // 1 query — todos los hábitos activos creados antes de ayer
      final habits = await _db
          .from('habits')
          .select('id, name')
          .eq('user_id', userId)
          .eq('active', true)
          .lte('created_at', yesterday);

      if (habits.isEmpty) return;

      final habitIds = habits.map((h) => h['id'] as int).toList();

      // 1 query — todos los logs de ayer para estos hábitos
      final logs = await _db
          .from('habit_logs')
          .select('habit_id')
          .inFilter('habit_id', habitIds)
          .eq('date', yesterday)
          .eq('completed', true);

      // 1 query — todos los freezes de ayer para estos hábitos
      final freezes = await _db
          .from('habit_freeze_days')
          .select('habit_id')
          .inFilter('habit_id', habitIds)
          .eq('date', yesterday);

      // Filtrar en Dart — sin más queries
      final completedIds = logs.map((l) => l['habit_id'] as int).toSet();
      final frozenIds    = freezes.map((f) => f['habit_id'] as int).toSet();

      for (final h in habits) {
        final hid = h['id'] as int;
        if (!completedIds.contains(hid) && !frozenIds.contains(hid)) {
          await applyXp(userId, -15, 'Hábito no registrado: ${h['name']}',
              'habit_missed', hid, yesterday);
        }
      }
    } catch (e) {
      debugPrint('checkMissed error: $e');
    }
  }

  // ── Evaluar objetivos de hábito vencidos ──────────────────────────────────

  Future<void> checkOverdueHabitObjectives(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Traer todos los objetivos de tipo hábito pendientes con deadline vencido
      final objectives = await _db
          .from('objectives')
          .select('id, habit_id, created_at, deadline, goals!inner(user_id)')
          .eq('type', 'habit')
          .eq('status', 'pending')
          .eq('goals.user_id', userId)
          .not('deadline', 'is', null)
          .lte('deadline', today);

      if ((objectives as List).isEmpty) return;

      // Verificar que el hábito pertenece al usuario
      final habitIds = objectives
          .map((o) => o['habit_id'] as int)
          .toSet()
          .toList();

      final userHabits = await _db
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .inFilter('id', habitIds);

      final userHabitIds = (userHabits as List)
          .map((h) => h['id'] as int)
          .toSet();

      for (final obj in objectives) {
        final habitId  = obj['habit_id'] as int;

        // Solo procesar hábitos del usuario actual
        if (!userHabitIds.contains(habitId)) continue;

        final objId        = obj['id'] as int;
        final deadlineRaw  = obj['deadline'];
        final createdAtRaw = obj['created_at'] as String;

        // Saltar si deadline es null o vacío
        if (deadlineRaw == null || deadlineRaw.toString().isEmpty) continue;
        final deadline = deadlineRaw.toString();

        // Convertir created_at UTC a fecha local
        final createdAtUtc   = DateTime.parse(createdAtRaw);
        final createdAtLocal = createdAtUtc.toLocal();
        final startDate      = DateTime(
          createdAtLocal.year,
          createdAtLocal.month,
          createdAtLocal.day,
        ).toIso8601String().substring(0, 10);

        // Calcular período completo
        final start     = DateTime.parse(startDate);
        final end       = DateTime.parse(deadline);
        final totalDays = end.difference(start).inDays + 1;
        if (totalDays <= 0) continue;

        // checkOverdueHabitObjectives solo se llama cuando deadline ya venció
        // así que siempre evaluamos sobre el total de días
        final logs = await _db
            .from('habit_logs')
            .select('date')
            .eq('habit_id', habitId)
            .eq('user_id', userId)
            .eq('completed', true)
            .gte('date', startDate)
            .lte('date', deadline);

        final completedDays = (logs as List).length;
        final ratio         = completedDays / totalDays;

        debugPrint('checkOverdueHabitObjectives: obj=$objId habit=$habitId '
            'start=$startDate end=$deadline '
            'completed=$completedDays total=$totalDays '
            'ratio=${(ratio * 100).round()}%');

        if (ratio >= 0.80) {
          await _db
              .from('objectives')
              .update({'status': 'completed'})
              .eq('id', objId);

          await applyXp(
            userId,
            50,
            'Objetivo de hábito completado',
            'objective_habit_completed',
            objId,
            today,
          );
        } else {
          await _db
              .from('objectives')
              .update({'status': 'failed'})
              .eq('id', objId);

          await applyXp(
            userId,
            -80,
            'Objetivo de hábito fallido (${(ratio * 100).round()}% completado)',
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
}
