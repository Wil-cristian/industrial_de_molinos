import 'package:flutter/material.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../core/utils/colombia_time.dart';

/// Página de diagnóstico para probar todas las conexiones a Supabase.
/// Acceder desde Settings o navegando a /diagnostics.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  bool _running = false;
  final List<_EndpointResult> _results = [];
  int _passed = 0;
  int _failed = 0;
  Duration _totalTime = Duration.zero;

  // Todas las tablas y vistas que usa la app
  static const List<_EndpointDef> _endpoints = [
    // --- Tablas principales ---
    _EndpointDef('accounts', 'SELECT', 'Cuentas bancarias'),
    _EndpointDef('activities', 'SELECT', 'Actividades/Agenda'),
    _EndpointDef('assets', 'SELECT', 'Activos fijos'),
    _EndpointDef('asset_maintenance', 'SELECT', 'Mantenimiento de activos'),
    _EndpointDef('cash_movements', 'SELECT', 'Movimientos de caja'),
    _EndpointDef('categories', 'SELECT', 'Categorías de productos'),
    _EndpointDef('chart_of_accounts', 'SELECT', 'Plan de cuentas'),
    _EndpointDef('company_settings', 'SELECT', 'Configuración empresa'),
    _EndpointDef('customers', 'SELECT', 'Clientes'),
    _EndpointDef('employees', 'SELECT', 'Empleados'),
    _EndpointDef('employee_tasks', 'SELECT', 'Tareas de empleados'),
    _EndpointDef('employee_time_entries', 'SELECT', 'Registro de tiempo'),
    _EndpointDef('employee_time_adjustments', 'SELECT', 'Ajustes de tiempo'),
    _EndpointDef('invoices', 'SELECT', 'Facturas'),
    _EndpointDef('invoice_items', 'SELECT', 'Items de factura'),
    _EndpointDef('iva_invoices', 'SELECT', 'Facturas IVA'),
    _EndpointDef('iva_config', 'SELECT', 'Configuración IVA'),
    _EndpointDef('iva_bimonthly_settlements', 'SELECT', 'Liquidaciones IVA'),
    _EndpointDef('journal_entries', 'SELECT', 'Asientos contables'),
    _EndpointDef('materials', 'SELECT', 'Materiales (inventario)'),
    _EndpointDef('material_prices', 'SELECT', 'Precios de materiales'),
    _EndpointDef('material_categories', 'SELECT', 'Categorías de materiales'),
    _EndpointDef(
      'material_subcategories',
      'SELECT',
      'Subcategorías de materiales',
    ),
    _EndpointDef('operational_costs', 'SELECT', 'Costos operacionales'),
    _EndpointDef('payroll_concepts', 'SELECT', 'Conceptos de nómina'),
    _EndpointDef('products', 'SELECT', 'Productos'),
    _EndpointDef('product_components', 'SELECT', 'Componentes de receta'),
    _EndpointDef('production_orders', 'SELECT', 'Órdenes de producción'),
    _EndpointDef(
      'production_order_materials',
      'SELECT',
      'Materiales de producción',
    ),
    _EndpointDef('production_stages', 'SELECT', 'Etapas de producción'),
    _EndpointDef('proveedores', 'SELECT', 'Proveedores'),
    _EndpointDef('purchase_orders', 'SELECT', 'Órdenes de compra'),
    _EndpointDef('purchase_order_items', 'SELECT', 'Items de OC'),
    _EndpointDef('quotations', 'SELECT', 'Cotizaciones'),
    _EndpointDef('quotation_items', 'SELECT', 'Items de cotización'),
    _EndpointDef('stock_movements', 'SELECT', 'Movimientos de stock'),
    _EndpointDef('supplier_materials', 'SELECT', 'Materiales por proveedor'),
    _EndpointDef('app_releases', 'SELECT', 'Releases de la app'),
    // --- Vistas ---
    _EndpointDef(
      'v_balance_comprobacion',
      'VIEW',
      'Vista: Balance Comprobación',
    ),
    _EndpointDef('v_libro_mayor', 'VIEW', 'Vista: Libro Mayor'),
    _EndpointDef('v_pyl_mensual', 'VIEW', 'Vista: P&L Mensual'),
    _EndpointDef(
      'v_customer_purchase_history',
      'VIEW',
      'Vista: Historial compras',
    ),
    _EndpointDef('v_customer_metrics', 'VIEW', 'Vista: Métricas clientes'),
    _EndpointDef(
      'v_top_selling_products',
      'VIEW',
      'Vista: Productos más vendidos',
    ),
    _EndpointDef(
      'v_material_consumption_monthly',
      'VIEW',
      'Vista: Consumo materiales',
    ),
    _EndpointDef('v_sales_by_period', 'VIEW', 'Vista: Ventas por período'),
    _EndpointDef('v_low_stock_products', 'VIEW', 'Vista: Stock bajo'),
    _EndpointDef(
      'v_iva_bimonthly_summary',
      'VIEW',
      'Vista: Resumen IVA bimestral',
    ),
  ];

  // RPCs que usa la app
  static const List<String> _rpcFunctions = [
    'get_journal_entries',
    'get_balance_general',
    'get_estado_resultados',
    'atomic_transfer',
    'generate_invoice_number',
    'generate_quotation_number',
    'generate_order_number',
    'update_product_totals',
    'check_recipe_stock',
    'check_quotation_stock',
    'add_recipe_to_quotation',
    'get_recipe_live_pricing',
    'deduct_stock_for_invoice',
    'get_my_profile',
    'create_employee_account',
    'list_user_accounts',
    'get_iva_invoices',
    'liquidar_bimestre',
    'get_iva_current_summary',
    'get_iva_settlements',
  ];

  Future<void> _runAllTests() async {
    setState(() {
      _running = true;
      _results.clear();
      _passed = 0;
      _failed = 0;
      _totalTime = Duration.zero;
    });

    final client = SupabaseDataSource.client;
    final globalStart = ColombiaTime.now();

    // Test 1: Conexión básica
    await _testEndpoint(
      name: 'Conexión Supabase',
      description: 'Verificar conectividad básica',
      test: () async => await SupabaseDataSource.checkConnection(),
    );

    // Test 2: Auth
    await _testEndpoint(
      name: 'Auth Status',
      description: 'Sesión de usuario activa',
      test: () async => SupabaseDataSource.isAuthenticated,
    );

    // Test 3: Todas las tablas y vistas
    for (final ep in _endpoints) {
      await _testEndpoint(
        name: '${ep.type}: ${ep.table}',
        description: ep.description,
        test: () async {
          await client.from(ep.table).select('id').limit(1);
          return true;
        },
      );
    }

    // Test 4: RPC functions (solo verificar que existen, no ejecutar lógica)
    for (final rpc in _rpcFunctions) {
      await _testEndpoint(
        name: 'RPC: $rpc',
        description: 'Función almacenada',
        test: () async {
          try {
            // Intentar invocar con parámetros vacíos - esperamos error de params, no 404
            await client.rpc(rpc);
            return true;
          } catch (e) {
            final msg = e.toString().toLowerCase();
            // Si el error es sobre parámetros faltantes, la función EXISTE
            if (msg.contains('argument') ||
                msg.contains('parameter') ||
                msg.contains('required') ||
                msg.contains('function') && !msg.contains('does not exist') ||
                msg.contains('could not find')) {
              // Function exists but needs params = OK
              return true;
            }
            // Si dice "does not exist" = la función NO existe
            if (msg.contains('does not exist') || msg.contains('404')) {
              return false;
            }
            // Otros errores (permisos, etc.) = la función existe
            return true;
          }
        },
      );
    }

    // Test 5: Storage bucket
    await _testEndpoint(
      name: 'Storage: attachments',
      description: 'Bucket de archivos adjuntos',
      test: () async {
        try {
          await client.storage.from('attachments').list(path: '');
          return true;
        } catch (_) {
          return false;
        }
      },
    );

    setState(() {
      _running = false;
      _totalTime = ColombiaTime.now().difference(globalStart);
    });
  }

  Future<void> _testEndpoint({
    required String name,
    required String description,
    required Future<bool> Function() test,
  }) async {
    final sw = Stopwatch()..start();
    bool success = false;
    String? error;
    try {
      success = await test();
    } catch (e) {
      success = false;
      error = e.toString();
      if (error.length > 120) error = '${error.substring(0, 120)}...';
    }
    sw.stop();

    setState(() {
      _results.add(
        _EndpointResult(
          name: name,
          description: description,
          success: success,
          duration: sw.elapsed,
          error: error,
        ),
      );
      if (success) {
        _passed++;
      } else {
        _failed++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de Conexiones'),
        actions: [
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '✅ $_passed  ❌ $_failed  ⏱ ${_totalTime.inMilliseconds}ms',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header con botón
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prueba de todos los endpoints de Supabase',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_endpoints.length} tablas/vistas + ${_rpcFunctions.length} RPCs + Storage + Auth',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _running ? null : _runAllTests,
                    icon: _running
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      _running
                          ? 'Probando... (${_results.length}/${_endpoints.length + _rpcFunctions.length + 3})'
                          : 'Ejecutar Diagnóstico',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_running) const LinearProgressIndicator(),
          const Divider(height: 1),
          // Resultados
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'Presiona "Ejecutar Diagnóstico" para comenzar',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          r.success ? Icons.check_circle : Icons.error,
                          color: r.success ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        title: Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: r.error != null
                            ? Text(
                                r.error!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                ),
                              )
                            : Text(
                                r.description,
                                style: const TextStyle(fontSize: 11),
                              ),
                        trailing: Text(
                          '${r.duration.inMilliseconds}ms',
                          style: TextStyle(
                            fontSize: 11,
                            color: r.duration.inMilliseconds > 500
                                ? Colors.orange
                                : Colors.grey,
                            fontWeight: r.duration.inMilliseconds > 500
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Resumen al final
          if (!_running && _results.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: _failed > 0 ? Colors.red.shade50 : Colors.green.shade50,
              child: Row(
                children: [
                  Icon(
                    _failed > 0 ? Icons.warning : Icons.check_circle,
                    color: _failed > 0 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _failed > 0
                          ? '$_failed conexiones fallaron de ${_results.length} probadas'
                          : 'Todas las ${_results.length} conexiones funcionan correctamente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _failed > 0
                            ? Colors.red.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                  ),
                  Text(
                    'Total: ${_totalTime.inMilliseconds}ms',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EndpointDef {
  final String table;
  final String type;
  final String description;
  const _EndpointDef(this.table, this.type, this.description);
}

class _EndpointResult {
  final String name;
  final String description;
  final bool success;
  final Duration duration;
  final String? error;
  const _EndpointResult({
    required this.name,
    required this.description,
    required this.success,
    required this.duration,
    this.error,
  });
}
