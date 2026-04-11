import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'stats_charts.dart';
import '../../../core/services/xp_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';
import '../../../core/theme/language_provider.dart';

// ── Strings ───────────────────────────────────────────────────────────────────

class _S {
  final AppLanguage lang;
  const _S(this.lang);
  bool get isEs => lang == AppLanguage.es;

  String get sectionXpHistory =>
      isEs ? '⚡  HISTORIAL XP' : '⚡  XP HISTORY';
  String get sectionAchievements => isEs ? '🏅  LOGROS' : '🏅  ACHIEVEMENTS';
  String get sectionStats => isEs ? '📊  ESTADÍSTICAS' : '📊  STATISTICS';
  String get sectionCharts => isEs ? '📈  GRÁFICAS' : '📈  CHARTS';
  String get sectionAppearance => isEs ? '🎨  APARIENCIA' : '🎨  APPEARANCE';
  String get sectionInfo => isEs ? 'ℹ️   INFORMACIÓN' : 'ℹ️   INFORMATION';
  String get sectionDanger =>
      isEs ? '⚠️   ZONA DE PELIGRO' : '⚠️   DANGER ZONE';

  String get theme => isEs ? 'TEMA' : 'THEME';
  String get themeLight => isEs ? 'CLARO' : 'LIGHT';
  String get themeDark => isEs ? 'OSCURO' : 'DARK';
  String get language => isEs ? 'IDIOMA' : 'LANGUAGE';

  String get resetXp => isEs ? 'RESETEAR XP Y NIVEL' : 'RESET XP & LEVEL';
  String get resetXpSub =>
      isEs ? 'Vuelve al nivel 1 con 0 XP' : 'Back to level 1 with 0 XP';
  String get deleteAccount => isEs ? 'BORRAR CUENTA' : 'DELETE ACCOUNT';
  String get deleteAccountSub => isEs
      ? 'Elimina tu cuenta permanentemente'
      : 'Permanently delete your account';
  String get danger => isEs ? 'ZONA DE PELIGRO' : 'DANGER ZONE';
  String get typeConfirm =>
      isEs ? 'Escribe CONFIRMAR para continuar' : 'Type CONFIRM to continue';

  String get version => isEs ? 'VERSIÓN' : 'VERSION';
  String get privacy => isEs ? 'POLÍTICA DE PRIVACIDAD' : 'PRIVACY POLICY';
  String get terms => isEs ? 'TÉRMINOS DE USO' : 'TERMS OF USE';
  String get licenses => isEs ? 'LICENCIAS' : 'LICENSES';
  String get contact => isEs ? 'CONTACTO Y SOPORTE' : 'CONTACT & SUPPORT';
  String get contactSub => isEs ? 'Escribinos por email' : 'Send us an email';
  String get rateApp => isEs ? 'CALIFICAR LA APP' : 'RATE THE APP';
  String get rateAppSub =>
      isEs ? 'Play Store / App Store' : 'Play Store / App Store';

  String get logout => isEs ? 'CERRAR SESIÓN' : 'LOG OUT';
  String get cancel => isEs ? 'CANCELAR' : 'CANCEL';
  String get confirm => isEs ? 'CONFIRMAR' : 'CONFIRM';
  String get logoutQ =>
      isEs ? '¿Seguro que quieres salir?' : 'Are you sure you want to log out?';
  String get logout2 => isEs ? 'SALIR' : 'LEAVE';
  String get loadingProfile =>
      isEs ? 'CARGANDO PERFIL...' : 'LOADING PROFILE...';
  String get noXpHistory =>
      isEs ? 'Todavia no hay movimientos de XP' : 'No XP activity yet';
  String get recentXpActivity =>
      isEs ? 'Ultimos movimientos registrados' : 'Latest recorded activity';

  String levelTitle(int l) {
    if (l >= 11) return isEs ? 'ÁRBOL LEGENDARIO' : 'LEGENDARY TREE';
    if (l >= 7) return isEs ? 'ÁRBOL MADURO' : 'MATURE TREE';
    if (l >= 3) return isEs ? 'ÁRBOL EN CRECIMIENTO' : 'GROWING TREE';
    return isEs ? 'ÁRBOL JOVEN' : 'YOUNG TREE';
  }
}

class _XpHistoryEntry {
  final int amount;
  final String reason;
  final String eventDate;

  const _XpHistoryEntry({
    required this.amount,
    required this.reason,
    required this.eventDate,
  });
}

// ── Main widget ───────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  final _db = SupabaseConfig.client;
  final _xpService = XpService();

  String _username = '';
  String _email = '';
  int _level = 1;
  int _totalXp = 0;
  int _currentXp = 0;
  int _xpForNext = 500;
  bool _loading = true;

  int _habitsCompleted = 0;
  int _goalsCompleted = 0;
  int _todosCompleted = 0;
  int _maxStreak = 0;
  int _totalDaysActive = 0;
  List<_XpHistoryEntry> _xpHistory = const [];

  late AnimationController _entryCtrl;
  late AnimationController _xpBarCtrl;
  late Animation<double> _xpBarAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _xpBarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _xpBarAnim =
        CurvedAnimation(parent: _xpBarCtrl, curve: Curves.easeOutCubic);
    _loadAll();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _xpBarCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadProfile(), _loadStats(), _loadXpHistory()]);
    if (mounted) {
      setState(() => _loading = false);
      _xpBarCtrl.forward();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _db
          .from('profiles')
          .select('username, email, total_xp')
          .eq('id', widget.userId)
          .single();
      final totalXp = profile['total_xp'] as int? ?? 0;
      final level = _calcLevel(totalXp);
      final xpForCurrent = _xpForLevel(level);
      final xpForNext = _xpForLevel(level + 1);
      final currentXp =
          (totalXp - xpForCurrent).clamp(0, xpForNext - xpForCurrent);
      if (mounted) {
        setState(() {
          _username = profile['username'] as String? ?? 'JUGADOR';
          _email = profile['email'] as String? ?? '';
          _totalXp = totalXp;
          _level = level;
          _currentXp = currentXp;
          _xpForNext = xpForNext - xpForCurrent;
        });
      }
    } catch (e) {
      debugPrint('loadProfile error: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        _db
            .from('habit_logs')
            .select('id')
            .eq('user_id', widget.userId)
            .eq('completed', true),
        _db
            .from('goals')
            .select('id')
            .eq('user_id', widget.userId)
            .eq('status', 'completed'),
        _db
            .from('todos')
            .select('id')
            .eq('user_id', widget.userId)
            .eq('status', 'done'),
        _db
            .from('habit_logs')
            .select('date')
            .eq('user_id', widget.userId)
            .eq('completed', true)
            .order('date'),
      ]);
      final habitLogs = results[0] as List;
      final goals = results[1] as List;
      final todos = results[2] as List;
      final streakLogs = results[3] as List;
      int maxStreak = 0, currentStreak = 0;
      DateTime? prev;
      final dates = streakLogs
          .map((l) => DateTime.tryParse(l['date'] as String? ?? ''))
          .whereType<DateTime>()
          .toSet()
          .toList()
        ..sort();
      for (final d in dates) {
        if (prev == null || d.difference(prev).inDays == 1) {
          currentStreak++;
        } else if (d.difference(prev).inDays > 1) {
          currentStreak = 1;
        }
        if (currentStreak > maxStreak) maxStreak = currentStreak;
        prev = d;
      }
      if (mounted) {
        setState(() {
          _habitsCompleted = habitLogs.length;
          _goalsCompleted = goals.length;
          _todosCompleted = todos.length;
          _maxStreak = maxStreak;
          _totalDaysActive = dates.length;
        });
      }
    } catch (e) {
      debugPrint('loadStats error: $e');
    }
  }

  Future<void> _loadXpHistory() async {
    try {
      final rows = await _db
          .from('xp_log')
          .select('amount, reason, event_date')
          .eq('user_id', widget.userId)
          .order('event_date', ascending: false)
          .limit(12);

      if (mounted) {
        setState(() {
          _xpHistory = (rows as List)
              .map(
                (row) => _XpHistoryEntry(
                  amount: row['amount'] as int? ?? 0,
                  reason: row['reason'] as String? ?? '',
                  eventDate: row['event_date'] as String? ?? '',
                ),
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('loadXpHistory error: $e');
    }
  }

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
    for (int i = 1; i < level; i++) {
      total += 300 + i * 200;
    }
    return total;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final c = context.ac;
    final s = _S(ref.read(languageProvider));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.logout.toUpperCase(),
            style: GoogleFonts.pressStart2p(
                fontSize: 10, color: AutumnColors.accentRed)),
        content: Text(s.logoutQ,
            style:
                GoogleFonts.pressStart2p(fontSize: 8, color: c.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel,
                  style: GoogleFonts.pressStart2p(
                      fontSize: 8, color: c.textDisabled))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.logout2,
                  style: GoogleFonts.pressStart2p(
                      fontSize: 8, color: AutumnColors.accentRed))),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    await SupabaseConfig.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user_id');
    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }

  // ── Danger zone ───────────────────────────────────────────────────────────

  Future<void> _resetXp() async {
    final s = _S(ref.read(languageProvider));
    final confirmed = await _showDangerDialog(
      title: s.resetXp,
      message: s.isEs
          ? 'Tu XP y nivel volverán a 0. Los hábitos, metas y tareas se mantienen.'
          : 'Your XP and level will return to 0. Habits, goals and tasks are kept.',
      confirmWord: s.isEs ? 'CONFIRMAR' : 'CONFIRM',
      color: AutumnColors.accentOrange,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await _xpService.resetXp(userId: widget.userId);
      setState(() {
        _totalXp = 0;
        _level = 1;
        _currentXp = 0;
        _xpForNext = 500;
      });
      _xpBarCtrl.reset();
      _xpBarCtrl.forward();
      HapticFeedback.heavyImpact();
      if (mounted) {
        _showSnack(
          s.isEs ? 'XP reseteado a 0' : 'XP reset to 0',
          AutumnColors.accentOrange,
        );
      }
    } catch (e) {
      debugPrint('resetXp error: $e');
    }
  }

  Future<void> _deleteAccount() async {
    final s = _S(ref.read(languageProvider));
    final confirmed = await _showDangerDialog(
      title: s.deleteAccount,
      message: s.isEs
          ? 'Esta acción es irreversible. Se eliminarán todos tus datos permanentemente.'
          : 'This action is irreversible. All your data will be permanently deleted.',
      confirmWord: s.isEs ? 'CONFIRMAR' : 'CONFIRM',
      color: AutumnColors.accentRed,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await _db.rpc('delete_my_account');
      await SupabaseConfig.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      if (mounted) {
        _showSnack(
          s.isEs
              ? 'Error al borrar cuenta. Verifica el RPC delete_my_account en Supabase.'
              : 'Error deleting account. Verify the delete_my_account RPC in Supabase.',
          AutumnColors.accentRed,
        );
      }
    }
  }

  Future<bool> _showDangerDialog({
    required String title,
    required String message,
    required String confirmWord,
    required Color color,
  }) async {
    final c = context.ac;
    final ctrl = TextEditingController();
    bool isValid = false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDlg) => AlertDialog(
              backgroundColor: c.bgCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: color.withValues(alpha: 0.5), width: 1.5)),
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                            '⚠️ ${_S(ref.read(languageProvider)).danger}',
                            style: GoogleFonts.pressStart2p(
                                fontSize: 8, color: color))),
                    const SizedBox(height: 10),
                    Text(title,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 9, color: c.textPrimary)),
                  ]),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 7, color: c.textSecondary, height: 1.8)),
                    const SizedBox(height: 16),
                    Text(_S(ref.read(languageProvider)).typeConfirm,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 6, color: c.textDisabled)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style:
                          GoogleFonts.pressStart2p(fontSize: 9, color: color),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: confirmWord,
                        hintStyle: GoogleFonts.pressStart2p(
                            fontSize: 9,
                            color: c.textDisabled.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: c.bgSurface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.divider)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: color, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => setDlg(() => isValid =
                          v.toUpperCase() == confirmWord.toUpperCase()),
                    ),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(_S(ref.read(languageProvider)).cancel,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 8, color: c.textDisabled))),
                AnimatedOpacity(
                  opacity: isValid ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
                    child: Text(_S(ref.read(languageProvider)).confirm,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 8, color: color)),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Info / Legal ──────────────────────────────────────────────────────────

  void _showLegalSheet(String title, String body) {
    final c = context.ac;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
              color: c.bgCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                  color: AutumnColors.accentOrange.withValues(alpha: 0.3))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: c.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(title,
                    style: GoogleFonts.pressStart2p(
                        fontSize: 10, color: AutumnColors.accentOrange))),
            const SizedBox(height: 4),
            Divider(color: c.divider),
            Expanded(
                child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Text(body,
                  style: GoogleFonts.pressStart2p(
                      fontSize: 7, color: c.textSecondary, height: 2.2)),
            )),
          ]),
        ),
      ),
    );
  }

  void _openPrivacy() {
    _openExternalLegalUrl(Uri(
      scheme: 'https',
      host: 'davidponcearauz.github.io',
      path: '/Lifexp/privacy-policy.html',
    ));
  }

  void _openTerms() {
    _openExternalLegalUrl(Uri(
      scheme: 'https',
      host: 'davidponcearauz.github.io',
      path: '/Lifexp/terms-of-use.html',
    ));
  }

  Future<void> _openExternalLegalUrl(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      final s = _S(ref.read(languageProvider));
      _showSnack(
        s.isEs
            ? 'No se pudo abrir la pagina legal.'
            : 'Could not open the legal page.',
        AutumnColors.accentRed,
      );
    }
  }

  void _openLicenses() {
    final s = _S(ref.read(languageProvider));
    _showLegalSheet(
        s.licenses,
        'flutter — BSD 3-Clause\nCopyright 2014 The Flutter Authors\n\n'
        'flutter_riverpod — MIT\nCopyright 2021 Remi Rousselet\n\n'
        'supabase_flutter — MIT\nCopyright 2021 Supabase Inc.\n\n'
        'google_fonts — Apache 2.0\nCopyright 2019 Google LLC\n\n'
        'shared_preferences — BSD 3-Clause\nCopyright 2017 The Chromium Authors\n\n'
        'flutter_local_notifications — BSD 3-Clause\nCopyright 2018 MichaelBui\n\n'
        'url_launcher — BSD 3-Clause\nCopyright 2017 The Chromium Authors\n\n'
        'fl_chart — MIT\nCopyright 2019 imaNNeo\n\n');
  }

  Future<void> _openContact() async {
    final uri = Uri(
        scheme: 'mailto',
        path: 'support@lifexp.app',
        query: 'subject=LifeXP Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse('https://apps.apple.com/app/idYOUR_APP_ID');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final lang = ref.watch(languageProvider);
    final s = _S(lang);

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: _loading
          ? _buildLoading(c, s)
          : CustomScrollView(slivers: [
              _buildAppBar(c),
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: _entryCtrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _entryCtrl,
                    child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _entryCtrl.value)),
                        child: child),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // XP Card — siempre visible
                          _buildXpCard(c, s),
                          const SizedBox(height: 10),

                          _buildSection(
                              c: c,
                              label: s.sectionXpHistory,
                              accent: AutumnColors.accentOrange,
                              child: _buildXpHistorySection(c, s),
                              initiallyExpanded: false),
                          const SizedBox(height: 8),

                          // Logros
                          _buildSection(
                              c: c,
                              label: s.sectionAchievements,
                              accent: AutumnColors.accentGold,
                              child: _buildBadgesGrid(c, s)),
                          const SizedBox(height: 8),

                          // Estadísticas
                          _buildSection(
                              c: c,
                              label: s.sectionStats,
                              accent: AutumnColors.accentOrange,
                              child: _buildStatsGrid(c, s)),
                          const SizedBox(height: 8),

                          // Gráficas
                          _buildSection(
                              c: c,
                              label: s.sectionCharts,
                              accent: AutumnColors.mossGreen,
                              child: StatsChartsSection(userId: widget.userId),
                              initiallyExpanded: false),
                          const SizedBox(height: 8),

                          // Apariencia
                          _buildSection(
                              c: c,
                              label: s.sectionAppearance,
                              accent: AutumnColors.accentGold,
                              child: _buildAppearanceContent(c, s)),
                          const SizedBox(height: 8),

                          // Información
                          _buildSection(
                              c: c,
                              label: s.sectionInfo,
                              accent: AutumnColors.mossGreen,
                              child: _buildInfoContent(c, s),
                              initiallyExpanded: false),
                          const SizedBox(height: 8),

                          // Zona de peligro
                          _buildSection(
                              c: c,
                              label: s.sectionDanger,
                              accent: AutumnColors.accentRed,
                              child: _buildDangerContent(c, s),
                              initiallyExpanded: false),
                          const SizedBox(height: 20),

                          // Logout
                          _buildLogoutButton(s),
                        ]),
                  ),
                ),
              ),
            ]),
    );
  }

  // ── Sección expandible ────────────────────────────────────────────────────

  Widget _buildSection({
    required dynamic c,
    required String label,
    required Color accent,
    required Widget child,
    bool initiallyExpanded = true,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.divider)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            iconColor: accent,
            collapsedIconColor: c.textDisabled,
            title: Row(children: [
              Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                      color: accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.pressStart2p(
                      fontSize: 8,
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold)),
            ]),
            children: [child],
          ),
        ),
      ),
    );
  }

  // ── Loading & AppBar ──────────────────────────────────────────────────────

  Widget _buildLoading(dynamic c, _S s) => Scaffold(
        backgroundColor: c.bgPrimary,
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AutumnColors.accentOrange),
          const SizedBox(height: 16),
          Text(s.loadingProfile,
              style:
                  GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled)),
        ])),
      );

  Widget _buildAppBar(dynamic c) => SliverAppBar(
        backgroundColor: c.bgCard,
        pinned: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AutumnColors.accentOrange, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AutumnColors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AutumnColors.accentOrange, width: 2)),
              child: Center(
                  child: Text(
                      _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 14, color: AutumnColors.accentOrange)))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(_username.toUpperCase(),
                    style: GoogleFonts.pressStart2p(
                        fontSize: 10, color: c.textPrimary),
                    overflow: TextOverflow.ellipsis),
                Text(_email,
                    style: GoogleFonts.pressStart2p(
                        fontSize: 6, color: c.textDisabled),
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(height: 2, color: AutumnColors.accentOrange)),
      );

  // ── XP Card ───────────────────────────────────────────────────────────────

  Widget _buildXpCard(dynamic c, _S s) {
    final xpPct =
        _xpForNext > 0 ? (_currentXp / _xpForNext).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AutumnColors.accentOrange.withValues(alpha: 0.5),
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: AutumnColors.accentOrange.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]),
      child: Column(children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AutumnColors.accentOrange,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('LVL $_level',
                  style: GoogleFonts.pressStart2p(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(s.levelTitle(_level),
                    style: GoogleFonts.pressStart2p(
                        fontSize: 8, color: AutumnColors.mossGreen)),
                const SizedBox(height: 3),
                Text('$_totalXp XP total',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7, color: c.textDisabled)),
              ])),
          _buildMiniTree(),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s.isEs ? 'PRÓXIMO NIVEL' : 'NEXT LEVEL',
              style:
                  GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled)),
          Text('$_currentXp / $_xpForNext XP',
              style: GoogleFonts.pressStart2p(
                  fontSize: 6, color: AutumnColors.accentOrange)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 16, color: c.bgSurface),
              AnimatedBuilder(
                  animation: _xpBarAnim,
                  builder: (_, __) => FractionallySizedBox(
                      widthFactor: xpPct * _xpBarAnim.value,
                      child: Container(
                          height: 16,
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                            AutumnColors.accentOrange,
                            AutumnColors.accentGold
                          ]))))),
              SizedBox(
                  height: 16,
                  child: Center(
                      child: Text('${(xpPct * 100).round()}%',
                          style: GoogleFonts.pressStart2p(
                              fontSize: 7,
                              color: xpPct > 0.3
                                  ? Colors.white
                                  : c.textDisabled)))),
            ])),
      ]),
    );
  }

  Widget _buildXpHistorySection(dynamic c, _S s) {
    if (_xpHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          s.noXpHistory,
          style: GoogleFonts.pressStart2p(
            fontSize: 7,
            color: c.textDisabled,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _xpHistory.map((entry) {
        final positive = entry.amount >= 0;
        final amountLabel = '${positive ? '+' : ''}${entry.amount} XP';
        final amountColor =
            positive ? AutumnColors.mossGreen : AutumnColors.accentRed;
        final icon = _xpHistoryIcon(entry.reason);
        final title = _xpHistoryTitle(entry.reason, s);

        return Column(
          children: [
            if (entry == _xpHistory.first)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  s.recentXpActivity,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 7,
                    color: c.textDisabled,
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.pressStart2p(
                            fontSize: 7,
                            color: c.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.eventDate,
                          style: GoogleFonts.pressStart2p(
                            fontSize: 6,
                            color: c.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    amountLabel,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _xpHistoryTitle(String reason, _S s) {
    final normalized = reason.toLowerCase();
    if (normalized.contains('habito') || normalized.contains('hábito')) {
      return s.isEs ? 'Habito completado' : 'Habit completed';
    }
    if (normalized.contains('meta vencida')) {
      return s.isEs ? 'Meta vencida' : 'Goal expired';
    }
    if (normalized.contains('objetivo de habito completado')) {
      return s.isEs ? 'Objetivo anclado completado' : 'Linked objective completed';
    }
    if (normalized.contains('objetivo de habito fallido')) {
      return s.isEs ? 'Objetivo anclado fallido' : 'Linked objective failed';
    }
    if (normalized.contains('objetivo completado')) {
      return s.isEs ? 'Objetivo completado' : 'Objective completed';
    }
    return reason;
  }

  String _xpHistoryIcon(String reason) {
    final normalized = reason.toLowerCase();
    if (normalized.contains('habito') || normalized.contains('hábito')) {
      return '✅';
    }
    if (normalized.contains('meta vencida')) {
      return '⏰';
    }
    if (normalized.contains('fallido')) {
      return '❌';
    }
    if (normalized.contains('objetivo')) {
      return '🎯';
    }
    return '⚡';
  }

  Widget _buildMiniTree() {
    final emoji = _level >= 11
        ? '🌳'
        : _level >= 7
            ? '🌲'
            : _level >= 3
                ? '🌿'
                : '🌱';
    return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: AutumnColors.mossGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AutumnColors.mossGreen.withValues(alpha: 0.3))),
        child:
            Center(child: Text(emoji, style: const TextStyle(fontSize: 24))));
  }

  // ── Badges ────────────────────────────────────────────────────────────────

  Widget _buildBadgesGrid(dynamic c, _S s) {
    final badges = _buildBadgeList(s);
    final unlocked = badges.where((b) => b.unlocked).length;
    return Column(children: [
      Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.divider)),
          child: Row(children: [
            Text('$unlocked / ${badges.length}',
                style: GoogleFonts.pressStart2p(
                    fontSize: 11,
                    color: AutumnColors.accentGold,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    s.isEs ? 'logros desbloqueados' : 'achievements unlocked',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7, color: c.textDisabled))),
            const Text('🏅', style: TextStyle(fontSize: 20)),
          ])),
      GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: badges.map((b) => _buildBadgeCard(c, b)).toList()),
    ]);
  }

  List<_Badge> _buildBadgeList(_S s) => [
        _Badge(
            '🔥',
            s.isEs ? 'INICIADO' : 'BEGINNER',
            s.isEs ? 'Completa 1 hábito' : 'Complete 1 habit',
            _habitsCompleted >= 1),
        _Badge(
            '⚡',
            s.isEs ? 'CONSTANTE' : 'CONSISTENT',
            s.isEs ? 'Completa 10 hábitos' : 'Complete 10 habits',
            _habitsCompleted >= 10),
        _Badge(
            '💪',
            s.isEs ? 'DISCIPLINADO' : 'DISCIPLINED',
            s.isEs ? 'Completa 50 hábitos' : 'Complete 50 habits',
            _habitsCompleted >= 50),
        _Badge(
            '🌟',
            s.isEs ? 'IMPARABLE' : 'UNSTOPPABLE',
            s.isEs ? 'Completa 100 hábitos' : 'Complete 100 habits',
            _habitsCompleted >= 100),
        _Badge(
            '🎯',
            s.isEs ? 'MISIONERO' : 'MISSION',
            s.isEs ? 'Completa 1 meta' : 'Complete 1 goal',
            _goalsCompleted >= 1),
        _Badge(
            '🏆',
            s.isEs ? 'CONQUISTADOR' : 'CONQUEROR',
            s.isEs ? 'Completa 5 metas' : 'Complete 5 goals',
            _goalsCompleted >= 5),
        _Badge(
            '📋',
            s.isEs ? 'ORDENADO' : 'ORGANIZED',
            s.isEs ? 'Completa 10 tareas' : 'Complete 10 tasks',
            _todosCompleted >= 10),
        _Badge(
            '✅',
            s.isEs ? 'PRODUCTIVO' : 'PRODUCTIVE',
            s.isEs ? 'Completa 50 tareas' : 'Complete 50 tasks',
            _todosCompleted >= 50),
        _Badge('🔄', s.isEs ? 'RACHA ×7' : 'STREAK ×7',
            s.isEs ? 'Racha de 7 días' : '7-day streak', _maxStreak >= 7),
        _Badge('📅', s.isEs ? 'RACHA ×30' : 'STREAK ×30',
            s.isEs ? 'Racha de 30 días' : '30-day streak', _maxStreak >= 30),
        _Badge('🌱', s.isEs ? 'EXPLORADOR' : 'EXPLORER',
            s.isEs ? 'Activo 7 días' : 'Active 7 days', _totalDaysActive >= 7),
        _Badge(
            '🌳',
            s.isEs ? 'VETERANO' : 'VETERAN',
            s.isEs ? 'Activo 30 días' : 'Active 30 days',
            _totalDaysActive >= 30),
      ];

  Widget _buildBadgeCard(dynamic c, _Badge b) {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: b.unlocked
                ? AutumnColors.accentGold.withValues(alpha: 0.1)
                : c.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: b.unlocked
                    ? AutumnColors.accentGold.withValues(alpha: 0.6)
                    : c.divider,
                width: b.unlocked ? 2 : 1),
            boxShadow: b.unlocked
                ? [
                    BoxShadow(
                        color: AutumnColors.accentGold.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : []),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ColorFiltered(
            colorFilter: b.unlocked
                ? const ColorFilter.mode(
                    Colors.transparent, BlendMode.saturation)
                : const ColorFilter.matrix([
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0.4,
                    0,
                  ]),
            child: Text(b.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 5),
          Text(b.name,
              style: GoogleFonts.pressStart2p(
                  fontSize: 6,
                  color: b.unlocked ? AutumnColors.accentGold : c.textDisabled,
                  fontWeight: b.unlocked ? FontWeight.bold : FontWeight.normal),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(b.description,
              style:
                  GoogleFonts.pressStart2p(fontSize: 5, color: c.textDisabled),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (b.unlocked) ...[
            const SizedBox(height: 4),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                    color: AutumnColors.accentGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4)),
                child: Text('✓ DONE',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 5, color: AutumnColors.accentGold))),
          ],
        ]));
  }

  // ── Stats Grid ────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(dynamic c, _S s) {
    final items = [
      (
        '🔥',
        '$_habitsCompleted',
        s.isEs ? 'HÁBITOS\nCOMPLETADOS' : 'HABITS\nCOMPLETED',
        AutumnColors.accentOrange
      ),
      (
        '🎯',
        '$_goalsCompleted',
        s.isEs ? 'METAS\nLOGRADAS' : 'GOALS\nACHIEVED',
        AutumnColors.accentGold
      ),
      (
        '✅',
        '$_todosCompleted',
        s.isEs ? 'TAREAS\nHECHAS' : 'TASKS\nDONE',
        AutumnColors.mossGreen
      ),
      (
        '⚡',
        '$_maxStreak',
        s.isEs ? 'RACHA\nMÁX.' : 'MAX\nSTREAK',
        AutumnColors.freeze
      ),
    ];
    return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
        children: items
            .map((st) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: st.$4.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: st.$4.withValues(alpha: 0.2))),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(st.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(st.$2,
                            style: GoogleFonts.pressStart2p(
                                fontSize: 13,
                                color: st.$4,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(st.$3,
                            style: GoogleFonts.pressStart2p(
                                fontSize: 5, color: c.textDisabled),
                            textAlign: TextAlign.center),
                      ]),
                ))
            .toList());
  }

  // ── Apariencia ────────────────────────────────────────────────────────────

  Widget _buildAppearanceContent(dynamic c, _S s) {
    final themeMode = ref.watch(themeModeProvider);
    final lang = ref.watch(languageProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Column(children: [
      // Tema toggle CLARO / OSCURO
      Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: AutumnColors.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                color: AutumnColors.accentGold,
                size: 17)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(s.theme,
                style: GoogleFonts.pressStart2p(
                    fontSize: 7, color: c.textPrimary))),
        // Toggle visual
        GestureDetector(
          onTap: () => ref
              .read(themeModeProvider.notifier)
              .setMode(isDark ? ThemeMode.light : ThemeMode.dark),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 110,
            height: 34,
            decoration: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AutumnColors.accentGold.withValues(alpha: 0.4))),
            child: Row(children: [
              Expanded(
                  child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color:
                        !isDark ? AutumnColors.accentGold : Colors.transparent,
                    borderRadius: BorderRadius.circular(7)),
                child: Center(
                    child: Text(s.themeLight,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 6,
                            color: !isDark ? Colors.white : c.textDisabled,
                            fontWeight: !isDark
                                ? FontWeight.bold
                                : FontWeight.normal))),
              )),
              Expanded(
                  child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color:
                        isDark ? AutumnColors.accentGold : Colors.transparent,
                    borderRadius: BorderRadius.circular(7)),
                child: Center(
                    child: Text(s.themeDark,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 6,
                            color: isDark ? Colors.white : c.textDisabled,
                            fontWeight:
                                isDark ? FontWeight.bold : FontWeight.normal))),
              )),
            ]),
          ),
        ),
      ]),

      Divider(height: 24, color: c.divider),

      // Idioma toggle ES / EN
      Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: AutumnColors.accentOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.language_rounded,
                color: AutumnColors.accentOrange, size: 17)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.language,
              style:
                  GoogleFonts.pressStart2p(fontSize: 7, color: c.textPrimary)),
          const SizedBox(height: 3),
          Text(lang == AppLanguage.es ? '🇪🇸 Español' : '🇺🇸 English',
              style:
                  GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled)),
        ])),
        GestureDetector(
          onTap: () {
            final next =
                lang == AppLanguage.es ? AppLanguage.en : AppLanguage.es;
            ref.read(languageProvider.notifier).setLanguage(next);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: AutumnColors.accentOrange,
                borderRadius: BorderRadius.circular(8)),
            child: Text(lang == AppLanguage.es ? 'ES  🇪🇸' : 'EN  🇺🇸',
                style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    ]);
  }

  // ── Info content ──────────────────────────────────────────────────────────

  Widget _buildInfoContent(dynamic c, _S s) {
    return Column(children: [
      _infoRow(c,
          icon: Icons.info_outline_rounded,
          iconColor: AutumnColors.mossGreen,
          title: s.version,
          subtitle: '1.0.0'),
      Divider(height: 1, color: c.divider),
      _infoRow(c,
          icon: Icons.shield_outlined,
          iconColor: AutumnColors.accentOrange,
          title: s.privacy,
          onTap: _openPrivacy),
      Divider(height: 1, color: c.divider),
      _infoRow(c,
          icon: Icons.gavel_rounded,
          iconColor: AutumnColors.accentOrange,
          title: s.terms,
          onTap: _openTerms),
      Divider(height: 1, color: c.divider),
      _infoRow(c,
          icon: Icons.code_rounded,
          iconColor: AutumnColors.mossGreen,
          title: s.licenses,
          onTap: _openLicenses),
      Divider(height: 1, color: c.divider),
      _infoRow(c,
          icon: Icons.mail_outline_rounded,
          iconColor: AutumnColors.accentGold,
          title: s.contact,
          subtitle: s.contactSub,
          onTap: _openContact),
      Divider(height: 1, color: c.divider),
      _infoRow(c,
          icon: Icons.star_outline_rounded,
          iconColor: AutumnColors.accentGold,
          title: s.rateApp,
          subtitle: s.rateAppSub,
          onTap: _rateApp),
    ]);
  }

  Widget _infoRow(
    dynamic c, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 16)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: GoogleFonts.pressStart2p(
                        fontSize: 7, color: c.textPrimary)),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: GoogleFonts.pressStart2p(
                          fontSize: 6, color: c.textDisabled)),
                ],
              ])),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textDisabled),
        ]),
      ),
    );
  }

  // ── Danger content ────────────────────────────────────────────────────────

  Widget _buildDangerContent(dynamic c, _S s) {
    return Column(children: [
      InkWell(
          onTap: _resetXp,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: AutumnColors.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.refresh_rounded,
                      color: AutumnColors.accentOrange, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.resetXp,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 7, color: AutumnColors.accentOrange)),
                    const SizedBox(height: 3),
                    Text(s.resetXpSub,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 6, color: c.textDisabled)),
                  ])),
              Icon(Icons.warning_amber_rounded,
                  color: AutumnColors.accentOrange.withValues(alpha: 0.7),
                  size: 18),
            ]),
          )),
      Divider(height: 1, color: AutumnColors.accentRed.withValues(alpha: 0.2)),
      InkWell(
          onTap: _deleteAccount,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: AutumnColors.accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: AutumnColors.accentRed, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.deleteAccount,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 7, color: AutumnColors.accentRed)),
                    const SizedBox(height: 3),
                    Text(s.deleteAccountSub,
                        style: GoogleFonts.pressStart2p(
                            fontSize: 6, color: c.textDisabled)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: AutumnColors.accentRed, size: 18),
            ]),
          )),
    ]);
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Widget _buildLogoutButton(_S s) {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: AutumnColors.accentRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AutumnColors.accentRed.withValues(alpha: 0.4),
                width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.logout_rounded,
              color: AutumnColors.accentRed, size: 16),
          const SizedBox(width: 10),
          Text(s.logout,
              style: GoogleFonts.pressStart2p(
                  fontSize: 9, color: AutumnColors.accentRed)),
        ]),
      ),
    );
  }
}

// ── Badge model ───────────────────────────────────────────────────────────────

class _Badge {
  final String emoji;
  final String name;
  final String description;
  final bool unlocked;
  const _Badge(this.emoji, this.name, this.description, this.unlocked);
}
