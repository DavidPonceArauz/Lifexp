// ===========================
// 📦 TODOS STATE
// ===========================

import 'todo.dart';

class TodosState {
  final List<Todo> allTodos;       // todos sin filtrar — fuente de verdad
  final List<Todo> filteredTodos;  // los que se muestran en pantalla
  final bool isLoading;
  final String? error;
  final String filterPriority;
  final String filterSort;
  final String? filterCategory;

  TodosState({
    this.allTodos = const [],
    this.filteredTodos = const [],
    this.isLoading = false,
    this.error,
    this.filterPriority = 'TODAS',
    this.filterSort = 'FECHA',
    this.filterCategory,
  });

  // Las columnas Kanban filtran sobre filteredTodos
  List<Todo> get pending    => filteredTodos.where((t) => t.status == 'pending').toList();
  List<Todo> get inProgress => filteredTodos.where((t) => t.status == 'in_progress').toList();
  List<Todo> get done       => filteredTodos.where((t) => t.status == 'done').toList();

  TodosState copyWith({
    List<Todo>? allTodos,
    List<Todo>? filteredTodos,
    bool? isLoading,
    String? error,
    String? filterPriority,
    String? filterSort,
    String? filterCategory,
    bool clearError = false,
    bool clearCategory = false,
  }) =>
      TodosState(
        allTodos:       allTodos       ?? this.allTodos,
        filteredTodos:  filteredTodos  ?? this.filteredTodos,
        isLoading:      isLoading      ?? this.isLoading,
        error:          clearError     ? null : (error ?? this.error),
        filterPriority: filterPriority ?? this.filterPriority,
        filterSort:     filterSort     ?? this.filterSort,
        filterCategory: clearCategory  ? null : (filterCategory ?? this.filterCategory),
      );
}
