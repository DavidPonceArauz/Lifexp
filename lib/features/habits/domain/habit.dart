// ===========================
// 🌱 DOMAIN MODEL — Habit
// ===========================
// Clase Dart pura. Sin Supabase, sin Flutter, sin dependencias externas.
// Fácil de testear unitariamente.

class Habit {
  final int id;
  final String userId;
  final String name;
  final String category;
  final bool active;
  final String createdAt;
  final HabitFrequencyMode frequencyMode;
  final int weeklyTarget;

  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.active,
    required this.createdAt,
    this.frequencyMode = HabitFrequencyMode.daily,
    this.weeklyTarget = 7,
  });

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as int,
        userId: map['user_id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? '',
        active: map['active'] as bool? ?? true,
        createdAt: map['created_at'] as String? ?? '',
        frequencyMode: (map['frequency_mode'] as String?) == 'weekly'
            ? HabitFrequencyMode.weekly
            : HabitFrequencyMode.daily,
        weeklyTarget: map['weekly_target'] as int? ?? 7,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'active': active,
        'created_at': createdAt,
        'frequency_mode': frequencyMode.name,
        'weekly_target': weeklyTarget,
      };

  Habit copyWith({
    int? id,
    String? userId,
    String? name,
    String? category,
    bool? active,
    String? createdAt,
    HabitFrequencyMode? frequencyMode,
    int? weeklyTarget,
  }) =>
      Habit(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        category: category ?? this.category,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
        frequencyMode: frequencyMode ?? this.frequencyMode,
        weeklyTarget: weeklyTarget ?? this.weeklyTarget,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Habit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── Streak info de un hábito ───────────────────────────────────────────────
class HabitStreak {
  final int habitId;
  final String name;
  final int streak;
  final HabitStatusKey statusKey;
  final int daysToFreeze;
  final HabitFrequencyMode frequencyMode;
  final int weeklyTarget;
  final int currentPeriodProgress;
  final int currentPeriodTarget;

  const HabitStreak({
    required this.habitId,
    required this.name,
    required this.streak,
    required this.statusKey,
    required this.daysToFreeze,
    this.frequencyMode = HabitFrequencyMode.daily,
    this.weeklyTarget = 7,
    this.currentPeriodProgress = 0,
    this.currentPeriodTarget = 1,
  });

  HabitStreak copyWith({
    int? habitId,
    String? name,
    int? streak,
    HabitStatusKey? statusKey,
    int? daysToFreeze,
    HabitFrequencyMode? frequencyMode,
    int? weeklyTarget,
    int? currentPeriodProgress,
    int? currentPeriodTarget,
  }) =>
      HabitStreak(
        habitId: habitId ?? this.habitId,
        name: name ?? this.name,
        streak: streak ?? this.streak,
        statusKey: statusKey ?? this.statusKey,
        daysToFreeze: daysToFreeze ?? this.daysToFreeze,
        frequencyMode: frequencyMode ?? this.frequencyMode,
        weeklyTarget: weeklyTarget ?? this.weeklyTarget,
        currentPeriodProgress: currentPeriodProgress ?? this.currentPeriodProgress,
        currentPeriodTarget: currentPeriodTarget ?? this.currentPeriodTarget,
      );
}

enum HabitFrequencyMode { daily, weekly }

enum HabitStatusKey { done, frozen, missed, pending }

class PendingHabitFreeze {
  final int habitId;
  final String name;
  final DateTime freezeDate;
  final bool isWeekly;
  final String periodLabel;

  const PendingHabitFreeze({
    required this.habitId,
    required this.name,
    required this.freezeDate,
    required this.isWeekly,
    required this.periodLabel,
  });
}
