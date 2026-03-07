import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/widgets/notification_config_widget.dart';
import '../../../core/services/notification_service.dart';
import '../domain/goal.dart';
import '../domain/goals_state.dart';
import 'providers/goals_provider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/celebration_overlay.dart';
import '../../../core/widgets/xp_toast.dart';

const List<Map<String, String>> kAppCategories = [
  {'label': 'Personal', 'emoji': '🧘'},
  {'label': 'Salud / Fitness', 'emoji': '💪'},
  {'label': 'Meditación', 'emoji': '🕯️'},
  {'label': 'Sueño / Descanso', 'emoji': '😴'},
  {'label': 'Alimentación', 'emoji': '🥗'},
  {'label': 'Hidratación', 'emoji': '💧'},
  {'label': 'Estudio / Educación', 'emoji': '📚'},
  {'label': 'Lectura / Libros', 'emoji': '📖'},
  {'label': 'Idiomas', 'emoji': '🌐'},
  {'label': 'Cursos Online', 'emoji': '🖥️'},
  {'label': 'Investigación', 'emoji': '🔬'},
  {'label': 'Trabajo / Laboral', 'emoji': '💼'},
  {'label': 'Finanzas / Ahorro', 'emoji': '💰'},
  {'label': 'Emprendimiento', 'emoji': '🚀'},
  {'label': 'Networking', 'emoji': '🤝'},
  {'label': 'Reuniones', 'emoji': '📅'},
  {'label': 'Proyectos / Hobbies', 'emoji': '🎨'},
  {'label': 'Creatividad / Arte', 'emoji': '🖌️'},
  {'label': 'Música', 'emoji': '🎵'},
  {'label': 'Fotografía', 'emoji': '📷'},
  {'label': 'Escritura', 'emoji': '✍️'},
  {'label': 'Cocina', 'emoji': '🍳'},
  {'label': 'Jardinería', 'emoji': '🌿'},
  {'label': 'Juegos / Gaming', 'emoji': '🎮'},
  {'label': 'Social / Amigos', 'emoji': '👥'},
  {'label': 'Familia', 'emoji': '🏠'},
  {'label': 'Pareja / Relaciones', 'emoji': '❤️'},
  {'label': 'Mascotas', 'emoji': '🐾'},
  {'label': 'Viajes', 'emoji': '✈️'},
  {'label': 'Naturaleza / Outdoor', 'emoji': '🏕️'},
  {'label': 'Deporte', 'emoji': '⚽'},
  {'label': 'Voluntariado', 'emoji': '🤲'},
  {'label': 'Rutina / Hábitos', 'emoji': '🔄'},
  {'label': 'Desarrollo personal', 'emoji': '🌱'},
  {'label': 'Tecnología', 'emoji': '💻'},
  {'label': 'Casa / Hogar', 'emoji': '🧹'},
  {'label': 'Trámites / Gestiones', 'emoji': '📋'},
  {'label': 'Espiritual / Fe', 'emoji': '🙏'},
];

final _categoryEmojiMap = {
  for (final c in kAppCategories) c['label']!: c['emoji']!
};

class GoalsScreen extends ConsumerStatefulWidget {
  final String userId;
  const GoalsScreen({super.key, required this.userId});
  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _message = '';
  Color _messageColor = AutumnColors.mossGreen;
  bool _filtersOpen = false;

  void _setMsg(String msg, Color color) {
    if (mounted)
      setState(() {
        _message = msg;
        _messageColor = color;
      });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = '');
    });
  }

  Widget _sectionLabel(BuildContext ctx, String text) {
    final c = ctx.ac;
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled)));
  }

  Widget _dlgInput(BuildContext ctx, TextEditingController ctrl, String hint,
      {bool multiline = false}) {
    final c = ctx.ac;
    return TextField(
        controller: ctrl,
        maxLines: multiline ? 3 : 1,
        style: GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 10),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled),
            filled: true,
            fillColor: c.bgSurface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AutumnColors.accentOrange, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));
  }

  String _daysLabel(DateTime date) {
    final diff = date.difference(DateTime.now()).inDays;
    if (diff < 0) return 'VENCIDA';
    if (diff == 0) return 'HOY';
    if (diff == 1) return 'MAÑANA';
    return 'EN $diff DÍAS';
  }

  Widget _pill(BuildContext ctx, String label, Color color) {
    final c = ctx.ac;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: GoogleFonts.pressStart2p(fontSize: 7, color: c.bgCard)));
  }

  Widget _fLabel(BuildContext ctx, String t) => Text(t,
      style: GoogleFonts.pressStart2p(fontSize: 7, color: ctx.ac.textDisabled));

  // ── Create Goal Dialog ─────────────────────────────────────────────────────

  void _openCreateGoalPopup() {
    final c = context.ac;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    DateTime? selectedDate;
    String? selectedCategory;
    String priority = 'Moderada';
    double difficulty = 5;
    NotificationConfig notifConfig = const NotificationConfig();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlg) => Dialog(
                backgroundColor: c.bgCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: SizedBox(
                  width: 400,
                  height: MediaQuery.of(ctx).size.height * 0.85,
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Row(children: [
                          const Icon(Icons.flag_rounded,
                              color: AutumnColors.accentOrange, size: 18),
                          const SizedBox(width: 10),
                          Text('NUEVA META',
                              style: GoogleFonts.pressStart2p(
                                  color: AutumnColors.accentOrange,
                                  fontSize: 12)),
                        ])),
                    Divider(height: 1, color: c.divider),
                    Expanded(
                        child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel(ctx, 'NOMBRE'),
                            _dlgInput(ctx, titleCtrl, 'Nombre de la misión...'),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, 'DESCRIPCIÓN (opcional)'),
                            _dlgInput(ctx, descCtrl, 'Describe tu objetivo...',
                                multiline: true),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, 'FECHA LÍMITE'),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: DateTime.now()
                                        .add(const Duration(days: 7)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 3650)),
                                    builder: (dCtx, child) => Theme(
                                        data: ThemeData.light().copyWith(
                                            colorScheme: const ColorScheme
                                                .light(
                                                primary: AutumnColors.mossGreen,
                                                onPrimary: Colors.white,
                                                surface: AutumnColors.bgCard,
                                                onSurface:
                                                    AutumnColors.textPrimary)),
                                        child: child!));
                                if (picked != null)
                                  setDlg(() => selectedDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                    color: c.bgSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: selectedDate != null
                                            ? AutumnColors.accentOrange
                                            : c.divider,
                                        width: selectedDate != null ? 1.5 : 1)),
                                child: Row(children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 16,
                                      color: selectedDate != null
                                          ? AutumnColors.accentOrange
                                          : c.textDisabled),
                                  const SizedBox(width: 10),
                                  Text(
                                      selectedDate != null
                                          ? DateFormat('dd MMM yyyy', 'es')
                                              .format(selectedDate!)
                                          : 'Toca para elegir fecha',
                                      style: GoogleFonts.pressStart2p(
                                          fontSize: 9,
                                          color: selectedDate != null
                                              ? c.textPrimary
                                              : c.textDisabled)),
                                  const Spacer(),
                                  if (selectedDate != null)
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: AutumnColors.accentOrange
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: Text(_daysLabel(selectedDate!),
                                            style: GoogleFonts.pressStart2p(
                                                fontSize: 7,
                                                color: AutumnColors
                                                    .accentOrange))),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, 'CATEGORÍA'),
                            _buildCategoryAutocomplete(ctx,
                                categoryCtrl: categoryCtrl,
                                selectedCategory: selectedCategory,
                                onSelected: (label, full) => setDlg(() {
                                      selectedCategory = label;
                                      categoryCtrl.text = full;
                                    }),
                                onCleared: () =>
                                    setDlg(() => selectedCategory = null)),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, 'PRIORIDAD'),
                            Row(
                                children: ['Alta', 'Moderada', 'Baja'].map((p) {
                              final sel = priority == p;
                              const pc = {
                                'Alta': AutumnColors.accentRed,
                                'Moderada': AutumnColors.accentGold,
                                'Baja': AutumnColors.mossGreen
                              };
                              return Expanded(
                                  child: GestureDetector(
                                      onTap: () => setDlg(() => priority = p),
                                      child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          margin: EdgeInsets.only(
                                              right: p != 'Baja' ? 6 : 0),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          decoration: BoxDecoration(
                                              color: sel ? pc[p] : c.bgSurface,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: sel
                                                      ? pc[p]!
                                                      : c.divider)),
                                          child: Text(p,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.pressStart2p(
                                                  fontSize: 8,
                                                  color: sel
                                                      ? c.bgCard
                                                      : c.textSecondary,
                                                  fontWeight: sel
                                                      ? FontWeight.bold
                                                      : FontWeight.normal)))));
                            }).toList()),
                            const SizedBox(height: 12),
                            _sectionLabel(
                                ctx, 'DIFICULTAD: ${difficulty.toInt()} / 10'),
                            SliderTheme(
                              data: SliderTheme.of(ctx).copyWith(
                                  activeTrackColor: AutumnColors.accentOrange,
                                  inactiveTrackColor: c.divider,
                                  thumbColor: AutumnColors.accentOrange,
                                  overlayColor: AutumnColors.accentOrange
                                      .withOpacity(0.15),
                                  trackHeight: 4),
                              child: Slider(
                                  value: difficulty,
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  onChanged: (v) =>
                                      setDlg(() => difficulty = v)),
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, '🔔 RECORDATORIO (opcional)'),
                            NotificationConfigWidget(
                                config: notifConfig,
                                onChanged: (cfg) =>
                                    setDlg(() => notifConfig = cfg)),
                            const SizedBox(height: 4),
                          ]),
                    )),
                    Divider(height: 1, color: c.divider),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('CANCELAR',
                                      style: GoogleFonts.pressStart2p(
                                          fontSize: 9, color: c.textDisabled))),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AutumnColors.accentOrange,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10)),
                                onPressed: () async {
                                  if (titleCtrl.text.trim().isEmpty ||
                                      selectedDate == null) {
                                    _setMsg('ERROR: Nombre y Fecha requeridos',
                                        AutumnColors.accentRed);
                                    Navigator.pop(ctx);
                                    return;
                                  }
                                  final t2 = titleCtrl.text.trim();
                                  final dl = selectedDate!;
                                  final cfg = notifConfig;
                                  Navigator.pop(ctx);
                                  final newId = await ref
                                      .read(goalsProvider.notifier)
                                      .createGoal(
                                          title: t2,
                                          description: descCtrl.text.trim(),
                                          deadline: dl
                                              .toIso8601String()
                                              .substring(0, 10),
                                          category: selectedCategory ?? '',
                                          priority: const {
                                                'Alta': 3,
                                                'Moderada': 2,
                                                'Baja': 1
                                              }[priority] ??
                                              2,
                                          difficulty: difficulty.toInt());
                                  if (cfg.enabled && newId > 0) {
                                    try {
                                      await NotificationService()
                                          .scheduleDeadlineNotifications(
                                              itemId: newId,
                                              itemType: 'goal',
                                              title: t2,
                                              deadline: dl,
                                              config: cfg.toConfigMap());
                                    } catch (_) {}
                                  }
                                  _setMsg('✓ MISIÓN CREADA CON ÉXITO!',
                                      AutumnColors.mossGreen);
                                },
                                child: Text('✅ INICIAR MISIÓN',
                                    style: GoogleFonts.pressStart2p(
                                        fontSize: 9, color: c.bgCard)),
                              ),
                            ])),
                  ]),
                ),
              )),
    );
  }

  Widget _buildCategoryAutocomplete(
    BuildContext ctx, {
    required TextEditingController categoryCtrl,
    required String? selectedCategory,
    required void Function(String, String) onSelected,
    required void Function() onCleared,
  }) {
    final c = ctx.ac;
    return Autocomplete<String>(
      optionsBuilder: (tv) {
        final q = tv.text.toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return kAppCategories
            .where((cat) => cat['label']!.toLowerCase().contains(q))
            .map((cat) => '${cat['emoji']} ${cat['label']}');
      },
      onSelected: (value) {
        final idx = value.indexOf(' ');
        onSelected(idx >= 0 ? value.substring(idx + 1) : value, value);
      },
      fieldViewBuilder: (ctx2, ctrl2, fn, _) => TextField(
        controller: ctrl2,
        focusNode: fn,
        onChanged: (v) {
          categoryCtrl.text = v;
          if (v.isEmpty) onCleared();
        },
        style: GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 9),
        decoration: InputDecoration(
            hintText: 'Escribe para buscar...',
            hintStyle:
                GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled),
            prefixIcon: const Icon(Icons.folder_outlined,
                size: 16, color: AutumnColors.accentOrange),
            suffixIcon: selectedCategory != null
                ? const Icon(Icons.check_circle,
                    size: 16, color: AutumnColors.accentOrange)
                : null,
            filled: true,
            fillColor: c.bgSurface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AutumnColors.accentOrange, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      ),
      optionsViewBuilder: (ctx2, onSel, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(10),
              color: c.bgCard,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: options.length,
                      itemBuilder: (ctx3, i) {
                        final opt = options.elementAt(i);
                        return InkWell(
                            onTap: () => onSel(opt),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Text(opt,
                                    style: GoogleFonts.pressStart2p(
                                        fontSize: 9, color: c.textPrimary))));
                      })))),
    );
  }

  // ── Goal Card ─────────────────────────────────────────────────────────────

  Widget _buildGoalCard(Goal goal) {
    final c = context.ac;
    const pColors = {
      3: AutumnColors.accentRed,
      2: AutumnColors.accentGold,
      1: AutumnColors.mossGreen
    };
    const pLabels = {3: '🔴 ALTA', 2: '🟡 MEDIA', 1: '🟢 BAJA'};
    final catEmoji = _categoryEmojiMap[goal.category ?? ''] ?? '🎯';
    final isComplete = goal.status == 'completed';
    final pct = goal.progress;
    final pctInt = (pct * 100).round();

    String deadlineBadge = '';
    Color deadlineColor = c.textDisabled;
    if ((goal.deadline ?? '').isNotEmpty) {
      try {
        final dl = DateTime.parse(goal.deadline!);
        final diff = dl.difference(DateTime.now()).inDays;
        if (diff < 0) {
          deadlineBadge = 'VENCIDA';
          deadlineColor = AutumnColors.accentRed;
        } else if (diff == 0) {
          deadlineBadge = 'HOY';
          deadlineColor = AutumnColors.accentRed;
        } else if (diff == 1) {
          deadlineBadge = 'MAÑANA';
          deadlineColor = AutumnColors.accentGold;
        } else {
          deadlineBadge = 'EN $diff DÍAS';
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isComplete ? AutumnColors.mossGreen : c.divider,
              width: isComplete ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            width: 5,
            decoration: BoxDecoration(
                color: isComplete
                    ? AutumnColors.mossGreen
                    : pColors[goal.priority] ?? AutumnColors.accentOrange,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12)))),
        Expanded(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$catEmoji ', style: const TextStyle(fontSize: 16)),
              Expanded(
                  child: Text(goal.title.toUpperCase(),
                      style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: isComplete
                              ? AutumnColors.mossGreen
                              : AutumnColors.accentOrange,
                          fontWeight: FontWeight.bold))),
              if (isComplete)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AutumnColors.mossGreen,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('✓ DONE',
                        style: GoogleFonts.pressStart2p(
                            fontSize: 7, color: Colors.white))),
            ]),
            const SizedBox(height: 6),
            if (goal.description.isNotEmpty) ...[
              Text(goal.description,
                  style: GoogleFonts.pressStart2p(
                      fontSize: 8, color: c.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
            ],
            Row(children: [
              _pill(context, pLabels[goal.priority] ?? '',
                  pColors[goal.priority] ?? c.divider),
              const SizedBox(width: 6),
              _pill(context, '⚔️ D:${goal.difficulty}', AutumnColors.leafBrown),
              const Spacer(),
              if (deadlineBadge.isNotEmpty)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: deadlineColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: deadlineColor.withOpacity(0.4))),
                    child: Text(deadlineBadge,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 7, color: deadlineColor))),
            ]),
            const SizedBox(height: 10),
            if (goal.objTotal > 0) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('OBJETIVOS',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7, color: c.textDisabled)),
                Text('${goal.objCompleted}/${goal.objTotal} completados',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7, color: AutumnColors.accentOrange)),
              ]),
              const SizedBox(height: 5),
              Stack(children: [
                Container(
                    height: 14,
                    decoration: BoxDecoration(
                        color: c.bgSurface,
                        borderRadius: BorderRadius.circular(7))),
                FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AutumnColors.accentOrange,
                              pct >= 1.0
                                  ? AutumnColors.mossGreen
                                  : AutumnColors.accentGold
                            ]),
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: pct > 0
                                ? [
                                    BoxShadow(
                                        color: AutumnColors.accentOrange
                                            .withOpacity(0.35),
                                        blurRadius: 4)
                                  ]
                                : []))),
                if (pct > 0.18)
                  Positioned.fill(
                      child: Center(
                          child: Text('$pctInt%',
                              style: GoogleFonts.pressStart2p(
                                  fontSize: 7,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)))),
              ]),
              const SizedBox(height: 8),
            ] else ...[
              Row(children: [
                Icon(Icons.add_circle_outline, size: 12, color: c.textDisabled),
                const SizedBox(width: 6),
                Text('Sin objetivos — toca para añadir',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7, color: c.textDisabled)),
              ]),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(
                  child: SizedBox(
                      height: 32,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AutumnColors.accentOrange,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.zero),
                          onPressed: () => _openObjectivesPopup(goal),
                          child: Text('📋 OBJETIVOS',
                              style: GoogleFonts.pressStart2p(
                                  fontSize: 7, color: c.bgCard))))),
              const SizedBox(width: 8),
              SizedBox(
                  height: 32,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: c.bgSurface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                  color: AutumnColors.accentRed)),
                          padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: () => _confirmDeleteGoal(goal.id),
                      child: Text('ELIMINAR',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 7, color: AutumnColors.accentRed)))),
            ]),
          ]),
        )),
      ])),
    );
  }

  Future<void> _confirmDeleteGoal(int goalId) async {
    final c = context.ac;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: c.bgCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                title: Text('ABANDONAR MISIÓN',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 11, color: AutumnColors.accentRed)),
                content: Text('¿Seguro que quieres eliminar esta meta?',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 9, color: c.textSecondary)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('CANCELAR',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 9, color: c.textDisabled))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AutumnColors.accentRed),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('ELIMINAR',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 9, color: c.bgCard))),
                ]));
    if (confirmed != true) return;
    await NotificationService()
        .cancelItemNotifications(itemId: goalId, itemType: 'goal');
    await ref.read(goalsProvider.notifier).deleteGoal(goalId);
  }

  void _openObjectivesPopup(Goal goal) {
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (ctx) => _ObjectivesDialog(
            goal: goal,
            userId: widget.userId,
            onChanged: (total, completed) => ref
                .read(goalsProvider.notifier)
                .updateGoalObjStats(goal.id, total, completed)));
  }

  // ── Filter Panel ──────────────────────────────────────────────────────────

  Widget _buildFilterPanel(BuildContext context, GoalsState state) {
    final c = context.ac;
    final af = (state.fPriority != 'TODAS' ? 1 : 0) +
        (state.fStatus != 'TODAS' ? 1 : 0) +
        (state.fCategory != null ? 1 : 0) +
        (state.fSort != 'FECHA' ? 1 : 0);
    final notifier = ref.read(goalsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: af > 0
                  ? AutumnColors.accentOrange.withOpacity(0.5)
                  : c.divider)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _filtersOpen = !_filtersOpen),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const Icon(Icons.filter_list_rounded,
                    size: 16, color: AutumnColors.accentOrange),
                const SizedBox(width: 8),
                Text('FILTROS',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 8, color: AutumnColors.accentOrange)),
                if (af > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AutumnColors.accentOrange,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('$af',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 7, color: Colors.white))),
                ],
                const Spacer(),
                if (af > 0)
                  GestureDetector(
                      onTap: () {
                        setState(() => _filtersOpen = false);
                        notifier.clearFilters();
                      },
                      child: Text('LIMPIAR',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 7, color: AutumnColors.accentRed))),
                const SizedBox(width: 8),
                Icon(
                    _filtersOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: c.textDisabled),
              ])),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _filtersOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: c.divider, height: 14),
                        _fLabel(context, 'PRIORIDAD'),
                        const SizedBox(height: 6),
                        Row(
                            children:
                                ['TODAS', 'Alta', 'Moderada', 'Baja'].map((p) {
                          final sel = state.fPriority == p;
                          const colors = {
                            'Alta': AutumnColors.accentRed,
                            'Moderada': AutumnColors.accentGold,
                            'Baja': AutumnColors.mossGreen,
                            'TODAS': AutumnColors.accentOrange
                          };
                          final col = colors[p] ?? AutumnColors.accentOrange;
                          return Expanded(
                              child: GestureDetector(
                                  onTap: () => notifier.setFilterPriority(p),
                                  child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 130),
                                      margin: const EdgeInsets.only(right: 5),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 7),
                                      decoration: BoxDecoration(
                                          color: sel ? col : c.bgSurface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: sel ? col : c.divider)),
                                      child: Text(
                                          p == 'TODAS'
                                              ? 'TODAS'
                                              : p.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.pressStart2p(
                                              fontSize: 6,
                                              color: sel
                                                  ? Colors.white
                                                  : c.textSecondary)))));
                        }).toList()),
                        const SizedBox(height: 10),
                        _fLabel(context, 'ESTADO'),
                        const SizedBox(height: 6),
                        Row(
                            children: [
                          {
                            'v': 'TODAS',
                            'l': 'TODAS',
                            'c': AutumnColors.accentOrange
                          },
                          {
                            'v': 'active',
                            'l': 'ACTIVAS',
                            'c': AutumnColors.mossGreen
                          },
                          {
                            'v': 'completed',
                            'l': 'COMPLETADAS',
                            'c': AutumnColors.accentGold
                          },
                        ].map((item) {
                          final v = item['v'] as String;
                          final l = item['l'] as String;
                          final col = item['c'] as Color;
                          final sel = state.fStatus == v;
                          return Expanded(
                              child: GestureDetector(
                                  onTap: () => notifier.setFilterStatus(v),
                                  child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 130),
                                      margin: const EdgeInsets.only(right: 5),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 7),
                                      decoration: BoxDecoration(
                                          color: sel ? col : c.bgSurface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: sel ? col : c.divider)),
                                      child: Text(l,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.pressStart2p(
                                              fontSize: 6,
                                              color: sel
                                                  ? Colors.white
                                                  : c.textSecondary)))));
                        }).toList()),
                        const SizedBox(height: 10),
                        _fLabel(context, 'CATEGORÍA'),
                        const SizedBox(height: 6),
                        Builder(builder: (_) {
                          final existingCats = state.allGoals
                              .map((g) => g.category ?? '')
                              .where((cat) => cat.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort();
                          if (existingCats.isEmpty) {
                            return Text('Sin categorías aún',
                                style: GoogleFonts.pressStart2p(
                                    fontSize: 7, color: c.textDisabled));
                          }
                          return Wrap(spacing: 5, runSpacing: 5, children: [
                            GestureDetector(
                                onTap: () => notifier.setFilterCategory(null),
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 130),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: state.fCategory == null
                                            ? AutumnColors.accentOrange
                                            : c.bgSurface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: state.fCategory == null
                                                ? AutumnColors.accentOrange
                                                : c.divider)),
                                    child: Text('TODAS',
                                        style: GoogleFonts.pressStart2p(
                                            fontSize: 7,
                                            color: state.fCategory == null
                                                ? Colors.white
                                                : c.textSecondary)))),
                            ...existingCats.map((cat) {
                              final sel = state.fCategory == cat;
                              final emoji = _categoryEmojiMap[cat] ?? '🏷️';
                              return GestureDetector(
                                  onTap: () => notifier
                                      .setFilterCategory(sel ? null : cat),
                                  child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 130),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: sel
                                              ? AutumnColors.accentOrange
                                              : c.bgSurface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: sel
                                                  ? AutumnColors.accentOrange
                                                  : c.divider)),
                                      child: Text('$emoji $cat',
                                          style: GoogleFonts.pressStart2p(
                                              fontSize: 7,
                                              color: sel
                                                  ? Colors.white
                                                  : c.textSecondary))));
                            }),
                          ]);
                        }),
                        const SizedBox(height: 10),
                        Divider(color: c.divider, height: 14),
                        _fLabel(context, 'ORDENAR POR'),
                        const SizedBox(height: 6),
                        Row(
                            children: [
                          {'v': 'FECHA', 'i': Icons.calendar_today_rounded},
                          {'v': 'PROGRESO', 'i': Icons.bar_chart_rounded},
                          {'v': 'CREACIÓN', 'i': Icons.history_rounded},
                        ].map((item) {
                          final v = item['v'] as String;
                          final ico = item['i'] as IconData;
                          final sel = state.fSort == v;
                          return Expanded(
                              child: GestureDetector(
                                  onTap: () => notifier.setFilterSort(v),
                                  child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 130),
                                      margin: const EdgeInsets.only(right: 5),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 9),
                                      decoration: BoxDecoration(
                                          color: sel
                                              ? AutumnColors.accentOrange
                                              : c.bgSurface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: sel
                                                  ? AutumnColors.accentOrange
                                                  : c.divider)),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(ico,
                                                size: 11,
                                                color: sel
                                                    ? Colors.white
                                                    : c.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(v,
                                                style: GoogleFonts.pressStart2p(
                                                    fontSize: 6,
                                                    color: sel
                                                        ? Colors.white
                                                        : c.textSecondary)),
                                          ]))));
                        }).toList()),
                      ]))
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.ac;
    final state = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: c.bgPrimary,
      appBar: AppBar(
        backgroundColor: c.bgCard,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('GOALS 🎯',
              style: GoogleFonts.pressStart2p(
                  fontSize: 14, color: AutumnColors.accentOrange)),
          Text('Toca una meta para ver sus objetivos',
              style:
                  GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AutumnColors.accentOrange, size: 26),
              tooltip: 'Nueva meta',
              onPressed: _openCreateGoalPopup),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(height: 2, color: AutumnColors.accentOrange)),
      ),
      body: state.isLoading && state.allGoals.isEmpty
          ? const Center(
              child:
                  CircularProgressIndicator(color: AutumnColors.accentOrange))
          : RefreshIndicator(
              onRefresh: () => ref.read(goalsProvider.notifier).load(),
              color: AutumnColors.accentOrange,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _buildFilterPanel(context, state),
                const SizedBox(height: 10),
                if (_message.isNotEmpty)
                  Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: _messageColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _messageColor.withOpacity(0.3))),
                      child: Text(_message,
                          style: GoogleFonts.pressStart2p(
                              fontSize: 9, color: _messageColor),
                          textAlign: TextAlign.center)),
                if (state.allGoals.isNotEmpty &&
                    state.filteredGoals.length != state.allGoals.length)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          'Mostrando ${state.filteredGoals.length} de ${state.allGoals.length} metas',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 7, color: c.textDisabled))),
                if (state.filteredGoals.isEmpty && state.allGoals.isEmpty)
                  PixelEmptyState(
                      type: EmptyStateType.goals,
                      onAction: _openCreateGoalPopup)
                else if (state.filteredGoals.isEmpty)
                  PixelEmptyState(
                      type: EmptyStateType.goals,
                      customTitle: 'SIN\nRESULTADOS',
                      customSubtitle: 'Intenta cambiar\nlos filtros.')
                else
                  ...state.filteredGoals.map(_buildGoalCard),
                const SizedBox(height: 16),
              ]),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ObjectivesDialog
// ══════════════════════════════════════════════════════════════════════════════

class _ObjectivesDialog extends StatefulWidget {
  final Goal goal;
  final String userId;
  final void Function(int total, int completed) onChanged;
  const _ObjectivesDialog(
      {required this.goal, required this.userId, required this.onChanged});
  @override
  State<_ObjectivesDialog> createState() => _ObjectivesDialogState();
}

class _ObjectivesDialogState extends State<_ObjectivesDialog> {
  final _db = SupabaseConfig.client;
  List<Objective> _objectives = [];
  bool _loaded = false;
  int _currentLevel = 1;

  int _calcLevel(int totalXp) {
    int level = 1;
    while (totalXp >= _xpForLevel(level + 1)) {
      level++;
      if (level >= 20) break;
    }
    return level;
  }

  int _xpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) total += 300 + i * 200;
    return total;
  }

  Future<void> _loadCurrentLevel() async {
    try {
      final profile = await _db
          .from('profiles')
          .select('total_xp')
          .eq('id', widget.userId)
          .single();
      final level = _calcLevel(profile['total_xp'] as int? ?? 0);
      if (mounted) setState(() => _currentLevel = level);
    } catch (e) {
      debugPrint('loadCurrentLevel error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadObjectives();
    _loadCurrentLevel();
  }

  Future<void> _loadObjectives() async {
    try {
      final rows = await _db
          .from('objectives')
          .select(
              'id, goal_id, title, deadline, status, type, habit_id, habits(name)')
          .eq('goal_id', widget.goal.id)
          .order('id', ascending: true);
      final parsed = (rows as List).map((r) {
        final hd = r['habits'] as Map<String, dynamic>?;
        return Objective.fromMap(
            {...Map<String, dynamic>.from(r), 'habit_name': hd?['name']});
      }).toList();
      if (mounted)
        setState(() {
          _objectives = parsed;
          _loaded = true;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _objectives = [];
          _loaded = true;
        });
    }
    _notifyParent();
  }

  void _notifyParent() => widget.onChanged(
      _objectives.length, _objectives.where((o) => o.isCompleted).length);

  Future<void> _toggleStatus(int objId, String newStatus) async {
    setState(() {
      final idx = _objectives.indexWhere((o) => o.id == objId);
      if (idx != -1)
        _objectives[idx] = _objectives[idx].copyWith(status: newStatus);
    });
    _notifyParent();
    try {
      await _db
          .from('objectives')
          .update({'status': newStatus}).eq('id', objId);
      if (newStatus == 'completed') {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final existing = await _db
            .from('xp_log')
            .select('id')
            .eq('source', 'objective_completed')
            .eq('source_id', objId)
            .eq('event_date', today)
            .maybeSingle();
        if (existing == null) {
          final profile = await _db
              .from('profiles')
              .select('total_xp')
              .eq('id', widget.userId)
              .single();
          final newXp =
              ((profile['total_xp'] as int? ?? 0) + 30).clamp(0, 999999);
          await _db
              .from('profiles')
              .update({'total_xp': newXp}).eq('id', widget.userId);
          await _db.from('xp_log').insert({
            'user_id': widget.userId,
            'amount': 30,
            'reason': 'Objetivo completado',
            'source': 'objective_completed',
            'source_id': objId,
            'event_date': today
          });
          if (mounted) XpToast.show(context, amount: 30);
          final profileAfter = await _db
              .from('profiles')
              .select('total_xp')
              .eq('id', widget.userId)
              .single();
          final levelAfter = _calcLevel(profileAfter['total_xp'] as int? ?? 0);
          if (levelAfter > _currentLevel && mounted) {
            _currentLevel = levelAfter;
            CelebrationOverlay.showLevelUp(context, levelAfter);
          }
        }
      }
    } catch (e) {
      await _loadObjectives();
    }
  }

  Future<void> _deleteObjective(int objId) async {
    setState(() => _objectives.removeWhere((o) => o.id == objId));
    _notifyParent();
    try {
      await _db.from('objectives').delete().eq('id', objId);
    } catch (e) {
      await _loadObjectives();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final total = _objectives.length;
    final done = _objectives.where((o) => o.isCompleted).length;
    final progress = total > 0 ? done / total : 0.0;

    return Dialog(
      backgroundColor: c.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.bgSurface,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.flag_rounded,
                          color: AutumnColors.accentOrange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(widget.goal.title.toUpperCase(),
                              style: GoogleFonts.pressStart2p(
                                  fontSize: 10,
                                  color: AutumnColors.accentOrange,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis)),
                      GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close,
                              color: c.textDisabled, size: 20)),
                    ]),
                    if (total > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PROGRESO',
                                style: GoogleFonts.pressStart2p(
                                    fontSize: 7, color: c.textDisabled)),
                            Text('$done/$total',
                                style: GoogleFonts.pressStart2p(
                                    fontSize: 7,
                                    color: AutumnColors.accentOrange)),
                          ]),
                      const SizedBox(height: 6),
                      Stack(children: [
                        Container(
                            height: 14,
                            decoration: BoxDecoration(
                                color: c.divider,
                                borderRadius: BorderRadius.circular(7))),
                        AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 400),
                            widthFactor: progress,
                            child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      AutumnColors.accentOrange,
                                      progress >= 1.0
                                          ? AutumnColors.mossGreen
                                          : AutumnColors.accentGold
                                    ]),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AutumnColors.accentOrange
                                              .withOpacity(0.4),
                                          blurRadius: 4)
                                    ]))),
                        if (progress > 0.15)
                          Positioned.fill(
                              child: Center(
                                  child: Text('${(progress * 100).round()}%',
                                      style: GoogleFonts.pressStart2p(
                                          fontSize: 7,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)))),
                      ]),
                      if (progress >= 1.0)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('🏆 ¡META COMPLETADA!',
                                style: GoogleFonts.pressStart2p(
                                    fontSize: 8,
                                    color: AutumnColors.mossGreen,
                                    fontWeight: FontWeight.bold))),
                    ],
                  ])),
          Expanded(
              child: !_loaded
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AutumnColors.accentOrange))
                  : _objectives.isEmpty
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.checklist_rounded,
                              size: 40, color: c.textDisabled),
                          const SizedBox(height: 12),
                          Text('Sin objetivos aún',
                              style: GoogleFonts.pressStart2p(
                                  fontSize: 9, color: c.textDisabled)),
                          const SizedBox(height: 4),
                          Text('Añade sub-misiones abajo',
                              style: GoogleFonts.pressStart2p(
                                  fontSize: 7, color: c.textDisabled)),
                        ]))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          itemCount: _objectives.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: c.divider, height: 8),
                          itemBuilder: (ctx, i) {
                            final obj = _objectives[i];
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: !obj.isHabit
                                        ? () => _toggleStatus(
                                            obj.id,
                                            obj.isCompleted
                                                ? 'pending'
                                                : 'completed')
                                        : null,
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                            color: obj.isCompleted
                                                ? AutumnColors.mossGreen
                                                : obj.isHabit
                                                    ? AutumnColors.accentGold
                                                        .withOpacity(0.15)
                                                    : c.bgSurface,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: obj.isCompleted
                                                    ? AutumnColors.mossGreen
                                                    : obj.isHabit
                                                        ? AutumnColors
                                                            .accentGold
                                                        : c.divider,
                                                width: 1.5)),
                                        child: Center(
                                            child: obj.isCompleted
                                                ? const Icon(Icons.check,
                                                    color: Colors.white,
                                                    size: 18)
                                                : obj.isHabit
                                                    ? const Icon(Icons.link,
                                                        color: AutumnColors
                                                            .accentGold,
                                                        size: 16)
                                                    : null)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        ObjectiveStrikeAnimation(
                                            text: obj.title,
                                            struck: obj.isCompleted,
                                            style: GoogleFonts.pressStart2p(
                                                fontSize: 9,
                                                color: obj.isCompleted
                                                    ? c.textDisabled
                                                    : c.textPrimary)),
                                        if (obj.isHabit &&
                                            obj.habitName != null)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 3),
                                              child: Row(children: [
                                                const Icon(Icons.link,
                                                    size: 10,
                                                    color: AutumnColors
                                                        .accentGold),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                    child: Text(
                                                        'Hábito: ${obj.habitName}',
                                                        style: GoogleFonts
                                                            .pressStart2p(
                                                                fontSize: 7,
                                                                color: AutumnColors
                                                                    .accentGold),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1)),
                                              ])),
                                        if ((obj.deadline ?? '').isNotEmpty)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 3),
                                              child: Row(children: [
                                                Icon(Icons.schedule,
                                                    size: 10,
                                                    color: c.textDisabled),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                    child: Text(obj.deadline!,
                                                        style: GoogleFonts
                                                            .pressStart2p(
                                                                fontSize: 7,
                                                                color: c
                                                                    .textDisabled),
                                                        overflow: TextOverflow
                                                            .ellipsis)),
                                              ])),
                                      ])),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: AutumnColors.accentRed,
                                          size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                      onPressed: () =>
                                          _deleteObjective(obj.id)),
                                ]);
                          })),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: c.bgSurface,
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16)),
                  border: Border(top: BorderSide(color: c.divider))),
              child: _AddObjectiveRow(
                  goalId: widget.goal.id,
                  userId: widget.userId,
                  onAdded: _loadObjectives)),
        ]),
      ),
    );
  }
}

// ── Add Objective Row ─────────────────────────────────────────────────────────

class _AddObjectiveRow extends StatefulWidget {
  final int goalId;
  final String userId;
  final VoidCallback onAdded;
  const _AddObjectiveRow(
      {required this.goalId, required this.userId, required this.onAdded});
  @override
  State<_AddObjectiveRow> createState() => _AddObjectiveRowState();
}

class _AddObjectiveRowState extends State<_AddObjectiveRow> {
  final _db = SupabaseConfig.client;
  final _titleCtrl = TextEditingController();
  DateTime? _deadline;
  int? _selectedHabitId;
  bool _linkHabit = false;
  List<Map<String, dynamic>> _habits = [];
  NotificationConfig _notifConfig = const NotificationConfig();

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    try {
      final h = await _db
          .from('habits')
          .select('id, name')
          .eq('user_id', widget.userId)
          .eq('active', true)
          .order('name');
      if (mounted) setState(() => _habits = List<Map<String, dynamic>>.from(h));
    } catch (_) {}
  }

  Future<void> _addObjective() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    try {
      final habitId = _linkHabit ? _selectedHabitId : null;
      final result = await _db
          .from('objectives')
          .insert({
            'goal_id': widget.goalId,
            'title': _titleCtrl.text.trim(),
            'description': '',
            'deadline': _deadline?.toIso8601String().substring(0, 10) ?? '',
            'type': habitId != null ? 'habit' : 'manual',
            'habit_id': habitId,
            'status': 'pending',
          })
          .select('id')
          .single();
      if (_notifConfig.enabled && _deadline != null) {
        try {
          await NotificationService().scheduleDeadlineNotifications(
              itemId: result['id'] as int,
              itemType: 'objective',
              title: _titleCtrl.text.trim(),
              deadline: _deadline!,
              config: _notifConfig.toConfigMap());
        } catch (_) {}
      }
      _titleCtrl.clear();
      setState(() {
        _deadline = null;
        _selectedHabitId = null;
        _linkHabit = false;
        _notifConfig = const NotificationConfig();
      });
      widget.onAdded();
    } catch (e) {
      debugPrint('addObjective error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: TextField(
                controller: _titleCtrl,
                style:
                    GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 9),
                decoration: InputDecoration(
                    hintText: 'Nuevo objetivo...',
                    hintStyle: GoogleFonts.pressStart2p(
                        fontSize: 8, color: c.textDisabled),
                    filled: true,
                    fillColor: c.bgCard,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: c.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AutumnColors.accentOrange)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10)))),
        const SizedBox(width: 8),
        SizedBox(
            width: 38,
            height: 38,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AutumnColors.accentOrange,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: _addObjective,
                child: const Icon(Icons.add, color: Colors.white, size: 20))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: GestureDetector(
          onTap: () async {
            final p = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                builder: (ctx, child) => Theme(
                    data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AutumnColors.accentOrange)),
                    child: child!));
            if (p != null) setState(() => _deadline = p);
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                  color: _deadline != null
                      ? AutumnColors.accentOrange.withOpacity(0.1)
                      : c.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _deadline != null
                          ? AutumnColors.accentOrange
                          : c.divider)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today,
                    size: 12,
                    color: _deadline != null
                        ? AutumnColors.accentOrange
                        : c.textDisabled),
                const SizedBox(width: 6),
                Text(
                    _deadline != null
                        ? DateFormat('dd/MM/yy').format(_deadline!)
                        : 'Sin fecha',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7,
                        color: _deadline != null
                            ? AutumnColors.accentOrange
                            : c.textDisabled)),
              ])),
        )),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() {
            _linkHabit = !_linkHabit;
            if (!_linkHabit) _selectedHabitId = null;
          }),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: _linkHabit
                      ? AutumnColors.accentGold.withOpacity(0.15)
                      : c.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _linkHabit ? AutumnColors.accentGold : c.divider)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link,
                    size: 14,
                    color:
                        _linkHabit ? AutumnColors.accentGold : c.textDisabled),
                const SizedBox(width: 6),
                Text('🔗 HÁBITO',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7,
                        color: _linkHabit
                            ? AutumnColors.accentGold
                            : c.textDisabled)),
              ])),
        ),
      ]),
      if (_linkHabit && _habits.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
                color: c.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AutumnColors.accentGold)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedHabitId,
                    hint: Text('Selecciona un hábito...',
                        style: GoogleFonts.pressStart2p(
                            fontSize: 8, color: c.textDisabled)),
                    dropdownColor: c.bgCard,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AutumnColors.accentGold),
                    items: _habits
                        .map((h) => DropdownMenuItem<int>(
                            value: h['id'] as int,
                            child: Row(children: [
                              const Icon(Icons.local_fire_department,
                                  size: 14, color: AutumnColors.accentGold),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(h['name'] as String? ?? '',
                                      style: GoogleFonts.pressStart2p(
                                          fontSize: 8, color: c.textPrimary),
                                      overflow: TextOverflow.ellipsis)),
                            ])))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedHabitId = v)))),
      ],
      if (_linkHabit && _habits.isEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('No tienes hábitos activos aún',
                style: GoogleFonts.pressStart2p(
                    fontSize: 7, color: c.textDisabled))),
      const SizedBox(height: 8),
      NotificationConfigWidget(
          config: _notifConfig,
          onChanged: (cfg) => setState(() => _notifConfig = cfg)),
    ]);
  }
}
