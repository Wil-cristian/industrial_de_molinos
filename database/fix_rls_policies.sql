-- =====================================================
-- FIX RLS POLICIES - Industrial de Molinos
-- Permite acceso anónimo (anon) y autenticado
-- =====================================================

-- Eliminar políticas antiguas si existen
DROP POLICY IF EXISTS "Allow all for authenticated users" ON categories;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON chart_of_accounts;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON company_settings;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON customers;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON invoice_items;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON invoices;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON journal_entries;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON journal_entry_lines;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON material_prices;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON operational_costs;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON payments;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON product_templates;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON products;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON product_components;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON quotation_items;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON quotations;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON stock_movements;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON sync_log;

-- Eliminar políticas nuevas si ya existen (para re-ejecutar el script)
DROP POLICY IF EXISTS "categories_all_policy" ON categories;
DROP POLICY IF EXISTS "chart_of_accounts_all_policy" ON chart_of_accounts;
DROP POLICY IF EXISTS "company_settings_all_policy" ON company_settings;
DROP POLICY IF EXISTS "customers_all_policy" ON customers;
DROP POLICY IF EXISTS "invoice_items_all_policy" ON invoice_items;
DROP POLICY IF EXISTS "invoices_all_policy" ON invoices;
DROP POLICY IF EXISTS "journal_entries_all_policy" ON journal_entries;
DROP POLICY IF EXISTS "journal_entry_lines_all_policy" ON journal_entry_lines;
DROP POLICY IF EXISTS "material_prices_all_policy" ON material_prices;
DROP POLICY IF EXISTS "operational_costs_all_policy" ON operational_costs;
DROP POLICY IF EXISTS "payments_all_policy" ON payments;
DROP POLICY IF EXISTS "product_templates_all_policy" ON product_templates;
DROP POLICY IF EXISTS "products_all_policy" ON products;
DROP POLICY IF EXISTS "product_components_all_policy" ON product_components;
DROP POLICY IF EXISTS "quotation_items_all_policy" ON quotation_items;
DROP POLICY IF EXISTS "quotations_all_policy" ON quotations;
DROP POLICY IF EXISTS "stock_movements_all_policy" ON stock_movements;
DROP POLICY IF EXISTS "sync_log_all_policy" ON sync_log;

-- =====================================================
-- OPCIÓN 1: DESACTIVAR RLS TEMPORALMENTE (DESARROLLO)
-- Esto permite acceso completo sin políticas
-- =====================================================

ALTER TABLE categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE chart_of_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE company_settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE invoices DISABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries DISABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_lines DISABLE ROW LEVEL SECURITY;
ALTER TABLE material_prices DISABLE ROW LEVEL SECURITY;
ALTER TABLE operational_costs DISABLE ROW LEVEL SECURITY;
ALTER TABLE payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE product_templates DISABLE ROW LEVEL SECURITY;
ALTER TABLE products DISABLE ROW LEVEL SECURITY;
ALTER TABLE product_components DISABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE quotations DISABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements DISABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log DISABLE ROW LEVEL SECURITY;

-- Tablas adicionales que pueden existir
ALTER TABLE IF EXISTS materials DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS assets DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS activities DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS proveedores DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS suppliers DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS cash_movements DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payroll DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payroll_details DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payroll_periods DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payroll_concepts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_loans DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS loan_payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_task_time_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_time_entries DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_time_sheets DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_time_adjustments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employee_incapacities DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS purchases DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS purchase_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS material_movements DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS material_price_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS monthly_expenses DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS asset_maintenance DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS invoice_interests DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
