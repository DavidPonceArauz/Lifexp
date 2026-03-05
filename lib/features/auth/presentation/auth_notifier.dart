import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/supabase/supabase_client.dart';

// ── Estado de auth ────────────────────────────────────────────

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  const AuthState({required this.status, this.userId});

  bool get isLoading         => status == AuthStatus.loading;
  bool get isAuthenticated   => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
}

// ── Notifier ──────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<sb.AuthState>? _sub;

  AuthNotifier() : super(const AuthState(status: AuthStatus.loading)) {
    _init();
  }

  void _init() {
    // Estado inicial
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      state = AuthState(status: AuthStatus.authenticated, userId: session.user.id);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    // Escuchar cambios
    _sub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = AuthState(status: AuthStatus.authenticated, userId: session.user.id);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// ── AuthGate ──────────────────────────────────────────────────

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE8820C))),
      );
    }

    if (auth.isAuthenticated && auth.userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/home', arguments: auth.userId);
        }
      });
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
    return const SizedBox.shrink();
  }
}