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

  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.active,
    required this.createdAt,
  });

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as int,
        userId: map['user_id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? '',
        active: map['active'] as bool? ?? true,
        createdAt: map['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'active': active,
        'created_at': createdAt,
      };

  Habit copyWith({
    int? id,
    String? userId,
    String? name,
    String? category,
    bool? active,
    String? createdAt,
  }) =>
      Habit(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        category: category ?? this.category,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
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

  const HabitStreak({
    required this.habitId,
    required this.name,
    required this.streak,
    required this.statusKey,
    required this.daysToFreeze,
  });

  HabitStreak copyWith({
    int? habitId,
    String? name,
    int? streak,
    HabitStatusKey? statusKey,
    int? daysToFreeze,
  }) =>
      HabitStreak(
        habitId: habitId ?? this.habitId,
        name: name ?? this.name,
        streak: streak ?? this.streak,
        statusKey: statusKey ?? this.statusKey,
        daysToFreeze: daysToFreeze ?? this.daysToFreeze,
      );
}

enum HabitStatusKey { done, frozen, missed, pending }
