# Plan de Conversión Responsive / Móvil — Molinos App

> **Fecha**: 11 Marzo 2026  
> **Objetivo**: Convertir la aplicación desktop Flutter en una app responsiva que funcione en celulares Android (y eventualmente iOS)  
> **Estado**: EN PLANIFICACIÓN

---

## 1. Inventario Completo de Pantallas (22 pantallas)

| # | Pantalla | Clase | Ruta | Complejidad Responsive | Prioridad |
|---|----------|-------|------|------------------------|-----------|
| 1 | **Login** | `LoginPage` | `/login` | 🟢 Baja | P0 |
| 2 | **Caja Diaria** | `DailyCashPage` | `/daily-cash` | 🟡 Media | P0 |
| 3 | **Dashboard** | `DashboardPage` | `/` | 🔴 Alta | P1 |
| 4 | **Ventas/Facturas** | `InvoicesPage` | `/invoices` | 🟡 Media | P0 |
| 5 | **Nueva Venta** | `NewSalePage` | `/invoices/new` | 🔴 Alta | P0 |
| 6 | **Cotizaciones** | `QuotationsPage` | `/quotations` | 🟡 Media | P1 |
| 7 | **Nueva Cotización** | `NewQuotationPage` | `/quotations/new` | 🔴 Alta | P1 |
| 8 | **Clientes** | `CustomersPage` | `/customers` | 🟡 Media | P0 |
| 9 | **Historial Cliente** | `CustomerHistoryPage` | `/customers/:id/history` | 🟡 Media | P2 |
| 10 | **Proveedores** | `SuppliersPage` | `/suppliers` | 🟡 Media | P2 |
| 11 | **Materiales** | `MaterialsPage` | `/materials` | 🟡 Media | P1 |
| 12 | **Productos Compuestos** | `CompositeProductsPage` | `/composite-products` | 🟡 Media | P1 |
| 13 | **Órdenes de Compra** | `PurchaseOrdersPage` | — | 🟡 Media | P2 |
| 14 | **Compras y Gastos** | `ExpensesPage` | `/expenses` | 🟡 Media | P1 |
| 15 | **Contabilidad** | `AccountingPage` | `/accounting` | 🔴 Alta | P3 |
| 16 | **Control IVA** | `IvaControlPage` | `/iva-control` | 🟡 Media | P3 |
| 17 | **Reportes/Analytics** | `ReportsAnalyticsPage` | `/reports` | 🔴 Alta | P2 |
| 18 | **Empleados** | `EmployeesPage` | `/employees` | 🟡 Media | P2 |
| 19 | **Activos** | `AssetsPage` | `/assets` | 🟡 Media | P2 |
| 20 | **Calendario** | `CalendarPage` | `/calendar` | 🟡 Media | P2 |
| 21 | **Configuración** | `SettingsPage` | — (no en router) | 🟢 Baja | P3 |
| 22 | **Productos (legacy)** | `ProductsPage` | `/products` → redirect | — Deprecada | — |

---

## 2. Problemas Actuales (Desktop-Only)

### Navegación
- **Sidebar fijo de 88px** (`AppSidebar`) siempre visible — no cabe en móvil
- Usa `Row` con sidebar + `Expanded` content — no se adapta a pantallas angostas
- `StatefulShellRoute.indexedStack` mantiene estado pero no hay bottom nav

### Layouts
- Muchas pantallas usan `Row` con columnas fijas para header (stats, filtros, botones)
- Tablas/DataTables con muchas columnas — overflow en pantallas pequeñas
- Diálogos modales con anchos fijos (`maxWidth: 600-900px`)
- Cards en filas horizontales sin Wrap

### Componentes
- Botones de acción en barras horizontales que no se envuelven
- `QuickActionsButton` flotante — podría chocar con FAB o bottom nav
- Gráficos `fl_chart` con tamaños hardcodeados

---

## 3. Arquitectura Responsive Propuesta

### 3.1 Breakpoints
```
Mobile:    < 600px   → Bottom Navigation + layouts verticales
Tablet:    600-1024px → Navigation Rail + layouts adaptados
Desktop:   > 1024px  → Sidebar actual (sin cambios)
```

### 3.2 Clase de Utilidad Central
```dart
// lib/core/responsive/responsive_helper.dart
class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;
  
  static bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600 && 
    MediaQuery.sizeOf(context).width < 1024;
  
  static bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1024;
}
```

### 3.3 Shell Principal Adaptivo
```
Desktop:  Sidebar (actual) + Content
Tablet:   NavigationRail colapsado + Content
Mobile:   BottomNavigationBar + Content (max 5 items + "Más")
```

### 3.4 Patrones por Tipo de Componente

| Componente Desktop | → Móvil |
|-------------------|---------|
| Sidebar con 13 items | Bottom nav con 5 items + menú "Más" |
| Diálogos anchos | Bottom sheets o pantallas completas |
| Tablas con DataTable | ListView con Cards expandibles |
| Filas de stats (Row) | Column o GridView 2 columnas |
| Filtros en header Row | ExpansionTile o bottom sheet con filtros |
| Botones de acción en fila | PopupMenu o SpeedDial FAB |
| Gráficos grandes | Gráficos scrollable o simplificados |

---

## 4. Fases de Implementación

### FASE 0 — Infraestructura Base (1-2 días)
- [ ] Crear `lib/core/responsive/responsive_helper.dart` (breakpoints, helpers)
- [ ] Crear `lib/core/responsive/responsive_wrapper.dart` (widget builder)
- [ ] Modificar `_MainShell` en `router.dart` para shell adaptivo
- [ ] Crear `BottomNavBar` con los 5 items más usados + "Más"
- [ ] Adaptar `QuickActionsButton` para móvil
- [ ] Verificar `main.dart` no tiene restricciones de tamaño mínimo

### FASE 1 — Pantallas Core (P0) — Las más usadas en campo
**Orden de trabajo:**

1. **Login** (`login_page.dart`) — 🟢 Probablemente ya funciona
   - [ ] Verificar que el form se centre y adapte
   - [ ] Teclado no cubra inputs

2. **Caja Diaria** (`daily_cash_page.dart`) — 🟡 La más usada
   - [ ] Header stats → Column en móvil
   - [ ] Lista de movimientos → Cards responsivos
   - [ ] Botones de acción → FAB o menú
   - [ ] Diálogo de nuevo movimiento → BottomSheet

3. **Ventas/Facturas** (`invoices_page.dart`) — 🟡
   - [ ] Tabla de facturas → ListView con Cards
   - [ ] Filtros → Chips o bottom sheet
   - [ ] Acciones → PopupMenu en cada card

4. **Nueva Venta** (`new_sale_page.dart`) — 🔴 Pantalla compleja
   - [ ] Layout de 2 columnas → Stack/Stepper en móvil
   - [ ] Selector de productos → Búsqueda fullscreen
   - [ ] Resumen de venta → Bottom sheet persistente
   - [ ] Teclado numérico no cortado

5. **Clientes** (`customers_page.dart`) — 🟡
   - [ ] Lista/Grid de clientes → ListView simple
   - [ ] Búsqueda → SearchBar in AppBar
   - [ ] Diálogo nuevo cliente → Pantalla completa

### FASE 2 — Pantallas Secundarias (P1)

6. **Dashboard** (`dashboard_page.dart`) — 🔴
   - [ ] Grid de KPIs → Column scrollable
   - [ ] Gráficos → Tamaño adaptativo
   - [ ] Widgets de resumen → Stacked cards

7. **Cotizaciones** (`quotations_page.dart`) — 🟡
   - [ ] Similar patrón a Facturas

8. **Nueva Cotización** (`new_quotation_page.dart`) — 🔴
   - [ ] Similar patrón a Nueva Venta

9. **Materiales** (`materials_page.dart`) — 🟡
   - [ ] Tabla de materiales → Cards con expandible
   - [ ] Filtros por categoría → Chips

10. **Productos Compuestos** (`composite_products_page.dart`) — 🟡
    - [ ] Lista con recetas → Cards expandibles
    - [ ] Editor de receta → Pantalla completa

11. **Compras y Gastos** (`expenses_page.dart`) — 🟡
    - [ ] Lista de gastos → Cards
    - [ ] Filtros → Chips o sheet

### FASE 3 — Pantallas de Gestión (P2)

12. **Reportes/Analytics** (`reports_analytics_page.dart`) — 🔴
    - [ ] Tabs de reportes → Scrollable tabs
    - [ ] Gráficos → Full-width scrollable
    - [ ] Tablas de datos → Cards resumen

13. **Empleados** (`employees_page.dart`) — 🟡
    - [ ] Lista de empleados → Cards
    - [ ] Asignación de tareas → Bottom sheet

14. **Activos** (`assets_page.dart`) — 🟡
    - [ ] Grid de activos → Lista vertical

15. **Calendario** (`calendar_page.dart`) — 🟡
    - [ ] Calendario → Vista mensual compacta
    - [ ] Lista de actividades → Cards

16. **Historial Cliente** (`customer_history_page.dart`) — 🟡
    - [ ] Timeline → Cards verticales

17. **Proveedores** (`suppliers_page.dart`) — 🟡
    - [ ] Similar a Clientes

18. **Órdenes de Compra** (`purchase_orders_page.dart`) — 🟡
    - [ ] Similar a Facturas

### FASE 4 — Pantallas Financieras (P3)

19. **Contabilidad** (`accounting_page.dart`) — 🔴
    - [ ] Múltiples tabs complejos → Pantallas separadas en móvil
    - [ ] Balance general → Simplificado

20. **Control IVA** (`iva_control_page.dart`) — 🟡
    - [ ] Tabla IVA → Cards agrupados

21. **Configuración** (`settings_page.dart`) — 🟢
    - [ ] Probablemente funciona con scroll

---

## 5. Bottom Navigation — Distribución Propuesta

### Items principales (5 visibles):
| # | Icono | Label | Ruta |
|---|-------|-------|------|
| 1 | 💰 | Caja | `/daily-cash` |
| 2 | 📄 | Ventas | `/invoices` |
| 3 | 👥 | Clientes | `/customers` |
| 4 | 📦 | Materiales | `/materials` |
| 5 | ☰ | Más | → Abre drawer/sheet |

### Menú "Más" contiene:
- Dashboard
- Compras/Gastos
- Productos Compuestos
- Cotizaciones
- Reportes
- Calendario
- Empleados
- Activos
- Contabilidad
- Control IVA
- Configuración

---

## 6. Herramientas MCP Disponibles

### Dart SDK MCP (conectado ✅)
- `list_devices` — Ver dispositivos conectados (emulador, Chrome, etc.)
- `launch_app` — Lanzar la app en un dispositivo
- `hot_reload` / `hot_restart` — Recargar cambios en vivo
- `get_widget_tree` — Inspeccionar el árbol de widgets
- `get_runtime_errors` — Ver errores en tiempo real
- `get_app_logs` — Ver logs de la app

### Para testing visual:
- Usar Chrome DevTools con responsive mode
- Emulador Android con diferentes tamaños
- `flutter run -d chrome --web-renderer html` para preview rápido

---

## 7. Checklist Pre-Build APK

- [ ] Todas las pantallas P0 responsive
- [ ] Bottom navigation funcional
- [ ] Shell adaptivo (mobile/tablet/desktop)
- [ ] Sin overflow errors en pantallas comunes
- [ ] Diálogos convertidos a bottom sheets en móvil
- [ ] Teclado no cubre inputs
- [ ] Pull-to-refresh donde aplique
- [ ] Splash screen y app icon configurados
- [ ] Permisos Android (internet, etc.)
- [ ] Firma APK configurada
- [ ] Test en emulador Android
- [ ] Test en dispositivo físico

---

## 8. Orden de Trabajo Recomendado

```
SEMANA 1: Fase 0 (infraestructura) + Login + Caja Diaria
SEMANA 2: Facturas + Nueva Venta + Clientes
SEMANA 3: Dashboard + Cotizaciones + Nueva Cotización
SEMANA 4: Materiales + Productos + Gastos
SEMANA 5: Reportes + Empleados + Activos + Calendario
SEMANA 6: Contabilidad + IVA + Settings + Testing final
SEMANA 7: Build APK + Testing en dispositivos + Release
```

---

## 9. Notas Técnicas

- **No se necesita `responsive_framework` externo** — Flutter tiene `LayoutBuilder`, `MediaQuery` y `Wrap` que son suficientes
- **Patrón ya usado**: Ya tenemos experiencia con `LayoutBuilder + Wrap` para headers (ver `/memories/repo/flutter-responsive-overflow.md`)
- **StatefulShellRoute** se mantiene — solo cambia el shell builder según breakpoint
- **GoRouter** no necesita cambios — las rutas son las mismas, solo cambia la navegación
- **Supabase** funciona igual en móvil — no hay cambios backend
