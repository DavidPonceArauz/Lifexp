import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/widgets/autumn_widgets.dart';
import '../../../core/widgets/notification_config_widget.dart';
import '../../../core/services/notification_service.dart';
import '../domain/todo.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../domain/todos_state.dart';
import 'providers/todos_provider.dart';
import '../../../core/widgets/rich_description_editor.dart';

class TodoScreen extends ConsumerStatefulWidget {
  final String userId;
  const TodoScreen({super.key, required this.userId});
  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const List<Map<String, String>> _categories = [
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

  bool _filtersOpen = false;
  static const _pColors = {3: AutumnColors.accentRed, 2: AutumnColors.accentGold, 1: AutumnColors.mossGreen};
  static const _pLabels = {3: 'ALTA', 2: 'MEDIA', 1: 'BAJA'};

  Map<String, dynamic> _deadlineInfo(String? deadline) {
    if (deadline == null || deadline.isEmpty) return {'text': '', 'color': AutumnColors.textDisabled};
    try {
      final d = DateFormat('yyyy-MM-dd').parse(deadline);
      final diff = d.difference(DateTime.now()).inDays;
      if (diff < 0)  return {'text': 'ATRASADA ${diff.abs()}d', 'color': AutumnColors.accentRed};
      if (diff == 0) return {'text': 'HOY',    'color': AutumnColors.accentRed};
      if (diff == 1) return {'text': 'MAÑANA', 'color': AutumnColors.accentGold};
      return {'text': 'En ${diff}d', 'color': AutumnColors.textDisabled};
    } catch (_) { return {'text': '', 'color': AutumnColors.textDisabled}; }
  }

  // ── CREATE / EDIT dialog ──────────────────────────────────────────────────

  void _openTodoDialog({Todo? todo}) {
    final c = context.ac;
    final isEdit = todo != null;
    final titleCtrl = TextEditingController(text: isEdit ? todo.title : '');
    String descJson = isEdit ? todo.description : '';
    String priority = isEdit ? (_pLabels[todo.priority] ?? 'MEDIA') : 'MEDIA';
    String? deadline = isEdit ? todo.deadline : null;
    NotificationConfig notifConfig = const NotificationConfig();
    String? selectedCategory = isEdit ? todo.category : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => Dialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(width: 400, height: 580, child: Column(children: [
          Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(color: c.bgSurface,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16), topRight: Radius.circular(16))),
              child: Row(children: [
                Icon(isEdit ? Icons.edit_rounded : Icons.add_task_rounded,
                    color: AutumnColors.accentOrange, size: 18),
                const SizedBox(width: 10),
                Text(isEdit ? 'EDITAR TAREA' : 'NUEVA TAREA',
                    style: GoogleFonts.pressStart2p(fontSize: 11, color: AutumnColors.accentOrange)),
              ])),
          Divider(height: 1, color: c.divider),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lbl(c, 'NOMBRE'),
                TextField(controller: titleCtrl,
                    style: GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 10),
                    decoration: _deco(c, 'Nombre de la tarea...')),
                const SizedBox(height: 14),
                _lbl(c, 'PRIORIDAD'),
                Row(children: ['ALTA', 'MEDIA', 'BAJA'].map((p) {
                  const pc = {'ALTA': AutumnColors.accentRed, 'MEDIA': AutumnColors.accentGold, 'BAJA': AutumnColors.mossGreen};
                  final sel = p == priority;
                  return Expanded(child: GestureDetector(
                      onTap: () => setDlg(() => priority = p),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(right: p != 'BAJA' ? 6 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: sel ? pc[p] : c.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? pc[p]! : c.divider)),
                          child: Text(p, textAlign: TextAlign.center,
                              style: GoogleFonts.pressStart2p(fontSize: 8,
                                  color: sel ? c.bgCard : c.textSecondary,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)))));
                }).toList()),
                const SizedBox(height: 14),
                _lbl(c, 'FECHA LIMITE'),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx,
                        initialDate: deadline != null
                            ? DateTime.tryParse(deadline!) ?? DateTime.now()
                            : DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        builder: (cx, w) => Theme(data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: AutumnColors.accentOrange,
                                onPrimary: Colors.white,
                                surface: AutumnColors.bgCard,
                                onSurface: AutumnColors.textPrimary)), child: w!));
                    if (picked != null) setDlg(() => deadline = DateFormat('yyyy-MM-dd').format(picked));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: c.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: deadline != null ? AutumnColors.accentOrange : c.divider,
                            width: deadline != null ? 1.5 : 1)),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 14,
                          color: deadline != null ? AutumnColors.accentOrange : c.textDisabled),
                      const SizedBox(width: 10),
                      Text(deadline ?? 'Sin fecha limite',
                          style: GoogleFonts.pressStart2p(fontSize: 9,
                              color: deadline != null ? c.textPrimary : c.textDisabled)),
                      const Spacer(),
                      if (deadline != null) GestureDetector(
                          onTap: () => setDlg(() => deadline = null),
                          child: Icon(Icons.close, size: 14, color: c.textDisabled)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                _lbl(c, 'CATEGORIA (opcional)'),
                _catAutocomplete(c,
                    selectedCategory: selectedCategory,
                    onSelected: (label) => setDlg(() => selectedCategory = label),
                    onCleared: () => setDlg(() => selectedCategory = null)),
                const SizedBox(height: 14),
                _lbl(c, 'DESCRIPCION (opcional)'),
                GestureDetector(
                  onTap: () async {
                    final result = await showRichEditorSheet(context,
                        initialJson: descJson,
                        title: titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Descripción',
                        accentColor: AutumnColors.accentOrange);
                    if (result != null) setDlg(() => descJson = result);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: c.bgSurface, borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: quillJsonToPlainText(descJson).isNotEmpty
                                ? AutumnColors.accentOrange : c.divider,
                            width: quillJsonToPlainText(descJson).isNotEmpty ? 1.5 : 1)),
                    child: Row(children: [
                      Icon(Icons.edit_note_rounded, size: 14,
                          color: quillJsonToPlainText(descJson).isNotEmpty
                              ? AutumnColors.accentOrange : c.textDisabled),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          quillJsonToPlainText(descJson).isNotEmpty
                              ? quillJsonToPlainText(descJson)
                              : 'Toca para añadir descripción...',
                          style: GoogleFonts.pressStart2p(fontSize: 8,
                              color: quillJsonToPlainText(descJson).isNotEmpty
                                  ? c.textPrimary : c.textDisabled),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                _lbl(c, 'RECORDATORIO (opcional)'),
                NotificationConfigWidget(config: notifConfig,
                    onChanged: (cfg) => setDlg(() => notifConfig = cfg)),
              ]))),
          Divider(height: 1, color: c.divider),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx),
                    child: Text('CANCELAR',
                        style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AutumnColors.accentOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    const pm = {'ALTA': 3, 'MEDIA': 2, 'BAJA': 1};
                    Navigator.pop(ctx);
                    int savedId;
                    if (isEdit) {
                      await ref.read(todosProvider.notifier).updateTodo(todo!.id,
                          title: titleCtrl.text, description: descJson,
                          priority: pm[priority] ?? 2, deadline: deadline,
                          category: selectedCategory);
                      savedId = todo.id;
                    } else {
                      savedId = await ref.read(todosProvider.notifier).createTodo(
                          title: titleCtrl.text, description: descJson,
                          priority: pm[priority] ?? 2, deadline: deadline,
                          category: selectedCategory);
                    }
                    final ns = NotificationService();
                    if (notifConfig.enabled && deadline != null && savedId > 0) {
                      try {
                        await ns.scheduleDeadlineNotifications(
                            itemId: savedId, itemType: 'todo',
                            title: titleCtrl.text.trim(),
                            deadline: DateTime.parse(deadline!),
                            config: notifConfig.toConfigMap());
                      } catch (_) {}
                    } else if (savedId > 0) {
                      await ns.cancelItemNotifications(itemId: savedId, itemType: 'todo');
                    }
                  },
                  child: Text(isEdit ? 'GUARDAR' : 'CREAR',
                      style: GoogleFonts.pressStart2p(fontSize: 9, color: c.bgCard)),
                ),
              ])),
        ])),
      )),
    );
  }

  // ── DETAIL dialog ─────────────────────────────────────────────────────────

  void _openDetailDialog(Todo todo) {
    final c = context.ac;
    final di = _deadlineInfo(todo.deadline);
    const statusLabels = {
      'pending': 'PENDIENTE', 'in_progress': 'EN PROCESO', 'done': 'HECHA'
    };
    const statusColors = {
      'pending': AutumnColors.accentOrange,
      'in_progress': AutumnColors.accentGold,
      'done': AutumnColors.mossGreen,
    };

    // Controller Quill para el detail — interactivo con checklist
    final quillCtrl = QuillController(
      document: quillDocumentFromJson(todo.description),
      selection: const TextSelection.collapsed(offset: 0),
    );
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(width: double.infinity, padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: (_pColors[todo.priority] ?? AutumnColors.accentOrange).withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    border: Border(bottom: BorderSide(
                        color: (_pColors[todo.priority] ?? AutumnColors.accentOrange).withOpacity(0.3)))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: _pColors[todo.priority] ?? AutumnColors.accentOrange,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(_pLabels[todo.priority] ?? '',
                            style: GoogleFonts.pressStart2p(fontSize: 7, color: c.bgCard))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: (statusColors[todo.status] ?? AutumnColors.accentOrange).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: (statusColors[todo.status] ?? AutumnColors.accentOrange).withOpacity(0.5))),
                        child: Text(statusLabels[todo.status] ?? todo.status,
                            style: GoogleFonts.pressStart2p(fontSize: 7,
                                color: statusColors[todo.status] ?? AutumnColors.accentOrange))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        // Guardar cambios del editor al cerrar
                        final newJson = quillDeltaToJson(quillCtrl.document);
                        if (newJson != todo.description) {
                          ref.read(todosProvider.notifier).updateTodo(
                            todo.id,
                            title: todo.title,
                            description: newJson,
                            priority: todo.priority,
                            deadline: todo.deadline,
                            category: todo.category,
                          );
                        }
                        quillCtrl.dispose();
                        focusNode.dispose();
                        Navigator.pop(ctx);
                      },
                      child: Icon(Icons.close, color: c.textDisabled, size: 20),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(todo.title.toUpperCase(),
                      style: GoogleFonts.pressStart2p(
                          fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.bold)),
                ])),
            // ── Descripción interactiva ──────────────────────────────────────
            if (todo.description.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Text('DESCRIPCION',
                    style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: c.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.divider),
                ),
                child: QuillEditor(
                  controller: quillCtrl,
                  focusNode: focusNode,
                  scrollController: ScrollController(),
                  config: QuillEditorConfig(
                    scrollable: true,
                    autoFocus: false,
                    expands: false,
                    padding: const EdgeInsets.all(12),
                    placeholder: '',
                  ),
                ),
              ),
            ],
            // ── Fecha y metadata ─────────────────────────────────────────────
            Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('FECHA LIMITE',
                          style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: di['color'] as Color),
                        const SizedBox(width: 6),
                        Text(todo.deadline ?? 'Sin fecha',
                            style: GoogleFonts.pressStart2p(fontSize: 9, color: di['color'] as Color)),
                      ]),
                    ])),
                    if ((di['text'] as String).isNotEmpty && todo.status != 'done')
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: (di['color'] as Color).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: (di['color'] as Color).withOpacity(0.4))),
                          child: Text(di['text'] as String,
                              style: GoogleFonts.pressStart2p(fontSize: 8, color: di['color'] as Color))),
                  ]),
                  if (todo.createdAt.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('CREADA', style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                    const SizedBox(height: 4),
                    Text(todo.createdAt.substring(0, 10),
                        style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled)),
                  ],
                ])),
            Divider(height: 1, color: c.divider),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AutumnColors.accentOrange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () {
                        quillCtrl.dispose();
                        focusNode.dispose();
                        Navigator.pop(ctx);
                        _openTodoDialog(todo: todo);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 14, color: AutumnColors.accentOrange),
                      label: Text('EDITAR',
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.accentOrange)))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AutumnColors.accentRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () async {
                        quillCtrl.dispose();
                        focusNode.dispose();
                        Navigator.pop(ctx);
                        await NotificationService()
                            .cancelItemNotifications(itemId: todo.id, itemType: 'todo');
                        await ref.read(todosProvider.notifier).deleteTodo(todo.id);
                      },
                      icon: const Icon(Icons.delete_outline, size: 14, color: Colors.white),
                      label: Text('ELIMINAR',
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)))),
                ])),
          ]),
        ),
      ),
    );
  }

  // ── KANBAN COLUMN ─────────────────────────────────────────────────────────

  Widget _buildColumn(BuildContext context, String title, String status,
      Color color, List<Todo> items) {
    final c = context.ac;
    return Expanded(child: DragTarget<Todo>(
      onAcceptWithDetails: (details) =>
          ref.read(todosProvider.notifier).moveStatus(details.data.id, status),
      builder: (ctx, candidateData, _) {
        final hl = candidateData.isNotEmpty;
        return AnimatedContainer(duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
              color: hl ? color.withOpacity(0.12) : c.bgCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: hl ? color : color.withOpacity(0.35),
                  width: hl ? 2 : 1.5)),
          child: Column(children: [
            Container(width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(title,
                          style: GoogleFonts.pressStart2p(fontSize: 7, color: color),
                          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: Text('${items.length}',
                              style: GoogleFonts.pressStart2p(fontSize: 6, color: color))),
                    ])),
            Expanded(child: items.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 40, height: 40, child: CustomPaint(painter: _EmptyBoxPainter(color: color))),
              const SizedBox(height: 8),
              Text('vacio', style: GoogleFonts.pressStart2p(fontSize: 7, color: color.withOpacity(0.35))),
            ]))
                : ListView.separated(
                padding: const EdgeInsets.all(6),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _buildTodoCard(context, items[i], color))),
          ]),
        );
      },
    ));
  }

  // ── TODO CARD ─────────────────────────────────────────────────────────────

  Widget _buildTodoCard(BuildContext context, Todo todo, Color accentColor) {
    final c = context.ac;
    final di = _deadlineInfo(todo.deadline);
    return Dismissible(
      key: ValueKey('todo_${todo.id}_${todo.status}'),
      background: Container(alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(color: AutumnColors.accentRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AutumnColors.accentRed.withOpacity(0.4))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.delete_outline, color: AutumnColors.accentRed, size: 20),
            const SizedBox(height: 2),
            Text('ELIMINAR', style: GoogleFonts.pressStart2p(fontSize: 6, color: AutumnColors.accentRed)),
          ])),
      secondaryBackground: Container(alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(color: AutumnColors.accentOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AutumnColors.accentOrange.withOpacity(0.4))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.edit_rounded, color: AutumnColors.accentOrange, size: 20),
            const SizedBox(height: 2),
            Text('EDITAR', style: GoogleFonts.pressStart2p(fontSize: 6, color: AutumnColors.accentOrange)),
          ])),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          return await showDialog<bool>(context: context,
              builder: (ctx) => AlertDialog(backgroundColor: c.bgCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text('ELIMINAR',
                      style: GoogleFonts.pressStart2p(fontSize: 11, color: AutumnColors.accentRed)),
                  content: Text(todo.title,
                      style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false),
                        child: Text('CANCELAR',
                            style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textDisabled))),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AutumnColors.accentRed),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('ELIMINAR',
                            style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.white))),
                  ]));
        } else {
          _openTodoDialog(todo: todo);
          return false;
        }
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await NotificationService().cancelItemNotifications(itemId: todo.id, itemType: 'todo');
          await ref.read(todosProvider.notifier).deleteTodo(todo.id);
        }
      },
      child: Draggable<Todo>(
        data: todo,
        feedback: Material(color: Colors.transparent,
            child: SizedBox(width: 120,
                child: Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentColor, width: 2),
                        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 8)]),
                    child: Text(todo.title.toUpperCase(),
                        style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textPrimary),
                        maxLines: 2, overflow: TextOverflow.ellipsis)))),
        childWhenDragging: Opacity(opacity: 0.3, child: _cardContent(context, todo, di)),
        child: GestureDetector(onTap: () => _openDetailDialog(todo),
            child: _cardContent(context, todo, di)),
      ),
    );
  }

  Widget _cardContent(BuildContext context, Todo todo, Map<String, dynamic> di) {
    final c = context.ac;
    final pColor = _pColors[todo.priority] ?? AutumnColors.accentOrange;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.bgCard, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 3, height: 36, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: pColor, borderRadius: BorderRadius.circular(2))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(todo.title.toUpperCase(),
                style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textPrimary, fontWeight: FontWeight.bold),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: pColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(_pLabels[todo.priority] ?? '',
                      style: GoogleFonts.pressStart2p(fontSize: 6, color: pColor),
                      maxLines: 1, overflow: TextOverflow.ellipsis))),
              if ((todo.category ?? '').isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: AutumnColors.accentGold.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Tooltip(message: todo.category ?? '',
                        child: Text(
                            _categories.firstWhere((cat) => cat['label'] == todo.category,
                                orElse: () => {'emoji': '📁', 'label': ''})['emoji']!,
                            style: const TextStyle(fontSize: 10)))),
              ],
            ]),
          ])),
        ]),
        if (todo.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(quillJsonToPlainText(todo.description),
              style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if ((di['text'] as String).isNotEmpty && todo.status != 'done') ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.schedule, size: 10, color: di['color'] as Color),
            const SizedBox(width: 4),
            Flexible(child: Text(di['text'] as String,
                style: GoogleFonts.pressStart2p(fontSize: 7, color: di['color'] as Color),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ]),
    );
  }

  // ── FILTER PANEL ──────────────────────────────────────────────────────────

  Widget _buildFilterPanel(BuildContext context, TodosState state) {
    final c = context.ac;
    final af = (state.filterPriority != 'TODAS' ? 1 : 0) +
        (state.filterCategory != null ? 1 : 0) +
        (state.filterSort != 'FECHA' ? 1 : 0);
    final cats = state.todos.map((t) => t.category)
        .where((cat) => cat != null && cat.isNotEmpty)
        .cast<String>().toSet().toList()..sort();

    return Container(
      decoration: BoxDecoration(color: c.bgCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: af > 0 ? AutumnColors.accentOrange.withOpacity(0.5) : c.divider)),
      child: Column(children: [
        GestureDetector(
            onTap: () => setState(() => _filtersOpen = !_filtersOpen),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.filter_list_rounded, size: 16, color: AutumnColors.accentOrange),
                  const SizedBox(width: 8),
                  Text('FILTROS', style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.accentOrange)),
                  if (af > 0) ...[
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AutumnColors.accentOrange, borderRadius: BorderRadius.circular(10)),
                        child: Text('$af', style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white))),
                  ],
                  const Spacer(),
                  if (af > 0) GestureDetector(
                      onTap: () { setState(() => _filtersOpen = false); ref.read(todosProvider.notifier).clearFilters(); },
                      child: Text('LIMPIAR', style: GoogleFonts.pressStart2p(fontSize: 7, color: AutumnColors.accentRed))),
                  const SizedBox(width: 8),
                  Icon(_filtersOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: c.textDisabled),
                ]))),
        AnimatedSize(duration: const Duration(milliseconds: 220), curve: Curves.easeInOut,
          child: _filtersOpen
              ? Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Divider(color: c.divider, height: 14),
                Text('PRIORIDAD', style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                const SizedBox(height: 6),
                Row(children: ['TODAS', 'ALTA', 'MEDIA', 'BAJA'].map((o) {
                  final sel = o == state.filterPriority;
                  const pc = {'ALTA': AutumnColors.accentRed, 'MEDIA': AutumnColors.accentGold,
                    'BAJA': AutumnColors.mossGreen, 'TODAS': AutumnColors.accentOrange};
                  final col = pc[o] ?? AutumnColors.accentOrange;
                  return Expanded(child: GestureDetector(
                      onTap: () => ref.read(todosProvider.notifier).setFilterPriority(o),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(color: sel ? col : c.bgSurface,
                              borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? col : c.divider)),
                          child: Text(o, textAlign: TextAlign.center,
                              style: GoogleFonts.pressStart2p(fontSize: 7,
                                  color: sel ? c.bgCard : c.textSecondary,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)))));
                }).toList()),
                const SizedBox(height: 10),
                Text('ORDENAR POR', style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                const SizedBox(height: 6),
                Row(children: [
                  {'v': 'FECHA', 'i': Icons.calendar_today_rounded},
                  {'v': 'PRIORIDAD', 'i': Icons.flag_rounded},
                ].map((item) {
                  final v = item['v'] as String; final ico = item['i'] as IconData;
                  final sel = state.filterSort == v;
                  return Expanded(child: GestureDetector(
                      onTap: () => ref.read(todosProvider.notifier).setFilterSort(v),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                              color: sel ? AutumnColors.accentOrange : c.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? AutumnColors.accentOrange : c.divider)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(ico, size: 11, color: sel ? c.bgCard : c.textSecondary),
                            const SizedBox(width: 5),
                            Text(v, style: GoogleFonts.pressStart2p(fontSize: 7,
                                color: sel ? c.bgCard : c.textSecondary,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          ]))));
                }).toList()),
                if (cats.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('CATEGORIA', style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    GestureDetector(
                        onTap: () => ref.read(todosProvider.notifier).setFilterCategory(null),
                        child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: state.filterCategory == null ? AutumnColors.accentOrange : c.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: state.filterCategory == null ? AutumnColors.accentOrange : c.divider)),
                            child: Text('TODAS', style: GoogleFonts.pressStart2p(fontSize: 7,
                                color: state.filterCategory == null ? Colors.white : c.textSecondary)))),
                    ...cats.map((cat) {
                      final sel = state.filterCategory == cat;
                      final emoji = _categories.firstWhere((cx) => cx['label'] == cat,
                          orElse: () => {'emoji': '📁', 'label': ''})['emoji']!;
                      return GestureDetector(
                          onTap: () => ref.read(todosProvider.notifier).setFilterCategory(sel ? null : cat),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 130),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                  color: sel ? AutumnColors.accentOrange : c.bgSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: sel ? AutumnColors.accentOrange : c.divider)),
                              child: Text('$emoji $cat', style: GoogleFonts.pressStart2p(fontSize: 7,
                                  color: sel ? Colors.white : c.textSecondary))));
                    }),
                  ]),
                ],
              ]))
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  // ── Category autocomplete ─────────────────────────────────────────────────

  Widget _catAutocomplete(dynamic c, {
    required String? selectedCategory,
    required void Function(String) onSelected,
    required void Function() onCleared,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (tv) {
        final q = tv.text.toLowerCase();
        if (q.isEmpty) return _categories.map((cat) => '${cat["emoji"]} ${cat["label"]}');
        return _categories.where((cat) => cat['label']!.toLowerCase().contains(q))
            .map((cat) => '${cat["emoji"]} ${cat["label"]}');
      },
      onSelected: (val) => onSelected(val.substring(val.indexOf(' ') + 1)),
      fieldViewBuilder: (ctx2, ctrl2, fn, _) => TextField(
          controller: ctrl2, focusNode: fn,
          onChanged: (v) { if (v.isEmpty) onCleared(); },
          style: GoogleFonts.pressStart2p(color: c.textPrimary, fontSize: 9),
          decoration: InputDecoration(
              hintText: 'Escribe para buscar categoria...',
              hintStyle: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled),
              prefixIcon: selectedCategory != null
                  ? Padding(padding: const EdgeInsets.all(10), child: Text(
                  _categories.firstWhere((cat) => cat['label'] == selectedCategory,
                      orElse: () => {'emoji': '📁', 'label': ''})['emoji']!,
                  style: const TextStyle(fontSize: 16)))
                  : Icon(Icons.folder_outlined, size: 16, color: c.textDisabled),
              suffixIcon: selectedCategory != null
                  ? const Icon(Icons.check_circle, size: 16, color: AutumnColors.accentOrange) : null,
              filled: true, fillColor: c.bgSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.divider)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AutumnColors.accentOrange, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
      optionsViewBuilder: (ctx2, onSel, options) => Align(alignment: Alignment.topLeft,
          child: Material(elevation: 6, borderRadius: BorderRadius.circular(10), color: c.bgCard,
              child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final opt = options.elementAt(i);
                        return InkWell(onTap: () => onSel(opt),
                            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Text(opt, style: GoogleFonts.pressStart2p(fontSize: 9, color: c.textPrimary))));
                      })))),
    );
  }

  Widget _lbl(dynamic c, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)));

  InputDecoration _deco(dynamic c, String hint) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled),
      filled: true, fillColor: c.bgSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AutumnColors.accentOrange, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c     = context.ac;
    final state = ref.watch(todosProvider);
    return Scaffold(
      backgroundColor: c.bgPrimary,
      appBar: AppBar(
        backgroundColor: c.bgCard, elevation: 0, automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SIDE QUESTS', style: GoogleFonts.pressStart2p(fontSize: 13, color: AutumnColors.accentOrange)),
          Text('Arrastra - Desliza - Toca', style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AutumnColors.accentOrange, size: 24),
              tooltip: 'Nueva tarea', onPressed: () => _openTodoDialog()),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2),
            child: Container(height: 2, color: AutumnColors.accentOrange)),
      ),
      body: state.isLoading && state.todos.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AutumnColors.accentOrange))
          : Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _buildFilterPanel(context, state)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.swipe, size: 9, color: c.textDisabled), const SizedBox(width: 3),
              Text('Editar', style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled)),
              const SizedBox(width: 8),
              Icon(Icons.touch_app, size: 9, color: c.textDisabled), const SizedBox(width: 3),
              Text('Ver detalle', style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled)),
              const SizedBox(width: 8),
              Icon(Icons.open_with, size: 9, color: c.textDisabled), const SizedBox(width: 3),
              Text('Mover', style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled)),
            ])),
        Expanded(child: state.todos.isEmpty
            ? PixelEmptyState(type: EmptyStateType.todos, onAction: () => _openTodoDialog())
            : Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              _buildColumn(context, 'PEND.', 'pending', AutumnColors.accentOrange, state.pending),
              const SizedBox(width: 6),
              _buildColumn(context, 'PROC.', 'in_progress', AutumnColors.accentGold, state.inProgress),
              const SizedBox(width: 6),
              _buildColumn(context, 'HECHO', 'done', AutumnColors.mossGreen, state.done),
            ]))),
      ]),
    );
  }
}

class _EmptyBoxPainter extends CustomPainter {
  final Color color;
  const _EmptyBoxPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s  = size.width / 8;
    final p  = Paint()..color = color.withOpacity(0.35);
    final pl = Paint()..color = color.withOpacity(0.15);
    for (int i = 0; i < 8; i++) {
      canvas.drawRect(Rect.fromLTWH(i * s, 0, s, s), p);
      canvas.drawRect(Rect.fromLTWH(i * s, 7 * s, s, s), p);
      canvas.drawRect(Rect.fromLTWH(0, i * s, s, s), p);
      canvas.drawRect(Rect.fromLTWH(7 * s, i * s, s, s), p);
    }
    for (int r = 1; r < 7; r++) {
      for (int col = 1; col < 7; col++) {
        canvas.drawRect(Rect.fromLTWH(col * s, r * s, s, s), pl);
      }
    }
    final pp = Paint()..color = color.withOpacity(0.5);
    canvas.drawRect(Rect.fromLTWH(3 * s, 2 * s, s, 4 * s), pp);
    canvas.drawRect(Rect.fromLTWH(2 * s, 3 * s, 4 * s, s), pp);
  }
  @override
  bool shouldRepaint(_EmptyBoxPainter old) => old.color != color;
}