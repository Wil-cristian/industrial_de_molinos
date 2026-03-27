import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'data/datasources/supabase_datasource.dart';
import 'data/datasources/app_update_datasource.dart';
import 'presentation/widgets/update_dialog.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suprimir errores del framework Flutter en Windows desktop que causan cascada.
  // 1. _debugDuringDeviceUpdate: assertion de mouse_tracker cuando widgets con
  //    MouseRegion se reconstruyen durante procesamiento del mouse.
  // 2. Cascada: "RenderBox was not laid out" y "Cannot hit test" que siguen.
  // Solo ocurre en debug, no afecta release builds.
  if (kDebugMode) {
    final defaultOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exception.toString();
      // Suprimir assertion de mouse_tracker
      if (details.exception is AssertionError &&
          msg.contains('_debugDuringDeviceUpdate')) {
        return;
      }
      // Suprimir errores cascada de layout que se disparan por el mouse tracker bug
      if (msg.contains('RenderBox was not laid out') ||
          msg.contains('Cannot hit test a render box with no size') ||
          (details.exception is AssertionError &&
              msg.contains('child!.hasSize'))) {
        return;
      }
      defaultOnError?.call(details);
    };
  }

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

  runApp(const RestartWidget(child: ProviderScope(child: MolinosApp())));
}

Future<void> _testSupabaseConnection() async {
  try {
    final connected = await SupabaseDataSource.checkConnection();
    AppLogger.info('Conexión Supabase: ${connected ? "OK" : "FALLO"}');
  } catch (e) {
    AppLogger.error('Error verificando conexión Supabase', e);
  }
}

/// Wrapper that forces a full rebuild of the widget tree (including ProviderScope),
/// effectively performing a hot restart of the entire application state.
class RestartWidget extends StatefulWidget {
  final Widget child;
  const RestartWidget({super.key, required this.child});

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class MolinosApp extends StatefulWidget {
  const MolinosApp({super.key});

  @override
  State<MolinosApp> createState() => _MolinosAppState();
}

class _MolinosAppState extends State<MolinosApp> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    // Esperar a que la app este lista y el contexto disponible
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final release = await AppUpdateService.checkForUpdate();
    if (release != null && mounted) {
      final ctx = router.routerDelegate.navigatorKey.currentContext;
      if (ctx != null) {
        UpdateDialog.show(ctx, release);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
