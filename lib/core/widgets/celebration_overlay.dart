import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/autumn_theme.dart';

// ══════════════════════════════════════════════════════════════════
// 🎉 CELEBRATION OVERLAY — Level Up
// Uso:
//   CelebrationOverlay.showLevelUp(context, newLevel);
// ══════════════════════════════════════════════════════════════════

class CelebrationOverlay {
  static void showLevelUp(BuildContext context, int newLevel) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _LevelUpOverlay(
      newLevel: newLevel,
      onDone: () => entry.remove(),
    ));
    overlay.insert(entry);
  }
}

class _LevelUpOverlay extends StatefulWidget {
  final int newLevel;
  final VoidCallback onDone;
  const _LevelUpOverlay({required this.newLevel, required this.onDone});

  @override
  State<_LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<_LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<double> _particleFade;
  final List<_Particle> _particles = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    // Generar partículas pixel
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x:      _rng.nextDouble(),
        y:      0.3 + _rng.nextDouble() * 0.3,
        dx:     (_rng.nextDouble() - 0.5) * 0.4,
        dy:     -(_rng.nextDouble() * 0.5 + 0.1),
        color:  [
          AutumnColors.accentOrange,
          AutumnColors.accentGold,
          AutumnColors.mossGreen,
          AutumnColors.freeze,
        ][_rng.nextInt(4)],
        size:   4.0 + _rng.nextDouble() * 6,
      ));
    }

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15)
          .chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    ]).animate(_ctrl);

    _fade = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.75), weight: 20),
      TweenSequenceItem(tween: ConstantTween(0.75), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 0.0), weight: 20),
    ]).animate(_ctrl);

    _particleFade = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(children: [
        // Fondo semi-transparente
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: _fade.value,
              child: Container(color: Colors.black),
            ),
          ),
        ),

        // Partículas pixel art
        ..._particles.map((p) {
          final t  = _ctrl.value;
          final px = (p.x + p.dx * t) * size.width;
          final py = (p.y + p.dy * t) * size.height;
          return Positioned(
            left: px,
            top:  py,
            child: Opacity(
              opacity: _particleFade.value,
              child: Container(
                width:  p.size,
                height: p.size,
                color:  p.color,
              ),
            ),
          );
        }),

        // Card central
        Center(
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              decoration: BoxDecoration(
                color: AutumnColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AutumnColors.accentGold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AutumnColors.accentGold.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('⬆', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text('LEVEL UP!',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 20,
                        color: AutumnColors.accentGold,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AutumnColors.accentOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('NIVEL ${widget.newLevel}',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                Text('¡Sigue creciendo!',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 8, color: AutumnColors.textDisabled)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// Partícula interna
class _Particle {
  final double x, y, dx, dy, size;
  final Color color;
  const _Particle({
    required this.x, required this.y,
    required this.dx, required this.dy,
    required this.color, required this.size,
  });
}

// ══════════════════════════════════════════════════════════════════
// 💥 HabitCompleteAnimation — pulso + escala en la card del hábito
// Uso: envuelve la card con este widget y llama a .pulse()
// via GlobalKey<HabitCompleteAnimationState>
// ══════════════════════════════════════════════════════════════════

class HabitCompleteAnimation extends StatefulWidget {
  final Widget child;
  const HabitCompleteAnimation({super.key, required this.child});

  @override
  State<HabitCompleteAnimation> createState() => HabitCompleteAnimationState();
}

class HabitCompleteAnimationState extends State<HabitCompleteAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.06)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.06, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 60),
    ]).animate(_ctrl);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Llamar externamente cuando el hábito se completa
  void pulse() {
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.scale(
        scale: _scale.value,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _glow.value > 0.01
                ? [BoxShadow(
                    color: AutumnColors.mossGreen.withValues(alpha: 0.45 * _glow.value),
                    blurRadius: 16 * _glow.value,
                    spreadRadius: 2 * _glow.value,
                  )]
                : [],
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ✅ ObjectiveStrikeAnimation — tachado progresivo al completar
// ══════════════════════════════════════════════════════════════════

class ObjectiveStrikeAnimation extends StatefulWidget {
  final String text;
  final bool struck;       // true = completado
  final TextStyle style;
  const ObjectiveStrikeAnimation({
    super.key,
    required this.text,
    required this.struck,
    required this.style,
  });

  @override
  State<ObjectiveStrikeAnimation> createState() =>
      _ObjectiveStrikeAnimationState();
}

class _ObjectiveStrikeAnimationState extends State<ObjectiveStrikeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress; // 0→1 = línea de tachado
  bool _wasStruck = false;

  @override
  void initState() {
    super.initState();
    _wasStruck = widget.struck;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (widget.struck) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(ObjectiveStrikeAnimation old) {
    super.didUpdateWidget(old);
    if (widget.struck && !_wasStruck) {
      // Recién completado → animar tachado
      _ctrl.forward(from: 0);
    } else if (!widget.struck && _wasStruck) {
      // Revertido → quitar tachado
      _ctrl.reverse();
    }
    _wasStruck = widget.struck;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) => CustomPaint(
        painter: _StrikePainter(
          progress: _progress.value,
          color: AutumnColors.mossGreen,
        ),
        child: Text(
          widget.text,
          style: widget.style.copyWith(
            color: widget.struck
                ? AutumnColors.textDisabled
                : widget.style.color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _StrikePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha:0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;
    final y = size.height * 0.52;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * progress, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.progress != progress;
}
