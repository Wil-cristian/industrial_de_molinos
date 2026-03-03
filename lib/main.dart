import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'data/datasources/supabase_datasource.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  // Inicializar formatos de fecha (Colombia)
  await initializeDateFormatting('es_CO', null);
  await initializeDateFormatting('es_ES', null);

  // Inicializar Supabase
  await SupabaseDataSource.initialize();

  // Test de conexión solo en modo debug
  if (kDebugMode) {
    await _testSupabaseConnection();
  }

  runApp(const ProviderScope(child: MolinosApp()));
}

Future<void> _testSupabaseConnection() async {
  try {
    final connected = await SupabaseDataSource.checkConnection();
    AppLogger.info('Conexión Supabase: ${connected ? "OK" : "FALLO"}');
  } catch (e) {
    AppLogger.error('Error verificando conexión Supabase', e);
  }
}

class MolinosApp extends StatelessWidget {
  const MolinosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
