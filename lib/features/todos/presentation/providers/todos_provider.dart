// ===========================
// ⚡ TODOS PROVIDER
// ===========================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/todo.dart';
import '../../domain/todos_state.dart';
import '../../data/todos_repository.dart';
import 'package:lifexp/features/habits/presentation/providers/habits_provider.dart';

final todosRepositoryProvider = Provider<TodosRepository>(
      (_) => TodosRepository(),
);

final todosProvider = StateNotifierProvider<TodosNotifier, TodosState>((ref) {
  final repo   = ref.watch(todosRepositoryProvider);
  final userId = ref.watch(userIdProvider);
  return TodosNotifier(repo, userId);
});

class TodosNotifier extends StateNotifier<TodosState> {
  final TodosRepository _repo;
  final String _userId;

  TodosNotifier(this._repo, this._userId) : super(TodosState()) {
    if (_userId.isNotEmpty) load();
  }

  // ── Carga ─────────────────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final todos = await _repo.loadTodos(_userId);
      state = state.copyWith(
        allTodos:      todos,
        filteredTodos: _applyFilters(todos),
        isLoading:     false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Filtros — locales, sin tocar el servidor ──────────────────────────────

  List<Todo> _applyFilters(List<Todo> todos) {
    var result = List<Todo>.from(todos);

    if (state.filterPriority != 'TODAS') {
      const pm = {'ALTA': 3, 'MEDIA': 2, 'BAJA': 1};
      result = result.where((t) => t.priority == pm[state.filterPriority]).toList();
    }
    if (state.filterCategory != null) {
      result = result.where((t) => t.category == state.filterCategory).toList();
    }
    if (state.filterSort == 'PRIORIDAD') {
      result.sort((a, b) => b.priority.compareTo(a.priority));
    } else {
      result.sort((a, b) {
        final da = a.deadline; final db = b.deadline;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }
    return result;
  }

  void _refreshFilters() {
    state = state.copyWith(filteredTodos: _applyFilters(state.allTodos));
  }

  void setFilterPriority(String priority) {
    state = state.copyWith(filterPriority: priority);
    _refreshFilters();
  }

  void setFilterSort(String sort) {
    state = state.copyWith(filterSort: sort);
    _refreshFilters();
  }

  void setFilterCategory(String? category) {
    state = state.copyWith(
      filterCategory: category,
      clearCategory:  category == null,
    );
    _refreshFilters();
  }

  void clearFilters() {
    state = TodosState(
      allTodos:      state.allTodos,
      filteredTodos: state.allTodos,
    );
  }

  // ── Crear (optimistic) ────────────────────────────────────────────────────

  Future<int> createTodo({
    required String title,
    required String description,
    required int priority,
    String? deadline,
    String? category,
  }) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempTodo = Todo(
      id: tempId, userId: _userId, title: title, description: description,
      priority: priority, deadline: deadline, category: category,
      status: 'pending', createdAt: DateTime.now().toIso8601String().substring(0, 10),
    );
    final newAll = [...state.allTodos, tempTodo];
    state = state.copyWith(
      allTodos:      newAll,
      filteredTodos: _applyFilters(newAll),
    );

    try {
      final newTodo = await _repo.createTodo(_userId,
          title: title, description: description,
          priority: priority, deadline: deadline, category: category);
      final updatedAll = state.allTodos.map((t) => t.id == tempId ? newTodo : t).toList();
      state = state.copyWith(
        allTodos:      updatedAll,
        filteredTodos: _applyFilters(updatedAll),
      );
      return newTodo.id;
    } catch (e) {
      final reverted = state.allTodos.where((t) => t.id != tempId).toList();
      state = state.copyWith(
        allTodos:      reverted,
        filteredTodos: _applyFilters(reverted),
        error:         e.toString(),
      );
      return -1;
    }
  }

  // ── Editar (optimistic) ───────────────────────────────────────────────────

  Future<void> updateTodo(int id, {
    required String title,
    required String description,
    required int priority,
    String? deadline,
    String? category,
  }) async {
    final updatedAll = state.allTodos.map((t) {
      if (t.id != id) return t;
      return t.copyWith(title: title, description: description,
          priority: priority, deadline: deadline, category: category);
    }).toList();
    state = state.copyWith(
      allTodos:      updatedAll,
      filteredTodos: _applyFilters(updatedAll),
    );

    try {
      await _repo.updateTodo(_userId, id, title: title, description: description,
          priority: priority, deadline: deadline, category: category);
    } catch (e) {
      await load();
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Mover columna (optimistic) ────────────────────────────────────────────

  Future<void> moveStatus(int id, String newStatus) async {
    final prevIndex = state.allTodos.indexWhere((t) => t.id == id);
    if (prevIndex == -1) return;
    final prev = state.allTodos[prevIndex];
    if (prev.status == newStatus) return;

    final updatedAll = state.allTodos.map((t) =>
    t.id == id ? t.copyWith(status: newStatus) : t).toList();
    state = state.copyWith(
      allTodos:      updatedAll,
      filteredTodos: _applyFilters(updatedAll),
    );

    try {
      await _repo.updateStatus(_userId, id, newStatus);
    } catch (e) {
      final reverted = state.allTodos.map((t) =>
      t.id == id ? t.copyWith(status: prev.status) : t).toList();
      state = state.copyWith(
        allTodos:      reverted,
        filteredTodos: _applyFilters(reverted),
        error:         e.toString(),
      );
    }
  }

  // ── Eliminar (optimistic) ─────────────────────────────────────────────────

  Future<void> deleteTodo(int id) async {
    final prevAll = List<Todo>.from(state.allTodos);
    final newAll  = state.allTodos.where((t) => t.id != id).toList();
    state = state.copyWith(
      allTodos:      newAll,
      filteredTodos: _applyFilters(newAll),
    );
    try {
      await _repo.deleteTodo(_userId, id);
    } catch (e) {
      state = state.copyWith(
        allTodos:      prevAll,
        filteredTodos: _applyFilters(prevAll),
        error:         e.toString(),
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
