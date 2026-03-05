import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/autumn_theme.dart';

// ===========================
// 🍂 AUTUMN BUTTON
// ===========================
class AutumnButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color bgColor;
  final Color textColor;
  final double height;
  final double fontSize;

  const AutumnButton({
    super.key,
    required this.text,
    this.onPressed,
    this.bgColor = AutumnColors.accentOrange,
    this.textColor = AutumnColors.bgCard,
    this.height = MobileSizes.buttonHeight,
    this.fontSize = 11,
  });

  @override
  State<AutumnButton> createState() => _AutumnButtonState();
}

class _AutumnButtonState extends State<AutumnButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c  = context.ac;
    final bg = widget.onPressed == null
        ? c.bgSurface
        : (_pressed ? _darken(widget.bgColor, 0.82) : widget.bgColor);

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
        setState(() => _pressed = false);
        widget.onPressed!();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: widget.height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
          border: Border.all(
            color: _darken(widget.bgColor, 0.78).withOpacity(0.45),
            width: 1.2,
          ),
          boxShadow: _pressed
              ? []
              : [
            BoxShadow(
              color: c.shadow.withOpacity(0.5),
              blurRadius: 4,
              offset: Offset(0, _pressed ? 1 : 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: GoogleFonts.pressStart2p(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.bold,
              color: widget.onPressed == null
                  ? c.textDisabled
                  : widget.textColor,
            ),
          ),
        ),
      ),
    );
  }

  Color _darken(Color c, double f) => Color.fromRGBO(
    (c.red * f).round(),
    (c.green * f).round(),
    (c.blue * f).round(),
    1,
  );
}

// ===========================
// 🍂 AUTUMN INPUT
// ===========================
class AutumnInput extends StatefulWidget {
  final String hintText;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final TextInputType? keyboardType;

  const AutumnInput({
    super.key,
    required this.hintText,
    this.isPassword = false,
    this.controller,
    this.textInputAction,
    this.onSubmitted,
    this.keyboardType,
  });

  @override
  State<AutumnInput> createState() => _AutumnInputState();
}

class _AutumnInputState extends State<AutumnInput> {
  bool _focused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: MobileSizes.inputHeight,
      decoration: BoxDecoration(
        color: c.bgInput,
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        border: Border.all(
          color: _focused ? AutumnColors.accentOrange : c.divider,
          width: _focused ? 1.8 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? AutumnColors.accentOrange.withOpacity(0.12)
                : Colors.transparent,
            blurRadius: 6,
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.isPassword,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        style: GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 11),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.pressStart2p(
              fontSize: 10, color: c.textDisabled),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cursorColor: AutumnColors.accentOrange,
      ),
    );
  }
}

// ===========================
// 🍂 AUTUMN CARD
// ===========================
class AutumnCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final String cardType;

  const AutumnCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.cardType = 'default',
  });

  Color _border(BuildContext context) {
    if (borderColor != null) return borderColor!;
    switch (cardType) {
      case 'leaf':   return AutumnColors.accentOrange;
      case 'branch': return AutumnColors.mossGreen;
      case 'acorn':  return AutumnColors.leafBrown;
      default:       return context.ac.divider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        border: Border.all(color: _border(context), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ===========================
// 🍂 ACCENT CARD
// ===========================
class AccentCard extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsets? padding;

  const AccentCard({
    super.key,
    required this.child,
    this.accentColor = AutumnColors.accentOrange,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        border: Border.all(color: c.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(2, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(14),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================
// 🍂 PRIORITY PILL
// ===========================
class PriorityPill extends StatelessWidget {
  final int priority;
  const PriorityPill({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final colors = {
      3: AutumnColors.accentRed,
      2: AutumnColors.accentGold,
      1: AutumnColors.mossGreen,
    };
    final labels = {3: 'ALTA', 2: 'MEDIA', 1: 'BAJA'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: colors[priority] ?? AutumnColors.accentGold,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(labels[priority] ?? '',
          style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: context.ac.bgCard,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ===========================
// 🍂 URGENCY PILL
// ===========================
class UrgencyPill extends StatelessWidget {
  final String text;
  final Color color;
  const UrgencyPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: GoogleFonts.pressStart2p(
              fontSize: 7,
              color: context.ac.bgCard,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ===========================
// 🍂 AUTUMN MESSAGE
// ===========================
class AutumnMessage extends StatelessWidget {
  final String text;
  final Color color;

  const AutumnMessage({
    super.key,
    required this.text,
    this.color = AutumnColors.textDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: TextAlign.center,
        style: GoogleFonts.pressStart2p(
            fontSize: 9, color: color, fontWeight: FontWeight.bold));
  }
}

// ===========================
// 🍂 SCREEN HEADER
// ===========================
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color accentColor;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor = AutumnColors.accentOrange,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.pressStart2p(
              fontSize: MobileSizes.fontLarge,
              color: accentColor,
              fontWeight: FontWeight.bold)),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!,
            style: GoogleFonts.pressStart2p(
                fontSize: 9, color: c.textDisabled)),
      ],
      const SizedBox(height: 8),
      Container(height: 2, color: accentColor),
    ]);
  }
}

// ===========================
// 🍂 XP PROGRESS BAR
// ===========================
class XpProgressBar extends StatelessWidget {
  final int currentXp;
  final int xpForNext;
  final int level;

  const XpProgressBar({
    super.key,
    required this.currentXp,
    required this.xpForNext,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final progress =
    xpForNext > 0 ? (currentXp / xpForNext).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('LEVEL $level',
            style: GoogleFonts.pressStart2p(
                fontSize: 10,
                color: AutumnColors.accentGold,
                fontWeight: FontWeight.bold)),
        Text('$currentXp / $xpForNext XP',
            style: GoogleFonts.pressStart2p(
                fontSize: 8, color: c.textSecondary)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 14,
          backgroundColor: c.bgSurface,
          valueColor:
          const AlwaysStoppedAnimation<Color>(AutumnColors.accentOrange),
        ),
      ),
    ]);
  }
}

// ===========================
// 🌳 PROGRESS TREE WIDGET
// ===========================
class ProgressTree extends StatelessWidget {
  final int level;
  final int currentXp;
  final int xpForNext;

  const ProgressTree({
    super.key,
    required this.level,
    this.currentXp = 0,
    this.xpForNext = 100,
  });

  String get _stage {
    if (level <= 3) return 'seedling';
    if (level <= 7) return 'sapling';
    if (level <= 10) return 'tree';
    return 'mighty';
  }

  @override
  Widget build(BuildContext context) {
    return _TreeVisual(level: level, stage: _stage);
  }
}

class _TreeVisual extends StatelessWidget {
  final int level;
  final String stage;
  const _TreeVisual({required this.level, required this.stage});

  @override
  Widget build(BuildContext context) {
    final Widget tree = switch (stage) {
      'seedling' => _buildSeedling(),
      'sapling'  => _buildSapling(),
      'tree'     => _buildTree(),
      _          => _buildMighty(),
    };
    return SizedBox(
      width: double.infinity,
      height: 150,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: 150,
          maxHeight: 300,
          minWidth: 0,
          maxWidth: double.infinity,
          child: SizedBox(height: 250, child: tree),
        ),
      ),
    );
  }

  Widget _trunk(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: const Color(0xFF8B5A2B),
      borderRadius: BorderRadius.circular(w / 4),
      gradient: const LinearGradient(
          colors: [Color(0xFFA0693A), Color(0xFF6B3E1A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight),
    ),
  );

  Widget _canopy(double size, Color color, {double opacity = 1.0}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(opacity),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)
      ],
    ),
  );

  Widget _leaf(double size, Color color) => Container(
    width: size, height: size * 1.3,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(size / 2),
        topRight: Radius.circular(size / 2),
        bottomRight: Radius.circular(size / 4),
      ),
    ),
  );

  Widget _buildSeedling() {
    const leafColor = Color(0xFF4A7A45);
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (level >= 2) Transform.rotate(angle: -0.3, child: _leaf(14, const Color(0xFFD4581A))),
        const SizedBox(width: 4),
        _leaf(20, leafColor),
        const SizedBox(width: 4),
        if (level >= 3) Transform.rotate(angle: 0.3, child: _leaf(14, const Color(0xFFC8860A))),
      ]),
      const SizedBox(height: 2),
      Center(child: _canopy(level >= 2 ? 22 : 16, leafColor)),
      const SizedBox(height: 4),
      Center(child: _trunk(5, 40)),
    ]);
  }

  Widget _buildSapling() {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Stack(alignment: Alignment.center, children: [
        Positioned(left: 20, top: 10, child: _canopy(50, const Color(0xFF4A7A45), opacity: 0.7)),
        Positioned(right: 20, top: 10, child: _canopy(50, const Color(0xFF5A8A55), opacity: 0.7)),
        _canopy(level >= 6 ? 70 : 60, const Color(0xFF4A7A45)),
        if (level >= 5) Positioned(top: 0, child: _canopy(40, const Color(0xFFD4581A), opacity: 0.6)),
      ]),
      const SizedBox(height: 2),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 20, height: 3, color: const Color(0xFF8B5A2B), margin: const EdgeInsets.only(right: 2)),
        _trunk(10, 55),
        Container(width: 20, height: 3, color: const Color(0xFF8B5A2B), margin: const EdgeInsets.only(left: 2)),
      ]),
    ]);
  }

  Widget _buildTree() {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Stack(alignment: Alignment.center, children: [
        Positioned(left: 10, top: 20, child: _canopy(65, const Color(0xFF3A6A35), opacity: 0.8)),
        Positioned(right: 10, top: 20, child: _canopy(65, const Color(0xFF4A7A45), opacity: 0.8)),
        Positioned(top: 8, child: _canopy(60, const Color(0xFFD4581A), opacity: 0.5)),
        _canopy(80, const Color(0xFF4A7A45)),
        Positioned(top: 0, child: _canopy(50, const Color(0xFF5A9A50))),
        Positioned(left: 30, top: 15, child: _canopy(18, const Color(0xFFC8860A), opacity: 0.8)),
        Positioned(right: 30, top: 25, child: _canopy(14, const Color(0xFFB03A2E), opacity: 0.7)),
      ]),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 30, height: 5, decoration: BoxDecoration(color: const Color(0xFF8B5A2B), borderRadius: BorderRadius.circular(3)), margin: const EdgeInsets.only(right: 2, bottom: 30)),
        _trunk(16, 60),
        Container(width: 30, height: 5, decoration: BoxDecoration(color: const Color(0xFF8B5A2B), borderRadius: BorderRadius.circular(3)), margin: const EdgeInsets.only(left: 2, bottom: 20)),
      ]),
    ]);
  }

  Widget _buildMighty() {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Stack(alignment: Alignment.center, children: [
        Positioned(left: 5, top: 25, child: _canopy(75, const Color(0xFF2A5A2A), opacity: 0.9)),
        Positioned(right: 5, top: 25, child: _canopy(75, const Color(0xFF3A6A35), opacity: 0.9)),
        Positioned(left: 15, top: 5, child: _canopy(55, const Color(0xFFD4581A), opacity: 0.6)),
        Positioned(right: 15, top: 5, child: _canopy(50, const Color(0xFFC8860A), opacity: 0.55)),
        _canopy(95, const Color(0xFF4A7A45)),
        Positioned(top: 0, child: _canopy(65, const Color(0xFF5A9A50))),
        Positioned(left: 28, top: 8, child: _canopy(22, const Color(0xFFC8860A), opacity: 0.9)),
        Positioned(right: 28, top: 15, child: _canopy(18, const Color(0xFFB03A2E), opacity: 0.85)),
        Positioned(top: 2, left: 50, child: _canopy(14, Colors.amber, opacity: 0.7)),
      ]),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 38, height: 6, decoration: BoxDecoration(color: const Color(0xFF8B5A2B), borderRadius: BorderRadius.circular(4)), margin: const EdgeInsets.only(right: 2, bottom: 38)),
        Container(width: 20, height: 6, decoration: BoxDecoration(color: const Color(0xFF8B5A2B), borderRadius: BorderRadius.circular(4)), margin: const EdgeInsets.only(right: 2, bottom: 55)),
        _trunk(22, 70),
        Container(width: 20, height: 6, decoration: BoxDecoration(color: const Color(0xFF8B5A2B), borderRadius: BorderRadius.circular(4)), margin: const EdgeInsets.only(left: 2, bottom: 45)),
        Container(width: 38, height: 6, decoration: BoxDecoration(color: const Color(0xFF8B5A2B), borderRadius: BorderRadius.circular(4)), margin: const EdgeInsets.only(left: 2, bottom: 28)),
      ]),
    ]);
  }
}

// ===========================
// 🍂 LEAF BACKGROUND
// ===========================
class LeafBackgroundPainter extends CustomPainter {
  final double animValue;
  LeafBackgroundPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final leaves = [
      (0.08, 0.12, AutumnColors.accentOrange),
      (0.88, 0.07, AutumnColors.accentGold),
      (0.04, 0.60, AutumnColors.accentRed),
      (0.92, 0.50, AutumnColors.leafBrown),
      (0.50, 0.88, AutumnColors.accentOrange),
      (0.75, 0.22, AutumnColors.mossGreen),
      (0.20, 0.35, AutumnColors.accentGold),
    ];
    for (int i = 0; i < leaves.length; i++) {
      final l = leaves[i];
      final paint = Paint()
        ..color = (l.$3 as Color).withOpacity(0.07)
        ..style = PaintingStyle.fill;
      final ox = (l.$1 as double) * size.width + 8 * (animValue - 0.5);
      final oy = (l.$2 as double) * size.height + 15 * animValue;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(ox, oy), width: 12.0 + i * 3, height: 10.0 + i * 2),
          paint);
    }
  }

  @override
  bool shouldRepaint(LeafBackgroundPainter old) => old.animValue != animValue;
}

// ===========================
// 🍂 SECTION LABEL
// ===========================
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: GoogleFonts.pressStart2p(
            fontSize: 9,
            color: context.ac.textDisabled,
            fontWeight: FontWeight.bold));
  }
}

// ===========================
// 🍂 AUTUMN DIVIDER
// ===========================
class AutumnDivider extends StatelessWidget {
  final String? label;
  const AutumnDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    if (label == null) {
      return Divider(color: c.divider, thickness: 1, height: 24);
    }
    return Row(children: [
      Expanded(child: Divider(color: c.divider, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(label!,
            style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled)),
      ),
      Expanded(child: Divider(color: c.divider, thickness: 1)),
    ]);
  }
}

// ===========================
// 🍂 FREEZE BADGE
// ===========================
class FreezeBadge extends StatelessWidget {
  final int count;
  const FreezeBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0 ? AutumnColors.freeze : AutumnColors.accentRed,
          width: 1.5,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.ac_unit,
            color: count > 0 ? AutumnColors.freeze : AutumnColors.accentRed,
            size: 16),
        const SizedBox(width: 8),
        Text(
            count > 0
                ? '$count FREEZE${count != 1 ? "S" : ""} DISPONIBLE${count != 1 ? "S" : ""}'
                : 'NO FREEZES',
            style: GoogleFonts.pressStart2p(
                fontSize: 9,
                color: count > 0 ? AutumnColors.freeze : AutumnColors.accentRed,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ===========================
// 🍂 AUTUMN TITLE
// ===========================
class AutumnTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;

  const AutumnTitle({
    super.key,
    required this.text,
    this.fontSize = MobileSizes.fontLarge,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.pressStart2p(
        fontSize: fontSize,
        color: color ?? AutumnColors.accentOrange,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: AutumnColors.accentOrange.withOpacity(0.3),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

// ===========================
// 🍂 AUTUMN SUBTITLE
// ===========================
class AutumnSubtitle extends StatelessWidget {
  final String text;
  final Color? color;

  const AutumnSubtitle({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.pressStart2p(
        fontSize: 9,
        color: color ?? AutumnColors.accentGold,
        letterSpacing: 1.5,
      ),
    );
  }
}