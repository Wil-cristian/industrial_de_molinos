-- =====================================================
-- SCRIPT: LIMPIAR DATOS TRANSACCIONALES
-- Borra TODOS los datos de prueba/operativos sin tocar
-- la configuración base (empleados, materiales, cuentas, etc.)
--
-- MODO 1: Solo transacciones (facturas, pagos, movimientos)
-- MODO 2: Todo incluyendo clientes y proveedores
-- =====================================================

-- ── MODO 1: Solo transacciones ──────────────────────
-- Descomenta el bloque que necesites y ejecuta en Supabase

/*
TRUNCATE TABLE
  cancellation_audit_log,
  invoice_interests,
  invoice_items,
  invoices,
  journal_entry_lines,
  journal_entries,
  payments,
  cash_movements,
  quotation_items,
  quotations,
  purchase_order_items,
  purchase_orders,
  material_movements,
  stock_movements
CASCADE;

SELECT 'Modo 1: Transacciones limpiadas ✅' as resultado;
*/

-- ── MODO 2: Todo incluyendo clientes y proveedores ──

TRUNCATE TABLE
  cancellation_audit_log,
  invoice_interests,
  invoice_items,
  invoices,
  journal_entry_lines,
  journal_entries,
  payments,
  cash_movements,
  quotation_items,
  quotations,
  purchase_order_items,
  purchase_orders,
  material_movements,
  stock_movements,
  customers,
  proveedores,
  supplier_materials,
  activities,
  sync_log
CASCADE;

-- Resetear stock de materiales y productos a 0
UPDATE materials SET stock = 0;
UPDATE products SET stock = 0;

SELECT 'Modo 2: Todo limpiado ✅' as resultado;

-- ── MODO 3: Limpieza total (incluye empleados y nómina) ──
/*
TRUNCATE TABLE
  cancellation_audit_log,
  invoice_interests,
  invoice_items,
  invoices,
  journal_entry_lines,
  journal_entries,
  payments,
  cash_movements,
  quotation_items,
  quotations,
  purchase_order_items,
  purchase_orders,
  material_movements,
  stock_movements,
  customers,
  proveedores,
  supplier_materials,
  activities,
  sync_log,
  payroll_details,
  payroll,
  payroll_periods,
  employee_loans,
  loan_payments,
  employee_task_time_logs,
  employee_tasks,
  employee_time_entries,
  employee_time_sheets,
  employee_time_adjustments,
  employee_incapacities,
  employees,
  assets,
  asset_maintenance,
  iva_invoices,
  iva_bimonthly_settlements,
  operational_costs
CASCADE;

UPDATE materials SET stock = 0;
UPDATE products SET stock = 0;

SELECT 'Modo 3: Limpieza total ✅' as resultado;
*/
