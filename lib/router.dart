import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/datasources/supabase_datasource.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/role_provider.dart';
import 'data/providers/accounting_provider.dart';
import 'core/permissions/screen_permissions.dart';
import 'presentation/pages/dashboard_page.dart';
// ProductsPage ya no se usa - unificada en CompositeProductsPage
import 'presentation/pages/customers_page.dart';
import 'presentation/pages/invoices_page.dart';
import 'presentation/pages/reports_analytics_page.dart';
import 'presentation/pages/quotations_page.dart';
import 'presentation/pages/new_quotation_page.dart';
import 'presentation/pages/new_sale_page.dart';
import 'presentation/pages/materials_page.dart';
import 'presentation/pages/daily_cash_page.dart';
import 'presentation/pages/expenses_page.dart';
import 'presentation/pages/composite_products_page.dart';
import 'presentation/pages/customer_history_page.dart';
import 'presentation/pages/calendar_page.dart';
import 'presentation/pages/assets_page.dart';
import 'presentation/pages/employees_page.dart';
import 'presentation/pages/production_orders_page.dart';
import 'presentation/pages/shipments_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/accounting_page.dart';
import 'presentation/pages/iva_control_page.dart';
import 'presentation/pages/nfc_attendance_page.dart';
import 'presentation/pages/employee_dashboard_page.dart';
import 'presentation/pages/user_management_page.dart';
import 'presentation/pages/diagnostics_page.dart';
import 'presentation/pages/audit_panel_page.dart';
import 'presentation/pages/chat_page.dart';
import 'presentation/pages/advance_sales_page.dart';
import 'presentation/widgets/ai_assistant_overlay.dart';
import 'presentation/widgets/app_sidebar.dart';
import 'presentation/widgets/app_bottom_nav_bar.dart';
import 'core/responsive/responsive_helper.dart';

// Claves de navegación para mantener el estado
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Listenable que refresca el router cuando cambia el estado de auth
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Configuración del router con StatefulShellRoute para mantener estado
final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/daily-cash',
  refreshListenable: GoRouterRefreshStream(
    SupabaseDataSource.isInitialized
        ? SupabaseDataSource.client.auth.onAuthStateChange
        : const Stream.empty(),
  ),
  redirect: (context, state) {
    final isAuthenticated =
        SupabaseDataSource.isInitialized &&
        SupabaseDataSource.isAuthenticated;
    final isLoginRoute = state.uri.path == '/login';

    // Si no está autenticado y no está en login, redirigir a login
    if (!isAuthenticated && !isLoginRoute) {
      return '/login';
    }

    // Si está autenticado y está en login, redirigir a la app
    if (isAuthenticated && isLoginRoute) {
      return '/daily-cash';
    }

    // No redirigir
    return null;
  },
  routes: [
    // Ruta de login (fuera del shell)
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginPage(),
    ),
    // StatefulShellRoute mantiene el estado de las páginas principales
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return _MainShell(
          navigationShell: navigationShell,
          currentPath: state.uri.path,
        );
      },
      branches: [
        // Branch 0: Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DashboardPage()),
            ),
          ],
        ),
        // Branch 1: Caja Diaria
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/daily-cash',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DailyCashPage()),
            ),
          ],
        ),
        // Branch 2: Compras y Gastos
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/expenses',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ExpensesPage()),
            ),
          ],
        ),
        // Branch 3: Productos (redirige a Compuestos unificado)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              redirect: (context, state) => '/composite-products',
            ),
          ],
        ),
        // Branch 3: Materiales
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/materials',
              pageBuilder: (context, state) {
                final action = state.uri.queryParameters['action'];
                return NoTransitionPage(
                  child: MaterialsPage(openNewDialog: action == 'new'),
                );
              },
            ),
          ],
        ),
        // Branch 4: Clientes y Proveedores
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/customers',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CustomersPage()),
              routes: [
                GoRoute(
                  path: 'new',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: CustomersPage(openNewDialog: true),
                  ),
                ),
                GoRoute(
                  path: ':id/history',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: CustomerHistoryPage(
                      customerId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Branch 5: Ventas/Facturas
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/invoices',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: InvoicesPage()),
            ),
          ],
        ),
        // Branch 6: Cotizaciones
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/quotations',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: QuotationsPage()),
            ),
          ],
        ),
        // Branch 7: Reportes
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ReportsAnalyticsPage()),
            ),
          ],
        ),
        // Branch 8: Calendario
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              pageBuilder: (context, state) {
                final action = state.uri.queryParameters['action'];
                return NoTransitionPage(
                  child: CalendarPage(openNewDialog: action == 'new'),
                );
              },
            ),
          ],
        ),
        // Branch 9: Empleados
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/employees',
              pageBuilder: (context, state) {
                final action = state.uri.queryParameters['action'];
                return NoTransitionPage(
                  child: EmployeesPage(
                    openNewDialog: action == 'new',
                    openNewTaskDialog: action == 'new-task',
                  ),
                );
              },
            ),
          ],
        ),
        // Branch 10: Activos
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/assets',
              pageBuilder: (context, state) {
                final action = state.uri.queryParameters['action'];
                return NoTransitionPage(
                  child: AssetsPage(openNewDialog: action == 'new'),
                );
              },
            ),
          ],
        ),
        // Branch 11: Contabilidad
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounting',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AccountingPage()),
            ),
          ],
        ),
        // Branch 12: Control IVA
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/iva-control',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: IvaControlPage()),
            ),
          ],
        ),
        // Branch 13: Productos Compuestos
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/composite-products',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CompositeProductsPage()),
            ),
          ],
        ),
        // Branch 14: Ordenes de Produccion
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/production-orders',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProductionOrdersPage()),
            ),
          ],
        ),
        // Branch 15: Remisiones y Entregas
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/shipments',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ShipmentsPage()),
            ),
          ],
        ),
        // Branch 16: Gestión de Usuarios (solo admin)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/user-management',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: UserManagementPage()),
            ),
          ],
        ),
        // Branch 17: Panel de Auditoría (admin, dueño, técnico)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/audit-panel',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AuditPanelPage()),
            ),
          ],
        ),
        // Branch 18: Ventas Anticipadas
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/advance-sales',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AdvanceSalesPage()),
            ),
          ],
        ),
        // Branch 19: Chat y Aprobaciones
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ChatPage()),
            ),
          ],
        ),
      ],
    ),
    // Rutas fuera del shell (pantalla completa sin sidebar)
    GoRoute(
      path: '/invoices/new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NewSalePage(),
    ),
    GoRoute(
      path: '/quotations/new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NewQuotationPage(),
    ),
    GoRoute(
      path: '/quotations/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          NewQuotationPage(quotationId: state.pathParameters['id']),
    ),
    // Kiosko de asistencia NFC (pantalla completa sin sidebar)
    GoRoute(
      path: '/nfc-attendance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NfcAttendancePage(),
    ),
    // Dashboard del empleado (pantalla completa sin sidebar)
    GoRoute(
      path: '/employee-dashboard',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EmployeeDashboardPage(),
    ),
    // Diagnóstico de conexiones (pantalla completa)
    GoRoute(
      path: '/diagnostics',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DiagnosticsPage(),
    ),
  ],
);

/// Shell principal adaptivo: sidebar en desktop, bottom nav en móvil
/// Si el usuario es empleado, redirige a su dashboard
/// Nav bar se oculta al scrollear hacia abajo y reaparece al subir
class _MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final String currentPath;

  const _MainShell({required this.navigationShell, required this.currentPath});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _navBarController;
  late Animation<Offset> _navBarSlide;
  int _previousIndex = -1;
  double _fadeOpacity = 1.0;

  /// Para empleados: null = aún verificando, true = tiene permisos, false = no tiene
  bool? _employeeHasOverrides;
  bool _checkingOverrides = false;

  @override
  void initState() {
    super.initState();
    _navBarController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _navBarSlide =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, 1), // slide down to hide
        ).animate(
          CurvedAnimation(parent: _navBarController, curve: Curves.easeInOut),
        );
  }

  @override
  void didUpdateWidget(covariant _MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fade in when branch changes
    final newIndex = widget.navigationShell.currentIndex;
    if (_previousIndex != -1 && _previousIndex != newIndex) {
      setState(() => _fadeOpacity = 0.0);
      Future.microtask(() {
        if (mounted) setState(() => _fadeOpacity = 1.0);
      });
      // Show nav bar when changing tabs
      _navBarController.reverse();

      // Recargar contabilidad cuando se navega a esa sección
      if (widget.currentPath == '/accounting') {
        Future.microtask(() {
          if (mounted) ref.read(accountingProvider.notifier).loadAll();
        });
      }
    }
    _previousIndex = newIndex;
  }

  @override
  void dispose() {
    _navBarController.dispose();
    super.dispose();
  }

  /// Verifica si el empleado tiene permisos de pantalla asignados en BD
  Future<void> _checkEmployeeOverrides() async {
    if (_checkingOverrides) return;
    _checkingOverrides = true;
    try {
      final client = SupabaseDataSource.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _employeeHasOverrides = false);
        return;
      }
      final rows = await client
          .from('screen_permissions')
          .select('screen_key')
          .eq('user_id', userId)
          .eq('is_allowed', true)
          .limit(1);
      if (mounted) {
        setState(() => _employeeHasOverrides = rows.isNotEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _employeeHasOverrides = false);
    } finally {
      _checkingOverrides = false;
    }
  }

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      // Scrolling down → hide
      if (_navBarController.status != AnimationStatus.forward &&
          _navBarController.status != AnimationStatus.completed) {
        _navBarController.forward();
      }
    } else if (notification.direction == ScrollDirection.forward) {
      // Scrolling up → show
      if (_navBarController.status != AnimationStatus.reverse &&
          _navBarController.status != AnimationStatus.dismissed) {
        _navBarController.reverse();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final roleState = ref.watch(roleProvider);

    // Si aún está cargando el perfil, mostrar loading
    if (roleState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Si es empleado, verificar si tiene permisos de pantalla asignados
    if (roleState.isEmployee) {
      if (_employeeHasOverrides == null) {
        // Aún no sabemos — lanzar verificación
        _checkEmployeeOverrides();
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!_employeeHasOverrides!) {
        // No tiene permisos → redirigir a Mi Portal
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            GoRouter.of(context).go('/employee-dashboard');
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      // Tiene permisos → continuar para mostrar sidebar
    }

    // Si hay error de cuenta inactiva, mostrar mensaje
    if (roleState.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                roleState.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      );
    }

    final isMobile = ResponsiveHelper.isMobile(context);

    // Verificar permisos de pantalla — si el usuario no tiene acceso, redirigir
    final permissions = ref.watch(screenPermissionsProvider);
    if (!permissions.canAccessRoute(widget.currentPath)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          // Buscar la primera ruta permitida para evitar loops
          final fallback = AppScreen.routeToScreen.entries
              .where((e) => permissions.canAccess(e.value))
              .map((e) => e.key)
              .firstOrNull ?? '/daily-cash';
          GoRouter.of(context).go(fallback);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isMobile) {
      return Scaffold(
        body: NotificationListener<UserScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _fadeOpacity,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: widget.navigationShell,
                  ),
                ),
              ),
              const AiAssistantFab(),
              // Nav bar overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _navBarSlide,
                  child: AppBottomNavBar(
                    currentRoute: widget.currentPath,
                    navigationShell: widget.navigationShell,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Desktop/Tablet: sidebar + contenido
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              AppSidebar(currentRoute: widget.currentPath),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  child: widget.navigationShell,
                ),
              ),
            ],
          ),
          const AiAssistantFab(),
        ],
      ),
    );
  }
}
