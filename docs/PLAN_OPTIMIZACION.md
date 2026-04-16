# PLAN DE OPTIMIZACIÓN — Industrial de Molinos
## Checkpoint de seguridad: commit `a48bf27` en `main`
## Fecha: 24 de marzo de 2026

---

## RESUMEN EJECUTIVO

| Archivo | Líneas | Problema Principal |
|---------|--------|--------------------|
| `employees_page.dart` | **18,197** | Monolito con 5 tabs, 18 diálogos, 7 violaciones Supabase |
| `reports_analytics_page.dart` | **6,120** | Monolito con 6 tabs (sin violaciones) |
| `new_sale_page.dart` | **4,629** | Monolito stepper 4 pasos |
| `daily_cash_page.dart` | **3,140** | 8 diálogos inline |
| `invoice_scan_dialog.dart` | **2,852** | Widget de 4 pasos en un solo archivo |
| `local_database.dart` | ~200 | Código muerto (SQLite sin usar) |
| Datasources varios | ~20 queries | `.select()` sin columnas, sin `.limit()` |

---

# FASE 1: LIMPIEZA DE CÓDIGO MUERTO
**Estimación: 1 sesión**

### 1.1 Eliminar `local_database.dart`
- **Archivo**: `lib/data/datasources/local_database.dart`
- **Razón**: Clase SQLite que nunca se importa ni se usa. La app usa Supabase directamente.
- **Acción**: Eliminar el archivo. Buscar cualquier import residual y eliminarlo.
- **Riesgo**: Ninguno — confirmado sin referencias.

### 1.2 Evaluar consolidación `recipes_datasource.dart` + `composite_products_datasource.dart`
- **Problema**: Ambos acceden a las tablas `products` y `product_components` con `is_recipe=true`.
- **Diferencia**: `RecipeDataSource` usa `.select()` genérico, `CompositeProductsDataSource` tiene pricing en vivo.
- **Acción**: Documentar pero NO consolidar aún. Primero optimizar cada uno por separado. Consolidar en fase posterior.
- **Riesgo**: Medio — hay providers distintos (`recipesProvider` y `compositeProductsProvider`) que dependen de cada uno.

---

# FASE 2: OPTIMIZACIÓN DE DATASOURCES
**Estimación: 2-3 sesiones**

### 2.1 Optimizar `accounts_datasource.dart` — 16 queries sin columnas

**Archivo**: `lib/data/datasources/accounts_datasource.dart`

Cada `.select()` sin columnas trae TODAS las columnas de la tabla `accounts` (20+ campos) cuando la mayoría de usos solo necesitan `id`, `name`, `type`, `balance`.

| Método | Línea | Cambio |
|--------|-------|--------|
| `getAllAccounts()` | L19 | `.select()` → `.select('id, name, type, balance, is_active, created_at')` |
| `getAccountById()` | L34 | Mantener `.select()` (necesita todos los campos) |
| `updateAccountBalance()` | L53 | `.select()` → `.select('id, balance')` |
| `deleteAccount()` | L69 | `.select()` → `.select('id')` |
| `getAllMovements()` | L126 | `.select()` → `.select('id, account_id, type, amount, description, category, date, reference, person_name, created_at')` |
| Resto (L141, L164, L180, L200) | Movimientos | Mismo patrón que `getAllMovements` |

**Cómo verificar**: Ejecutar la página de Caja Diaria y Cuentas después de cada cambio. Verificar que los campos mostrados en las tarjetas siguen apareciendo.

### 2.2 Optimizar `invoices_datasource.dart` — Sin paginación

**Archivo**: `lib/data/datasources/invoices_datasource.dart`

| Método | Problema | Solución |
|--------|----------|----------|
| `getAll()` L16 | Sin `.limit()`, trae TODAS las facturas + items | Agregar `.limit(500)` y crear `getAllPaginated(page, pageSize)` |
| `getByStatus()` | Sin `.limit()` | Agregar `.limit(200)` |
| `getByCustomerId()` | Sin `.limit()` | Agregar `.limit(100)` |
| `getOverdue()` | Sin `.limit()` | Agregar `.limit(200)` |
| `getPending()` | Sin `.limit()` | Agregar `.limit(200)` |

**Nota**: El `getAll()` actual hace `.select('*, invoice_items(*)')` que es un JOIN pesado. Para la lista de facturas, primero cargar solo facturas y luego cargar items bajo demanda al abrir el detalle.

### 2.3 Optimizar `customers_datasource.dart` — Sin paginación

**Archivo**: `lib/data/datasources/customers_datasource.dart`

| Método | Problema | Solución |
|--------|----------|----------|
| `getAll()` L14 | `.select()` sin columnas + sin `.limit()` | `.select('id, name, document_type, document_number, phone, email, balance, is_active')` + `.limit(500)` |
| `getWithDebt()` | Sin `.limit()` | Agregar `.limit(200)` |
| `recalculateAllBalances()` | Carga TODOS los clientes en memoria | Procesar en lotes de 50 |

### 2.4 Optimizar `composite_products_datasource.dart` — 2 roundtrips

**Archivo**: `lib/data/datasources/composite_products_datasource.dart`

**Problema actual** (líneas 12-50):
```
Query 1: SELECT * FROM products WHERE is_active = true
Query 2: SELECT *, materials:material_id(*) FROM product_components WHERE product_id IN (...)
```

**Solución**: Usar un solo query con JOIN de Supabase:
```dart
final response = await _client
    .from('products')
    .select('id, name, sale_price, cost, is_recipe, product_components(*, materials:material_id(id, name, unit, current_price))')
    .eq('is_active', true)
    .order('name');
```

Esto reduce de 2 roundtrips a 1 y especifica columnas.

### 2.5 Optimizar `recipes_datasource.dart` — `.select()` genérico

**Archivo**: `lib/data/datasources/recipes_datasource.dart`

| Método | Cambio |
|--------|--------|
| `getRecipes()` L37 | `.select()` → `.select('id, name, sale_price, cost, is_recipe, description, created_at')` |
| `getRecipeComponents()` L87 | `.select()` ya tiene especificación — OK |
| `saveRecipe()` L116 | `.select()` en insert — OK (necesita ID de retorno) |

---

# FASE 3: DESCOMPOSICIÓN DE `employees_page.dart` (18,197 líneas → ~8 archivos)
**Estimación: 4-5 sesiones — ES LA FASE MÁS CRÍTICA**

## Arquitectura objetivo:

```
lib/presentation/pages/employees/
├── employees_page.dart              (~300 líneas — shell con TabBar)
├── employees_list_tab.dart          (~3,200 líneas — Tab 1)
├── employees_tasks_tab.dart         (~1,200 líneas — Tab 2)
├── employees_payroll_tab.dart       (~2,100 líneas — Tab 3)
├── employees_loans_tab.dart         (~1,000 líneas — Tab 4)
├── employees_incapacity_tab.dart    (~400 líneas — Tab 5)
└── dialogs/
    ├── employee_form_dialog.dart    (~450 líneas)
    ├── employee_detail_dialog.dart  (~900 líneas)
    ├── task_form_dialog.dart        (~500 líneas)
    ├── attendance_dialog.dart       (~750 líneas)
    ├── payroll_create_dialog.dart   (~2,900 líneas)
    ├── payroll_payment_dialog.dart  (~700 líneas)
    ├── loan_form_dialog.dart        (~600 líneas)
    ├── loan_payment_dialog.dart     (~400 líneas)
    └── incapacity_dialog.dart       (~350 líneas)
```

### 3.1 Tab "Empleados" (Lista + Dashboard) — Líneas 363–3575

**Archivo destino**: `employees_list_tab.dart`

**Qué contiene**:
- Panel izquierdo: lista de empleados con búsqueda y filtros
- Panel derecho: dashboard del empleado seleccionado
  - Tarjetas de resumen (horas, tareas, préstamos)
  - Calendario de quincena con indicadores por día
  - Historial de semana (7 tarjetas con detalle de horas)
  - Ajustes recientes del empleado

**Métodos a migrar**:
- `_buildEmployeeListPanel()` (L514–754)
- `_buildEmployeeDashboard()` (L1014–1138)
- `_buildEmployeeQuincenaSection()` (L1651–2315)
- `_buildWeekHistorySection()` (L2316–2632)
- `_buildAdjustmentCard()` (L2707–2882)
- `_buildDashboardPlaceholder()` (L2884–2927)
- `_buildQuincenaCalendarGrid()` (L7929–8088)
- `_buildAttendanceSummaryChip()` (L8108–8133)
- `_buildAttendanceStatusButton()` (L8146–8242)
- `_buildCalendarLegendDot()` (L8090–8106)
- Todos los helpers de chips, progress bars, etc.

**Estado local necesario**:
- `_searchController` — búsqueda de empleados
- `_filterStatus`, `_filterDepartment` — filtros
- `_selectedEmployee` — empleado seleccionado para dashboard
- `_weekOffset` — navegación de semanas
- `_showWeekHistory` — toggle de historial
- `_quincenaRefreshKey` — forzar refresh del calendario

**Provider que escucha**: `employeesProvider`

**Diálogos asociados** (extraer a `dialogs/`):
- `_showEmployeeDialog()` → `employee_form_dialog.dart`
- `_showEmployeeDetail()` → `employee_detail_dialog.dart`
- `_showDayStatusDialog()` → dentro de `attendance_dialog.dart`
- `_showAttendanceDialog()` → `attendance_dialog.dart`
- `_showAbsenceDurationDialog()` → `attendance_dialog.dart`
- `_showTimeHistoryDialog()` → `attendance_dialog.dart`
- `_showTimeAdjustmentDialog()` → `attendance_dialog.dart`

### 3.2 Tab "Tareas" — Líneas 3576–4706

**Archivo destino**: `employees_tasks_tab.dart`

**Qué contiene**:
- Barra de filtros compacta (estado, categoría, asignado)
- Tabla scrollable de tareas con columnas: nombre, asignado, prioridad, estado, tiempo estimado vs real, complejidad
- Vista de tarjetas para móvil

**Métodos a migrar**:
- `_buildTasksTab()` (L3576–4706)
- `_buildCompactFilter()` (L3931–4002)
- `_buildTaskRow()` (L4075–4187)
- `_buildTaskCard()` (L4539–4653)
- `_buildTimeCell()` (L4402–4474)
- `_buildComplexityBars()` (L4476–4537)

**Estado local necesario**:
- `_taskSearchController` — búsqueda
- `_taskFilterStatus`, `_taskFilterCategory`, `_taskFilterAssignee` — filtros
- `_taskDateRange` — rango de fechas

**Provider que escucha**: `employeesProvider` (subsección tareas)

**Diálogos asociados**:
- `_showTaskDialog()` → `task_form_dialog.dart`
- `_showAssignTaskDialog()` → `task_form_dialog.dart`
- `_showNfcAssignDialog()` → `task_form_dialog.dart`

### 3.3 Tab "Nómina" — Líneas 9681–11745

**Archivo destino**: `employees_payroll_tab.dart`

**Qué contiene**:
- Panel de control moderno con 4 tarjetas KPI (total nómina, promedio, empleados activos, tendencia)
- Tarjeta de distribución salarial (gráfico)
- Tabla de pagos recientes
- Tabla de empleados con nómina (expandible con detalle)

**Métodos a migrar**:
- `_buildPayrollTab()` (L9681–11745)
- `_buildCompactStatCard()` (L10175–10251)
- `_buildCompactTrendCard()` (L10253–10359)
- `_buildCompactDistributionCard()` (L10361–10499)
- `_buildCompactPaymentsTable()` (L10501–10854)
- `_buildPayrollEmployeesTable()` (L10857–11026)
- `_buildPayrollRow()` (L11029–11360)
- `_buildPayrollCard()` (L11609–11744)

**Provider que escucha**: `payrollProvider`

**Diálogos asociados** (extraer a `dialogs/`):
- `_showCreatePayrollDialog()` (L13095–15929) → `payroll_create_dialog.dart` — **¡2,834 líneas solo este diálogo!**
  - Incluye: selección de empleado, cálculo diferenciado por tipo de pago (diario/hora/quincena/mensual), conceptos de devengos/deducciones, preview de nómina, botón de aprobar
  - Subsecciones internas:
    - Cálculo para pago diario (L13443+)
    - Cálculo para pago por hora (L13600+)
    - Cálculo para pago quincenal (L13800+)
    - Sección de horas extras (L14730+)
    - Preview final (L15200+)
- `_showPayrollDetailDialog()` (L11236–11367) → `payroll_payment_dialog.dart`
- `_showAddConceptDialog()` (L15931–16055) → `payroll_payment_dialog.dart`
- `_showPayPayrollDialog()` (L16057–16479) → `payroll_payment_dialog.dart`
  - ⚠️ **VIOLACIÓN**: Línea 16059 hace `.from('accounts').select()` directo
  - **FIX**: Usar `AccountsDataSource.getAllAccounts()` o mejor aún, el provider
- `_showMonthlyPaymentDialog()` (L16575–17252) → `payroll_payment_dialog.dart`

### 3.4 Tab "Préstamos" — Líneas 11749–12726

**Archivo destino**: `employees_loans_tab.dart`

**Qué contiene**:
- Resumen del portafolio de préstamos (total prestado, pendiente, pagado)
- Lista de préstamos activos con estado de pago
- Botones de acción: nuevo préstamo, registrar pago, adelanto

**Métodos a migrar**:
- `_buildLoansTab()` (L11749–12726)
- Helpers de tarjetas de préstamo

**Provider que escucha**: `payrollProvider` (subsección préstamos)

**Diálogos asociados** (extraer a `dialogs/`):
- `_showLoanDialog()` (L17255–17851) → `loan_form_dialog.dart`
- `_showAdelantoDialog()` (L12006–12257) → `loan_payment_dialog.dart`
  - ⚠️ **VIOLACIÓN**: Línea 12008 hace `.from('accounts').select()` directo
  - **FIX**: Inyectar lista de cuentas desde el provider
- `_showManualLoanPaymentDialog()` (L12259–12643) → `loan_payment_dialog.dart`
  - ⚠️ **VIOLACIÓN**: Línea 12261 hace `.from('accounts').select()` directo
  - **FIX**: Inyectar lista de cuentas desde el provider

### 3.5 Tab "Incapacidades" — Líneas 12729–13090

**Archivo destino**: `employees_incapacity_tab.dart`

**Qué contiene**:
- Calendario de incapacidades
- Lista de registros de ausencia (tipo, duración, empleado)
- Estadísticas de ausencias por tipo

**Métodos a migrar**:
- `_buildIncapacitiesTab()` (L12729–13090)

**Diálogos asociados**:
- `_showIncapacityDialog()` (L17853+) → `incapacity_dialog.dart`

### 3.6 Corregir violaciones Supabase en `employees_page.dart`

| Ubicación | Tabla | Operación | Fix |
|-----------|-------|-----------|-----|
| `_showAdelantoDialog()` L12008 | `accounts` | SELECT | Pasar `List<Account>` como parámetro del diálogo |
| `_showManualLoanPaymentDialog()` L12261 | `accounts` | SELECT | Pasar `List<Account>` como parámetro del diálogo |
| `_showPayPayrollDialog()` L16059 | `accounts` | SELECT | Pasar `List<Account>` como parámetro del diálogo |
| `_executeDeletePayroll()` L16486 | `cash_movements` | SELECT | Crear `PayrollDataSource.revertPayrollPayment()` |
| `_executeDeletePayroll()` L16498 | `accounts` | SELECT+UPDATE | Incluir en `PayrollDataSource.revertPayrollPayment()` |
| `_executeDeletePayroll()` L16515 | `payroll` | UPDATE | Incluir en `PayrollDataSource.revertPayrollPayment()` |
| `_executeDeletePayroll()` L16525 | `cash_movements` | DELETE | Incluir en `PayrollDataSource.revertPayrollPayment()` |

**Solución**: Crear un método `PayrollDataSource.revertPayrollPayment(payrollId)` que haga TODO en un RPC o transacción server-side.

### 3.7 Shell coordinator (`employees_page.dart` final — ~300 líneas)

El archivo principal queda como coordinador:
```dart
class EmployeesPage extends ConsumerStatefulWidget { ... }

class _EmployeesPageState extends ConsumerState<EmployeesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeaderStats(),             // 4 stat chips
          TabBar(controller: _tabController, tabs: [...]),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                EmployeesListTab(),        // Tab 1
                EmployeesTasksTab(),       // Tab 2
                EmployeesPayrollTab(),     // Tab 3
                EmployeesLoansTab(),       // Tab 4
                EmployeesIncapacityTab(),  // Tab 5
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }
}
```

### 3.8 Painter class `_WaveChartPainter` (L18113+)

**Archivo destino**: `lib/presentation/widgets/wave_chart_painter.dart`
- CustomPainter reutilizable para gráficos de onda
- Se usa solo en la tab de nómina → puede ir dentro de `employees_payroll_tab.dart` si es exclusivo

---

# FASE 4: DESCOMPOSICIÓN DE `reports_analytics_page.dart` (6,120 líneas → ~7 archivos)
**Estimación: 2-3 sesiones**

## Arquitectura objetivo:

```
lib/presentation/pages/reports/
├── reports_analytics_page.dart        (~400 líneas — shell con TabBar)
├── tabs/
│   ├── analytics_tab.dart             (~3,200 líneas)
│   ├── inventory_report_tab.dart      (~550 líneas)
│   ├── cobranzas_tab.dart             (~530 líneas)
│   ├── mora_intereses_tab.dart        (~760 líneas)
│   ├── cash_flow_tab.dart             (~580 líneas)
│   └── employee_expenses_tab.dart     (~410 líneas — ya es clase separada)
└── painters/
    └── cumulative_line_painter.dart   (~60 líneas)
```

### 4.1 Tab "Analytics" — L452–3661 (~3,200 líneas)

**El tab más grande**. Contiene:
- KPI cards (ventas, margen, DSO, CEI)
- Gráficos de tendencia
- Health score card
- Top productos
- Top clientes

**Provider**: `analyticsProvider`

### 4.2 Tab "Inventario" — L3662–4199

**Contiene**: Stock actual, materiales bajo mínimo, valoración de inventario
**Provider**: Necesita un `inventoryReportProvider` (o reutilizar `inventoryProvider`)

### 4.3 Tab "Cobranzas" — L4200–4722

**Contiene**: Lista de facturas pendientes de cobro, aging analysis
**Provider**: `invoicesProvider` (filtrando por pendientes)

### 4.4 Tab "Mora e Intereses" — L4723–5477

**Contiene**: Cálculo de intereses moratorios, facturas vencidas
**Provider**: `invoicesProvider` + `customersProvider`

### 4.5 Tab "Flujo de Caja" — L5478–6054

**Contiene**: Flujo de caja proyectado, gráfico acumulativo
**Ya tiene clase separada parcial**: `_CashFlowTabContent` (StatefulWidget)
**No necesita mucho trabajo** — solo extraer a su propio archivo

### 4.6 Tab "Gastos Empleados" — L6114–6520

**Ya es una clase separada**: `_EmployeeExpensesTab`
**Solo necesita**: mover a su propio archivo

---

# FASE 5: DESCOMPOSICIÓN DE `new_sale_page.dart` (4,629 líneas → ~5 archivos)
**Estimación: 2 sesiones**

## Arquitectura objetivo:

```
lib/presentation/pages/sales/
├── new_sale_page.dart                 (~500 líneas — stepper shell)
├── steps/
│   ├── customer_step.dart             (~200 líneas)
│   ├── components_step.dart           (~600 líneas)
│   ├── costs_step.dart                (~350 líneas)
│   └── payment_step.dart              (~400 líneas)
├── sale_summary_panel.dart            (~500 líneas)
├── sale_preview_dialog.dart           (~400 líneas)
└── stock_verification_card.dart       (~200 líneas)
```

### 5.1 Fix violación: L289 `AccountsDataSource.getAllAccounts()`
**Cambiar a**: `ref.read(accountsProvider.notifier).loadAccounts()` y obtener desde el state

---

# FASE 6: DESCOMPOSICIÓN DE `daily_cash_page.dart` (3,140 líneas → ~4 archivos)
**Estimación: 1-2 sesiones**

## Arquitectura objetivo:

```
lib/presentation/pages/cash/
├── daily_cash_page.dart               (~700 líneas — layout principal)
├── dialogs/
│   ├── add_movement_dialog.dart       (~500 líneas — ya es clase interna)
│   ├── transfer_dialog.dart           (~400 líneas — ya es clase interna)
│   ├── history_dialog.dart            (~350 líneas)
│   └── create_person_dialog.dart      (~250 líneas)
└── widgets/
    └── account_summary_card.dart      (~200 líneas)
```

**Nota**: `daily_cash_page.dart` ya tiene buena separación interna con clases `_AddMovementDialog` y `_TransferDialog`. Solo hay que moverlas a archivos separados.

---

# FASE 7: OPTIMIZACIONES TRANSVERSALES
**Estimación: 1-2 sesiones**

### 7.1 Agregar `audit_logs` a operaciones críticas

Usando la migración `068_audit_logs.sql` y el `AuditLogDatasource`, agregar logging a:
- Creación/edición de facturas
- Pagos de nómina
- Movimientos de caja
- Cambios de stock
- Aprobación de órdenes de producción

### 7.2 Implementar lazy loading en tabs

Actualmente el `TabBarView` renderiza TODOS los tabs al inicio. Cambiar a:
```dart
TabBarView(
  children: [
    _currentTab == 0 ? EmployeesListTab() : const SizedBox(),
    _currentTab == 1 ? EmployeesTasksTab() : const SizedBox(),
    // etc.
  ],
)
```
O mejor: usar `AutomaticKeepAliveClientMixin` solo en los tabs más usados.

### 7.3 Implementar debounce en búsquedas

Los campos de búsqueda en empleados, clientes, productos hacen query a Supabase en cada tecla. Agregar debounce de 300ms:
```dart
Timer? _debounce;
void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    // ejecutar búsqueda
  });
}
```

---

# ORDEN DE EJECUCIÓN RECOMENDADO

| Paso | Fase | Qué hacer | Impacto |
|------|------|-----------|---------|
| **1** | 1.1 | Eliminar `local_database.dart` | Bajo esfuerzo, limpieza |
| **2** | 2.1–2.5 | Optimizar datasources (columnas + límites) | Reduce tráfico de red 40-60% |
| **3** | 3.7 | Crear shell `employees_page.dart` con TabBar | Estructura base |
| **4** | 3.1 | Extraer Tab "Empleados" (lista + dashboard) | -3,200 líneas |
| **5** | 3.2 | Extraer Tab "Tareas" | -1,200 líneas |
| **6** | 3.3 | Extraer Tab "Nómina" + diálogos de pago | -2,100 líneas + -2,834 líneas diálogos |
| **7** | 3.4 | Extraer Tab "Préstamos" + diálogos de préstamo | -1,000 líneas |
| **8** | 3.5 | Extraer Tab "Incapacidades" | -400 líneas |
| **9** | 3.6 | Corregir violaciones Supabase en empleados | Limpieza arquitectónica |
| **10** | 4.1–4.6 | Descomponer `reports_analytics_page.dart` | -5,700 líneas |
| **11** | 5.1 | Descomponer `new_sale_page.dart` | -4,100 líneas |
| **12** | 6 | Descomponer `daily_cash_page.dart` | -2,400 líneas |
| **13** | 7 | Optimizaciones transversales (audit, lazy, debounce) | Performance general |

---

# CRITERIOS DE ÉXITO

Después de completar todas las fases:

- [ ] Ningún archivo `.dart` de UI supera **2,000 líneas**
- [ ] **0 llamadas** directas a Supabase desde `presentation/`
- [ ] Todos los `getAll()` tienen `.limit()` o paginación
- [ ] Los `.select()` especifican columnas (excepto casos puntuales que necesitan todo)
- [ ] Hot reload en `employees_page.dart` tarda **<2 segundos** (vs ~8-10 actual)
- [ ] Todas las operaciones críticas generan audit log
- [ ] La app sigue funcionando igual — sin regresiones visibles
- [ ] Tests de diagnóstico (`/diagnostics`) pasan al 100%

---

# CÓMO REVERTIR SI ALGO SALE MAL

```powershell
# Volver al checkpoint pre-optimización
git reset --hard a48bf27
git push --force origin main
```

Esto restaura TODA la app al estado funcional del 24 de marzo de 2026 antes de cualquier optimización.
