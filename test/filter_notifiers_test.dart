import 'package:flutter_test/flutter_test.dart';
import 'package:lifexp/features/goals/data/goals_repository.dart';
import 'package:lifexp/features/goals/domain/goal.dart';
import 'package:lifexp/features/goals/presentation/providers/goals_provider.dart';
import 'package:lifexp/features/todos/data/todos_repository.dart';
import 'package:lifexp/features/todos/domain/todo.dart';
import 'package:lifexp/features/todos/presentation/providers/todos_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeGoalsRepository extends GoalsRepository {
  @override
  Future<void> checkOverdueGoals(String userId) async {}

  @override
  Future<List<Goal>> loadGoals(String userId) async => [];
}

class _FakeTodosRepository extends TodosRepository {
  @override
  Future<List<Todo>> loadTodos(String userId) async => [];
}

class _TestGoalsNotifier extends GoalsNotifier {
  _TestGoalsNotifier() : super(_FakeGoalsRepository(), '',);

  void seed(List<Goal> goals) {
    state = state.copyWith(allGoals: goals, filteredGoals: goals);
  }
}

class _TestTodosNotifier extends TodosNotifier {
  _TestTodosNotifier() : super(_FakeTodosRepository(), '');

  void seed(List<Todo> todos) {
    state = state.copyWith(allTodos: todos, filteredTodos: todos);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('GoalsNotifier filters', () {
    test('filters by status and category', () {
      final notifier = _TestGoalsNotifier();
      notifier.seed(const [
        Goal(
          id: 1,
          userId: 'u1',
          title: 'Health',
          description: '',
          category: 'Personal',
          priority: 3,
          difficulty: 2,
          status: 'active',
          createdAt: '2026-04-05',
        ),
        Goal(
          id: 2,
          userId: 'u1',
          title: 'Work launch',
          description: '',
          category: 'Work',
          priority: 2,
          difficulty: 3,
          status: 'failed',
          createdAt: '2026-04-04',
        ),
        Goal(
          id: 3,
          userId: 'u1',
          title: 'Read more',
          description: '',
          category: 'Personal',
          priority: 1,
          difficulty: 1,
          status: 'active',
          createdAt: '2026-04-03',
        ),
      ]);

      notifier.setFilterStatus('active');
      notifier.setFilterCategory('Personal');

      expect(notifier.state.filteredGoals.map((g) => g.id), [1, 3]);
    });

    test('sorts by progress descending', () {
      final notifier = _TestGoalsNotifier();
      notifier.seed(const [
        Goal(
          id: 1,
          userId: 'u1',
          title: 'A',
          description: '',
          priority: 3,
          difficulty: 2,
          status: 'active',
          createdAt: '2026-04-05',
          objTotal: 5,
          objCompleted: 2,
        ),
        Goal(
          id: 2,
          userId: 'u1',
          title: 'B',
          description: '',
          priority: 2,
          difficulty: 3,
          status: 'active',
          createdAt: '2026-04-04',
          objTotal: 4,
          objCompleted: 4,
        ),
      ]);

      notifier.setFilterSort('PROGRESO');

      expect(notifier.state.filteredGoals.map((g) => g.id), [2, 1]);
    });
  });

  group('TodosNotifier filters', () {
    test('filters by priority and category', () {
      final notifier = _TestTodosNotifier();
      notifier.seed(const [
        Todo(
          id: 1,
          userId: 'u1',
          title: 'A',
          description: '',
          priority: 3,
          category: 'Work',
          deadline: '2026-04-06',
          status: 'pending',
          createdAt: '2026-04-05',
        ),
        Todo(
          id: 2,
          userId: 'u1',
          title: 'B',
          description: '',
          priority: 2,
          category: 'Work',
          deadline: '2026-04-04',
          status: 'pending',
          createdAt: '2026-04-05',
        ),
        Todo(
          id: 3,
          userId: 'u1',
          title: 'C',
          description: '',
          priority: 3,
          category: 'Personal',
          deadline: '2026-04-05',
          status: 'pending',
          createdAt: '2026-04-05',
        ),
      ]);

      notifier.setFilterPriority('ALTA');
      notifier.setFilterCategory('Work');

      expect(notifier.state.filteredTodos.map((t) => t.id), [1]);
    });

    test('sorts by priority descending', () {
      final notifier = _TestTodosNotifier();
      notifier.seed(const [
        Todo(
          id: 1,
          userId: 'u1',
          title: 'A',
          description: '',
          priority: 1,
          status: 'pending',
          createdAt: '2026-04-05',
        ),
        Todo(
          id: 2,
          userId: 'u1',
          title: 'B',
          description: '',
          priority: 3,
          status: 'pending',
          createdAt: '2026-04-05',
        ),
        Todo(
          id: 3,
          userId: 'u1',
          title: 'C',
          description: '',
          priority: 2,
          status: 'pending',
          createdAt: '2026-04-05',
        ),
      ]);

      notifier.setFilterSort('PRIORIDAD');

      expect(notifier.state.filteredTodos.map((t) => t.id), [2, 3, 1]);
    });
  });
}
