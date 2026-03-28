import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/autumn_theme.dart';

// ══════════════════════════════════════════════════════════════════
// ⭐ XP TOAST — Toast flotante reutilizable
//
// Uso:
//   XpToast.show(context, amount: 10);           // hábito
//   XpToast.show(context, amount: 50);           // meta
//   XpToast.show(context, amount: 5);            // tarea
//   XpToast.show(context, amount: -15, loss: true); // penalización
// ══════════════════════════════════════════════════════════════════

class XpToast {
  static void show(
      BuildContext context, {
        required int amount,
        bool loss = false,
      }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _XpToastWidget(
        amount: amount,
        loss: loss,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _XpToastWidget extends StatefulWidget {
  final int amount;
  final bool loss;
  final VoidCallback onDone;

  const _XpToastWidget({
    required this.amount,
    required this.loss,
    required this.onDone,
  });

  @override
  State<_XpToastWidget> createState() => _XpToastWidgetState();
}

class _XpToastWidgetState extends State<_XpToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _translateY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Sube suavemente y desaparece
    _translateY = Tween(begin: 0.0, end: -36.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Aparece rápido, desaparece casi de inmediato
    _opacity = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.72)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.72),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.72, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_ctrl);

    // Sin pop — entrada directa
    _scale = ConstantTween(1.0).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoss   = widget.loss;
    final color    = isLoss ? AutumnColors.accentRed : AutumnColors.accentOrange;
    final sign     = isLoss ? '' : '+';
    final label    = '$sign${widget.amount} XP';
    final emoji    = isLoss ? '💔' : _xpEmoji(widget.amount);

    return Positioned(
      // Centrado horizontalmente, en el tercio superior de la pantalla
      top: MediaQuery.of(context).size.height * 0.28,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _translateY.value),
              child: Transform.scale(
                scale: _scale.value,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AutumnColors.bgCard.withValues(alpha:0.82),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.pressStart2p(
                            fontSize: 8,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _xpEmoji(int amount) {
    if (amount >= 50) return '🏆';
    if (amount >= 25) return '⭐';
    if (amount >= 10) return '🔥';
    return '✨';
  }
}