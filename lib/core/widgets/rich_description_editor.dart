import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/autumn_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 📝 RICH DESCRIPTION EDITOR — flutter_quill ^11.5.0
// ═══════════════════════════════════════════════════════════════════════════

// ── Serialización ───────────────────────────────────────────────────────────

String quillDeltaToJson(Document doc) =>
    jsonEncode(doc.toDelta().toJson());

Document quillDocumentFromJson(String? raw) {
  if (raw == null || raw.isEmpty) return Document();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return Document.fromJson(decoded);
  } catch (_) {}
  if (raw.isNotEmpty) {
    try { return Document()..insert(0, raw); } catch (_) {}
  }
  return Document();
}

String quillJsonToPlainText(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try { return quillDocumentFromJson(raw).toPlainText().trim(); }
  catch (_) { return raw; }
}

// ── Bottom sheet helper ─────────────────────────────────────────────────────

Future<String?> showRichEditorSheet(
    BuildContext context, {
      required String initialJson,
      required String title,
      required Color accentColor,
    }) async {
  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RichEditorSheet(
      initialJson: initialJson,
      title: title,
      accentColor: accentColor,
    ),
  );
}

// ── Bottom sheet ────────────────────────────────────────────────────────────

class _RichEditorSheet extends StatefulWidget {
  final String initialJson;
  final String title;
  final Color accentColor;
  const _RichEditorSheet({
    required this.initialJson,
    required this.title,
    required this.accentColor,
  });
  @override
  State<_RichEditorSheet> createState() => _RichEditorSheetState();
}

class _RichEditorSheetState extends State<_RichEditorSheet> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: quillDocumentFromJson(widget.initialJson),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: widget.accentColor.withValues(alpha:0.3)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.edit_note_rounded, color: widget.accentColor, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.title,
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: widget.accentColor),
                    overflow: TextOverflow.ellipsis)),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('CANCELAR',
                      style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => Navigator.pop(context, quillDeltaToJson(_controller.document)),
                  child: Text('GUARDAR',
                      style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Divider(color: c.divider, height: 1),
            // Toolbar — API v11.5.0: parámetros directos sin configurations
            Container(
              color: c.bgSurface,
              child: QuillSimpleToolbar(
                controller: _controller,
                config: QuillSimpleToolbarConfig(
                  showDividers: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: false,
                  showInlineCode: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showClearFormat: true,
                  showAlignmentButtons: true,
                  showLeftAlignment: true,
                  showCenterAlignment: true,
                  showRightAlignment: true,
                  showJustifyAlignment: false,
                  showHeaderStyle: false,
                  showListNumbers: true,
                  showListBullets: true,
                  showListCheck: true,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showLink: false,
                  showUndo: true,
                  showRedo: true,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                ),
              ),
            ),
            Divider(color: c.divider, height: 1),
            // Editor — API v11.5.0
            Expanded(
              child: QuillEditor(
                controller: _controller,
                focusNode: _focusNode,
                scrollController: scrollCtrl,
                config: QuillEditorConfig(
                  scrollable: true,
                  autoFocus: true,
                  expands: false,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  placeholder: 'Escribe tu descripción aquí...',
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Viewer solo lectura ─────────────────────────────────────────────────────

class RichDescriptionViewer extends StatelessWidget {
  final String descriptionJson;
  final Color accentColor;
  final int? maxLines;

  const RichDescriptionViewer({
    super.key,
    required this.descriptionJson,
    this.accentColor = AutumnColors.accentOrange,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final plain = quillJsonToPlainText(descriptionJson);
    if (plain.isEmpty) return const SizedBox.shrink();
    return Text(plain,
        style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textSecondary, height: 1.6),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null);
  }
}