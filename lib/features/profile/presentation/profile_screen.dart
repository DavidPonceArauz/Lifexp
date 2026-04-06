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
      if (mounted)
        setState(() {
          _username = profile['username'] as String? ?? 'JUGADOR';
          _email = profile['email'] as String? ?? '';
          _totalXp = totalXp;
          _level = level;
          _currentXp = currentXp;
          _xpForNext = xpForNext - xpForCurrent;
        });
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
      if (mounted)
        setState(() {
          _habitsCompleted = habitLogs.length;
          _goalsCompleted = goals.length;
          _todosCompleted = todos.length;
          _maxStreak = maxStreak;
          _totalDaysActive = dates.length;
        });
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
    for (int i = 1; i < level; i++) total += 300 + i * 200;
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
    if (confirm != true || !mounted) return;
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
    if (!confirmed || !mounted) return;
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
      if (mounted)
        _showSnack(s.isEs ? 'XP reseteado a 0' : 'XP reset to 0',
            AutumnColors.accentOrange);
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
    if (!confirmed || !mounted) return;
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
    final s = _S(ref.read(languageProvider));
    _showLegalSheet(
        s.privacy,
        s.isEs
            ? 'POLITICA DE PRIVACIDAD\n\n'
                'Ultima actualizacion: 6 de abril de 2026\n\n'
                '1. QUIENES SOMOS\n'
                'LifeXP es una aplicacion de productividad y seguimiento personal orientada a habitos, metas, tareas, progreso y estadisticas. Si tienes preguntas sobre esta politica, puedes escribir a support@lifexp.app.\n\n'
                '2. DATOS QUE RECOPILAMOS\n'
                'Podemos recopilar y tratar las siguientes categorias de datos:\n'
                '- Datos de cuenta: correo electronico, identificador de usuario y nombre de usuario.\n'
                '- Contenido generado por ti: habitos, registros de habitos, metas, objetivos, tareas, eventos de calendario, descripciones y ajustes dentro de la app.\n'
                '- Datos de progreso: XP, nivel, rachas, historial de XP, estadisticas y logros generados a partir de tu uso.\n'
                '- Datos tecnicos y de diagnostico: informacion basica del dispositivo, eventos de errores y fallos, y datos de uso anonimizados o seudonimizados para analitica y mejora del servicio.\n'
                '- Datos de notificaciones: permisos concedidos y programacion de recordatorios locales.\n\n'
                '3. COMO OBTENEMOS LOS DATOS\n'
                'Obtenemos los datos directamente de ti cuando creas una cuenta, completas habitos, registras metas o tareas, editas tu perfil, activas notificaciones o utilizas funciones de la aplicacion.\n\n'
                '4. PARA QUE USAMOS LOS DATOS\n'
                'Usamos tus datos para:\n'
                '- Crear y administrar tu cuenta.\n'
                '- Guardar y sincronizar tu informacion entre dispositivos.\n'
                '- Mostrar progreso, estadisticas, graficas, nivel, XP, rachas y widgets.\n'
                '- Enviar o programar recordatorios y notificaciones solicitadas por ti.\n'
                '- Detectar errores, prevenir abuso y mejorar estabilidad, rendimiento y experiencia de usuario.\n'
                '- Analizar el uso general de la app para priorizar mejoras de producto.\n\n'
                '5. BASES DEL TRATAMIENTO\n'
                'Tratamos tus datos para ejecutar el servicio que solicitas al usar LifeXP, cumplir nuestras obligaciones legales cuando aplique, proteger la seguridad de la plataforma y, en algunos casos, por interes legitimo para analitica tecnica y mejora del producto.\n\n'
                '6. SERVICIOS DE TERCEROS\n'
                'LifeXP utiliza proveedores externos para operar el servicio, entre ellos:\n'
                '- Supabase, para autenticacion, base de datos y almacenamiento de informacion de cuenta y contenido.\n'
                '- Sentry, para registro y monitoreo de errores y fallos.\n'
                '- PostHog, para analitica de uso del producto.\n'
                'Estos proveedores procesan datos segun nuestras instrucciones o sus propias condiciones y politicas de privacidad aplicables.\n\n'
                '7. NO VENDEMOS TUS DATOS\n'
                'No vendemos tus datos personales. Tampoco compartimos tus datos con terceros para publicidad conductual de terceros.\n\n'
                '8. CONSERVACION DE LOS DATOS\n'
                'Conservamos tu informacion mientras tu cuenta este activa o mientras sea necesario para prestarte el servicio, resolver disputas, cumplir obligaciones legales, hacer cumplir nuestros acuerdos y mantener registros tecnicos razonables de seguridad e integridad.\n\n'
                '9. ELIMINACION DE CUENTA Y DATOS\n'
                'Puedes solicitar la eliminacion permanente de tu cuenta desde la propia app. Al confirmar esta accion, eliminaremos la informacion asociada a tu cuenta de acuerdo con el flujo tecnico disponible en LifeXP, salvo datos que debamos conservar por obligaciones legales, seguridad o prevencion de fraude.\n\n'
                '10. TUS DERECHOS\n'
                'Segun tu jurisdiccion, puedes tener derecho a acceder, corregir, actualizar, eliminar o limitar el tratamiento de tus datos personales. Tambien puedes solicitar informacion sobre el tratamiento escribiendo a support@lifexp.app.\n\n'
                '11. SEGURIDAD\n'
                'Aplicamos medidas tecnicas y organizativas razonables para proteger tus datos. Sin embargo, ningun sistema es completamente infalible y no podemos garantizar seguridad absoluta.\n\n'
                '12. MENORES DE EDAD\n'
                'LifeXP no esta dirigida a menores de 13 anos, ni a una edad superior si asi lo exige la ley local. Si detectamos que se ha recopilado informacion personal de un menor sin autorizacion valida, podremos eliminarla.\n\n'
                '13. TRANSFERENCIAS INTERNACIONALES\n'
                'Tus datos pueden tratarse en paises distintos al tuyo cuando nuestros proveedores operen infraestructura internacional. En esos casos procuramos utilizar salvaguardas razonables y proveedores reconocidos.\n\n'
                '14. CAMBIOS A ESTA POLITICA\n'
                'Podemos actualizar esta politica ocasionalmente. Cuando los cambios sean relevantes, publicaremos la version actualizada en la app y, cuando corresponda, te lo notificaremos por medios razonables.\n\n'
                '15. CONTACTO\n'
                'Para soporte, consultas de privacidad o ejercicio de derechos: support@lifexp.app'
            : 'PRIVACY POLICY\n\n'
                'Last updated: April 6, 2026\n\n'
                '1. WHO WE ARE\n'
                'LifeXP is a productivity and personal tracking app focused on habits, goals, tasks, progress, and statistics. If you have questions about this policy, you can contact us at support@lifexp.app.\n\n'
                '2. DATA WE COLLECT\n'
                'We may collect and process the following categories of data:\n'
                '- Account data: email address, user identifier, and username.\n'
                '- User-generated content: habits, habit logs, goals, objectives, tasks, calendar events, descriptions, and in-app settings.\n'
                '- Progress data: XP, level, streaks, XP history, statistics, and achievements generated from your use.\n'
                '- Technical and diagnostics data: basic device information, crash and error events, and anonymized or pseudonymized usage data for analytics and product improvement.\n'
                '- Notification data: granted permissions and locally scheduled reminders.\n\n'
                '3. HOW WE COLLECT DATA\n'
                'We collect data directly from you when you create an account, complete habits, create goals or tasks, edit your profile, enable notifications, or otherwise use the app.\n\n'
                '4. HOW WE USE DATA\n'
                'We use your data to:\n'
                '- Create and manage your account.\n'
                '- Store and sync your information across devices.\n'
                '- Display progress, statistics, charts, level, XP, streaks, and widgets.\n'
                '- Send or schedule reminders and notifications requested by you.\n'
                '- Detect errors, prevent abuse, and improve stability, performance, and user experience.\n'
                '- Analyze general product usage in order to prioritize improvements.\n\n'
                '5. LEGAL BASIS\n'
                'We process your data to provide the service you request when using LifeXP, to comply with legal obligations where applicable, to protect platform security, and in some cases for legitimate interests related to technical analytics and product improvement.\n\n'
                '6. THIRD-PARTY SERVICES\n'
                'LifeXP uses third-party providers to operate the service, including:\n'
                '- Supabase, for authentication, database, and account/content storage.\n'
                '- Sentry, for crash and error monitoring.\n'
                '- PostHog, for product analytics.\n'
                'These providers process data under our instructions or under their own applicable terms and privacy policies.\n\n'
                '7. WE DO NOT SELL YOUR DATA\n'
                'We do not sell your personal data. We also do not share your data for third-party behavioral advertising.\n\n'
                '8. DATA RETENTION\n'
                'We retain your information while your account is active or as needed to provide the service, resolve disputes, comply with legal obligations, enforce our agreements, and maintain reasonable technical records for security and integrity.\n\n'
                '9. ACCOUNT AND DATA DELETION\n'
                'You can request permanent deletion of your account from within the app. Once confirmed, we will delete the information associated with your account according to the technical deletion flow available in LifeXP, except for data we must retain for legal, security, or fraud-prevention purposes.\n\n'
                '10. YOUR RIGHTS\n'
                'Depending on your jurisdiction, you may have the right to access, correct, update, delete, or restrict the processing of your personal data. You may also request information about our processing by contacting support@lifexp.app.\n\n'
                '11. SECURITY\n'
                'We apply reasonable technical and organizational measures to protect your data. However, no system is completely secure, and we cannot guarantee absolute security.\n\n'
                '12. CHILDREN\n'
                'LifeXP is not directed to children under 13, or any higher age required by local law. If we learn that personal data from a child has been collected without valid authorization, we may delete it.\n\n'
                '13. INTERNATIONAL TRANSFERS\n'
                'Your data may be processed in countries other than your own when our providers operate international infrastructure. In those cases, we seek to rely on reasonable safeguards and recognized providers.\n\n'
                '14. CHANGES TO THIS POLICY\n'
                'We may update this policy from time to time. When changes are material, we will publish the updated version in the app and, where appropriate, notify you through reasonable means.\n\n'
                '15. CONTACT\n'
                'For support, privacy questions, or rights requests: support@lifexp.app');
  }

  void _openTerms() {
    final s = _S(ref.read(languageProvider));
    _showLegalSheet(
        s.terms,
        s.isEs
            ? 'TERMINOS DE USO\n\n'
                'Ultima actualizacion: 6 de abril de 2026\n\n'
                '1. ACEPTACION\n'
                'Al crear una cuenta, acceder o usar LifeXP, aceptas estos Terminos de Uso. Si no estas de acuerdo, no debes utilizar la aplicacion.\n\n'
                '2. SERVICIO\n'
                'LifeXP ofrece herramientas de organizacion personal, seguimiento de habitos, metas, tareas, progreso, recordatorios y estadisticas. Podemos modificar, mejorar, suspender o eliminar funciones en cualquier momento.\n\n'
                '3. ELEGIBILIDAD Y USO PERSONAL\n'
                'Debes tener capacidad legal suficiente para aceptar estos terminos segun la ley aplicable. La app esta destinada a uso personal y no comercial, salvo autorizacion expresa por escrito.\n\n'
                '4. CUENTA Y SEGURIDAD\n'
                'Eres responsable de la actividad realizada desde tu cuenta y de mantener la confidencialidad de tus credenciales. Debes proporcionarnos informacion razonablemente precisa y actualizada.\n\n'
                '5. CONDUCTA PROHIBIDA\n'
                'No puedes usar LifeXP para:\n'
                '- Violaciones de ley o derechos de terceros.\n'
                '- Intentos de acceso no autorizado, interferencia, scraping, abuso tecnico o fraude.\n'
                '- Distribuir malware, contenido danino o material que vulnere derechos de propiedad intelectual o privacidad.\n'
                '- Usar la app de forma que perjudique la estabilidad, seguridad o disponibilidad del servicio.\n\n'
                '6. TU CONTENIDO\n'
                'Conservas la titularidad sobre el contenido que ingresas en LifeXP. Nos otorgas una licencia limitada, no exclusiva y necesaria para alojar, procesar, sincronizar, mostrar y operar ese contenido con el fin de prestarte el servicio.\n\n'
                '7. PROPIEDAD INTELECTUAL DE LIFEXP\n'
                'La aplicacion, su marca, interfaz, diseno, codigo, logica de producto, textos, graficos y demas elementos, salvo contenido tuyo y componentes de terceros, pertenecen a LifeXP o a sus licenciantes y estan protegidos por la normativa aplicable.\n\n'
                '8. FEEDBACK\n'
                'Si nos envias sugerencias, comentarios o ideas, podremos usarlos para mejorar LifeXP sin obligacion de compensacion, salvo que la ley disponga lo contrario.\n\n'
                '9. DISPONIBILIDAD Y CAMBIOS\n'
                'No garantizamos que la app estara disponible en todo momento ni libre de errores. Podemos realizar mantenimiento, actualizaciones o cambios tecnicos que afecten temporalmente el servicio.\n\n'
                '10. NOTIFICACIONES Y RECORDATORIOS\n'
                'Si activas recordatorios o notificaciones, autorizas su uso en tu dispositivo conforme a los permisos que concedas. La recepcion efectiva puede depender del sistema operativo, configuraciones del dispositivo o servicios de terceros.\n\n'
                '11. DESCARGO DE RESPONSABILIDAD\n'
                'LifeXP se proporciona en la medida permitida por la ley "tal cual" y "segun disponibilidad", sin garantias expresas o implicitas de disponibilidad continua, exactitud absoluta, aptitud para un proposito particular o ausencia total de errores.\n\n'
                '12. LIMITACION DE RESPONSABILIDAD\n'
                'En la medida permitida por la ley, LifeXP y sus responsables no seran responsables por danos indirectos, incidentales, especiales, consecuentes o perdida de datos, ingresos, beneficios o reputacion derivados del uso o imposibilidad de uso de la app.\n\n'
                '13. TERMINACION\n'
                'Podemos suspender o cerrar cuentas que infrinjan estos terminos, la ley aplicable o la seguridad del servicio. Tambien puedes dejar de usar la app o eliminar tu cuenta en cualquier momento desde las opciones disponibles.\n\n'
                '14. PRIVACIDAD\n'
                'El uso de la app tambien esta regulado por nuestra Politica de Privacidad, que forma parte complementaria de estos terminos.\n\n'
                '15. CAMBIOS A LOS TERMINOS\n'
                'Podemos actualizar estos terminos ocasionalmente. Cuando los cambios sean relevantes, publicaremos la version actualizada en la app y, cuando corresponda, te lo notificaremos por medios razonables.\n\n'
                '16. LEY APLICABLE\n'
                'Estos terminos se interpretaran conforme a la ley aplicable determinada por el proveedor del servicio y las normas imperativas de proteccion al consumidor que correspondan en tu jurisdiccion.\n\n'
                '17. CONTACTO\n'
                'Para soporte o consultas legales: support@lifexp.app'
            : 'TERMS OF USE\n\n'
                'Last updated: April 6, 2026\n\n'
                '1. ACCEPTANCE\n'
                'By creating an account, accessing, or using LifeXP, you agree to these Terms of Use. If you do not agree, you must not use the app.\n\n'
                '2. SERVICE\n'
                'LifeXP provides personal organization, habit tracking, goal tracking, task management, progress, reminder, and statistics features. We may modify, improve, suspend, or remove features at any time.\n\n'
                '3. ELIGIBILITY AND PERSONAL USE\n'
                'You must have sufficient legal capacity to accept these terms under applicable law. The app is intended for personal, non-commercial use unless expressly authorized in writing.\n\n'
                '4. ACCOUNT AND SECURITY\n'
                'You are responsible for activity under your account and for keeping your credentials confidential. You must provide reasonably accurate and updated information.\n\n'
                '5. PROHIBITED CONDUCT\n'
                'You may not use LifeXP for:\n'
                '- Violating any law or third-party rights.\n'
                '- Attempting unauthorized access, interference, scraping, technical abuse, or fraud.\n'
                '- Distributing malware, harmful material, or content that infringes intellectual property or privacy rights.\n'
                '- Using the app in a way that harms the stability, security, or availability of the service.\n\n'
                '6. YOUR CONTENT\n'
                'You retain ownership of the content you submit to LifeXP. You grant us a limited, non-exclusive license necessary to host, process, sync, display, and operate that content for the purpose of providing the service.\n\n'
                '7. LIFEXP INTELLECTUAL PROPERTY\n'
                'The app, its brand, interface, design, code, product logic, text, graphics, and other elements, excluding your content and third-party components, belong to LifeXP or its licensors and are protected by applicable law.\n\n'
                '8. FEEDBACK\n'
                'If you send us suggestions, comments, or ideas, we may use them to improve LifeXP without obligation to compensate you, except where required by law.\n\n'
                '9. AVAILABILITY AND CHANGES\n'
                'We do not guarantee that the app will always be available or error-free. We may perform maintenance, updates, or technical changes that temporarily affect the service.\n\n'
                '10. NOTIFICATIONS AND REMINDERS\n'
                'If you enable reminders or notifications, you authorize their use on your device according to the permissions you grant. Actual delivery may depend on the operating system, device settings, or third-party services.\n\n'
                '11. DISCLAIMER\n'
                'To the maximum extent permitted by law, LifeXP is provided "as is" and "as available", without warranties of continuous availability, absolute accuracy, fitness for a particular purpose, or complete absence of errors.\n\n'
                '12. LIMITATION OF LIABILITY\n'
                'To the maximum extent permitted by law, LifeXP and its operators will not be liable for indirect, incidental, special, consequential damages, or loss of data, revenue, profits, or reputation arising from the use of, or inability to use, the app.\n\n'
                '13. TERMINATION\n'
                'We may suspend or terminate accounts that violate these terms, applicable law, or service security. You may also stop using the app or delete your account at any time using the available options.\n\n'
                '14. PRIVACY\n'
                'Use of the app is also governed by our Privacy Policy, which forms a complementary part of these terms.\n\n'
                '15. CHANGES TO THE TERMS\n'
                'We may update these terms from time to time. When changes are material, we will publish the updated version in the app and, where appropriate, notify you through reasonable means.\n\n'
                '16. GOVERNING LAW\n'
                'These terms will be interpreted under the applicable law determined by the service provider and by any mandatory consumer protection rules that apply in your jurisdiction.\n\n'
                '17. CONTACT\n'
                'For support or legal inquiries: support@lifexp.app');
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
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse('https://apps.apple.com/app/idYOUR_APP_ID');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                      color: (st.$4 as Color).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: (st.$4 as Color).withValues(alpha: 0.2))),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(st.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(st.$2,
                            style: GoogleFonts.pressStart2p(
                                fontSize: 13,
                                color: st.$4 as Color,
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
