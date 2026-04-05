import 'package:flutter_test/flutter_test.dart';
import 'package:lifexp/features/habits/domain/habit_objective_eval.dart';

void main() {
  group('evaluateHabitObjectiveProgress', () {
    test('returns 80 percent when 4 of 5 days are completed at deadline', () {
      final result = evaluateHabitObjectiveProgress(
        createdAtRaw: '2026-04-04 10:00:00+00',
        endDate: '2026-04-08',
        today: '2026-04-08',
        completedDays: 4,
      );

      expect(result, isNotNull);
      expect(result!.startDate, '2026-04-04');
      expect(result.evalEndDate, '2026-04-08');
      expect(result.totalDays, 5);
      expect(result.elapsedDays, 5);
      expect(result.deadlineReached, isTrue);
      expect(result.ratio, 0.8);
    });

    test('uses elapsed days before deadline is reached', () {
      final result = evaluateHabitObjectiveProgress(
        createdAtRaw: '2026-04-04 10:00:00+00',
        endDate: '2026-04-08',
        today: '2026-04-06',
        completedDays: 2,
      );

      expect(result, isNotNull);
      expect(result!.evalEndDate, '2026-04-06');
      expect(result.totalDays, 5);
      expect(result.elapsedDays, 3);
      expect(result.deadlineReached, isFalse);
      expect(result.ratio, closeTo(2 / 3, 0.0001));
    });

    test('returns null when end date is before start date', () {
      final result = evaluateHabitObjectiveProgress(
        createdAtRaw: '2026-04-09 10:00:00+00',
        endDate: '2026-04-08',
        today: '2026-04-08',
        completedDays: 0,
      );

      expect(result, isNull);
    });

    test('returns failure ratio under 80 percent after deadline', () {
      final result = evaluateHabitObjectiveProgress(
        createdAtRaw: '2026-04-04 10:00:00+00',
        endDate: '2026-04-08',
        today: '2026-04-08',
        completedDays: 3,
      );

      expect(result, isNotNull);
      expect(result!.deadlineReached, isTrue);
      expect(result.ratio, 0.6);
    });
  });
}
