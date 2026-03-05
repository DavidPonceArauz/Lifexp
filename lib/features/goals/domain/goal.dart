// ===========================
// 🌱 DOMAIN MODEL — Goal
// ===========================

class Goal {
  final int id;
  final String userId;
  final String title;
  final String description;
  final String? deadline;
  final String? category;
  final int priority;
  final int difficulty;
  final String status;
  final String createdAt;
  // Stats de objetivos (cargados junto con la meta)
  final int objTotal;
  final int objCompleted;

  const Goal({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.deadline,
    this.category,
    required this.priority,
    required this.difficulty,
    required this.status,
    required this.createdAt,
    this.objTotal = 0,
    this.objCompleted = 0,
  });

  factory Goal.fromMap(Map<String, dynamic> map, {int objTotal = 0, int objCompleted = 0}) => Goal(
        id:           map['id'] as int,
        userId:       map['user_id'] as String? ?? '',
        title:        map['title'] as String? ?? '',
        description:  map['description'] as String? ?? '',
        deadline:     map['deadline'] as String?,
        category:     map['category'] as String?,
        priority:     map['priority'] as int? ?? 2,
        difficulty:   map['difficulty'] as int? ?? 5,
        status:       map['status'] as String? ?? 'active',
        createdAt:    map['created_at'] as String? ?? '',
        objTotal:     objTotal,
        objCompleted: objCompleted,
      );

  Goal copyWith({
    int? id, String? userId, String? title, String? description,
    String? deadline, String? category, int? priority, int? difficulty,
    String? status, String? createdAt, int? objTotal, int? objCompleted,
  }) => Goal(
    id:           id           ?? this.id,
    userId:       userId       ?? this.userId,
    title:        title        ?? this.title,
    description:  description  ?? this.description,
    deadline:     deadline     ?? this.deadline,
    category:     category     ?? this.category,
    priority:     priority     ?? this.priority,
    difficulty:   difficulty   ?? this.difficulty,
    status:       status       ?? this.status,
    createdAt:    createdAt    ?? this.createdAt,
    objTotal:     objTotal     ?? this.objTotal,
    objCompleted: objCompleted ?? this.objCompleted,
  );

  double get progress => objTotal > 0 ? objCompleted / objTotal : 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Goal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── Objective ────────────────────────────────────────────────────────────────

class Objective {
  final int id;
  final int goalId;
  final String title;
  final String? deadline;
  final String status;
  final String type;
  final int? habitId;
  final String? habitName;

  const Objective({
    required this.id,
    required this.goalId,
    required this.title,
    this.deadline,
    required this.status,
    required this.type,
    this.habitId,
    this.habitName,
  });

  factory Objective.fromMap(Map<String, dynamic> map) {
    final habitData = map['habits'] as Map<String, dynamic>?;
    return Objective(
      id:         map['id'] as int,
      goalId:     map['goal_id'] as int,
      title:      map['title'] as String? ?? '',
      deadline:   map['deadline'] as String?,
      status:     map['status'] as String? ?? 'pending',
      type:       map['type'] as String? ?? 'manual',
      habitId:    map['habit_id'] as int?,
      habitName:  map['habit_name'] as String? ?? habitData?['name'] as String?,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isHabit => type == 'habit' && habitId != null;

  Objective copyWith({String? status}) => Objective(
    id: id, goalId: goalId, title: title, deadline: deadline,
    status: status ?? this.status, type: type,
    habitId: habitId, habitName: habitName,
  );
}
