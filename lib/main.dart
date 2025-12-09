import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'data/datasources/supabase_datasource.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar formatos de fecha
  await initializeDateFormatting('es_ES', null);
  
  // Inicializar Supabase
  await SupabaseDataSource.initialize();
  
  runApp(const ProviderScope(child: MolinosApp()));
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
