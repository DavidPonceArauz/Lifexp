// ===========================
// 📦 TODOS STATE
// ===========================

import 'todo.dart';

class TodosState {
  final List<Todo> todos;
  final bool isLoading;
  final String? error;
  final String filterPriority;
  final String filterSort;
  final String? filterCategory;

  TodosState({
    this.todos = const [],
    this.isLoading = false,
    this.error,
    this.filterPriority = 'TODAS',
    this.filterSort = 'FECHA',
    this.filterCategory,
  });

  List<Todo> get pending    => todos.where((t) => t.status == 'pending').toList();
  List<Todo> get inProgress => todos.where((t) => t.status == 'in_progress').toList();
  List<Todo> get done       => todos.where((t) => t.status == 'done').toList();

  TodosState copyWith({
    List<Todo>? todos,
    bool? isLoading,
    String? error,
    String? filterPriority,
    String? filterSort,
    String? filterCategory,
    bool clearError = false,
    bool clearCategory = false,
  }) =>
      TodosState(
        todos:          todos          ?? this.todos,
        isLoading:      isLoading      ?? this.isLoading,
        error:          clearError     ? null : (error ?? this.error),
        filterPriority: filterPriority ?? this.filterPriority,
        filterSort:     filterSort     ?? this.filterSort,
        filterCategory: clearCategory  ? null : (filterCategory ?? this.filterCategory),
      );
}
