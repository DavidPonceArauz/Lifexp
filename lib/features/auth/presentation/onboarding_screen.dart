import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';

// ══════════════════════════════════════════════════════════════════
// 🌱 ONBOARDING — Historia simbólica del árbol
// 5 pantallas: El árbol → El estancamiento → La regadera
//              → Tu nombre → Hoy empieza
// ══════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final String initialUsername;
  const OnboardingScreen({
    super.key,
    required this.userId,
    required this.initialUsername,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();
  int _page = 0;
  bool _saving = false;
  String? _nameError;

  // ── Animaciones globales ──────────────────────────────────
  late AnimationController _floatCtrl; // árbol flotante
  late AnimationController _entryCtrl; // fade entrada por página
  late AnimationController _particleCtrl; // partículas de fondo

  late Animation<double> _floatAnim;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialUsername;

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _floatAnim = Tween(begin: -6.0, end: 6.0)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _floatCtrl.dispose();
    _entryCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  // ── Navegar ───────────────────────────────────────────────

  void _next() {
    if (_page == 3) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _nameError = 'Tu árbol necesita un nombre');
        return;
      }
      if (name.length < 3) {
        setState(() => _nameError = 'Mínimo 3 caracteres');
        return;
      }
      setState(() => _nameError = null);
    }
    _entryCtrl.forward(from: 0);
    HapticFeedback.selectionClick();
    setState(() => _page++);
    _pageCtrl.animateToPage(_page,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final name = _nameCtrl.text.trim();
      if (name != widget.initialUsername) {
        await SupabaseConfig.client
            .from('profiles')
            .update({'username': name}).eq('id', widget.userId);
      }
    } catch (e) {
      debugPrint('onboarding save: $e');
    }
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home',
          arguments: widget.userId);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AutumnColors.bgPrimary,
      body: Stack(children: [
        // Partículas de fondo — hojas y polvo de luz
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => CustomPaint(
            painter: _NaturePainter(_particleCtrl.value),
            size: Size.infinite,
          ),
        ),

        SafeArea(
            child: Column(children: [
          // Indicador de progreso
          _buildProgressBar(),

          // Páginas
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPage0(), // El árbol eres tú
                _buildPage1(), // El estancamiento
                _buildPage2(), // La regadera
                _buildPage3(), // Tu nombre
                _buildPage4(), // Hoy empieza
              ],
            ),
          ),
        ])),
      ]),
    );
  }

  // ── Barra de progreso ─────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: List.generate(5, (i) {
          final done = i < _page;
          final active = i == _page;
          return Expanded(
              child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 3,
            decoration: BoxDecoration(
              color: done
                  ? AutumnColors.mossGreen
                  : active
                      ? AutumnColors.accentOrange
                      : AutumnColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ));
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PÁGINA 0 — "El árbol eres tú"
  // ══════════════════════════════════════════════════════════

  Widget _buildPage0() {
    return _PageWrapper(
      entryFade: _entryFade,
      entrySlide: _entrySlide,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _floatingEmoji('🌱', size: 80),
          const SizedBox(height: 36),
          _headline('EL ÁRBOL\nERES TÚ'),
          const SizedBox(height: 24),
          _poem(
            'Dentro de ti hay una semilla.\n\n'
            'No importa dónde estás ahora.\n'
            'No importa cuánto tiempo llevas parado.\n\n'
            'Las semillas no se rinden.\n'
            'Solo esperan el momento de crecer.',
          ),
          const SizedBox(height: 48),
          _nextBtn('CONTINUAR', _next),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PÁGINA 1 — "El estancamiento"
  // ══════════════════════════════════════════════════════════

  Widget _buildPage1() {
    return _PageWrapper(
      entryFade: _entryFade,
      entrySlide: _entrySlide,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _floatingEmoji('🪨', size: 64),
          const SizedBox(height: 36),
          _headline('EL PESO\nDE LA QUIETUD'),
          const SizedBox(height: 24),
          _poem(
            'Hay días en que sientes que el tiempo pasa\n'
            'y tú te quedas igual.\n\n'
            'Esa sensación tiene nombre:\n'
            'es una semilla que todavía no ha encontrado\n'
            'la tierra correcta.\n\n'
            'Hoy cambia eso.',
          ),
          const SizedBox(height: 48),
          _nextBtn('LO RECONOZCO', _next),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PÁGINA 2 — "La regadera"
  // ══════════════════════════════════════════════════════════

  Widget _buildPage2() {
    return _PageWrapper(
      entryFade: _entryFade,
      entrySlide: _entrySlide,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _floatingEmoji('🪣', size: 64),
          const SizedBox(height: 36),
          _headline('TUS ACCIONES\nSON EL AGUA'),
          const SizedBox(height: 24),
          _poem(
            'Cada hábito que cumples es una gota.\n'
            'Cada meta que alcanzas es una lluvia.\n'
            'Cada tarea completada es tierra fértil.\n\n'
            'No necesitas hacerlo todo.\n'
            'Solo necesitas regar\n'
            'un poco cada día.',
          ),
          const SizedBox(height: 28),

          // Visual de las 3 fuentes de agua
          _waterSourcesCard(),

          const SizedBox(height: 40),
          _nextBtn('ENTENDIDO', _next),
        ],
      ),
    );
  }

  Widget _waterSourcesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AutumnColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AutumnColors.mossGreen.withValues(alpha:0.3), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _waterSource('🔥', 'HÁBITOS', '+10 XP'),
          _dividerLine(),
          _waterSource('🎯', 'METAS', '+50 XP'),
          _dividerLine(),
          _waterSource('✅', 'TAREAS', '+5 XP'),
        ],
      ),
    );
  }

  Widget _waterSource(String emoji, String label, String xp) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 26)),
      const SizedBox(height: 6),
      Text(label,
          style: GoogleFonts.pressStart2p(
              fontSize: 6, color: AutumnColors.textSecondary)),
      const SizedBox(height: 4),
      Text(xp,
          style: GoogleFonts.pressStart2p(
              fontSize: 7,
              color: AutumnColors.accentOrange,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _dividerLine() => Container(
        width: 1,
        height: 48,
        color: AutumnColors.divider,
      );

  // ══════════════════════════════════════════════════════════
  // PÁGINA 3 — "Tu nombre"
  // ══════════════════════════════════════════════════════════

  Widget _buildPage3() {
    return _PageWrapper(
      entryFade: _entryFade,
      entrySlide: _entrySlide,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _floatingEmoji('✍️', size: 56),
          const SizedBox(height: 32),
          _headline('PLANTA\nTU SEMILLA'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Todo árbol tiene un nombre.\n¿Cómo se llamará el tuyo?',
              style: GoogleFonts.pressStart2p(
                  fontSize: 9, color: AutumnColors.textSecondary, height: 1.9),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Campo de nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              style: GoogleFonts.pressStart2p(
                  color: AutumnColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'TU NOMBRE',
                hintStyle: GoogleFonts.pressStart2p(
                    fontSize: 11, color: AutumnColors.textDisabled),
                filled: true,
                fillColor: AutumnColors.bgCard,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AutumnColors.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AutumnColors.mossGreen, width: 2)),
                errorText: _nameError,
                errorStyle: GoogleFonts.pressStart2p(
                    fontSize: 7, color: AutumnColors.accentRed),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
          ),
          const SizedBox(height: 48),
          _nextBtn('ESTE ES MI NOMBRE', _next),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PÁGINA 4 — "Hoy empieza"
  // ══════════════════════════════════════════════════════════

  Widget _buildPage4() {
    final name = _nameCtrl.text.trim();
    return _PageWrapper(
      entryFade: _entryFade,
      entrySlide: _entrySlide,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Árbol con glow verde
          AnimatedBuilder(
            animation: _floatAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _floatAnim.value),
              child: child,
            ),
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AutumnColors.mossGreen.withValues(alpha:0.25),
                    blurRadius: 50,
                    spreadRadius: 12,
                  )
                ],
              ),
              child: const Center(
                child: Text('🌱', style: TextStyle(fontSize: 80)),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Saludo personalizado
          Text('HOY,',
              style: GoogleFonts.pressStart2p(
                  fontSize: 11, color: AutumnColors.textDisabled)),
          const SizedBox(height: 6),
          Text(
            name.isEmpty ? 'JUGADOR' : name.toUpperCase(),
            style: GoogleFonts.pressStart2p(
                fontSize: 22,
                color: AutumnColors.accentOrange,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text('PLANTAS TU PRIMERA SEMILLA.',
              style: GoogleFonts.pressStart2p(
                  fontSize: 9, color: AutumnColors.mossGreen)),

          const SizedBox(height: 28),

          // Frase final
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'No importa lo pequeño que empieces.\n'
              'Los árboles más grandes del mundo\n'
              'también fueron una semilla.',
              style: GoogleFonts.pressStart2p(
                  fontSize: 8, color: AutumnColors.textSecondary, height: 2.0),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 36),

          // Stats iniciales — presentados como el estado del árbol
          _treeStatsCard(),

          const SizedBox(height: 36),

          _saving
              ? const CircularProgressIndicator(color: AutumnColors.mossGreen)
              : _nextBtn('🌱 COMENZAR A CRECER', _finish,
                  color: AutumnColors.mossGreen),
        ],
      ),
    );
  }

  Widget _treeStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AutumnColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AutumnColors.mossGreen.withValues(alpha:0.35), width: 1.5),
      ),
      child: Column(children: [
        Text('ESTADO DE TU ÁRBOL',
            style: GoogleFonts.pressStart2p(
                fontSize: 7, color: AutumnColors.textDisabled)),
        const SizedBox(height: 12),
        _statRow('🌱', 'FORMA', 'SEMILLA'),
        const Divider(color: AutumnColors.divider, height: 14),
        _statRow('⭐', 'NIVEL', 'LVL 1'),
        const Divider(color: AutumnColors.divider, height: 14),
        _statRow('💧', 'AGUA', '0 XP'),
      ]),
    );
  }

  Widget _statRow(String emoji, String label, String value) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Text(label,
          style: GoogleFonts.pressStart2p(
              fontSize: 7, color: AutumnColors.textDisabled)),
      const Spacer(),
      Text(value,
          style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: AutumnColors.accentOrange,
              fontWeight: FontWeight.bold)),
    ]);
  }

  // ── Widgets reutilizables ─────────────────────────────────

  Widget _floatingEmoji(String emoji, {required double size}) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatAnim.value * 0.6),
        child: Text(emoji, style: TextStyle(fontSize: size)),
      ),
    );
  }

  Widget _headline(String text) {
    return Text(text,
        style: GoogleFonts.pressStart2p(
            fontSize: 16,
            color: AutumnColors.accentOrange,
            fontWeight: FontWeight.bold,
            height: 1.6),
        textAlign: TextAlign.center);
  }

  Widget _poem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(text,
          style: GoogleFonts.pressStart2p(
              fontSize: 8, color: AutumnColors.textSecondary, height: 2.2),
          textAlign: TextAlign.center),
    );
  }

  Widget _nextBtn(String label, VoidCallback onTap,
      {Color color = AutumnColors.accentOrange}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: onTap,
          child: Text(label,
              style: GoogleFonts.pressStart2p(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Wrapper de entrada con fade + slide por página
// ══════════════════════════════════════════════════════════════

class _PageWrapper extends StatelessWidget {
  final Animation<double> entryFade;
  final Animation<Offset> entrySlide;
  final Widget child;
  const _PageWrapper({
    required this.entryFade,
    required this.entrySlide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: entryFade,
      child: SlideTransition(
        position: entrySlide,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Fondo — hojas y partículas de luz flotantes
// ══════════════════════════════════════════════════════════════

class _NaturePainter extends CustomPainter {
  final double t;
  _NaturePainter(this.t);

  static const _elements = [
    // x,    y,    size, speed, type  (0=hoja, 1=círculo luz)
    [0.08, 0.12, 14.0, 0.7, 0.0],
    [0.88, 0.06, 10.0, 0.5, 1.0],
    [0.04, 0.55, 18.0, 0.4, 0.0],
    [0.92, 0.48, 12.0, 0.8, 0.0],
    [0.45, 0.95, 16.0, 0.6, 1.0],
    [0.22, 0.82, 10.0, 0.9, 0.0],
    [0.75, 0.75, 14.0, 0.3, 1.0],
    [0.60, 0.08, 8.0, 0.7, 0.0],
    [0.15, 0.30, 12.0, 0.5, 1.0],
    [0.80, 0.30, 9.0, 0.6, 0.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in _elements) {
      final x = e[0] as double;
      final y = e[1] as double;
      final s = e[2] as double;
      final speed = e[3] as double;
      final type = e[4] as double;

      final phase = (t * speed + x) % 1.0;
      final dy = 10.0 * (0.5 - (phase % 1.0 - 0.5).abs());
      final cx = x * size.width;
      final cy = y * size.height + dy;
      final opacity = 0.035 + 0.025 * (0.5 - (phase - 0.5).abs());

      final paint = Paint()
        ..color = (type == 0 ? AutumnColors.mossGreen : AutumnColors.accentGold)
            .withValues(alpha:opacity)
        ..style = PaintingStyle.fill;

      if (type == 0) {
        // Hoja — rectángulo pequeño rotado
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(phase * 3.14);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.6),
              const Radius.circular(3)),
          paint,
        );
        canvas.restore();
      } else {
        // Partícula de luz — círculo suave
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(cx, cy), s * 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_NaturePainter old) => old.t != t;
}
