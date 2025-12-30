import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/products_page.dart';
import 'presentation/pages/customers_page.dart';
import 'presentation/pages/invoices_page.dart';
import 'presentation/pages/reports_analytics_page.dart';
import 'presentation/pages/settings_page.dart';
import 'presentation/pages/quotations_page.dart';
import 'presentation/pages/new_quotation_page.dart';
import 'presentation/pages/new_invoice_page.dart';
import 'presentation/pages/materials_page.dart';
import 'presentation/pages/daily_cash_page.dart';
import 'presentation/pages/composite_products_page.dart';
import 'presentation/pages/customer_history_page.dart';
import 'presentation/pages/calendar_page.dart';
import 'presentation/pages/assets_page.dart';
import 'presentation/pages/employees_page.dart';
import 'presentation/widgets/app_sidebar.dart';
import 'presentation/widgets/quick_actions_button.dart';
import 'core/theme/app_theme.dart';

// Claves de navegación para mantener el estado
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Configuración del router con StatefulShellRoute para mantener estado
final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/daily-cash',
  routes: [
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
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardPage(),
              ),
            ),
          ],
        ),
        // Branch 1: Caja Diaria
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/daily-cash',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DailyCashPage(),
              ),
            ),
          ],
        ),
        // Branch 2: Productos
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProductsPage(),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: ProductsPage(openNewDialog: true),
                  ),
                ),
              ],
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
        // Branch 4: Clientes
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/customers',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: CustomersPage(),
              ),
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
              pageBuilder: (context, state) => const NoTransitionPage(
                child: InvoicesPage(),
              ),
            ),
          ],
        ),
        // Branch 6: Cotizaciones
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/quotations',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: QuotationsPage(),
              ),
            ),
          ],
        ),
        // Branch 7: Reportes
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ReportsAnalyticsPage(),
              ),
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
        // Branch 11: Configuración
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsPage(),
              ),
            ),
          ],
        ),
        // Branch 12: Productos Compuestos
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/composite-products',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: CompositeProductsPage(),
              ),
            ),
          ],
        ),
      ],
    ),
    // Rutas fuera del shell (pantalla completa sin sidebar)
    GoRoute(
      path: '/invoices/new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NewInvoicePage(),
    ),
    GoRoute(
      path: '/quotations/new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NewQuotationPage(),
    ),
    GoRoute(
      path: '/quotations/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Editar Cotización - Por implementar')),
      ),
    ),
    // Redirección
    GoRoute(
      path: '/recipe-builder',
      redirect: (context, state) => '/products/new',
    ),
  ],
);

/// Shell principal que mantiene el sidebar y el contenido
class _MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final String currentPath;

  const _MainShell({
    required this.navigationShell,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar persistente
              AppSidebar(currentRoute: currentPath),
              // Contenido de la página actual
              Expanded(
                child: Container(
                  color: AppTheme.backgroundColor,
                  child: navigationShell,
                ),
              ),
            ],
          ),
          // Botón de acciones rápidas flotante (siempre visible)
          const QuickActionsButton(),
        ],
      ),
    );
  }
}
