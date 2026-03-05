// ===========================
// 🌱 DOMAIN MODEL — Todo
// ===========================

class Todo {
  final int id;
  final String userId;
  final String title;
  final String description;
  final int priority;
  final String? deadline;
  final String? category;
  final String status;
  final String createdAt;

  const Todo({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.priority,
    this.deadline,
    this.category,
    required this.status,
    required this.createdAt,
  });

  factory Todo.fromMap(Map<String, dynamic> map) => Todo(
        id:          map['id'] as int,
        userId:      map['user_id'] as String? ?? '',
        title:       map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        priority:    map['priority'] as int? ?? 2,
        deadline:    map['deadline'] as String?,
        category:    map['category'] as String?,
        status:      map['status'] as String? ?? 'pending',
        createdAt:   map['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id':          id,
        'user_id':     userId,
        'title':       title,
        'description': description,
        'priority':    priority,
        'deadline':    deadline,
        'category':    category,
        'status':      status,
        'created_at':  createdAt,
      };

  Todo copyWith({
    int? id,
    String? userId,
    String? title,
    String? description,
    int? priority,
    String? deadline,
    String? category,
    String? status,
    String? createdAt,
  }) =>
      Todo(
        id:          id          ?? this.id,
        userId:      userId      ?? this.userId,
        title:       title       ?? this.title,
        description: description ?? this.description,
        priority:    priority    ?? this.priority,
        deadline:    deadline    ?? this.deadline,
        category:    category    ?? this.category,
        status:      status      ?? this.status,
        createdAt:   createdAt   ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Todo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
