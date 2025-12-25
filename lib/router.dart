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

// Configuración del router
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/daily-cash',
      builder: (context, state) => const DailyCashPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsPage(),
    ),
    GoRoute(
      path: '/products/new',
      builder: (context, state) => const ProductsPage(openNewDialog: true),
    ),
    // Redirección: /recipe-builder ahora abre el dialog desde products page
    GoRoute(
      path: '/recipe-builder',
      redirect: (context, state) => '/products/new',
    ),
    GoRoute(
      path: '/materials',
      builder: (context, state) {
        final action = state.uri.queryParameters['action'];
        return MaterialsPage(openNewDialog: action == 'new');
      },
    ),
    GoRoute(
      path: '/composite-products',
      builder: (context, state) => const CompositeProductsPage(),
    ),
    GoRoute(
      path: '/assets',
      builder: (context, state) {
        final action = state.uri.queryParameters['action'];
        return AssetsPage(openNewDialog: action == 'new');
      },
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomersPage(),
    ),
    GoRoute(
      path: '/customers/new',
      builder: (context, state) => const CustomersPage(openNewDialog: true),
    ),
    GoRoute(
      path: '/customers/:id/history',
      builder: (context, state) => CustomerHistoryPage(
        customerId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/invoices',
      builder: (context, state) => const InvoicesPage(),
    ),
    GoRoute(
      path: '/invoices/new',
      builder: (context, state) => const NewInvoicePage(),
    ),
    GoRoute(
      path: '/quotations',
      builder: (context, state) => const QuotationsPage(),
    ),
    GoRoute(
      path: '/quotations/new',
      builder: (context, state) => const NewQuotationPage(),
    ),
    GoRoute(
      path: '/quotations/edit/:id',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Editar Cotización - Por implementar')),
      ),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsAnalyticsPage(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) {
        final action = state.uri.queryParameters['action'];
        return CalendarPage(openNewDialog: action == 'new');
      },
    ),
    GoRoute(
      path: '/employees',
      builder: (context, state) {
        final action = state.uri.queryParameters['action'];
        return EmployeesPage(
          openNewDialog: action == 'new',
          openNewTaskDialog: action == 'new-task',
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
