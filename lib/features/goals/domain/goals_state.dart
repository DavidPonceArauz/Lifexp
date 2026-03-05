// ===========================
// 📦 GOALS STATE
// ===========================

import 'goal.dart';

class GoalsState {
  final List<Goal> allGoals;
  final List<Goal> filteredGoals;
  final bool isLoading;
  final String? error;
  final String fPriority;
  final String fStatus;
  final String? fCategory;
  final String fSort;

  GoalsState({
    this.allGoals = const [],
    this.filteredGoals = const [],
    this.isLoading = false,
    this.error,
    this.fPriority = 'TODAS',
    this.fStatus = 'TODAS',
    this.fCategory,
    this.fSort = 'FECHA',
  });

  GoalsState copyWith({
    List<Goal>? allGoals,
    List<Goal>? filteredGoals,
    bool? isLoading,
    String? error,
    String? fPriority,
    String? fStatus,
    String? fCategory,
    String? fSort,
    bool clearError = false,
    bool clearCategory = false,
  }) =>
      GoalsState(
        allGoals:       allGoals       ?? this.allGoals,
        filteredGoals:  filteredGoals  ?? this.filteredGoals,
        isLoading:      isLoading      ?? this.isLoading,
        error:          clearError     ? null : (error ?? this.error),
        fPriority:      fPriority      ?? this.fPriority,
        fStatus:        fStatus        ?? this.fStatus,
        fCategory:      clearCategory  ? null : (fCategory ?? this.fCategory),
        fSort:          fSort          ?? this.fSort,
      );
}
