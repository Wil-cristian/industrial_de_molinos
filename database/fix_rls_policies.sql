-- =====================================================
-- FIX RLS POLICIES - Industrial de Molinos
-- Solo aplica políticas de seguridad (sin crear tablas)
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
-- HABILITAR RLS EN TODAS LAS TABLAS
-- =====================================================

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE material_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE operational_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- CREAR NUEVAS POLÍTICAS (Permisivas para desarrollo)
-- =====================================================

-- CATEGORIES
CREATE POLICY "categories_all_policy" ON categories FOR ALL USING (true) WITH CHECK (true);

-- CHART_OF_ACCOUNTS
CREATE POLICY "chart_of_accounts_all_policy" ON chart_of_accounts FOR ALL USING (true) WITH CHECK (true);

-- COMPANY_SETTINGS
CREATE POLICY "company_settings_all_policy" ON company_settings FOR ALL USING (true) WITH CHECK (true);

-- CUSTOMERS
CREATE POLICY "customers_all_policy" ON customers FOR ALL USING (true) WITH CHECK (true);

-- INVOICE_ITEMS
CREATE POLICY "invoice_items_all_policy" ON invoice_items FOR ALL USING (true) WITH CHECK (true);

-- INVOICES
CREATE POLICY "invoices_all_policy" ON invoices FOR ALL USING (true) WITH CHECK (true);

-- JOURNAL_ENTRIES
CREATE POLICY "journal_entries_all_policy" ON journal_entries FOR ALL USING (true) WITH CHECK (true);

-- JOURNAL_ENTRY_LINES
CREATE POLICY "journal_entry_lines_all_policy" ON journal_entry_lines FOR ALL USING (true) WITH CHECK (true);

-- MATERIAL_PRICES
CREATE POLICY "material_prices_all_policy" ON material_prices FOR ALL USING (true) WITH CHECK (true);

-- OPERATIONAL_COSTS
CREATE POLICY "operational_costs_all_policy" ON operational_costs FOR ALL USING (true) WITH CHECK (true);

-- PAYMENTS
CREATE POLICY "payments_all_policy" ON payments FOR ALL USING (true) WITH CHECK (true);

-- PRODUCT_TEMPLATES
CREATE POLICY "product_templates_all_policy" ON product_templates FOR ALL USING (true) WITH CHECK (true);

-- PRODUCTS
CREATE POLICY "products_all_policy" ON products FOR ALL USING (true) WITH CHECK (true);

-- PRODUCT_COMPONENTS
CREATE POLICY "product_components_all_policy" ON product_components FOR ALL USING (true) WITH CHECK (true);

-- QUOTATION_ITEMS
CREATE POLICY "quotation_items_all_policy" ON quotation_items FOR ALL USING (true) WITH CHECK (true);

-- QUOTATIONS
CREATE POLICY "quotations_all_policy" ON quotations FOR ALL USING (true) WITH CHECK (true);

-- STOCK_MOVEMENTS
CREATE POLICY "stock_movements_all_policy" ON stock_movements FOR ALL USING (true) WITH CHECK (true);

-- SYNC_LOG
CREATE POLICY "sync_log_all_policy" ON sync_log FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
