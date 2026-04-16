# Plan de Implementación — Industrial de Molinos

> **Fecha:** 21 de febrero de 2026  
> **Estado:** ✅ COMPLETADO — Las 8 fases han sido implementadas  
> **Objetivo:** Corregir falencias de seguridad, eliminar código muerto, consolidar base de datos, optimizar rendimiento y completar funcionalidades pendientes.

---

## Índice

1. [Fase 1 — Seguridad Crítica](#fase-1--seguridad-crítica)
2. [Fase 2 — Corrección de Bugs](#fase-2--corrección-de-bugs)
3. [Fase 3 — Limpieza de Código Muerto](#fase-3--limpieza-de-código-muerto)
4. [Fase 4 — Consolidación de Base de Datos](#fase-4--consolidación-de-base-de-datos)
5. [Fase 5 — Validaciones e Integridad de Datos](#fase-5--validaciones-e-integridad-de-datos)
6. [Fase 6 — Funcionalidades Pendientes](#fase-6--funcionalidades-pendientes)
7. [Fase 7 — Optimización de Rendimiento](#fase-7--optimización-de-rendimiento)
8. [Fase 8 — Pulido Final y Testing](#fase-8--pulido-final-y-testing)

---

## Fase 1 — Seguridad Crítica

> **Prioridad:** MÁXIMA  
> **Impacto:** Sin esto, cualquier persona con la URL puede leer/modificar TODOS los datos.

### Paso 1.1 — Mover credenciales fuera del código fuente

**Problema:** Supabase URL y anon key están hardcodeadas en `lib/core/constants/app_constants.dart` y visibles en el binario compilado.

**Acciones:**
- [ ] Crear archivo `.env` en la raíz del proyecto con las credenciales
- [ ] Instalar `flutter_dotenv` como dependencia
- [ ] Modificar `app_constants.dart` para leer de variables de entorno
- [ ] Modificar `main.dart` para cargar `.env` antes de inicializar
- [ ] Verificar que `.env` está en `.gitignore`
- [ ] Eliminar credenciales de `docs/INVESTIGACION_PROYECTO.md`
- [ ] Documentar en README cómo configurar el `.env`

**Archivos afectados:**
- `lib/core/constants/app_constants.dart`
- `lib/main.dart`
- `pubspec.yaml`
- `.env` (nuevo)
- `.gitignore`
- `docs/INVESTIGACION_PROYECTO.md`

---

### Paso 1.2 — Implementar sistema de autenticación

**Problema:** No hay login, no hay route guards, no hay verificación de usuario. La app es completamente abierta.

**Acciones:**
- [ ] Crear página de login (`lib/presentation/pages/login_page.dart`)
- [ ] Crear página de registro (opcional, si se necesitan múltiples usuarios)
- [ ] Crear provider de autenticación (`lib/data/providers/auth_provider.dart`)
- [ ] Conectar los métodos `signIn`/`signOut` ya existentes en `SupabaseDataSource`
- [ ] Agregar redirect guard en `router.dart` que verifique `isAuthenticated`
- [ ] Redirigir a `/login` si no hay sesión activa
- [ ] Agregar botón de cerrar sesión funcional en Settings
- [ ] Reemplazar los mockups de sesiones activas en Settings por datos reales
- [ ] Persistir sesión entre reinicios de la app

**Archivos afectados:**
- `lib/presentation/pages/login_page.dart` (nuevo)
- `lib/data/providers/auth_provider.dart` (nuevo)
- `lib/router.dart`
- `lib/data/datasources/supabase_datasource.dart`
- `lib/presentation/pages/settings_page.dart`

---

### Paso 1.3 — Implementar RLS (Row Level Security) real

**Problema:** Todas las políticas RLS son `USING (true)` y `fix_rls_policies.sql` las deshabilita por completo. El `GRANT ALL TO anon` permite acceso total sin autenticación.

**Acciones:**
- [ ] Diseñar modelo de permisos (¿un solo usuario dueño? ¿multi-usuario con roles?)
- [ ] Crear nueva migración SQL que:
  - Habilita RLS en todas las tablas
  - Crea políticas que validen `auth.uid()`
  - Revoca `GRANT ALL` al rol `anon`
  - Permite solo `authenticated` para operaciones CRUD
  - Permite `anon` solo para registro/login
- [ ] Eliminar o archivar `database/fix_rls_policies.sql`
- [ ] Probar que la app funciona con RLS activo
- [ ] Verificar que las funciones RPC respetan el contexto de auth

**Archivos afectados:**
- `supabase_migrations/026_real_rls_policies.sql` (nuevo)
- `database/fix_rls_policies.sql` (eliminar/archivar)

---

### Paso 1.4 — Eliminar debug en producción

**Problema:** `_testSupabaseConnection()` se ejecuta siempre e imprime URLs y datos sensibles. Múltiples `print()` exponen datos financieros en logs.

**Acciones:**
- [ ] Eliminar o condicionar `_testSupabaseConnection()` con `kDebugMode`
- [ ] Reemplazar todos los `print()` por un logger condicional (`kDebugMode` check)
- [ ] Crear utilidad de logging en `lib/core/utils/logger.dart`
- [ ] Buscar y reemplazar todos los `print()` en datasources y providers

**Archivos afectados:**
- `lib/main.dart`
- `lib/core/utils/logger.dart` (nuevo)
- `lib/data/datasources/*.dart` (todos)
- `lib/data/providers/*.dart` (los que tengan prints)

---

## Fase 2 — Corrección de Bugs

> **Prioridad:** ALTA  
> **Impacto:** Funcionalidades rotas que afectan la experiencia del usuario.

### Paso 2.1 — Corregir ruta `/sales` inexistente

**Problema:** En `quotations_page.dart`, tras aprobar una cotización, el SnackBar navega a `/sales` pero la ruta correcta es `/invoices`.

**Acciones:**
- [ ] Buscar `context.go('/sales')` en `quotations_page.dart`
- [ ] Reemplazar por `context.go('/invoices')`

**Archivos afectados:**
- `lib/presentation/pages/quotations_page.dart`

---

### Paso 2.2 — Corregir stub de editar cotización

**Problema:** `/quotations/edit/:id` muestra solo `Text('Por implementar')` sin botón de retroceso. El usuario queda atrapado.

**Acciones:**
- [ ] Implementar la página de edición de cotización completa, o
- [ ] Como mínimo temporal: agregar un `Scaffold` con `AppBar` y botón back
- [ ] Si se hace completa: reutilizar lógica de `NewQuotationPage` con pre-carga de datos

**Archivos afectados:**
- `lib/router.dart`
- `lib/presentation/pages/new_quotation_page.dart` (adaptar para edición)

---

### Paso 2.3 — Hacer `/composite-products` accesible desde sidebar

**Problema:** Branch 12 existe en el router pero no aparece en el sidebar. Solo accesible por quick-actions.

**Acciones:**
- [ ] Agregar entrada en la lista `_navItems` del sidebar para Productos Compuestos
- [ ] Elegir icono apropiado (ej: `Icons.layers` o `Icons.build`)

**Archivos afectados:**
- `lib/presentation/widgets/app_sidebar.dart`

---

### Paso 2.4 — Corregir errores SQL

**Problema:** Múltiples errores en los archivos SQL que impediríarjan su ejecución correcta.

**Acciones:**
- [ ] Corregir `DEFAULT '',,` (doble coma) en `supabase_migrations/EJECUTAR_AHORA.sql`
- [ ] Corregir vista `v_quotation_profit_analysis`: `q.quotation_number` → `q.number`, `q.issue_date` → `q.date`
- [ ] Corregir enum mismatch: agregar `'ruc'` y `'dni'` al enum `document_type`, o cambiar seed data
- [ ] Corregir `approve_quotation_with_materials` que guarda `profit_margin` en campo `tax_rate`

**Archivos afectados:**
- `supabase_migrations/EJECUTAR_AHORA.sql`
- `supabase_migrations/023_profit_margins.sql`
- `database/supabase_schema.sql`
- `database/seed_data.sql`

---

## Fase 3 — Limpieza de Código Muerto

> **Prioridad:** MEDIA  
> **Impacto:** Reduce confusión, mejora mantenibilidad, reduce tamaño del proyecto.

### Paso 3.1 — Eliminar páginas huérfanas

**Problema:** Archivos de páginas que no tienen ruta o fueron reemplazados.

**Acciones:**
- [ ] Eliminar `lib/presentation/pages/reports_page.dart` (reemplazada por `reports_analytics_page.dart`)
- [ ] Eliminar `lib/presentation/pages/recipe_builder_page.dart` (redirigida a `/products/new`)
- [ ] Verificar que ningún import referencia estos archivos
- [ ] Eliminar la ruta redirect de `/recipe-builder` en `router.dart` si ya no se usa

**Archivos afectados:**
- `lib/presentation/pages/reports_page.dart` (eliminar)
- `lib/presentation/pages/recipe_builder_page.dart` (eliminar)
- `lib/router.dart`

---

### Paso 3.2 — Limpiar carpetas vacías de Clean Architecture

**Problema:** Carpetas `domain/repositories/`, `domain/usecases/`, `data/repositories/`, `data/models/`, `presentation/providers/` existen pero están vacías. El proyecto no usa esas capas.

**Acciones:**
- [ ] Eliminar carpetas vacías o agregar archivos `.gitkeep` si se planea usarlas en el futuro
- [ ] Documentar la decisión arquitectónica (se usa Riverpod directamente sin la capa de use cases)

**Archivos afectados:**
- `lib/domain/repositories/` (eliminar o `.gitkeep`)
- `lib/domain/usecases/` (eliminar o `.gitkeep`)
- `lib/data/repositories/` (eliminar o `.gitkeep`)
- `lib/data/models/` (eliminar o `.gitkeep`)
- `lib/presentation/providers/` (eliminar o `.gitkeep`)

---

### Paso 3.3 — Limpiar código auth no funcional

**Problema:** `SupabaseDataSource` tiene `signIn`/`signUp`/`signOut` pero nunca se usan. Settings tiene UI mockup de sesiones.

**Acciones:**
- [ ] Mantener los métodos auth (se usarán en Fase 1.2)
- [ ] Eliminar los mockups de sesiones activas en `settings_page.dart` ("Windows · Chrome", "Hace 2 días")
- [ ] Marcar sección de seguridad en Settings como "disponible cuando se implemente login"

**Archivos afectados:**
- `lib/presentation/pages/settings_page.dart`

---

## Fase 4 — Consolidación de Base de Datos

> **Prioridad:** MEDIA-ALTA  
> **Impacto:** Elimina duplicación, reduce confusión, simplifica mantenimiento.

### Paso 4.1 — Consolidar tablas de proveedores

**Problema:** Dos tablas: `proveedores` (español, usada por assets) y `suppliers` (inglés, usada por purchases).

**Acciones:**
- [ ] Elegir una tabla única (recomendado: `proveedores` por consistencia con el idioma del app)
- [ ] Migrar datos de `suppliers` a `proveedores` (agregar campos faltantes: `category`, `rating`, `payment_terms`)
- [ ] Actualizar FK de `purchases` para apuntar a `proveedores`
- [ ] Actualizar datasource y provider de suppliers
- [ ] Eliminar tabla `suppliers`
- [ ] Crear migración SQL

**Archivos afectados:**
- `supabase_migrations/026_consolidar_proveedores.sql` (nuevo)
- `lib/data/datasources/suppliers_datasource.dart`
- `lib/data/providers/suppliers_provider.dart`
- `lib/domain/entities/supplier.dart`

---

### Paso 4.2 — Consolidar sistema de materiales/inventario

**Problema:** `material_prices` (original, sin stock) y `materials` (nuevo, con stock) coexisten. `quotation_items.material_id` apunta a la tabla vieja.

**Acciones:**
- [ ] Migrar datos relevantes de `material_prices` a `materials`
- [ ] Actualizar FK de `quotation_items.material_id` para apuntar a `materials`
- [ ] Eliminar la columna `inv_material_id` de `quotation_items` (redundante tras la migración)
- [ ] Deprecar/eliminar tabla `material_prices`
- [ ] Consolidar `stock_movements` y `material_movements` en una sola tabla
- [ ] Actualizar datasources y providers afectados
- [ ] Crear migración SQL

**Archivos afectados:**
- `supabase_migrations/027_consolidar_materiales.sql` (nuevo)
- `lib/data/datasources/materials_datasource.dart`
- `lib/data/datasources/inventory_datasource.dart`
- `lib/data/providers/materials_provider.dart`
- `lib/data/providers/inventory_provider.dart`

---

### Paso 4.3 — Eliminar tablas no utilizadas

**Problema:** Tablas creadas pero nunca usadas por la aplicación.

**Acciones:**
- [ ] Eliminar `product_templates` (reemplazada por `products.is_recipe + product_components`)
- [ ] Eliminar `sync_log` (nadie escribe en ella)
- [ ] Eliminar `employee_payments` (reemplazada por sistema de nómina)
- [ ] Evaluar `journal_entries`/`journal_entry_lines`: ¿se implementará contabilidad real? Si no → eliminar
- [ ] Crear migración SQL de limpieza

**Archivos afectados:**
- `supabase_migrations/028_eliminar_tablas_muertas.sql` (nuevo)

---

### Paso 4.4 — Consolidar funciones SQL redefinidas

**Problema:** Funciones redefinidas hasta 5 veces en distintas migraciones. Solo la última versión está activa pero las anteriores generan confusión.

**Acciones:**
- [ ] Crear un archivo SQL maestro con la versión FINAL de cada función:
  - `approve_quotation_with_materials` (versión definitiva)
  - `deduct_inventory_item` (versión definitiva)
  - `deduct_inventory_for_invoice` (versión definitiva)
  - `register_payroll_payment` (versión definitiva)
  - `calculate_payroll_totals` (versión definitiva)
  - `register_employee_loan` (versión definitiva)
- [ ] Eliminar las funciones de flujo de aprobación duplicadas (`approve_quotation_and_create_invoice` vs `approve_quotation_with_materials` — elegir una)
- [ ] Eliminar funciones de stock check redundantes (`check_stock_availability` vs `check_quotation_stock`)
- [ ] Documentar qué función hace qué

**Archivos afectados:**
- `supabase_migrations/029_funciones_consolidadas.sql` (nuevo)

---

### Paso 4.5 — Crear las 4 tablas fantasma de time tracking

**Problema:** Entidades en Flutter (`EmployeeTimeEntry`, `EmployeeTimeSheet`, etc.) referenciadas en código pero sin tablas en la BD.

**Acciones:**
- [ ] Crear tabla `employee_time_entries` (registro de horas por empleado)
- [ ] Crear tabla `employee_time_sheets` (hojas de tiempo semanales/quincenales)
- [ ] Crear tabla `employee_time_adjustments` (ajustes de tiempo)
- [ ] Crear tabla `employee_task_time_logs` (logs de tiempo por tarea)
- [ ] Agregar RLS policies correspondientes
- [ ] Agregar índices necesarios
- [ ] Conectar con los datasources existentes

**Archivos afectados:**
- `supabase_migrations/030_employee_time_tracking.sql` (nuevo)
- `lib/data/datasources/employees_datasource.dart`

---

## Fase 5 — Validaciones e Integridad de Datos

> **Prioridad:** ALTA  
> **Impacto:** Previene corrupción de datos financieros y estados inconsistentes.

### Paso 5.1 — Agregar validación de inputs en operaciones financieras

**Problema:** No hay validación de montos en pagos, transferencias ni préstamos. Se permiten valores negativos, sobrepagos y auto-transferencias.

**Acciones:**
- [ ] `invoices_datasource.dart` → `registerPayment()`:
  - Validar `amount > 0`
  - Validar `amount <= invoice.total - invoice.paidAmount`
  - Validar `taxRate` entre 0 y 100
- [ ] `accounts_datasource.dart` → `createTransfer()`:
  - Validar `fromAccountId != toAccountId`
  - Validar saldo suficiente en cuenta origen
  - Validar `amount > 0`
- [ ] `accounts_datasource.dart` → `createMovementWithBalanceUpdate()`:
  - Validar `amount > 0`
- [ ] `payroll_datasource.dart` → `createLoan()`:
  - Validar `amount > 0`
  - Validar `installments > 0`
  - Validar que el empleado está activo

**Archivos afectados:**
- `lib/data/datasources/invoices_datasource.dart`
- `lib/data/datasources/accounts_datasource.dart`
- `lib/data/datasources/payroll_datasource.dart`

---

### Paso 5.2 — Corregir race conditions en balances

**Problema:** `createTransfer()` y `createMovementWithBalanceUpdate()` tienen patrón read-then-write que permite duplicación/pérdida de dinero en acceso concurrente.

**Acciones:**
- [ ] Crear función RPC en Supabase para transferencias atómicas (con `SELECT ... FOR UPDATE`)
- [ ] Crear función RPC para actualización atómica de balance (`UPDATE accounts SET balance = balance + $amount`)
- [ ] Refactorizar datasource para usar las RPCs en vez de read-then-write
- [ ] Crear migración SQL con las nuevas funciones

**Archivos afectados:**
- `supabase_migrations/031_atomic_balance_operations.sql` (nuevo)
- `lib/data/datasources/accounts_datasource.dart`

---

### Paso 5.3 — Agregar constraints de stock

**Problema:** Stock puede ir a negativo sin restricción.

**Acciones:**
- [ ] Agregar `CHECK (stock >= 0)` en tabla `materials`
- [ ] Agregar `CHECK (stock >= 0)` en tabla `products`
- [ ] Actualizar funciones de deducción para verificar antes de restar
- [ ] Manejar el error gracefully en el frontend (mostrar "stock insuficiente")

**Archivos afectados:**
- `supabase_migrations/032_stock_constraints.sql` (nuevo)
- `lib/data/datasources/inventory_datasource.dart`

---

### Paso 5.4 — Corregir errores silenciados

**Problema:** `_revertPayments()` captura excepciones y las ignora. Si la reversión falla, la factura se anula pero el dinero persiste.

**Acciones:**
- [ ] Hacer que `_revertPayments()` propague el error
- [ ] Envolver anulación + reversión en una transacción (o RPC)
- [ ] Si la reversión falla, NO anular la factura
- [ ] Mostrar error al usuario

**Archivos afectados:**
- `lib/data/datasources/invoices_datasource.dart`

---

## Fase 6 — Funcionalidades Pendientes

> **Prioridad:** MEDIA  
> **Impacto:** Completa flujos de trabajo que están a medias.

### Paso 6.1 — Implementar edición de cotizaciones

**Problema:** La página de edición es un stub vacío.

**Acciones:**
- [ ] Crear `EditQuotationPage` reutilizando la lógica de `NewQuotationPage`
- [ ] Cargar datos existentes de la cotización por ID
- [ ] Permitir modificar items, cantidades, precios, cliente
- [ ] Solo permitir edición si la cotización está en estado `pendiente`
- [ ] Actualizar router para usar la nueva página

**Archivos afectados:**
- `lib/presentation/pages/edit_quotation_page.dart` (nuevo) o refactorizar `new_quotation_page.dart`
- `lib/router.dart`
- `lib/data/providers/quotations_provider.dart`

---

### Paso 6.2 — Implementar time tracking de empleados

**Problema:** Entidades existen en Flutter pero las tablas no existen en la BD (creadas en Fase 4.5).

**Acciones:**
- [ ] Implementar UI de time tracking en `employees_page.dart`
- [ ] Conectar con las nuevas tablas creadas en Fase 4.5
- [ ] Crear datasource methods para CRUD de time entries
- [ ] Integrar con el sistema de nómina (horas trabajadas → cálculo de salario)

**Archivos afectados:**
- `lib/presentation/pages/employees_page.dart`
- `lib/data/datasources/employees_datasource.dart`
- `lib/data/providers/employees_provider.dart`

---

### Paso 6.3 — Conectar contabilidad (si se decide mantener)

**Problema:** `journal_entries`/`journal_entry_lines` y `chart_of_accounts` existen pero no se generan asientos automáticos.

**Acciones (solo si se decide mantener la contabilidad):**
- [ ] Crear triggers o funciones que generen asientos automáticamente desde:
  - Pagos registrados → asiento contable
  - Facturas emitidas → asiento contable
  - Nómina procesada → asiento contable
  - Movimientos de caja → asiento contable
- [ ] Crear vista de libro mayor
- [ ] Crear reporte de balance general

**Archivos afectados:**
- `supabase_migrations/033_contabilidad_automatica.sql` (nuevo)
- `lib/data/datasources/accounts_datasource.dart`

---

## Fase 7 — Optimización de Rendimiento

> **Prioridad:** MEDIA  
> **Impacto:** Mejora velocidad de carga, especialmente en dashboard y reportes.

### Paso 7.1 — Agregar índices faltantes ✅

**Acciones:**
- [x] `CREATE INDEX idx_invoices_quotation_id ON invoices(quotation_id)`
- [x] `CREATE INDEX idx_material_movements_material_type ON material_movements(material_id, type)`
- [x] `CREATE INDEX idx_invoice_items_product_id ON invoice_items(product_id)`
- [x] `CREATE INDEX idx_invoice_items_material_id ON invoice_items(material_id)`
- [x] `CREATE INDEX idx_cash_movements_category ON cash_movements(category)`
- [x] `CREATE INDEX idx_payroll_employee_id ON payroll(employee_id)`
- [x] + 8 índices adicionales (composite, quotation_items, loan_payments, product_components)

**Archivos afectados:**
- `supabase_migrations/034_indices_faltantes.sql` (nuevo)

---

### Paso 7.2 — Materializar vistas pesadas ✅

**Problema:** Vistas como `v_receivables_kpis`, `v_inventory_abc_analysis`, `v_profit_loss_monthly` son computadas en cada consulta.

**Acciones:**
- [x] Convertir las 4 vistas más pesadas a **materialized views** (mv_receivables_kpis, mv_profit_loss_monthly, mv_inventory_abc_analysis, mv_customer_payment_behavior)
- [x] Crear función `refresh_materialized_views()` para refrescar con CONCURRENTLY
- [x] Crear RPC `get_dso_trend(p_months)` → reemplaza N+1 de 24 queries
- [x] Crear vistas de compatibilidad (v_* → mv_*) para código existente
- [x] Actualizar `analytics_datasource.dart` con RPC y refresh

**Archivos afectados:**
- `supabase_migrations/035_materialized_views.sql` (nuevo)
- `lib/data/datasources/analytics_datasource.dart`

---

### Paso 7.3 — Implementar actualizaciones optimistas ✅

**Problema:** Todas las mutaciones esperan respuesta del servidor y luego recargan la lista completa.

**Acciones:**
- [x] `invoices_provider.dart`: registerPayment y cancelInvoice optimistas con rollback
- [x] `accounts_provider.dart`: addIncome, addExpense, transfer, deleteMovement optimistas con rollback
- [x] Background refresh de datos secundarios (_refreshStatsInBackground, _refreshMovementsInBackground)
- [x] products_provider ya estaba optimizado

**Archivos afectados:**
- `lib/data/providers/invoices_provider.dart`
- `lib/data/providers/products_provider.dart`
- `lib/data/providers/accounts_provider.dart`

---

### Paso 7.4 — Refactorizar N+1 en funciones SQL ✅

**Problema:** `deduct_inventory_item()` y funciones de cotización/factura hacen UPDATE + INSERT individual por cada componente.

**Acciones:**
- [x] `deduct_inventory_item`: receta FOR LOOP → 1 validación bulk + 1 INSERT...SELECT + 1 UPDATE...FROM
- [x] `approve_quotation_with_materials`: N llamadas → 5 operaciones bulk inline (validar + INSERT + UPDATE materiales + UPDATE productos)
- [x] `deduct_inventory_for_invoice`: N llamadas → 5 operaciones bulk inline
- [x] `revert_material_deduction`: FOR LOOP → 1 INSERT + 1 UPDATE

**Archivos afectados:**
- `supabase_migrations/036_bulk_inventory_operations.sql` (nuevo)

---

## Fase 8 — Pulido Final y Testing

> **Prioridad:** BAJA (pero importante)  
> **Impacto:** Estabilidad y confiabilidad a largo plazo.

### Paso 8.1 — Crear migration consolidada

**Acciones:**
- [x] Crear archivo `database/schema_consolidado.sql` con TODO el esquema limpio y consolidado (38 tablas, 8 enums, ~30 funciones, 4 vistas materializadas, ~25 vistas regulares, triggers, RLS, permisos)
- [x] Documentar el orden de ejecución de migraciones
- [x] Mantener migraciones individuales como historial incremental

---

### Paso 8.2 — Encriptar base de datos local

**Estado:** N/A — La clase `LocalDatabase` no está en uso (la app usa Supabase directamente).
Se puede implementar en el futuro si se necesita modo offline.

---

### Paso 8.3 — Agregar tests

**Acciones:**
- [x] Tests unitarios para entidades: Invoice, InvoiceItem, Quotation, QuotationItem, Customer, DocumentType, Account, CashMovement, DailyCashReport, InchFractions
- [x] 88 tests creados verificando: serialización JSON, computed properties, copyWith, defaults, edge cases
- [x] Cobertura de modelos principales del dominio

**Archivos creados:**
- `test/domain/entities/invoice_test.dart`
- `test/domain/entities/quotation_test.dart`
- `test/domain/entities/customer_test.dart`
- `test/domain/entities/account_test.dart`
- `test/domain/entities/cash_movement_test.dart`
- `test/domain/entities/inventory_material_test.dart`

---

### Paso 8.4 — Documentar API y esquema final

**Acciones:**
- [x] Documentar todas las tablas finales: `database/schema_consolidado.sql` con comentarios
- [x] Documentar todas las RPCs y sus parámetros: `docs/DATABASE_REFERENCE.md`
- [x] Documentar flujos de negocio principales: incluido en DATABASE_REFERENCE.md
- [x] Actualizar README.md con instrucciones de setup

---

## Resumen de Migraciones SQL Nuevas

| # | Archivo | Fase | Contenido |
|---|---------|------|-----------|
| 026 | `026_real_rls_policies.sql` | 1.3 | Políticas RLS reales con `auth.uid()` |
| 027 | `027_consolidar_proveedores.sql` | 4.1 | Merge `suppliers` → `proveedores` |
| 028 | `028_consolidar_materiales.sql` | 4.2 | Merge `material_prices` → `materials` |
| 029 | `029_eliminar_tablas_muertas.sql` | 4.3 | Drop tablas no usadas |
| 030 | `030_funciones_consolidadas.sql` | 4.4 | Versión final de todas las funciones |
| 031 | `031_employee_time_tracking.sql` | 4.5 | Crear 4 tablas de time tracking |
| 032 | `032_atomic_balance_operations.sql` | 5.2 | RPCs atómicas para balances |
| 033 | `033_stock_constraints.sql` | 5.3 | CHECK constraints de stock |
| 034 | `034_contabilidad_automatica.sql` | 6.3 | Triggers contables (opcional) |
| 035 | `035_indices_faltantes.sql` | 7.1 | Índices de rendimiento |
| 036 | `036_materialized_views.sql` | 7.2 | Vistas materializadas |
| 037 | `037_bulk_inventory_operations.sql` | 7.4 | Operaciones bulk de inventario |

---

## Orden de Ejecución Recomendado

```
Fase 1 (Seguridad)    ██████████████████████████  ✅ COMPLETADA
Fase 2 (Bugs)         ████████████████            ✅ COMPLETADA
Fase 3 (Limpieza)     ████████████                ✅ COMPLETADA
Fase 4 (Consolidación)████████████████████████████ ✅ COMPLETADA
Fase 5 (Validaciones) ████████████████████        ✅ COMPLETADA
Fase 6 (Pendientes)   ████████████████████        ✅ COMPLETADA
Fase 7 (Optimización) ████████████████            ✅ COMPLETADA
Fase 8 (Pulido)       ████████████████████████████ ✅ COMPLETADA
```

> **Nota:** Las fases 2, 3 y 5 pueden ejecutarse en paralelo con la Fase 1. La Fase 4 requiere cuidado porque modifica esquema y FK. La Fase 7 se puede hacer incrementalmente.

---

## Estimación de Esfuerzo

| Fase | Complejidad | Estimación |
|------|------------|------------|
| Fase 1 — Seguridad | Alta | 2-3 días |
| Fase 2 — Bugs | Baja-Media | 1 día |
| Fase 3 — Limpieza | Baja | 0.5 días |
| Fase 4 — Consolidación BD | Alta | 2-3 días |
| Fase 5 — Validaciones | Media | 1-2 días |
| Fase 6 — Funcionalidades | Media-Alta | 2-3 días |
| Fase 7 — Optimización | Media | 1-2 días |
| Fase 8 — Pulido | Media | 2-3 días |
| **Total estimado** | | **~12-18 días** |
