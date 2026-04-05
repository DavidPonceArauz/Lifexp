// ===========================
// 🗄️ TODOS REPOSITORY
// ===========================

import 'package:flutter/foundation.dart';
import '../domain/todo.dart';
import '../../../core/supabase/supabase_client.dart';

class TodosRepository {
  final _db = SupabaseConfig.client;

  Future<List<Todo>> loadTodos(String userId) async {
    final result = await _db
        .from('todos')
        .select('id, title, description, priority, deadline, category, status, created_at, user_id')
        .eq('user_id', userId)
        .neq('status', 'archived');
    return List<Map<String, dynamic>>.from(result)
        .map(Todo.fromMap)
        .toList();
  }

  Future<Todo> createTodo(String userId, {
    required String title,
    required String description,
    required int priority,
    String? deadline,
    String? category,
  }) async {
    final result = await _db.from('todos').insert({
      'user_id':     userId,
      'title':       title.trim(),
      'description': description.trim(),
      'priority':    priority,
      'deadline':    deadline,
      'category':    category,
      'status':      'pending',
    }).select('id, title, description, priority, deadline, category, status, created_at, user_id').single();
    return Todo.fromMap(result);
  }

  Future<void> updateTodo(String userId, int id, {
    required String title,
    required String description,
    required int priority,
    String? deadline,
    String? category,
  }) async {
    await _db.from('todos').update({
      'title':       title.trim(),
      'description': description.trim(),
      'priority':    priority,
      'deadline':    deadline,
      'category':    category,
    }).eq('id', id).eq('user_id', userId);
  }

  Future<void> updateStatus(String userId, int id, String status) async {
    await _db.from('todos').update({'status': status}).eq('id', id).eq('user_id', userId);
  }

  Future<void> deleteTodo(String userId, int id) async {
    await _db.from('todos').delete().eq('id', id).eq('user_id', userId);
  }
}
