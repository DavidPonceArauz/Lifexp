import 'package:flutter_test/flutter_test.dart';
import 'package:lifexp/features/goals/domain/goal.dart';
import 'package:lifexp/features/todos/domain/todo.dart';

void main() {
  group('Goal', () {
    test('progress returns completion ratio when objectives exist', () {
      const goal = Goal(
        id: 1,
        userId: 'user-1',
        title: 'Learn Flutter',
        description: 'Ship the app',
        priority: 3,
        difficulty: 4,
        status: 'active',
        createdAt: '2026-04-05',
        objTotal: 5,
        objCompleted: 4,
      );

      expect(goal.progress, 0.8);
    });

    test('progress returns 0 when there are no objectives', () {
      const goal = Goal(
        id: 1,
        userId: 'user-1',
        title: 'Learn Flutter',
        description: 'Ship the app',
        priority: 3,
        difficulty: 4,
        status: 'active',
        createdAt: '2026-04-05',
      );

      expect(goal.progress, 0.0);
    });
  });

  group('Objective', () {
    test('fromMap detects linked habit objectives and reads habit name', () {
      final objective = Objective.fromMap({
        'id': 10,
        'goal_id': 99,
        'title': 'Walk daily',
        'description': '',
        'deadline': '2026-04-08',
        'status': 'pending',
        'type': 'habit',
        'habit_id': 45,
        'habits': {'name': 'Walk 20 minutes'},
      });

      expect(objective.isHabit, isTrue);
      expect(objective.habitId, 45);
      expect(objective.habitName, 'Walk 20 minutes');
      expect(objective.isCompleted, isFalse);
    });
  });

  group('Todo', () {
    test('copyWith preserves untouched values and updates changed ones', () {
      const todo = Todo(
        id: 7,
        userId: 'user-1',
        title: 'Write tests',
        description: 'Cover domain logic',
        priority: 2,
        deadline: '2026-04-06',
        category: 'Work',
        status: 'pending',
        createdAt: '2026-04-05',
      );

      final updated = todo.copyWith(status: 'done', priority: 3);

      expect(updated.id, todo.id);
      expect(updated.title, todo.title);
      expect(updated.status, 'done');
      expect(updated.priority, 3);
      expect(updated.category, 'Work');
    });
  });
}
