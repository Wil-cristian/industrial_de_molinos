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
  
  // TEST: Verificar conexión a las tablas nuevas
  await _testSupabaseConnection();
  
  runApp(const ProviderScope(child: MolinosApp()));
}

Future<void> _testSupabaseConnection() async {
  final client = SupabaseDataSource.client;
  
  print('🔍 ===== TEST DE CONEXIÓN SUPABASE =====');
  print('📍 URL: ${AppConstants.supabaseUrl}');
  
  // Test 1: Tabla products (sabemos que existe)
  try {
    final products = await client.from('products').select('id').limit(1);
    print('✅ products: OK (${products.length} registros)');
  } catch (e) {
    print('❌ products: $e');
  }
  
  // Test 2: Tabla customers (sabemos que existe)
  try {
    final customers = await client.from('customers').select('id').limit(1);
    print('✅ customers: OK (${customers.length} registros)');
  } catch (e) {
    print('❌ customers: $e');
  }
  
  // Test 3: Tabla accounts (nueva)
  try {
    final accounts = await client.from('accounts').select('id').limit(1);
    print('✅ accounts: OK (${accounts.length} registros)');
  } catch (e) {
    print('❌ accounts: $e');
  }
  
  // Test 4: Tabla cash_movements (nueva)
  try {
    final movements = await client.from('cash_movements').select('id').limit(1);
    print('✅ cash_movements: OK (${movements.length} registros)');
  } catch (e) {
    print('❌ cash_movements: $e');
  }
  
  // Test 5: Tabla proveedores (nueva)
  try {
    final proveedores = await client.from('proveedores').select('id').limit(1);
    print('✅ proveedores: OK (${proveedores.length} registros)');
  } catch (e) {
    print('❌ proveedores: $e');
  }
  
  print('🔍 ===== FIN TEST =====');
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
