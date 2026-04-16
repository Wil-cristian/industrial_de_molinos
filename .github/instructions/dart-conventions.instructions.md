---
name: "Dart Conventions"
description: "Use when writing or editing Dart files. Covers naming conventions, import ordering, class structure, error handling, and code style for Industrial de Molinos."
applyTo: "**/*.dart"
---

# Dart Conventions — Industrial de Molinos

## Naming
- **Files**: `snake_case.dart` — match the primary class name
- **Classes**: `PascalCase` — `ProductsDataSource`, `InvoicesNotifier`
- **Variables/methods**: `camelCase` — `loadProducts()`, `isLoading`
- **Constants**: `camelCase` — `appVersion`, `maxRetries`
- **Private members**: prefix `_` — `_client`, `_fromJson()`, `_table`
- **Providers**: `camelCase` ending with `Provider` — `productsProvider`, `lowStockProductsProvider`

## Import Order
1. `dart:` packages
2. `package:flutter/` and `package:flutter_riverpod/`
3. Third-party packages (`package:go_router/`, `package:supabase_flutter/`, `package:intl/`)
4. Project imports with relative paths (`../../core/`, `../../domain/`, `../../data/`)

## Class Structure Order
1. Static constants (`static const String _table = ...`)
2. Static getters (`static SupabaseClient get _client => ...`)
3. Final fields
4. Constructor
5. Computed getters
6. `copyWith()` method (entities/states)
7. Public methods
8. Private methods
9. `_fromJson()` / `_toJson()` helpers (datasources)

## Error Handling
- Notifiers: wrap DataSource calls in `try/catch`, set `state.error` on failure
- DataSources: let exceptions bubble up (don't catch, let notifier handle)
- Use `AppLogger.error()` for logging, never `print()`
- Always clear `isLoading` in both success and error paths

## File Encoding
- All `.dart` files: **UTF-8 without BOM**
- Some legacy files were Windows-1252 — verify encoding when editing datasources

## Locale
- All user-facing strings in **Spanish** (`es_CO`)
- Date formatting via `intl` package with `es_CO` locale
- Currency: USD with `NumberFormat.currency(locale: 'es_CO', symbol: '\$')`
