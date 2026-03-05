// ===========================
// ⚡ GOALS PROVIDER
// ===========================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/goal.dart';
import '../../domain/goals_state.dart';
import '../../data/goals_repository.dart';
import 'package:lifexp/features/habits/presentation/providers/habits_provider.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (_) => GoalsRepository(),
);

final goalsProvider = StateNotifierProvider<GoalsNotifier, GoalsState>((ref) {
  final repo   = ref.watch(goalsRepositoryProvider);
  final userId = ref.watch(userIdProvider);
  return GoalsNotifier(repo, userId);
});

class GoalsNotifier extends StateNotifier<GoalsState> {
  final GoalsRepository _repo;
  final String _userId;

  GoalsNotifier(this._repo, this._userId) : super(GoalsState()) {
    if (_userId.isNotEmpty) load();
  }

  // ── Carga ─────────────────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.checkOverdueGoals(_userId);
      final goals = await _repo.loadGoals(_userId);
      state = state.copyWith(
        allGoals:      goals,
        filteredGoals: _applyFilters(goals),
        isLoading:     false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  List<Goal> _applyFilters(List<Goal> goals) {
    var result = List<Goal>.from(goals);

    if (state.fPriority != 'TODAS') {
      const pm = {'Alta': 3, 'Moderada': 2, 'Baja': 1};
      result = result.where((g) => g.priority == pm[state.fPriority]).toList();
    }
    if (state.fStatus != 'TODAS') {
      result = result.where((g) => g.status == state.fStatus).toList();
    }
    if (state.fCategory != null) {
      result = result.where((g) => g.category == state.fCategory).toList();
    }
    if (state.fSort == 'FECHA') {
      result.sort((a, b) {
        final da = a.deadline ?? ''; final db = b.deadline ?? '';
        if (da.isEmpty && db.isEmpty) return 0;
        if (da.isEmpty) return 1; if (db.isEmpty) return -1;
        return da.compareTo(db);
      });
    } else if (state.fSort == 'CREACIÓN') {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (state.fSort == 'PROGRESO') {
      result.sort((a, b) => b.progress.compareTo(a.progress));
    }
    return result;
  }

  void _refreshFilters() {
    state = state.copyWith(filteredGoals: _applyFilters(state.allGoals));
  }

  void setFilterPriority(String v) { state = state.copyWith(fPriority: v); _refreshFilters(); }
  void setFilterStatus(String v)   { state = state.copyWith(fStatus: v);   _refreshFilters(); }
  void setFilterSort(String v)     { state = state.copyWith(fSort: v);     _refreshFilters(); }
  void setFilterCategory(String? v) {
    state = state.copyWith(fCategory: v, clearCategory: v == null);
    _refreshFilters();
  }
  void clearFilters() {
    state = GoalsState(allGoals: state.allGoals, filteredGoals: state.allGoals);
  }

  // ── Crear (optimistic) ────────────────────────────────────────────────────

  Future<int> createGoal({
    required String title,
    required String description,
    required String deadline,
    required String category,
    required int priority,
    required int difficulty,
  }) async {
    // Optimistic con ID temporal
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempGoal = Goal(
      id: tempId, userId: _userId, title: title, description: description,
      deadline: deadline, category: category, priority: priority,
      difficulty: difficulty, status: 'active',
      createdAt: DateTime.now().toIso8601String().substring(0, 10),
    );
    final newAll = [...state.allGoals, tempGoal];
    state = state.copyWith(allGoals: newAll, filteredGoals: _applyFilters(newAll));

    try {
      final real = await _repo.createGoal(_userId,
          title: title, description: description, deadline: deadline,
          category: category, priority: priority, difficulty: difficulty);
      final updated = state.allGoals.map((g) => g.id == tempId ? real : g).toList();
      state = state.copyWith(allGoals: updated, filteredGoals: _applyFilters(updated));
      return real.id;
    } catch (e) {
      final reverted = state.allGoals.where((g) => g.id != tempId).toList();
      state = state.copyWith(allGoals: reverted, filteredGoals: _applyFilters(reverted), error: e.toString());
      return -1;
    }
  }

  // ── Eliminar (optimistic) ─────────────────────────────────────────────────

  Future<void> deleteGoal(int goalId) async {
    final prev = List<Goal>.from(state.allGoals);
    final newAll = state.allGoals.where((g) => g.id != goalId).toList();
    state = state.copyWith(allGoals: newAll, filteredGoals: _applyFilters(newAll));
    try {
      await _repo.deleteGoal(goalId);
    } catch (e) {
      state = state.copyWith(allGoals: prev, filteredGoals: _applyFilters(prev), error: e.toString());
    }
  }

  // ── Actualizar stats de objetivos de una meta ─────────────────────────────
  // Llamado por _ObjectivesDialog cuando cambian los objetivos

  void updateGoalObjStats(int goalId, int total, int completed) {
    final newAll = state.allGoals.map((g) =>
        g.id == goalId ? g.copyWith(objTotal: total, objCompleted: completed) : g
    ).toList();
    state = state.copyWith(allGoals: newAll, filteredGoals: _applyFilters(newAll));
  }

  // ── XP ────────────────────────────────────────────────────────────────────

  Future<void> applyXp(int amount, String reason, String source,
      int sourceId, String eventDate) =>
      _repo.applyXp(_userId, amount, reason, source, sourceId, eventDate);

  void clearError() => state = state.copyWith(clearError: true);
}
