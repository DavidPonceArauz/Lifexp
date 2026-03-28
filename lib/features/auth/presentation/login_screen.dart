import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/widgets/autumn_widgets.dart';
import '../../../core/services/sentry_service.dart';
import '../../../core/services/analytics_service.dart'; // ← nuevo
import '../../../main.dart' show kIsRecoveryFlow, NotificationDeepLink;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading         = true;
  bool _passwordVisible = false;
  String _message       = '🎮 INSERT COIN TO PLAY';
  Color  _messageColor  = AutumnColors.textDisabled;

  late AnimationController _shakeController;
  late AnimationController _leafController;
  late Animation<double>   _shakeAnimation;
  late Animation<double>   _leafAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _leafController  = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _leafAnimation   = Tween<double>(begin: 0, end: 1).animate(_leafController);
    _checkSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    _leafController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    if (kIsRecoveryFlow) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      final user = session.user;
      await SentryService.setUser(user.id, email: user.email);
      await AnalyticsService.identify(user.id, email: user.email); // ← nuevo

      if (mounted) {
        setState(() {
          _message      = '✓ BIENVENIDO DE NUEVO!';
          _messageColor = AutumnColors.mossGreen;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          final pending = NotificationDeepLink.consume();
          final route   = pending != null ? '/$pending' : '/home';
          Navigator.pushReplacementNamed(context, route, arguments: user.id);
        }
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('✗ EMAIL Y CONTRASEÑA REQUERIDOS');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null && mounted) {
        await SentryService.setUser(user.id, email: user.email);
        await SentryService.addBreadcrumb('Login exitoso', category: 'auth');
        await AnalyticsService.identify(user.id, email: user.email); // ← nuevo

        _showSuccess('✓ ACCESS GRANTED');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          final pending = NotificationDeepLink.consume();
          final route   = pending != null ? '/$pending' : '/home';
          Navigator.pushReplacementNamed(context, route, arguments: user.id);
        }
      } else {
        _showError('❌ CREDENCIALES INVÁLIDAS');
      }
    } on AuthException catch (e) {
      await SentryService.captureException(e, hint: 'Auth error en login');
      _showError('❌ ${e.message.toUpperCase()}');
    } catch (e, st) {
      await SentryService.captureException(e, stackTrace: st, hint: 'Error inesperado en login');
      _showError('❌ ERROR DE CONEXIÓN');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('✗ INGRESA TU EMAIL PRIMERO');
      return;
    }
    setState(() => _loading = true);
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.lifexp://io.lifexp/reset-password',
      );
      _showSuccess('📧 EMAIL ENVIADO — REVISA TU CORREO');
    } catch (e, st) {
      await SentryService.captureException(e, stackTrace: st, hint: 'Error reset password');
      _showError('❌ ERROR AL ENVIAR EMAIL');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    setState(() { _message = msg; _messageColor = AutumnColors.accentRed; });
    _shakeController.forward(from: 0);
  }

  void _showSuccess(String msg) {
    setState(() { _message = msg; _messageColor = AutumnColors.mossGreen; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AutumnColors.bgPrimary,
        body: Stack(children: [
          AnimatedBuilder(animation: _leafAnimation, builder: (_, __) => CustomPaint(painter: LeafBackgroundPainter(_leafAnimation.value), size: Size.infinite)),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🌳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AutumnColors.accentOrange),
            const SizedBox(height: 16),
            Text('CARGANDO...', style: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.textDisabled)),
          ])),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: AutumnColors.bgPrimary,
      body: Stack(children: [
        AnimatedBuilder(animation: _leafAnimation, builder: (_, __) => CustomPaint(painter: LeafBackgroundPainter(_leafAnimation.value), size: Size.infinite)),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: MobileSizes.screenPadding, vertical: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildHeader(),
              const SizedBox(height: MobileSizes.spacingLarge),
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (_, child) {
                  final dx = _shakeController.isAnimating
                      ? 10 * (0.5 - (_shakeAnimation.value % 0.25) / 0.25)
                      : 0.0;
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: _buildLoginCard(),
              ),
              const SizedBox(height: MobileSizes.spacingLarge),
              AutumnMessage(text: _message, color: _messageColor),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() => Column(children: [
    const Text('🌳', style: TextStyle(fontSize: 64)),
    const SizedBox(height: 12),
    AutumnTitle(text: 'LifeXP'),
    const SizedBox(height: 8),
    AutumnSubtitle(text: 'LEVEL UP YOUR LIFE'),
  ]);

  Widget _buildLoginCard() {
    return AutumnCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AutumnInput(
        hintText: 'EMAIL',
        controller: _emailController,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: MobileSizes.spacingMedium),
      TextField(
        controller: _passwordController,
        obscureText: !_passwordVisible,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _login(),
        style: GoogleFonts.pressStart2p(color: AutumnColors.textPrimary, fontSize: 11),
        decoration: InputDecoration(
          hintText: 'ACCESS CODE',
          hintStyle: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.textDisabled),
          filled: true, fillColor: AutumnColors.bgSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AutumnColors.mossGreen.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AutumnColors.accentOrange, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
            icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility, color: AutumnColors.textDisabled, size: 20),
            splashRadius: 20,
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _forgotPassword,
          child: Text('¿OLVIDASTE TU CONTRASEÑA?',
              style: GoogleFonts.pressStart2p(fontSize: 7, color: AutumnColors.accentGold)),
        ),
      ),
      const SizedBox(height: MobileSizes.spacingMedium),
      AutumnButton(
        text: 'PRESS START',
        onPressed: _loading ? null : _login,
        bgColor: AutumnColors.accentOrange,
      ),
      const SizedBox(height: MobileSizes.spacingMedium),
      AutumnButton(
        text: 'SIGN UP',
        onPressed: () => Navigator.pushNamed(context, '/register'),
        bgColor: AutumnColors.bgSurface,
        textColor: AutumnColors.textPrimary,
        height: MobileSizes.buttonHeightSmall,
        fontSize: MobileSizes.fontNormal,
      ),
    ]));
  }
}