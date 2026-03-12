import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/datasources/supabase_datasource.dart';
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
import 'presentation/pages/login_page.dart';
import 'presentation/pages/accounting_page.dart';
import 'presentation/pages/iva_control_page.dart';
import 'presentation/widgets/app_sidebar.dart';
import 'presentation/widgets/app_bottom_nav_bar.dart';
import 'presentation/widgets/quick_actions_button.dart';
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
    SupabaseDataSource.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final isAuthenticated = SupabaseDataSource.isAuthenticated;
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
  ],
);

/// Shell principal adaptivo: sidebar en desktop, bottom nav en móvil
class _MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final String currentPath;

  const _MainShell({required this.navigationShell, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      return Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: navigationShell,
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentRoute: currentPath,
          navigationShell: navigationShell,
        ),
      );
    }

    // Desktop/Tablet: sidebar + contenido
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              AppSidebar(currentRoute: currentPath),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  child: navigationShell,
                ),
              ),
            ],
          ),
          const QuickActionsButton(),
        ],
      ),
    );
  }
}
