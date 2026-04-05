class HabitObjectiveEvaluation {
  final String startDate;
  final String evalEndDate;
  final int totalDays;
  final int elapsedDays;
  final double ratio;
  final bool deadlineReached;

  const HabitObjectiveEvaluation({
    required this.startDate,
    required this.evalEndDate,
    required this.totalDays,
    required this.elapsedDays,
    required this.ratio,
    required this.deadlineReached,
  });
}

HabitObjectiveEvaluation? evaluateHabitObjectiveProgress({
  required String createdAtRaw,
  required String endDate,
  required String today,
  required int completedDays,
}) {
  final createdAtUtc = DateTime.parse(createdAtRaw);
  final createdAtLocal = createdAtUtc.toLocal();
  final startDate = DateTime(
    createdAtLocal.year,
    createdAtLocal.month,
    createdAtLocal.day,
  ).toIso8601String().substring(0, 10);

  final start = DateTime.parse(startDate);
  final end = DateTime.parse(endDate);
  final totalDays = end.difference(start).inDays + 1;
  if (totalDays <= 0) return null;

  final deadlineReached = endDate.compareTo(today) <= 0;
  final evalEndDate = deadlineReached ? endDate : today;
  final elapsedDays = DateTime.parse(evalEndDate).difference(start).inDays + 1;
  if (elapsedDays <= 0) return null;

  final denominator = deadlineReached ? totalDays : elapsedDays;
  final ratio = denominator > 0 ? completedDays / denominator : 0.0;

  return HabitObjectiveEvaluation(
    startDate: startDate,
    evalEndDate: evalEndDate,
    totalDays: totalDays,
    elapsedDays: elapsedDays,
    ratio: ratio,
    deadlineReached: deadlineReached,
  );
}
