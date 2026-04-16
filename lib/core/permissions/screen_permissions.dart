import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/role_provider.dart';
import '../../data/datasources/supabase_datasource.dart';

/// Claves de pantalla para el sistema de permisos
class AppScreen {
  static const dashboard = 'dashboard';
  static const dailyCash = 'daily-cash';
  static const expenses = 'expenses';
  static const compositeProducts = 'composite-products';
  static const productionOrders = 'production-orders';
  static const materials = 'materials';
  static const customers = 'customers';
  static const invoices = 'invoices';
  static const shipments = 'shipments';
  static const quotations = 'quotations';
  static const reports = 'reports';
  static const calendar = 'calendar';
  static const employees = 'employees';
  static const assets = 'assets';
  static const accounting = 'accounting';
  static const ivaControl = 'iva-control';
  static const userManagement = 'user-management';
  static const auditPanel = 'audit-panel';
  static const advanceSales = 'advance-sales';
  static const chat = 'chat';

  /// Mapa ruta → screen key (para buscar permisos desde la ruta)
  static const routeToScreen = <String, String>{
    '/': dashboard,
    '/daily-cash': dailyCash,
    '/expenses': expenses,
    '/composite-products': compositeProducts,
    '/production-orders': productionOrders,
    '/materials': materials,
    '/customers': customers,
    '/invoices': invoices,
    '/shipments': shipments,
    '/pending-deliveries': shipments,
    '/quotations': quotations,
    '/reports': reports,
    '/calendar': calendar,
    '/employees': employees,
    '/assets': assets,
    '/accounting': accounting,
    '/iva-control': ivaControl,
    '/user-management': userManagement,
    '/audit-panel': auditPanel,
    '/advance-sales': advanceSales,
    '/chat': chat,
  };

  /// Nombre legible de cada pantalla (para UI de administración)
  static const screenLabels = <String, String>{
    dashboard: 'Dashboard',
    dailyCash: 'Caja Diaria',
    expenses: 'Compras',
    compositeProducts: 'Productos',
    productionOrders: 'Producción',
    materials: 'Materiales',
    customers: 'Clientes',
    invoices: 'Ventas',
    shipments: 'Remisiones',
    quotations: 'Cotizaciones',
    reports: 'Reportes',
    calendar: 'Calendario',
    employees: 'Empleados',
    assets: 'Activos',
    accounting: 'Contabilidad',
    ivaControl: 'Control IVA',
    userManagement: 'Usuarios',
    auditPanel: 'Auditoría',
    advanceSales: 'Ventas Anticipadas',
    chat: 'Chat',
  };

  /// Permisos por defecto para cada rol.
  /// true = tiene acceso, ausencia = no tiene acceso.
  static const defaultPermissions = <String, Set<String>>{
    'admin': {
      dashboard,
      dailyCash,
      expenses,
      compositeProducts,
      productionOrders,
      materials,
      customers,
      invoices,
      shipments,
      quotations,
      reports,
      calendar,
      employees,
      assets,
      accounting,
      ivaControl,
      userManagement,
      advanceSales,
      chat,
      // admin NO ve auditoría por defecto
    },
    'dueno': {
      dashboard,
      dailyCash,
      expenses,
      compositeProducts,
      productionOrders,
      materials,
      customers,
      invoices,
      shipments,
      quotations,
      reports,
      calendar,
      employees,
      assets,
      accounting,
      ivaControl,
      userManagement,
      advanceSales,
      chat,
      // auditPanel se asigna por usuario, no por rol
    },
    'tecnico': {
      dashboard,
      dailyCash,
      expenses,
      compositeProducts,
      productionOrders,
      materials,
      customers,
      invoices,
      shipments,
      quotations,
      calendar,
      employees,
      assets,
      advanceSales,
      chat,
    },
    'employee': <String>{
      chat,
    },
  };
}

/// Estado de permisos de pantalla para el usuario actual
class ScreenPermissionsState {
  final Set<String> allowedScreens;
  final String role;
  final bool isLoading;

  const ScreenPermissionsState({
    this.allowedScreens = const {},
    this.role = 'employee',
    this.isLoading = false,
  });

  /// Verifica si el usuario puede acceder a una pantalla por su key
  bool canAccess(String screenKey) => allowedScreens.contains(screenKey);

  /// Verifica si el usuario puede acceder a una ruta
  bool canAccessRoute(String route) {
    // Rutas especiales que siempre están permitidas
    if (route == '/' ||
        route == '/login' ||
        route == '/employee-dashboard' ||
        route == '/nfc-attendance' ||
        route == '/diagnostics') {
      return true;
    }
    // Rutas de creación/edición heredan el permiso de su módulo
    if (route.startsWith('/invoices/')) return canAccess(AppScreen.invoices);
    if (route.startsWith('/quotations/')) {
      return canAccess(AppScreen.quotations);
    }
    if (route.startsWith('/customers/')) return canAccess(AppScreen.customers);

    final screenKey = AppScreen.routeToScreen[route];
    if (screenKey == null) return true; // Ruta desconocida → permitir
    return canAccess(screenKey);
  }
}

/// Provider de permisos de pantalla basado en el rol + overrides de BD
final screenPermissionsProvider =
    NotifierProvider<ScreenPermissionsNotifier, ScreenPermissionsState>(
      ScreenPermissionsNotifier.new,
    );

class ScreenPermissionsNotifier extends Notifier<ScreenPermissionsState> {
  @override
  ScreenPermissionsState build() {
    final roleState = ref.watch(roleProvider);
    final role = roleState.role;
    final defaults = AppScreen.defaultPermissions[role] ?? <String>{};

    // Para employee, los permisos por defecto están vacíos,
    // así que marcamos isLoading=true hasta cargar overrides de BD
    final needsOverrides = defaults.isEmpty;

    // Cargar overrides de BD asíncronamente
    _loadOverrides(role, Set<String>.from(defaults));

    return ScreenPermissionsState(
      allowedScreens: defaults,
      role: role,
      isLoading: needsOverrides,
    );
  }

  Future<void> _loadOverrides(String role, Set<String> baseScreens) async {
    try {
      final client = SupabaseDataSource.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        state = ScreenPermissionsState(
          allowedScreens: baseScreens,
          role: role,
          isLoading: false,
        );
        return;
      }

      final rows = await client
          .from('screen_permissions')
          .select('screen_key, is_allowed')
          .eq('user_id', userId);

      if (rows.isEmpty) {
        state = ScreenPermissionsState(
          allowedScreens: baseScreens,
          role: role,
          isLoading: false,
        );
        return;
      }

      final merged = Set<String>.from(baseScreens);
      for (final row in rows) {
        final key = row['screen_key'] as String;
        final allowed = row['is_allowed'] as bool;
        if (allowed) {
          merged.add(key);
        } else {
          merged.remove(key);
        }
      }

      state = ScreenPermissionsState(
        allowedScreens: merged,
        role: role,
        isLoading: false,
      );
    } catch (_) {
      // Si falla la carga de BD, mantener defaults del rol
      state = ScreenPermissionsState(
        allowedScreens: baseScreens,
        role: role,
        isLoading: false,
      );
    }
  }

  /// Recarga los permisos desde la BD (útil después de editar permisos)
  Future<void> reload() async {
    final roleState = ref.read(roleProvider);
    final role = roleState.role;
    final defaults = Set<String>.from(
      AppScreen.defaultPermissions[role] ?? <String>{},
    );
    await _loadOverrides(role, defaults);
  }
}
