import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Constantes de la aplicación.
/// Las credenciales sensibles se leen del archivo .env
class AppConstants {
  static const String appName = 'Industrial de Molinos';
  static const String appVersion = '1.0.6';
  static const int appBuildNumber = 7;
  static const String appFullVersion = '$appVersion+$appBuildNumber';

  // Supabase — leídas de .env en tiempo de ejecución
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Base de datos local
  static const String dbName = 'molinos_app.db';
  static const int dbVersion = 1;

  // Configuración
  static const String defaultCurrency = 'USD';
  static const double defaultTaxRate = 0.0;

  // URLs de actualizacion
  static const String releasesBaseUrl = 'https://github.com';
}
