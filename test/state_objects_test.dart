import 'package:flutter_test/flutter_test.dart';
import 'package:lifexp/features/habits/domain/habit.dart';
import 'package:lifexp/features/habits/domain/habits_state.dart';
import 'package:lifexp/features/todos/domain/todo.dart';
import 'package:lifexp/features/todos/domain/todos_state.dart';

void main() {
  group('HabitsState', () {
    test('isToday is true when selectedDate is today', () {
      final state = HabitsState(selectedDate: DateTime.now());

      expect(state.isToday, isTrue);
    });

    test('isCompleted reads from completed cache', () {
      final state = HabitsState(
        completedCache: const {1: true, 2: false},
      );

      expect(state.isCompleted(1), isTrue);
      expect(state.isCompleted(2), isFalse);
      expect(state.isCompleted(3), isFalse);
    });

    test('copyWith can clear errors without losing data', () {
      final state = HabitsState(
        habits: const [
          Habit(
            id: 1,
            userId: 'user-1',
            name: 'Read',
            category: 'Learning',
            active: true,
            createdAt: '2026-04-05',
          ),
        ],
        error: 'boom',
      );

      final updated = state.copyWith(clearError: true, freezes: 2);

      expect(updated.error, isNull);
      expect(updated.freezes, 2);
      expect(updated.habits, hasLength(1));
    });
  });

  group('TodosState', () {
    const pendingTodo = Todo(
      id: 1,
      userId: 'user-1',
      title: 'Plan sprint',
      description: '',
      priority: 3,
      status: 'pending',
      createdAt: '2026-04-05',
    );

    const inProgressTodo = Todo(
      id: 2,
      userId: 'user-1',
      title: 'Build feature',
      description: '',
      priority: 2,
      status: 'in_progress',
      createdAt: '2026-04-05',
    );

    const doneTodo = Todo(
      id: 3,
      userId: 'user-1',
      title: 'Ship fix',
      description: '',
      priority: 1,
      status: 'done',
      createdAt: '2026-04-05',
    );

    test('kanban getters split todos by status', () {
      final state = TodosState(
        filteredTodos: const [pendingTodo, inProgressTodo, doneTodo],
      );

      expect(state.pending.map((t) => t.id), [1]);
      expect(state.inProgress.map((t) => t.id), [2]);
      expect(state.done.map((t) => t.id), [3]);
    });

    test('copyWith can clear category and error independently', () {
      final state = TodosState(
        allTodos: const [pendingTodo],
        filteredTodos: const [pendingTodo],
        error: 'network',
        filterCategory: 'Work',
      );

      final updated = state.copyWith(clearError: true, clearCategory: true);

      expect(updated.error, isNull);
      expect(updated.filterCategory, isNull);
      expect(updated.allTodos, hasLength(1));
    });
  });
}
