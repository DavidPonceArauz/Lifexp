// ===========================
// 📦 HABITS STATE
// ===========================

import 'habit.dart';

class HabitsState {
  final List<Habit> habits;
  final List<HabitStreak> streakData;
  final Map<int, bool> completedCache;
  final int freezes;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;

  HabitsState({
    this.habits = const [],
    this.streakData = const [],
    this.completedCache = const {},
    this.freezes = 0,
    this.isLoading = false,
    this.error,
    DateTime? selectedDate,
  }) : selectedDate = selectedDate ?? DateTime.now();

  HabitsState copyWith({
    List<Habit>? habits,
    List<HabitStreak>? streakData,
    Map<int, bool>? completedCache,
    int? freezes,
    bool? isLoading,
    String? error,
    DateTime? selectedDate,
    bool clearError = false,
  }) =>
      HabitsState(
        habits: habits ?? this.habits,
        streakData: streakData ?? this.streakData,
        completedCache: completedCache ?? this.completedCache,
        freezes: freezes ?? this.freezes,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        selectedDate: selectedDate ?? this.selectedDate,
      );

  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  bool isCompleted(int habitId) => completedCache[habitId] ?? false;
}
