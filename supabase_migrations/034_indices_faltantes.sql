-- =====================================================
-- MIGRACIÓN 034: Índices Faltantes para Rendimiento
-- =====================================================
-- Agrega índices que faltan en tablas con JOINs y filtros frecuentes.
-- =====================================================

-- invoice_items: usado en JOINs de analytics, profit analysis, inventory deduction
CREATE INDEX IF NOT EXISTS idx_invoice_items_product_id 
    ON invoice_items(product_id);

CREATE INDEX IF NOT EXISTS idx_invoice_items_material_id 
    ON invoice_items(material_id);

-- quotation_items: usado en inventory deduction loops
CREATE INDEX IF NOT EXISTS idx_quotation_items_product_id 
    ON quotation_items(product_id);

CREATE INDEX IF NOT EXISTS idx_quotation_items_material_id 
    ON quotation_items(material_id);

-- material_movements: filtros por tipo frecuentes en vistas de consumo
CREATE INDEX IF NOT EXISTS idx_material_movements_type 
    ON material_movements(movement_type);

-- invoices: composite para filtros WHERE status + ORDER BY issue_date (dashboard, reportes)
CREATE INDEX IF NOT EXISTS idx_invoices_status_date 
    ON invoices(status, issue_date DESC);

-- invoices: FK de cotización (usado en approve_quotation)
CREATE INDEX IF NOT EXISTS idx_invoices_quotation_id 
    ON invoices(quotation_id);

-- cash_movements: composite para P&L y reportes de caja
CREATE INDEX IF NOT EXISTS idx_cash_movements_date_type 
    ON cash_movements(date, type);

CREATE INDEX IF NOT EXISTS idx_cash_movements_category 
    ON cash_movements(category);

-- cash_movements: búsqueda por referencia (usado en reversión de pagos)
CREATE INDEX IF NOT EXISTS idx_cash_movements_reference 
    ON cash_movements(reference);

-- payroll: composite para búsqueda de nómina por empleado + periodo
CREATE INDEX IF NOT EXISTS idx_payroll_employee_period 
    ON payroll(employee_id, period_id);

-- loan_payments: búsqueda por préstamo
CREATE INDEX IF NOT EXISTS idx_loan_payments_loan_date 
    ON loan_payments(loan_id, payment_date DESC);

-- product_components: composite para deducción de inventario
CREATE INDEX IF NOT EXISTS idx_product_components_product_material 
    ON product_components(product_id, material_id);
