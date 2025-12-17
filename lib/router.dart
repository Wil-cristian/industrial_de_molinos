import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/products_page.dart';
import 'presentation/pages/customers_page.dart';
import 'presentation/pages/invoices_page.dart';
import 'presentation/pages/reports_page.dart';
import 'presentation/pages/settings_page.dart';
import 'presentation/pages/quotations_page.dart';
import 'presentation/pages/new_quotation_page.dart';
import 'presentation/pages/new_invoice_page.dart';
import 'presentation/pages/materials_page.dart';
import 'presentation/pages/composite_products_page.dart';
import 'presentation/pages/daily_cash_page.dart';

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
    GoRoute(
      path: '/materials',
      builder: (context, state) => const MaterialsPage(),
    ),
    GoRoute(
      path: '/composite-products',
      builder: (context, state) => const CompositeProductsPage(),
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
      builder: (context, state) => const ReportsPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
