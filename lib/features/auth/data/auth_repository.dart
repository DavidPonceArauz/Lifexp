import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class AuthRepository {
  final _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Obtener username del perfil ────────────────────────────
  Future<String> getUsername(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .single();
    return profile['username'] as String? ?? '';
  }

  Future<void> ensureProfileExists({
    required String userId,
    String? email,
    String? username,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      if (email != null && email.isNotEmpty) 'email': email,
      'username': (username != null && username.trim().isNotEmpty)
          ? username.trim()
          : (email?.split('@').first ?? 'PLAYER'),
      'total_xp': 0,
    });
  }

  // ── Registro ───────────────────────────────────────────────
  Future<User?> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    final user = response.user;
    if (user == null) return null;
    await ensureProfileExists(userId: user.id, email: email, username: username);
    return user;
  }

  // ── Login ──────────────────────────────────────────────────
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user;
  }

  // ── Logout ─────────────────────────────────────────────────
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  // ── Recuperar contraseña ───────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── Verificar username único ───────────────────────────────
  Future<bool> usernameExists(String username) async {
    final result = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return result != null;
  }
}
