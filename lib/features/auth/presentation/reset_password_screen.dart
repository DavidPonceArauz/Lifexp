import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/widgets/autumn_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _loading         = false;
  bool _passwordVisible = false;
  bool _confirmVisible  = false;
  bool _done            = false;
  String _message       = 'INGRESA TU NUEVA CONTRASEÑA';
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
    _passwordController.dispose();
    _confirmController.dispose();
    _shakeController.dispose();
    _leafController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirm  = _confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      _showError('❌ AMBOS CAMPOS REQUERIDOS'); return;
    }
    if (password.length < 6) {
      _showError('❌ CONTRASEÑA MÍN. 6 CARACTERES'); return;
    }
    if (password != confirm) {
      _showError('❌ LAS CONTRASEÑAS NO COINCIDEN'); return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: password),
      );
      setState(() => _done = true);
      _showSuccess('✅ CONTRASEÑA ACTUALIZADA');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } on AuthException catch (e) {
      _showError('❌ ${e.message.toUpperCase()}');
    } catch (_) {
      _showError('❌ ERROR AL ACTUALIZAR');
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
    return Scaffold(
      backgroundColor: AutumnColors.bgPrimary,
      body: Stack(children: [
        AnimatedBuilder(animation: _leafAnimation, builder: (_, __) => CustomPaint(painter: LeafBackgroundPainter(_leafAnimation.value), size: Size.infinite)),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: MobileSizes.screenPadding, vertical: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Header
              Column(children: [
                const Text('🔐', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                AutumnTitle(text: 'LifeXP'),
                const SizedBox(height: 8),
                AutumnSubtitle(text: 'RESET PASSWORD'),
              ]),
              const SizedBox(height: MobileSizes.spacingLarge),

              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (_, child) {
                  final dx = _shakeController.isAnimating
                      ? 10 * (0.5 - (_shakeAnimation.value % 0.25) / 0.25)
                      : 0.0;
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: AutumnCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Nueva contraseña
                  _buildPasswordField(
                    'NUEVA CONTRASEÑA',
                    _passwordController,
                    _passwordVisible,
                    () => setState(() => _passwordVisible = !_passwordVisible),
                    TextInputAction.next,
                  ),
                  const SizedBox(height: MobileSizes.spacingMedium),

                  // Confirmar
                  _buildPasswordField(
                    'CONFIRMAR CONTRASEÑA',
                    _confirmController,
                    _confirmVisible,
                    () => setState(() => _confirmVisible = !_confirmVisible),
                    TextInputAction.done,
                    onSubmitted: (_) => _resetPassword(),
                  ),
                  const SizedBox(height: MobileSizes.spacingLarge),

                  if (_done)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AutumnColors.mossGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AutumnColors.mossGreen.withOpacity(0.4)),
                      ),
                      child: Text('✅ CONTRASEÑA ACTUALIZADA\nRedirigiendo al login...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.mossGreen)),
                    )
                  else
                    AutumnButton(
                      text: 'ACTUALIZAR CONTRASEÑA',
                      onPressed: _loading ? null : _resetPassword,
                      bgColor: AutumnColors.accentOrange,
                    ),

                  if (_loading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator(color: AutumnColors.accentOrange)),
                  ],

                  const SizedBox(height: MobileSizes.spacingMedium),
                  AutumnButton(
                    text: 'VOLVER AL LOGIN',
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    bgColor: AutumnColors.bgSurface,
                    textColor: AutumnColors.textPrimary,
                    height: MobileSizes.buttonHeightSmall,
                    fontSize: MobileSizes.fontNormal,
                  ),
                ])),
              ),

              const SizedBox(height: MobileSizes.spacingLarge),
              AutumnMessage(text: _message, color: _messageColor),
            ]),
          ),
        ),
      ]),
    );
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
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AutumnColors.accentOrange, width: 1.5)),
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
