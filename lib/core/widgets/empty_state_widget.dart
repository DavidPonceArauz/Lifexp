import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/autumn_theme.dart';

// ===========================
// 🕹️ PIXEL EMPTY STATE WIDGET
// ===========================

enum EmptyStateType { habits, goals, todos, home }

class PixelEmptyState extends StatefulWidget {
  final EmptyStateType type;
  final VoidCallback? onAction;
  final String? customTitle;
  final String? customSubtitle;
  final String? customActionLabel;

  const PixelEmptyState({
    super.key,
    required this.type,
    this.onAction,
    this.customTitle,
    this.customSubtitle,
    this.customActionLabel,
  });

  @override
  State<PixelEmptyState> createState() => _PixelEmptyStateState();
}

class _PixelEmptyStateState extends State<PixelEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;
  late final Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _float = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _blink = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Tipo explícito en el Map para evitar que Dart infiera Object en los values
  static final Map<EmptyStateType, Map<String, dynamic>> _configs = {
    EmptyStateType.habits: {
      'title':    'SIN HÁBITOS\nAÚN',
      'subtitle': 'Construye tu racha.\nUn hábito a la vez.',
      'action':   '+ NUEVO HÁBITO',
      'hint':     '< DESLIZA PARA NAVEGAR >',
      'color':    AutumnColors.mossGreen,
    },
    EmptyStateType.goals: {
      'title':    'SIN MISIONES\nACTIVAS',
      'subtitle': 'Cada gran logro\nempezó con una meta.',
      'action':   '+ INICIAR MISIÓN',
      'hint':     '< USA EL + ARRIBA >',
      'color':    AutumnColors.accentOrange,
    },
    EmptyStateType.todos: {
      'title':    'BANDEJA\nVACÍA',
      'subtitle': 'Nada pendiente.\n¡O todo por hacer!',
      'action':   '+ NUEVA TAREA',
      'hint':     '< USA EL + ARRIBA >',
      'color':    AutumnColors.accentGold,
    },
    EmptyStateType.home: {
      'title':    '¡BIENVENIDO\nA LIFEXP!',
      'subtitle': 'Empieza creando\ntus primeros hábitos.',
      'action':   'IR A HÁBITOS',
      'hint':     '< DESLIZA PARA EXPLORAR >',
      'color':    AutumnColors.accentOrange,
    },
  };

  @override
  Widget build(BuildContext context) {
    final cfg      = _configs[widget.type]!;
    final color    = cfg['color']    as Color;
    final title    = (widget.customTitle    ?? cfg['title']!)    as String;
    final subtitle = (widget.customSubtitle ?? cfg['subtitle']!) as String;
    final action   = (widget.customActionLabel ?? cfg['action']!) as String;
    final hint     = cfg['hint']! as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Sprite animado ────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -_float.value),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Sombra dinámica
                  Transform.scale(
                    scale: 0.6 + (_float.value / 8) * 0.15,
                    child: Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CustomPaint(
                      painter: _PixelSpritePainter(
                        type: widget.type,
                        blinkValue: _blink.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Título ────────────────────────────────────────────────────────
          Text(
            title,
            style: GoogleFonts.pressStart2p(
              fontSize: 11,
              color: color,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          // ── Subtítulo ─────────────────────────────────────────────────────
          Text(
            subtitle,
            style: GoogleFonts.pressStart2p(
              fontSize: 7,
              color: AutumnColors.textDisabled,
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // ── CTA ───────────────────────────────────────────────────────────
          if (widget.onAction != null)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) => Opacity(
                opacity: 0.6 + _blink.value * 0.4,
                child: child,
              ),
              child: GestureDetector(
                onTap: widget.onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.12),
                    border: Border.all(color: color, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cursor parpadeante estilo terminal
                      Container(
                        width: 8,
                        height: 14,
                        color: color,
                        margin: const EdgeInsets.only(right: 10),
                      ),
                      Text(
                        action,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 9,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Hint ──────────────────────────────────────────────────────────
          Text(
            hint,
            style: GoogleFonts.pressStart2p(
              fontSize: 6,
              color: AutumnColors.textDisabled.withValues(alpha:0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Painter — sprites pixel art por tipo
// ══════════════════════════════════════════════════════════════════════════════

class _PixelSpritePainter extends CustomPainter {
  final EmptyStateType type;
  final double blinkValue;

  const _PixelSpritePainter({required this.type, required this.blinkValue});

  // Helper único — sin duplicados
  void _px(Canvas c, Paint p, double x, double y, double sz) {
    c.drawRect(Rect.fromLTWH(x, y, sz, sz), p);
  }

  void _row(Canvas c, Paint p, List<int> mask, double startX, double y, double px) {
    for (int i = 0; i < mask.length; i++) {
      if (mask[i] == 1) _px(c, p, startX + i * px, y, px);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case EmptyStateType.habits:
        _paintFlame(canvas, size);
        break;
      case EmptyStateType.goals:
        _paintFlag(canvas, size);
        break;
      case EmptyStateType.todos:
        _paintCheckboard(canvas, size);
        break;
      case EmptyStateType.home:
        _paintCharacter(canvas, size);
        break;
    }
  }

  // ── 🔥 Flame (habits) ─────────────────────────────────────────────────────
  void _paintFlame(Canvas canvas, Size size) {
    final s  = size.width / 12;
    final ox = size.width / 2 - s * 4;
    final oy = size.height * 0.08;

    final orange = Paint()..color = AutumnColors.accentOrange;
    final gold   = Paint()..color = AutumnColors.accentGold;
    final red    = Paint()..color = AutumnColors.accentRed;
    final white  = Paint()..color = Colors.white.withValues(alpha:0.9);

    final flame = [
      [0, 0, 0, 1, 0, 0, 0, 0],
      [0, 0, 1, 1, 1, 0, 0, 0],
      [0, 1, 1, 1, 1, 1, 0, 0],
      [1, 1, 1, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 0],
      [0, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1, 1, 1, 1],
      [0, 0, 1, 1, 1, 1, 1, 0],
      [0, 0, 0, 1, 1, 1, 0, 0],
      [0, 0, 0, 0, 1, 0, 0, 0],
    ];
    for (int r = 0; r < flame.length; r++) {
      for (int c = 0; c < flame[r].length; c++) {
        if (flame[r][c] == 1) {
          final p = r < 3 ? red : (r < 6 ? orange : gold);
          _px(canvas, p, ox + c * s, oy + r * s, s);
        }
      }
    }

    final inner = [
      [0, 0, 1, 0],
      [0, 1, 1, 0],
      [0, 1, 1, 0],
      [0, 0, 1, 0],
    ];
    for (int r = 0; r < inner.length; r++) {
      _row(canvas, white, inner[r], ox + s * 2, oy + s * (r + 3), s);
    }
  }

  // ── 🎯 Flag (goals) ───────────────────────────────────────────────────────
  void _paintFlag(Canvas canvas, Size size) {
    final s  = size.width / 12;
    final ox = size.width / 2 - s * 4;
    final oy = size.height * 0.05;

    final orange = Paint()..color = AutumnColors.accentOrange;
    final brown  = Paint()..color = AutumnColors.leafBrown;
    final gold   = Paint()..color = AutumnColors.accentGold;

    for (int r = 0; r < 11; r++) {
      _px(canvas, brown, ox + s * 2, oy + r * s, s);
    }

    final flag = [
      [0, 1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1, 0],
      [0, 1, 1, 1, 0, 0],
      [0, 1, 1, 0, 0, 0],
      [0, 1, 0, 0, 0, 0],
    ];
    for (int r = 0; r < flag.length; r++) {
      for (int c = 0; c < flag[r].length; c++) {
        if (flag[r][c] == 1) {
          _px(canvas, r < 2 ? orange : gold, ox + (c + 2) * s, oy + r * s, s);
        }
      }
    }

    final star = [
      [0, 1, 0],
      [1, 1, 1],
      [0, 1, 0],
    ];
    for (int r = 0; r < star.length; r++) {
      _row(canvas, gold, star[r], ox + s * 1.5, oy - s * (3 - r), s);
    }

    _row(canvas, brown, [1, 1, 1, 1, 1], ox, oy + s * 11, s);
  }

  // ── ✅ Checkboard (todos) ─────────────────────────────────────────────────
  void _paintCheckboard(Canvas canvas, Size size) {
    final s  = size.width / 12;
    final ox = size.width / 2 - s * 5;
    final oy = size.height * 0.05;

    final gold     = Paint()..color = AutumnColors.accentGold;
    final surface  = Paint()..color = AutumnColors.bgSurface;
    final border   = Paint()..color = AutumnColors.divider;
    final green    = Paint()..color = AutumnColors.mossGreen;
    final disabled = Paint()..color = AutumnColors.textDisabled;

    for (int r = 1; r < 11; r++) {
      for (int c = 0; c < 9; c++) {
        _px(canvas,
            r == 0 || r == 10 || c == 0 || c == 8 ? border : surface,
            ox + c * s, oy + r * s, s);
      }
    }
    _row(canvas, gold, [0, 0, 1, 1, 1, 1, 1, 0, 0], ox, oy, s);

    _row(canvas, green,    [1, 1, 0], ox + s * 1.5, oy + s * 2.5, s);
    _row(canvas, disabled, [1, 1, 1, 1, 1], ox + s * 3, oy + s * 2.5, s);

    _row(canvas, green,    [1, 1, 0], ox + s * 1.5, oy + s * 4.5, s);
    _row(canvas, disabled, [1, 1, 1, 1, 1], ox + s * 3, oy + s * 4.5, s);

    _row(canvas, border, [1, 1, 0], ox + s * 1.5, oy + s * 6.5, s);
    _row(canvas, border, [1, 1, 1, 1, 1], ox + s * 3, oy + s * 6.5, s);

    _px(canvas, gold, ox + s * 7,   oy + s * 2,   s);
    _px(canvas, gold, ox + s * 6.5, oy + s * 2.5, s);
    _px(canvas, gold, ox + s * 7.5, oy + s * 2.5, s);
    _px(canvas, gold, ox + s * 7,   oy + s * 3,   s);
  }

  // ── 🏠 Character (home) ───────────────────────────────────────────────────
  void _paintCharacter(Canvas canvas, Size size) {
    final s  = size.width / 14;
    final ox = size.width / 2 - s * 4;
    final oy = size.height * 0.04;

    final orange = Paint()..color = AutumnColors.accentOrange;
    final skin   = Paint()..color = const Color(0xFFFFCC88);
    final dark   = Paint()..color = const Color(0xFF2D1B00);
    final white  = Paint()..color = Colors.white;
    final gold   = Paint()..color = AutumnColors.accentGold;
    final green  = Paint()..color = AutumnColors.mossGreen;

    final head = [
      [0, 1, 1, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1, 1, 1, 0],
    ];
    for (int r = 0; r < head.length; r++) {
      for (int c = 0; c < head[r].length; c++) {
        if (head[r][c] == 1) _px(canvas, skin, ox + c * s, oy + r * s, s);
      }
    }

    if (blinkValue > 0.2) {
      _px(canvas, dark,  ox + s * 1.5, oy + s * 2,   s);
      _px(canvas, dark,  ox + s * 5.5, oy + s * 2,   s);
      _px(canvas, white, ox + s * 2,   oy + s * 1.5, s * 0.5);
      _px(canvas, white, ox + s * 6,   oy + s * 1.5, s * 0.5);
    } else {
      _row(canvas, dark, [1, 1], ox + s * 1.5, oy + s * 2.5, s * 0.6);
      _row(canvas, dark, [1, 1], ox + s * 5.5, oy + s * 2.5, s * 0.6);
    }

    _px(canvas, dark, ox + s * 2, oy + s * 4,   s);
    _px(canvas, dark, ox + s * 3, oy + s * 4.5, s);
    _px(canvas, dark, ox + s * 4, oy + s * 4.5, s);
    _px(canvas, dark, ox + s * 5, oy + s * 4,   s);

    final body = [
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 1, 1, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 0, 1, 1, 0, 1, 1],
    ];
    for (int r = 0; r < body.length; r++) {
      for (int c = 0; c < body[r].length; c++) {
        if (body[r][c] == 1) {
          _px(canvas, r < 2 ? orange : green,
              ox + c * s, oy + (r + 6) * s, s);
        }
      }
    }

    _px(canvas, gold, ox + s * 3.5, oy + s * 7, s);
    _px(canvas, gold, ox + s * 4.5, oy + s * 7, s);

    _px(canvas, dark, ox + s * 2, oy + s * 10, s);
    _px(canvas, dark, ox + s * 2, oy + s * 11, s);
    _px(canvas, dark, ox + s * 5, oy + s * 10, s);
    _px(canvas, dark, ox + s * 5, oy + s * 11, s);

    _row(canvas, dark, [1, 1], ox + s * 1.5, oy + s * 12, s);
    _row(canvas, dark, [1, 1], ox + s * 5,   oy + s * 12, s);

    _px(canvas, gold, ox + s * 7,   oy - s,       s);
    _px(canvas, gold, ox + s * 6.5, oy - s * 0.5, s);
    _px(canvas, gold, ox + s * 7.5, oy - s * 0.5, s);
    _px(canvas, gold, ox + s * 7,   oy,            s);
  }

  @override
  bool shouldRepaint(_PixelSpritePainter old) =>
      old.blinkValue != blinkValue || old.type != type;
}