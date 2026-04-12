import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../main.dart' show NotificationDeepLink;

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

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _navigating = false;

  void _navigate(String route, {Object? arguments}) {
    if (_navigating) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, route, arguments: arguments);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AutumnColors.accentOrange),
        ),
      );
    }

    if (auth.isAuthenticated && auth.userId != null) {
      final pending = NotificationDeepLink.consume();
      final route = pending != null ? '/$pending' : '/home';
      _navigate(route, arguments: auth.userId);
      return const SizedBox.shrink();
    }

    _navigate('/login');
    return const SizedBox.shrink();
  }
}
