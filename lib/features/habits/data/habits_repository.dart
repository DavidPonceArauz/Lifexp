// ===========================
// 🗄️ HABITS REPOSITORY
// ===========================

import 'package:flutter/foundation.dart';
import '../domain/habit.dart';
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

      final habits = await _db
          .from('habits')
          .select('id, name')
          .eq('user_id', userId)
          .eq('active', true)
          .lte('created_at', yesterday);

      final missing = <({int id, String name})>[];
      for (final h in habits) {
        final hid = h['id'] as int;
        final log = await _db
            .from('habit_logs')
            .select('id')
            .eq('habit_id', hid)
            .eq('date', yesterday)
            .eq('completed', true)
            .maybeSingle();
        final frozen = await _db
            .from('habit_freeze_days')
            .select('id')
            .eq('habit_id', hid)
            .eq('date', yesterday)
            .maybeSingle();
        if (log == null && frozen == null) {
          missing.add((id: hid, name: h['name'] as String));
        }
      }
      return missing;
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
      final habits = await _db
          .from('habits')
          .select('id, name')
          .eq('user_id', userId)
          .eq('active', true)
          .lte('created_at', yesterday);

      for (final h in habits) {
        final hid = h['id'] as int;
        final log = await _db
            .from('habit_logs')
            .select('id')
            .eq('habit_id', hid)
            .eq('date', yesterday)
            .eq('completed', true)
            .maybeSingle();
        final frozen = await _db
            .from('habit_freeze_days')
            .select('id')
            .eq('habit_id', hid)
            .eq('date', yesterday)
            .maybeSingle();
        if (log == null && frozen == null) {
          await applyXp(userId, -15, 'Hábito no registrado: ${h['name']}',
              'habit_missed', hid, yesterday);
        }
      }
    } catch (e) {
      debugPrint('checkMissed error: $e');
    }
  }
}