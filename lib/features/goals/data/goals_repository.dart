// ===========================
// 🗄️ GOALS REPOSITORY
// ===========================

import 'package:flutter/foundation.dart';
import '../domain/goal.dart';
import '../../../core/supabase/supabase_client.dart';

class GoalsRepository {
  final _db = SupabaseConfig.client;

  // ── Carga principal ───────────────────────────────────────────────────────

  Future<List<Goal>> loadGoals(String userId) async {
    final goals = await _db
        .from('goals')
        .select('id, title, description, deadline, category, priority, difficulty, status, created_at')
        .eq('user_id', userId)
        .order('deadline', ascending: true, nullsFirst: false);

    final goalsList = List<Map<String, dynamic>>.from(goals);
    if (goalsList.isEmpty) return [];

    // Cargar stats de objetivos en batch
    final goalIds = goalsList.map((g) => g['id'] as int).toList();
    final objRows = await _db
        .from('objectives')
        .select('goal_id, status')
        .inFilter('goal_id', goalIds);

    final statsMap = <int, Map<String, int>>{
      for (final id in goalIds) id: {'total': 0, 'completed': 0},
    };
    for (final r in objRows) {
      final gid = r['goal_id'] as int;
      statsMap[gid]!['total'] = statsMap[gid]!['total']! + 1;
      if (r['status'] == 'completed') {
        statsMap[gid]!['completed'] = statsMap[gid]!['completed']! + 1;
      }
    }

    return goalsList.map((g) {
      final gid = g['id'] as int;
      return Goal.fromMap(g,
          objTotal:     statsMap[gid]!['total']!,
          objCompleted: statsMap[gid]!['completed']!);
    }).toList();
  }

  // ── Overdue check ─────────────────────────────────────────────────────────

  Future<void> checkOverdueGoals(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final overdue = await _db
          .from('goals')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .lt('deadline', today);

      for (final g in overdue) {
        await _db
            .from('goals')
            .update({'status': 'failed'})
            .eq('id', g['id'])
            .eq('user_id', userId);
        await applyXp(userId, -50, 'Meta vencida', 'goal_failed', g['id'] as int, today);
      }
    } catch (e) {
      debugPrint('checkOverdue error: $e');
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<Goal> createGoal(String userId, {
    required String title,
    required String description,
    required String deadline,
    required String category,
    required int priority,
    required int difficulty,
  }) async {
    final result = await _db.from('goals').insert({
      'user_id':     userId,
      'title':       title,
      'description': description,
      'deadline':    deadline,
      'category':    category,
      'priority':    priority,
      'difficulty':  difficulty,
      'status':      'active',
    }).select('id, title, description, deadline, category, priority, difficulty, status, created_at').single();
    return Goal.fromMap(result);
  }

  Future<void> deleteGoal(String userId, int goalId) async {
    final ownedGoal = await _db
        .from('goals')
        .select('id')
        .eq('id', goalId)
        .eq('user_id', userId)
        .maybeSingle();
    if (ownedGoal == null) return;

    await _db.from('objectives').delete().eq('goal_id', goalId);
    await _db.from('goals').delete().eq('id', goalId).eq('user_id', userId);
  }

  // ── Objectives ────────────────────────────────────────────────────────────

  Future<List<Objective>> loadObjectives(String userId, int goalId) async {
    final rows = await _db
        .from('objectives')
        .select('id, goal_id, title, deadline, status, type, habit_id, habits(name), goals!inner(user_id)')
        .eq('goal_id', goalId)
        .eq('goals.user_id', userId)
        .order('id', ascending: true);

    return (rows as List).map((r) {
      final hd = r['habits'] as Map<String, dynamic>?;
      return Objective.fromMap({...Map<String, dynamic>.from(r), 'habit_name': hd?['name']});
    }).toList();
  }

  Future<int> createObjective(int goalId, String userId, {
    required String title,
    String? deadline,
    int? habitId,
  }) async {
    final result = await _db.from('objectives').insert({
      'goal_id':     goalId,
      'title':       title,
      'description': '',
      'deadline':    deadline ?? '',
      'type':        habitId != null ? 'habit' : 'manual',
      'habit_id':    habitId,
      'status':      'pending',
    }).select('id').single();
    return result['id'] as int;
  }

  Future<void> toggleObjective(String userId, int goalId, int objId, String newStatus) async {
    final ownedObjective = await _db
        .from('objectives')
        .select('id, goals!inner(user_id)')
        .eq('id', objId)
        .eq('goal_id', goalId)
        .eq('goals.user_id', userId)
        .maybeSingle();
    if (ownedObjective == null) return;

    await _db
        .from('objectives')
        .update({'status': newStatus})
        .eq('id', objId)
        .eq('goal_id', goalId);
  }

  Future<void> deleteObjective(String userId, int goalId, int objId) async {
    final ownedObjective = await _db
        .from('objectives')
        .select('id, goals!inner(user_id)')
        .eq('id', objId)
        .eq('goal_id', goalId)
        .eq('goals.user_id', userId)
        .maybeSingle();
    if (ownedObjective == null) return;

    await _db.from('objectives').delete().eq('id', objId).eq('goal_id', goalId);
  }

  Future<List<Map<String, dynamic>>> loadHabits(String userId) async {
    final result = await _db
        .from('habits')
        .select('id, name')
        .eq('user_id', userId)
        .eq('active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  // ── XP ────────────────────────────────────────────────────────────────────

  Future<void> applyXp(String userId, int amount, String reason,
      String source, int sourceId, String eventDate) async {
    try {
      final existing = await _db.from('xp_log').select('id')
          .eq('source', source).eq('source_id', sourceId)
          .eq('event_date', eventDate).maybeSingle();
      if (existing != null) return;
      final profile = await _db.from('profiles').select('total_xp').eq('id', userId).single();
      final newXp = ((profile['total_xp'] as int? ?? 0) + amount).clamp(0, 999999);
      await _db.from('profiles').update({'total_xp': newXp}).eq('id', userId);
      await _db.from('xp_log').insert({
        'user_id': userId, 'amount': amount, 'reason': reason,
        'source': source, 'source_id': sourceId, 'event_date': eventDate,
      });
    } catch (e) {
      debugPrint('XP error: $e');
    }
  }
}
