# Referencia de Base de Datos — Industrial de Molinos

> **Esquema consolidado:** `database/schema_consolidado.sql`  
> **Backend:** Supabase (PostgreSQL)  
> **Última actualización:** Febrero 2026

---

## Tablas (38)

### Configuración
| Tabla | Descripción |
|-------|-------------|
| `company_settings` | Datos de la empresa (RUC, dirección, tasa IGV) |
| `operational_costs` | Tarifas operativas (mano de obra/hora, energía/kWh, gas/m³, margen default) |

### Catálogos
| Tabla | Descripción |
|-------|-------------|
| `categories` | Categorías de productos (jerárquicas con `parent_id`) |
| `chart_of_accounts` | Plan contable (código, tipo, nivel) |

### Clientes
| Tabla | Descripción |
|-------|-------------|
| `customers` | Clientes individuales o empresas con límite de crédito y saldo |

### Productos & Materiales
| Tabla | Descripción |
|-------|-------------|
| `products` | Productos terminados; si `is_recipe=true`, se fabrica desde componentes |
| `materials` | Materia prima (acero, etc.) con stock, precio/kg, densidad |
| `product_components` | BOM: componentes de un producto-receta (liga `products` ↔ `materials`) |

### Cotizaciones
| Tabla | Descripción |
|-------|-------------|
| `quotations` | Cotización con costos indirectos y margen de ganancia |
| `quotation_items` | Ítems de cotización con peso, precio/kg, costo unitario |

### Facturación
| Tabla | Descripción |
|-------|-------------|
| `invoices` | Facturas con `full_number` generado, estado, montos pagados/pendientes |
| `invoice_items` | Ítems de factura con `cost_price` auto-filled por trigger |
| `payments` | Pagos parciales o totales contra facturas |
| `invoice_interests` | Intereses moratorios aplicados a facturas vencidas |

### Finanzas / Caja
| Tabla | Descripción |
|-------|-------------|
| `accounts` | Cuentas de efectivo y bancarias con saldo en tiempo real |
| `cash_movements` | Movimientos de caja (ingresos, gastos, traslados) |

### Proveedores
| Tabla | Descripción |
|-------|-------------|
| `proveedores` | Proveedores con datos de contacto, cuenta bancaria, rating |

### Compras
| Tabla | Descripción |
|-------|-------------|
| `purchases` | Órdenes de compra con estado de pago y recepción |
| `purchase_items` | Ítems de compra con cantidad recibida vs. pedida |

### Inventario — Movimientos
| Tabla | Descripción |
|-------|-------------|
| `stock_movements` | Movimientos de stock de productos (entrada/salida/ajuste) |
| `material_movements` | Movimientos de materia prima con referencia a cotización/factura |
| `material_price_history` | Historial de cambios de precio de materiales |

### Recursos Humanos
| Tabla | Descripción |
|-------|-------------|
| `employees` | Empleados con datos personales, salario, tarifa/hora |
| `payroll_concepts` | Conceptos de nómina (ingresos y descuentos) |
| `payroll_periods` | Períodos de nómina (quincenal/mensual) |
| `payroll` | Nómina por empleado y período |
| `payroll_details` | Detalle de conceptos aplicados a cada nómina |
| `employee_incapacities` | Incapacidades médicas de empleados |
| `employee_loans` | Préstamos otorgados a empleados con cuotas |
| `loan_payments` | Pagos de cuotas de préstamos |
| `employee_tasks` | Tareas asignadas a empleados |

### Time Tracking
| Tabla | Descripción |
|-------|-------------|
| `employee_time_entries` | Registros diarios de asistencia (check-in/check-out) |
| `employee_time_sheets` | Hojas de tiempo semanales con minutos trabajados/extras/déficit |
| `employee_time_adjustments` | Ajustes manuales de tiempo |
| `employee_task_time_logs` | Registro de tiempo dedicado a tareas específicas |

### Actividades & Notificaciones
| Tabla | Descripción |
|-------|-------------|
| `activities` | Calendario/organizador con tipos (pago, entrega, reunión, etc.) |
| `notifications` | Alertas del sistema (stock bajo, facturas vencidas, recordatorios) |

### Analítica
| Tabla | Descripción |
|-------|-------------|
| `monthly_expenses` | Gastos fijos mensuales (electricidad, gas, alquiler, etc.) con `total_fixed` calculado |

### Auditoría
| Tabla | Descripción |
|-------|-------------|
| `sync_log` | Log de sincronización con datos old/new en JSONB |

---

## Tipos Enumerados (8)

| Enum | Valores |
|------|---------|
| `customer_type` | `individual`, `business` |
| `document_type` | `cc`, `nit`, `ce`, `pasaporte`, `ti`, `ruc`, `dni` |
| `quotation_status` | `Borrador`, `Enviada`, `Aprobada`, `Rechazada`, `Vencida`, `Anulada` |
| `component_type` | `cylinder`, `circular_plate`, `rectangular_plate`, `shaft`, `ring`, `custom`, `product` |
| `invoice_type` | `invoice`, `receipt`, `credit_note`, `debit_note` |
| `invoice_status` | `draft`, `issued`, `paid`, `partial`, `cancelled`, `overdue` |
| `payment_method` | `cash`, `card`, `transfer`, `credit`, `check`, `yape`, `plin` |
| `stock_movement_type` | `incoming`, `outgoing`, `adjustment` |

---

## Vistas Materializadas (4)

| Vista | Descripción | Índice único |
|-------|-------------|--------------|
| `mv_receivables_kpis` | KPIs de cuentas por cobrar (AR total, DSO, CEI) | `refreshed_at` |
| `mv_profit_loss_monthly` | P&L mensual (ingresos vs. gastos fijos + variables) | `period` |
| `mv_inventory_abc_analysis` | Clasificación ABC de productos por revenue | `product_id` |
| `mv_customer_payment_behavior` | Comportamiento de pago de clientes | `customer_id` |

Se refrescan con: `SELECT refresh_materialized_views();`

Vistas de compatibilidad (`v_receivables_kpis`, `v_profit_loss_monthly`, etc.) envuelven las materializadas para queries directos.

---

## Funciones RPC Principales

### Inventario
| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `deduct_inventory_item` | `material_id`, `product_id`, `quantity`, `reference`, `reason`, `quotation_id?`, `invoice_id?` | Descuenta material o producto (bulk para recetas) |
| `approve_quotation_with_materials` | `p_quotation_id` | Aprueba cotización → crea factura + descuenta inventario |
| `deduct_inventory_for_invoice` | `p_invoice_id` | Descuenta inventario para los ítems de una factura |
| `revert_material_deduction` | `p_quotation_id?`, `p_invoice_id?` | Revierte descuentos de inventario |

### Pagos
| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `register_payment` | `invoice_id`, `amount`, `method`, `reference?`, `notes?` | Registra pago y actualiza estado de factura |

### Finanzas (Atómicas)
| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `atomic_transfer` | `from_account_id`, `to_account_id`, `amount`, `description`, `date?`, `reference?` | Transferencia atómica con `SELECT FOR UPDATE` |
| `atomic_movement_with_balance` | `account_id`, `type`, `category`, `amount`, `description`, `reference?`, `person_name?`, `date?` | Movimiento + actualización de saldo atómica |

### Nómina
| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `calculate_payroll_totals` | `payroll_id` | Recalcula ingresos/descuentos/neto de una nómina |

### Analítica
| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `refresh_materialized_views` | — | Refresca las 4 vistas materializadas con timing |
| `get_dso_trend` | `p_months` (default 12) | Tendencia DSO mensual |

### Utilidades
| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `generate_quotation_number` | — | Genera `COT-YYYY-NNNN` secuencial |
| `generate_invoice_number` | `series` | Genera número de factura secuencial para la serie |
| `generate_purchase_number` | — | Genera `OC-YYYY-NNNN` secuencial |
| `recalculate_quotation_totals` | `quotation_id` | Recalcula materiales, subtotal, margen, total |

---

## Triggers Automáticos

| Trigger | Tabla | Acción |
|---------|-------|--------|
| `update_*_updated_at` | customers, products, quotations, invoices, accounts, proveedores, activities, employee_tasks | Auto-actualiza `updated_at` |
| `recalculate_quotation_on_item_change` | quotation_items | Recalcula totales al agregar/editar/eliminar ítems |
| `trigger_purchase_received` | purchases | Actualiza stock al recibir compra |
| `trigger_material_price_change` | materials | Registra historial de precios |
| `trg_validate_product_stock` | products | Impide stock negativo |
| `trg_validate_material_stock` | materials | Impide stock negativo |
| `trg_calculate_worked_minutes` | employee_time_entries | Calcula minutos trabajados/extras/déficit |
| `trg_calculate_task_minutes` | employee_task_time_logs | Calcula duración de time logs |
| `trg_auto_fill_invoice_item_cost` | invoice_items | Auto-rellena `cost_price` desde producto/material |
| `trg_auto_fill_quotation_item_cost` | quotation_items | Auto-rellena `cost_price` desde producto/material |

---

## Seguridad (RLS)

- **Todas las tablas** tienen RLS habilitado con `FORCE ROW LEVEL SECURITY`
- **Rol `authenticated`**: SELECT, INSERT, UPDATE, DELETE permitidos
- **Rol `anon`**: bloqueado completamente (REVOKE ALL)
- Funciones: REVOKE de `anon`, GRANT a `authenticated`
- Secuencias: REVOKE de `anon`, GRANT USAGE+SELECT a `authenticated`

---

## Flujos de Negocio Principales

### Cotización → Factura → Pago
```
1. Crear cotización (quotations + quotation_items)
2. Aprobar cotización → approve_quotation_with_materials()
   ├── Cambia status a 'Aprobada'
   ├── Crea factura (invoices + invoice_items)
   └── Descuenta inventario (materials/products con movimientos)
3. Registrar pago → register_payment()
   ├── Crea payment
   ├── Actualiza paid_amount en invoice
   └── Cambia status a 'partial' o 'paid'
```

### Movimiento de Caja
```
1. Ingreso/Gasto → atomic_movement_with_balance()
   ├── Crea cash_movement
   └── Actualiza balance de cuenta atómicamente
2. Transferencia → atomic_transfer()
   ├── Crea 2 cash_movements (salida + entrada)
   └── Actualiza balances de ambas cuentas con FOR UPDATE
```

### Compra → Recepción → Stock
```
1. Crear orden de compra (purchases + purchase_items)
2. Marcar como recibida → trigger_purchase_received
   ├── Actualiza stock de materials
   └── Registra material_movements
   └── Registra historial de precios si cambió
```

### Nómina
```
1. Crear período de nómina (payroll_periods)
2. Crear nómina por empleado (payroll)
3. Agregar conceptos detallados (payroll_details)
4. Recalcular → calculate_payroll_totals()
5. Registrar pago → actualiza status y crea cash_movement
```

---

## Arquitectura de la App Flutter

```
lib/
├── main.dart                    # Inicialización + Supabase + Riverpod
├── router.dart                  # go_router con 13 ramas
├── core/                        # Constantes, tema, extensiones
├── domain/entities/             # 18 entidades del dominio
├── data/
│   ├── datasources/             # Comunicación directa con Supabase
│   └── providers/               # Riverpod Notifiers (estado + lógica)
├── presentation/
│   ├── pages/                   # Páginas por módulo
│   └── widgets/                 # Widgets reutilizables
└── photo/                       # Gestión de fotos

test/
├── widget_test.dart             # Test básico de inicio
└── domain/entities/             # 88 tests unitarios
    ├── invoice_test.dart
    ├── quotation_test.dart
    ├── customer_test.dart
    ├── account_test.dart
    ├── cash_movement_test.dart
    └── inventory_material_test.dart
```

**Patrones clave:**
- Clean Architecture (Domain → Data → Presentation)
- Riverpod `Notifier<State>` para manejo de estado
- Optimistic updates con rollback automático en providers
- Operaciones atómicas via RPCs PostgreSQL (no múltiples requests)
- Vistas materializadas con vistas de compatibilidad para queries
