import 'package:sentry_flutter/sentry_flutter.dart';

/// Wrapper para reportar errores y eventos a Sentry manualmente.
/// Úsalo en catch blocks de toda la app.
class SentryService {
  /// Reporta una excepción con su stack trace
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? hint,
  }) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: hint != null ? Hint.withMap({'message': hint}) : null,
    );
  }

  /// Registra un evento informativo (no es un error)
  static Future<void> captureMessage(String message) async {
    await Sentry.captureMessage(message);
  }

  /// Identifica al usuario en Sentry (llamar al hacer login)
  static Future<void> setUser(String userId, {String? email}) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: userId, email: email));
    });
  }

  /// Limpia el usuario al hacer logout
  static Future<void> clearUser() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Agrega contexto extra al próximo error capturado
  static Future<void> addBreadcrumb(String message, {String? category}) async {
    await Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category ?? 'app',
    ));
  }
}
