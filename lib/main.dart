import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/autumn_theme.dart';
import 'core/theme/language_provider.dart';
import 'core/supabase/supabase_client.dart';
import 'core/services/notification_service.dart';
import 'core/services/widget_service.dart';
import 'core/services/sentry_service.dart';
import 'core/services/analytics_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/auth/presentation/onboarding_screen.dart';
import 'main_shell.dart';
import 'features/auth/presentation/auth_notifier.dart';

bool kIsRecoveryFlow = false;

const _sentryDsn =
    'https://fa3674a0b82c7eaf8354e0054586bc40@o4510991988817920.ingest.us.sentry.io/4510991992291328';

Future<void> main() async {
  await SentryFlutter.init(
        (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.2;
      options.environment = 'production';
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env');
      await SupabaseConfig.initialize();
      await initializeDateFormatting('es', null);
      await NotificationService().init();
      await WidgetService.init();
      await AnalyticsService.init();

      runApp(
        const ProviderScope(
          child: LifeXPApp(),
        ),
      );
    },
  );
}

class LifeXPApp extends ConsumerStatefulWidget {
  const LifeXPApp({super.key});
  @override
  ConsumerState<LifeXPApp> createState() => _LifeXPAppState();
}

class _LifeXPAppState extends ConsumerState<LifeXPApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initNotificationTaps();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        kIsRecoveryFlow = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushReplacementNamed('/reset-password');
        });
      }
    });

    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) _handleLink(initialLink);

    _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    final fragment = uri.fragment;
    final params =
    Uri.splitQueryString(fragment.isNotEmpty ? fragment : uri.query);
    if (params['type'] == 'recovery') {
      _navigatorKey.currentState?.pushReplacementNamed('/reset-password');
    }
  }

  void _initNotificationTaps() {
    NotificationService().onNotificationTap.listen((payload) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _navigateToPayload(payload);
      });
    });
  }

  void _navigateToPayload(String payload) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final session = SupabaseConfig.client.auth.currentSession;

    if (session != null) {
      final userId = session.user.id;
      navigator.pushReplacementNamed('/$payload', arguments: userId);
    } else {
      NotificationDeepLink.pending = payload;
      navigator.pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final language  = ref.watch(languageProvider);
    final locale    = language == AppLanguage.en
        ? const Locale('en')
        : const Locale('es');

    return MaterialApp(
      title: 'LifeXP',
      debugShowCheckedModeBanner: false,
      theme: autumnTheme(),
      darkTheme: autumnThemeDark(),
      themeMode: themeMode,
      locale: locale,
      navigatorKey: _navigatorKey,
      navigatorObservers: [SentryNavigatorObserver()],

      // ── Localizations para flutter_quill ────────────────────────────────
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],

      initialRoute: '/',
      onGenerateRoute: (settings) {
        final args = settings.arguments;

        String userId   = '';
        String username = '';
        int    tab      = 0;

        if (args is Map) {
          userId   = (args['userId']   as String?) ?? '';
          username = (args['username'] as String?) ?? '';
          tab      = (args['tab']      as int?)    ?? 0;
        } else if (args is String) {
          userId = args;
        }

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const AuthGate());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/reset-password':
            return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());
          case '/onboarding':
            return MaterialPageRoute(
              builder: (_) => OnboardingScreen(
                userId: userId,
                initialUsername: username,
              ),
            );
          case '/home':
            return MaterialPageRoute(
                builder: (_) => MainShell(userId: userId, initialTab: 0));
          case '/goals':
            return MaterialPageRoute(
                builder: (_) => MainShell(userId: userId, initialTab: 1));
          case '/habits':
            return MaterialPageRoute(
                builder: (_) => MainShell(userId: userId, initialTab: 2));
          case '/todo':
            return MaterialPageRoute(
                builder: (_) => MainShell(userId: userId, initialTab: 3));
          case '/shell':
            return MaterialPageRoute(
                builder: (_) => MainShell(userId: userId, initialTab: tab));
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}

class NotificationDeepLink {
  static String? pending;

  static String? consume() {
    final route = pending;
    pending = null;
    return route;
  }
}