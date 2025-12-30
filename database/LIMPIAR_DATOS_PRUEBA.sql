-- =====================================================
-- SCRIPT PARA LIMPIAR DATOS DE PRUEBA
-- Industrial de Molinos
-- =====================================================
-- ADVERTENCIA: Este script eliminará TODOS los datos
-- Ejecutar con precaución
-- =====================================================

-- =====================================================
-- 1. LIMPIAR TABLAS DE DATOS (en orden de dependencias)
-- =====================================================

-- Contabilidad
TRUNCATE TABLE journal_entry_lines CASCADE;
TRUNCATE TABLE journal_entries CASCADE;

-- Nómina y empleados (dependientes)
TRUNCATE TABLE payroll_details CASCADE;
TRUNCATE TABLE payroll CASCADE;
TRUNCATE TABLE payroll_periods CASCADE;
TRUNCATE TABLE loan_payments CASCADE;
TRUNCATE TABLE employee_loans CASCADE;
TRUNCATE TABLE employee_payments CASCADE;
TRUNCATE TABLE employee_task_time_logs CASCADE;
TRUNCATE TABLE employee_tasks CASCADE;
TRUNCATE TABLE employee_time_adjustments CASCADE;
TRUNCATE TABLE employee_time_entries CASCADE;
TRUNCATE TABLE employee_time_sheets CASCADE;
TRUNCATE TABLE employee_incapacities CASCADE;

-- Ventas y facturación
TRUNCATE TABLE invoice_interests CASCADE;
TRUNCATE TABLE invoice_items CASCADE;
TRUNCATE TABLE invoices CASCADE;
TRUNCATE TABLE quotation_items CASCADE;
TRUNCATE TABLE quotations CASCADE;
TRUNCATE TABLE payments CASCADE;

-- Compras
TRUNCATE TABLE purchase_items CASCADE;
TRUNCATE TABLE purchases CASCADE;

-- Movimientos de caja
TRUNCATE TABLE cash_movements CASCADE;

-- Inventario y productos
TRUNCATE TABLE stock_movements CASCADE;
TRUNCATE TABLE material_movements CASCADE;
TRUNCATE TABLE material_price_history CASCADE;
TRUNCATE TABLE material_prices CASCADE;
TRUNCATE TABLE product_components CASCADE;
TRUNCATE TABLE product_templates CASCADE;
TRUNCATE TABLE products CASCADE;
TRUNCATE TABLE materials CASCADE;

-- Activos
TRUNCATE TABLE asset_maintenance CASCADE;
TRUNCATE TABLE assets CASCADE;

-- Actividades y calendario
TRUNCATE TABLE activities CASCADE;

-- Costos
TRUNCATE TABLE monthly_expenses CASCADE;
TRUNCATE TABLE operational_costs CASCADE;

-- Sync
TRUNCATE TABLE sync_log CASCADE;

-- =====================================================
-- 2. LIMPIAR TABLAS PRINCIPALES (padres)
-- =====================================================

-- Clientes y proveedores
TRUNCATE TABLE customers CASCADE;
TRUNCATE TABLE suppliers CASCADE;
TRUNCATE TABLE proveedores CASCADE;

-- Empleados
TRUNCATE TABLE employees CASCADE;

-- =====================================================
-- 3. RESETEAR SALDOS DE CUENTAS (sin eliminar cuentas)
-- =====================================================

UPDATE accounts SET balance = 0 WHERE balance IS NOT NULL;

-- =====================================================
-- 4. TABLAS DE CONFIGURACIÓN (NO SE LIMPIAN)
-- Estas tablas contienen configuración, no datos de prueba:
-- - categories
-- - chart_of_accounts
-- - company_settings
-- - payroll_concepts
-- =====================================================

-- Si quieres limpiar TODO (incluido configuración), descomenta:
-- TRUNCATE TABLE categories CASCADE;
-- TRUNCATE TABLE chart_of_accounts CASCADE;
-- TRUNCATE TABLE company_settings CASCADE;
-- TRUNCATE TABLE payroll_concepts CASCADE;
-- TRUNCATE TABLE accounts CASCADE;

-- =====================================================
-- 5. VERIFICACIÓN
-- =====================================================

SELECT 'customers' as tabla, COUNT(*) as registros FROM customers
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'materials', COUNT(*) FROM materials
UNION ALL SELECT 'quotations', COUNT(*) FROM quotations
UNION ALL SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL SELECT 'cash_movements', COUNT(*) FROM cash_movements
UNION ALL SELECT 'activities', COUNT(*) FROM activities
UNION ALL SELECT 'assets', COUNT(*) FROM assets
UNION ALL SELECT 'payroll', COUNT(*) FROM payroll
UNION ALL SELECT 'purchases', COUNT(*) FROM purchases
UNION ALL SELECT 'journal_entries', COUNT(*) FROM journal_entries;

-- Verificar saldos de cuentas
SELECT name, balance FROM accounts;

-- =====================================================
-- LISTO! Base de datos limpia
-- =====================================================
