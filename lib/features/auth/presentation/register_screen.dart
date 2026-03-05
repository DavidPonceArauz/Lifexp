import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/widgets/autumn_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _loading         = false;
  bool _passwordVisible = false;
  bool _confirmVisible  = false;
  String _message       = 'CREATE YOUR ADVENTURE';
  Color  _messageColor  = AutumnColors.accentGold;

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
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _shakeController.dispose();
    _leafController.dispose();
    super.dispose();
  }

  // ── Register ──────────────────────────────────────────────

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm  = _confirmController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('❌ TODOS LOS CAMPOS REQUERIDOS'); return;
    }
    if (username.length < 3) {
      _showError('❌ USERNAME MÍN. 3 CARACTERES'); return;
    }
    if (!email.contains('@')) {
      _showError('❌ EMAIL INVÁLIDO'); return;
    }
    if (password.length < 6) {
      _showError('❌ CONTRASEÑA MÍN. 6 CARACTERES'); return;
    }
    if (password != confirm) {
      _showError('❌ LAS CONTRASEÑAS NO COINCIDEN'); return;
    }

    setState(() => _loading = true);
    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      final user = response.user;
      if (user == null) {
        _showError('❌ ERROR AL CREAR CUENTA'); return;
      }

      await SupabaseConfig.client.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'email': email,
        'total_xp': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccess('✅ CUENTA CREADA! BIENVENIDO...');
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        // ── Cambio quirúrgico: va al onboarding en lugar del home ──
        Navigator.pushReplacementNamed(
          context, '/onboarding',
          arguments: {'userId': user.id, 'username': username},
        );
      }
    } on AuthException catch (e) {
      _showError('❌ ${e.message.toUpperCase()}');
    } catch (e) {
      debugPrint('register error: $e');
      _showError('❌ ERROR DE CONEXIÓN');
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

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                child: _buildRegisterCard(),
              ),
              const SizedBox(height: MobileSizes.spacingLarge),
              AutumnMessage(text: _message, color: _messageColor),
              if (_loading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(color: AutumnColors.mossGreen)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() => Column(children: [
    const Text('🌱', style: TextStyle(fontSize: 64)),
    const SizedBox(height: 12),
    AutumnTitle(text: 'LifeXP'),
    const SizedBox(height: 8),
    AutumnSubtitle(text: 'NEW PLAYER'),
  ]);

  Widget _buildRegisterCard() {
    return AutumnCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AutumnInput(
        hintText: 'PLAYER NAME',
        controller: _usernameController,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: MobileSizes.spacingMedium),
      AutumnInput(
        hintText: 'EMAIL',
        controller: _emailController,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: MobileSizes.spacingMedium),
      _buildPasswordField('ACCESS CODE', _passwordController, _passwordVisible, () {
        setState(() => _passwordVisible = !_passwordVisible);
      }, TextInputAction.next),
      const SizedBox(height: MobileSizes.spacingMedium),
      _buildPasswordField('CONFIRM CODE', _confirmController, _confirmVisible, () {
        setState(() => _confirmVisible = !_confirmVisible);
      }, TextInputAction.done, onSubmitted: (_) => _register()),
      const SizedBox(height: MobileSizes.spacingLarge),
      AutumnButton(
        text: 'CREATE ACCOUNT',
        onPressed: _loading ? null : _register,
        bgColor: AutumnColors.mossGreen,
      ),
      const SizedBox(height: MobileSizes.spacingMedium),
      AutumnButton(
        text: 'BACK TO LOGIN',
        onPressed: () => Navigator.pop(context),
        bgColor: AutumnColors.bgSurface,
        textColor: AutumnColors.textPrimary,
        height: MobileSizes.buttonHeightSmall,
        fontSize: MobileSizes.fontNormal,
      ),
    ]));
  }

  Widget _buildPasswordField(
      String hint,
      TextEditingController ctrl,
      bool visible,
      VoidCallback onToggle,
      TextInputAction action, {
        void Function(String)? onSubmitted,
      }) {
    return TextField(
      controller: ctrl,
      obscureText: !visible,
      textInputAction: action,
      onSubmitted: onSubmitted,
      style: GoogleFonts.pressStart2p(color: AutumnColors.textPrimary, fontSize: 11),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.pressStart2p(fontSize: 9, color: AutumnColors.textDisabled),
        filled: true, fillColor: AutumnColors.bgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AutumnColors.mossGreen.withOpacity(0.4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AutumnColors.mossGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility, color: AutumnColors.textDisabled, size: 20),
          splashRadius: 20,
        ),
      ),
    );
  }
}